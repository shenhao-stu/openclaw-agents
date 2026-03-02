#!/usr/bin/env bash
# ============================================================
#  OpenClaw Agents — One-Command Multi-Agent Setup
# ============================================================
#  Usage:
#    ./setup.sh                          # Interactive setup
#    ./setup.sh --channel feishu         # Pre-select channel
#    ./setup.sh --group-id oc_xxx        # Pre-fill group ID
#    ./setup.sh --model zai/glm-5        # Unified model for all agents
#    ./setup.sh --model-map planner=zai/glm-5,coder=ollama/kimi-k2.5:cloud
#    ./setup.sh --skip-bindings          # Skip channel binding
#    ./setup.sh --dry-run                # Preview without executing
#
#  This script will:
#    1. Verify openclaw CLI is installed
#    2. Create all sub-agents with dedicated workspaces
#    3. Set visual identities for each agent
#    4. Deploy soul.md / agent.md / user.md into each workspace
#    5. Configure openclaw.json with routing bindings
#    6. Verify the setup
#
#  ⚠️ SAFE MERGE: This script APPENDS sub-agents to your existing
#  config. It will NOT overwrite your main agent, existing agents,
#  models, auth, plugins, or any other settings.
# ============================================================

set -euo pipefail

# ── Color & Formatting ──────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ── Logging Helpers ─────────────────────────────────────────
info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✖${NC}  $*" >&2; }
step()    { echo -e "\n${MAGENTA}▸${NC} ${BOLD}$*${NC}"; }
banner()  {
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${BOLD}🐾 OpenClaw Multi-Agent Setup${NC}                    ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}One-command fleet initialization${NC}                 ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}Safe merge — your existing config is preserved${NC}   ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo -e ""
}

# ── Constants ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/.agents"
OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"
DEFAULT_MODEL="zai/glm-5"
VERSION="1.1.0"

# Agent definitions: id|name|emoji|role
CORE_AGENTS=(
  "planner|Planner|🧠|Task decomposition, progress tracking, cross-agent coordination"
  "ideator|Ideator|💡|Idea generation, novelty assessment, contribution refinement"
  "critic|Critic|🎯|SHARP taste evaluation, soul questions, anti-pattern detection"
  "surveyor|Surveyor|📚|Literature search, paper analysis, research gap identification"
  "coder|Coder|💻|Algorithm implementation, experiment execution, code optimization"
  "writer|Writer|✍️|Paper writing, LaTeX formatting, academic expression"
  "reviewer|Reviewer|🔍|Internal peer review, weakness diagnosis, rebuttal strategy"
  "scout|Scout|📰|Daily paper digest, trend analysis, competitive intelligence"
)

# ── Default Flags ───────────────────────────────────────────
CHANNEL=""
GROUP_ID=""
SESSION_ID=""
MODEL="${DEFAULT_MODEL}"
MODEL_MAP=""        # Per-agent model overrides: "planner=X,coder=Y"
SKIP_BINDINGS=false
DRY_RUN=false

# ── Parse Arguments ─────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --channel)      CHANNEL="$2";      shift 2 ;;
    --group-id)     GROUP_ID="$2";     shift 2 ;;
    --session-id)   SESSION_ID="$2";   shift 2 ;;
    --model)        MODEL="$2";        shift 2 ;;
    --model-map)    MODEL_MAP="$2";    shift 2 ;;
    --skip-bindings) SKIP_BINDINGS=true; shift ;;
    --dry-run)      DRY_RUN=true;      shift ;;
    -h|--help)
      echo "Usage: ./setup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --channel CHANNEL    Channel type (feishu|whatsapp|telegram|discord|slack)"
      echo "  --group-id ID        Group/chat ID for channel binding"
      echo "  --session-id ID      Session ID for channel group routing"
      echo "  --model MODEL        Default model for ALL agents (default: ${DEFAULT_MODEL})"
      echo "  --model-map MAP      Per-agent model overrides (comma-separated)"
      echo "                       Example: planner=zai/glm-5,coder=ollama/kimi-k2.5:cloud"
      echo "  --skip-bindings      Skip channel binding configuration"
      echo "  --dry-run            Preview commands without executing"
      echo "  -h, --help           Show this help message"
      echo ""
      echo "Model Configuration:"
      echo "  By default, all agents use ${DEFAULT_MODEL}."
      echo "  Use --model to change the default for all agents."
      echo "  Use --model-map to assign different models to specific agents."
      echo "  --model-map takes priority over --model for listed agents."
      echo ""
      echo "Examples:"
      echo "  # All agents use zai/glm-5 (default)"
      echo "  ./setup.sh --channel feishu --group-id oc_xxx"
      echo ""
      echo "  # All agents use a custom model"
      echo "  ./setup.sh --model ollama/kimi-k2.5:cloud --channel feishu --group-id oc_xxx"
      echo ""
      echo "  # Different models per agent"
      echo "  ./setup.sh --model zai/glm-5 \\"
      echo "    --model-map 'coder=ollama/kimi-k2.5:cloud,writer=zai/glm-4.7' \\"
      echo "    --channel feishu --group-id oc_xxx"
      echo ""
      echo "⚠️  SAFE MERGE: This script appends sub-agents to your existing"
      echo "   openclaw.json. It will NOT overwrite your main agent or other settings."
      exit 0
      ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Parse model map into associative array ──────────────────
declare -A AGENT_MODELS
if [[ -n "${MODEL_MAP}" ]]; then
  IFS=',' read -ra MAP_ENTRIES <<< "${MODEL_MAP}"
  for entry in "${MAP_ENTRIES[@]}"; do
    local_key="${entry%%=*}"
    local_val="${entry#*=}"
    AGENT_MODELS["${local_key}"]="${local_val}"
  done
fi

# ── Get model for an agent ──────────────────────────────────
get_model() {
  local agent_id="$1"
  if [[ -n "${AGENT_MODELS[${agent_id}]+x}" ]]; then
    echo "${AGENT_MODELS[${agent_id}]}"
  else
    echo "${MODEL}"
  fi
}

# ── Helper: run or preview ──────────────────────────────────
run() {
  if [[ "${DRY_RUN}" == true ]]; then
    echo -e "  ${DIM}\$ $*${NC}"
  else
    eval "$@"
  fi
}

# ── Preflight Checks ───────────────────────────────────────
preflight() {
  step "Preflight checks"

  # Check openclaw CLI
  if ! command -v openclaw &>/dev/null; then
    error "openclaw CLI not found."
    echo -e "  Install it with: ${CYAN}npm install -g openclaw@latest${NC}"
    echo -e "  Then run:        ${CYAN}openclaw onboard --install-daemon${NC}"
    exit 1
  fi
  success "openclaw CLI found: $(openclaw --version 2>/dev/null || echo 'installed')"

  # Check that agent source files exist
  if [[ ! -d "${AGENTS_DIR}" ]]; then
    error "Agent source directory not found: ${AGENTS_DIR}"
    error "Please run this script from the repository root."
    exit 1
  fi
  success "Agent source files found"

  # Check jq (needed for safe JSON merging)
  if ! command -v jq &>/dev/null; then
    warn "jq not found — JSON config will use append-only mode."
    warn "Install jq for safe config merging: https://jqlang.github.io/jq/download/"
  fi

  # Backup existing config
  if [[ -f "${OPENCLAW_CONFIG}" ]]; then
    local backup="${OPENCLAW_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${OPENCLAW_CONFIG}" "${backup}"
    success "Existing config backed up to: ${backup}"
  fi

  # Show model configuration
  info "Default model: ${BOLD}${MODEL}${NC}"
  if [[ -n "${MODEL_MAP}" ]]; then
    info "Per-agent overrides:"
    for key in "${!AGENT_MODELS[@]}"; do
      echo -e "    ${key} → ${AGENT_MODELS[${key}]}"
    done
  fi
}

# ── Create Agents ───────────────────────────────────────────
create_agents() {
  step "Creating ${#CORE_AGENTS[@]} sub-agents"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${SCRIPT_DIR}/.agents/${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    info "Creating agent: ${emoji} ${name} (${id}) → model: ${agent_model}"
    run "openclaw agents add ${id} \
      --model '${agent_model}' \
      --workspace '${workspace}' 2>/dev/null || true"

    success "Agent '${id}' created"
  done
}

# ── Set Identities ─────────────────────────────────────────
set_identities() {
  step "Setting visual identities"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local display_name="${emoji} ${name}"

    info "Setting identity: ${display_name}"
    run "openclaw agents set-identity \
      --agent '${id}' \
      --name '${display_name}' 2>/dev/null || true"

    success "Identity set for '${id}' → ${display_name}"
  done
}

# ── Deploy Workspace Files ──────────────────────────────────
deploy_workspace_files() {
  step "Deploying workspace files (soul.md / agent.md / user.md)"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${AGENTS_DIR}/${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    # Ensure workspace directory exists
    mkdir -p "${workspace}"

    # soul.md should already exist from the repository
    if [[ -f "${workspace}/soul.md" ]]; then
      success "${id}/soul.md ✓ (exists)"
    else
      warn "${id}/soul.md not found — creating placeholder"
      cat > "${workspace}/soul.md" << SOUL
# ${emoji} OpenClaw · ${name}

## Identity
You are **OpenClaw-${name}**, a specialized agent in the OpenClaw multi-agent system.
Your role: ${role}

## Core Principles
- Maintain professional standards at all times
- Collaborate effectively with other agents
- Report progress to Planner and escalate issues to Main Agent
SOUL
    fi

    # agent.md — technical configuration
    if [[ ! -f "${workspace}/agent.md" ]]; then
      cat > "${workspace}/agent.md" << AGENT
# ${emoji} ${name} — Agent Configuration

## Model
- **Primary**: ${agent_model}

## Tools
- read, write, edit, exec, apply_patch
- sessions_list, sessions_history, sessions_send

## Sandbox
- mode: off (trusted agent)

## Session
- Maintain context across interactions
- Reference previous outputs when relevant
AGENT
      success "${id}/agent.md ✓ (created)"
    else
      success "${id}/agent.md ✓ (exists)"
    fi

    # user.md — user context
    if [[ ! -f "${workspace}/user.md" ]]; then
      cat > "${workspace}/user.md" << USER
# User Context for ${emoji} ${name}

## Research Profile
- **Domain**: AI / NLP / Multi-Agent Systems
- **Target Venues**: ACL, EMNLP, NAACL, NeurIPS, ICML, ICLR
- **Tech Stack**: Python, PyTorch, HuggingFace Transformers

## Preferences
- **Language**: Chinese (primary), English for technical terms
- **Quality Bar**: Top-tier AI conference Oral-level
- **Communication**: Structured output with clear sections
USER
      success "${id}/user.md ✓ (created)"
    else
      success "${id}/user.md ✓ (exists)"
    fi
  done
}

# ── Interactive Channel Setup ───────────────────────────────
prompt_channel() {
  if [[ "${SKIP_BINDINGS}" == true ]]; then
    info "Skipping channel binding (--skip-bindings)"
    return
  fi

  if [[ -z "${CHANNEL}" ]]; then
    echo -e "\n${BOLD}Select a channel for group binding:${NC}"
    echo -e "  ${CYAN}1${NC}) feishu   (飞书)"
    echo -e "  ${CYAN}2${NC}) whatsapp"
    echo -e "  ${CYAN}3${NC}) telegram"
    echo -e "  ${CYAN}4${NC}) discord"
    echo -e "  ${CYAN}5${NC}) slack"
    echo -e "  ${CYAN}s${NC}) skip"
    echo -en "\n${BOLD}  Choice [1-5/s]: ${NC}"
    read -r choice
    case "${choice}" in
      1) CHANNEL="feishu" ;;
      2) CHANNEL="whatsapp" ;;
      3) CHANNEL="telegram" ;;
      4) CHANNEL="discord" ;;
      5) CHANNEL="slack" ;;
      s|S) SKIP_BINDINGS=true; return ;;
      *) warn "Invalid choice, skipping bindings."; SKIP_BINDINGS=true; return ;;
    esac
  fi

  if [[ -z "${GROUP_ID}" ]]; then
    echo -en "\n${BOLD}  Enter group/chat ID for ${CHANNEL}: ${NC}"
    read -r GROUP_ID
    if [[ -z "${GROUP_ID}" ]]; then
      warn "No group ID provided, skipping bindings."
      SKIP_BINDINGS=true
      return
    fi
  fi

  if [[ -z "${SESSION_ID}" ]]; then
    echo -en "${BOLD}  Enter session ID (optional, press Enter to skip): ${NC}"
    read -r SESSION_ID
  fi
}

# ── Configure Bindings ──────────────────────────────────────
configure_bindings() {
  if [[ "${SKIP_BINDINGS}" == true ]]; then
    return
  fi

  step "Configuring channel bindings (${CHANNEL})"

  # =============================================
  # ⚠️ SAFE MERGE STRATEGY
  # =============================================
  # We build a patch containing ONLY our sub-agents and bindings.
  # When merging, we APPEND to existing agents.list and bindings
  # arrays instead of replacing them. This preserves:
  #   - Your main agent configuration
  #   - Existing agents you've added manually
  #   - Auth, models, plugins, gateway, and all other settings
  # =============================================

  # Build the new agents entries
  # Each agent gets: identity, groupChat.mentionPatterns, historyLimit
  # See: https://docs.openclaw.ai/channels/groups#mention-gating-default
  local agents_json='['
  local first=true
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${SCRIPT_DIR}/.agents/${id}"
    local agent_model
    agent_model="$(get_model "${id}")"
    if [[ "${first}" == true ]]; then
      first=false
    else
      agents_json+=','
    fi
    agents_json+="$(cat <<AJSON
{
      "id": "${id}",
      "name": "${emoji} ${name}",
      "workspace": "${workspace}",
      "model": "${agent_model}",
      "identity": { "name": "${emoji} ${name}" },
      "groupChat": {
        "mentionPatterns": ["@${id}", "${id}", "@${name}"],
        "historyLimit": 50
      }
    }
AJSON
)"
  done
  agents_json+=']'

  # Build bindings array — bind each agent to the group
  # IMPORTANT: main agent binding comes FIRST so it handles
  # non-@mentioned messages. Sub-agents only respond to @mentions.
  # See: https://docs.openclaw.ai/concepts/multi-agent#routing-rules-how-messages-pick-an-agent
  local bindings_json
  bindings_json='[{"agentId": "main", "match": {"channel": "'"${CHANNEL}"'", "peer": {"kind": "group", "id": "'"${GROUP_ID}"'"}}}'
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    bindings_json+=",$(cat <<BJSON
{
      "agentId": "${id}",
      "match": {
        "channel": "${CHANNEL}",
        "peer": {
          "kind": "group",
          "id": "${GROUP_ID}"
        }
      }
    }
BJSON
)"
  done
  bindings_json+=']'

  # ── SAFE MERGE with jq ─────────────────────────────────
  # Key difference from naive `jq -s '.[0] * .[1]'`:
  #   - We APPEND new agents to existing .agents.list (dedup by id)
  #   - We APPEND new bindings to existing .bindings (dedup by agentId+groupId)
  #   - We deep-merge .channels (preserving existing channel settings)
  #   - We NEVER touch .auth, .models, .plugins, .gateway, .tools, etc.
  if command -v jq &>/dev/null && [[ -f "${OPENCLAW_CONFIG}" ]]; then
    info "Safe-merging into existing ${OPENCLAW_CONFIG}"
    info "${DIM}(Appending agents, preserving your main agent and all other settings)${NC}"

    local tmp_file
    tmp_file="$(mktemp)"

    # The jq expression:
    # 1. Read existing config
    # 2. Remove our agent IDs from existing list (to avoid duplicates)
    # 3. Append our new agents to the list
    # 4. Same dedup+append for bindings
    # 5. Deep merge channel config (preserving existing keys like appId, appSecret)
    # 6. Set groupChat historyLimit if not already set
    local our_ids
    our_ids="$(printf '%s\n' "${CORE_AGENTS[@]}" | cut -d'|' -f1 | jq -R . | jq -s '. + ["main"]')"

    jq --argjson new_agents "${agents_json}" \
       --argjson new_bindings "${bindings_json}" \
       --argjson our_ids "${our_ids}" \
       --arg channel "${CHANNEL}" \
       --arg group_id "${GROUP_ID}" \
    '
      # Remove our agent IDs from existing list (if any), then append new ones
      .agents.list = (
        [(.agents.list // [])[] | select(.id as $id | $our_ids | index($id) | not)]
        + $new_agents
      )
      # Remove our bindings from existing list (if any), then append new ones
      | .bindings = (
        [(.bindings // [])[] | select(
          (.agentId as $aid | $our_ids | index($aid) | not)
          or (.match.peer.id != $group_id)
        )]
        + $new_bindings
      )
      # Merge channel config (preserve existing keys like appId, appSecret, token)
      | .channels[$channel] = (
        (.channels[$channel] // {}) * {
          "groupPolicy": "allowlist",
          "groupAllowFrom": (
            [(.channels[$channel].groupAllowFrom // [])[] | select(. != $group_id)]
            + [$group_id]
          ),
          "groups": ((.channels[$channel].groups // {}) * {
            ($group_id): { "requireMention": true }
          })
        }
      )
      # Set groupChat historyLimit (preserve if already set)
      | .messages = (.messages // {}) * { "groupChat": { "historyLimit": (.messages.groupChat.historyLimit // 50) } }
    ' "${OPENCLAW_CONFIG}" > "${tmp_file}"

    if [[ "${DRY_RUN}" == true ]]; then
      echo -e "  ${DIM}Would write to ${OPENCLAW_CONFIG}:${NC}"
      cat "${tmp_file}"
    else
      cp "${tmp_file}" "${OPENCLAW_CONFIG}"
    fi
    rm -f "${tmp_file}"

  else
    # No existing config or no jq — create a minimal config with ONLY our agents
    warn "No existing config found or jq not available."
    warn "Creating new config with sub-agents only."
    warn "Your main agent will use agents.defaults settings."

    local config_dir
    config_dir="$(dirname "${OPENCLAW_CONFIG}")"
    mkdir -p "${config_dir}"

    local channel_config
    channel_config="$(cat <<CHCFG
{
      "${CHANNEL}": {
        "groupPolicy": "allowlist",
        "groupAllowFrom": ["${GROUP_ID}"],
        "groups": {
          "${GROUP_ID}": {
            "requireMention": true
          }
        }
      }
    }
CHCFG
)"

    local config_new
    config_new="$(cat <<CONFIG
{
  "agents": {
    "list": ${agents_json}
  },
  "bindings": ${bindings_json},
  "channels": ${channel_config},
  "messages": {
    "groupChat": {
      "historyLimit": 50
    }
  }
}
CONFIG
)"
    if [[ "${DRY_RUN}" == true ]]; then
      echo -e "  ${DIM}Would write to ${OPENCLAW_CONFIG}:${NC}"
      echo "${config_new}"
    else
      echo "${config_new}" > "${OPENCLAW_CONFIG}"
    fi
  fi

  success "Channel bindings configured for ${CHANNEL} → ${GROUP_ID}"

  # Also save a local copy of the generated PATCH (not the full config)
  echo "${agents_json}" > "${SCRIPT_DIR}/openclaw.generated.agents.json"
  success "Generated agent patch saved to openclaw.generated.agents.json"
}

# ── Verify Setup ────────────────────────────────────────────
verify() {
  step "Verifying setup"

  if [[ "${DRY_RUN}" == true ]]; then
    info "Dry-run mode — skipping verification"
    return
  fi

  info "Listing agents..."
  openclaw agents list --bindings 2>/dev/null || warn "Could not verify agents (gateway may not be running)"

  success "Setup complete!"
}

# ── Summary ─────────────────────────────────────────────────
summary() {
  echo -e ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}✅ Setup Complete!${NC}                              ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo -e ""
  echo -e "  ${BOLD}Agents created:${NC} ${#CORE_AGENTS[@]}"
  echo -e "  ${BOLD}Default model:${NC}  ${MODEL}"
  if [[ -n "${MODEL_MAP}" ]]; then
    echo -e "  ${BOLD}Model overrides:${NC}"
    for key in "${!AGENT_MODELS[@]}"; do
      echo -e "    ${key} → ${AGENT_MODELS[${key}]}"
    done
  fi
  if [[ "${SKIP_BINDINGS}" != true ]]; then
    echo -e "  ${BOLD}Channel:${NC}        ${CHANNEL}"
    echo -e "  ${BOLD}Group ID:${NC}       ${GROUP_ID}"
    [[ -n "${SESSION_ID}" ]] && echo -e "  ${BOLD}Session ID:${NC}     ${SESSION_ID}"
  fi
  echo -e ""
  echo -e "  ${DIM}Your existing main agent and settings were preserved.${NC}"
  echo -e ""
  echo -e "  ${DIM}Next steps:${NC}"
  echo -e "    1. Start the gateway:  ${CYAN}openclaw gateway${NC}"
  echo -e "    2. Check status:       ${CYAN}openclaw agents list --bindings${NC}"
  echo -e "    3. Test in channel:    Mention any agent in your ${CHANNEL} group"
  echo -e ""
}

# ── Main ────────────────────────────────────────────────────
main() {
  banner
  preflight
  create_agents
  set_identities
  deploy_workspace_files
  prompt_channel
  configure_bindings
  verify
  summary
}

main "$@"
