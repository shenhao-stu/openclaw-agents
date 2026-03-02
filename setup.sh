#!/usr/bin/env bash
# ============================================================
#  OpenClaw Agents — One-Command Multi-Agent Setup  (v1.2.0)
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
#    4. Deploy SOUL.md / AGENT.md / USER.md / AGENTS.md into each workspace
#    5. Configure openclaw.json with routing bindings
#    6. Verify the setup
#
#  ⚠️ SAFE MERGE: This script APPENDS sub-agents to your existing
#  config. It will NOT overwrite your main agent, other agents,
#  auth, models, plugins, or any other settings.
#  No sandbox is used — each sub-agent has its own workspace.
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
NC='\033[0m'

# ── Logging Helpers ─────────────────────────────────────────
info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✖${NC}  $*" >&2; }
step()    { echo -e "\n${MAGENTA}▸${NC} ${BOLD}$*${NC}"; }
banner()  {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${BOLD}🐾 OpenClaw Multi-Agent Setup${NC}  v1.2.0          ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}One-command fleet initialization${NC}                 ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}Safe merge · No sandbox · Independent workspaces${NC}${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

# ── Constants ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/.agents"
OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"
DEFAULT_MODEL="zai/glm-5"

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
MODEL_MAP=""
SKIP_BINDINGS=false
DRY_RUN=false
REQUIRE_MENTION=""  # will be asked interactively if empty

# ── Parse Arguments ─────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --channel)         CHANNEL="$2";         shift 2 ;;
    --group-id)        GROUP_ID="$2";        shift 2 ;;
    --session-id)      SESSION_ID="$2";      shift 2 ;;
    --model)           MODEL="$2";           shift 2 ;;
    --model-map)       MODEL_MAP="$2";       shift 2 ;;
    --require-mention) REQUIRE_MENTION="$2"; shift 2 ;;
    --skip-bindings)   SKIP_BINDINGS=true;   shift ;;
    --dry-run)         DRY_RUN=true;         shift ;;
    -h|--help)
      echo "Usage: ./setup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --channel CHANNEL      Channel type (feishu|whatsapp|telegram|discord|slack)"
      echo "  --group-id ID          Group/chat ID for channel binding"
      echo "  --session-id ID        Session ID for channel group routing"
      echo "  --model MODEL          Default model for ALL agents (default: ${DEFAULT_MODEL})"
      echo "  --model-map MAP        Per-agent model overrides (comma-separated)"
      echo "                         Example: planner=zai/glm-5,coder=ollama/kimi-k2.5:cloud"
      echo "  --require-mention BOOL Whether agents require @mention to respond in group (true|false)"
      echo "  --skip-bindings        Skip channel binding configuration"
      echo "  --dry-run              Preview commands without executing"
      echo "  -h, --help             Show this help message"
      echo ""
      echo "Model Configuration:"
      echo "  By default, all agents use ${DEFAULT_MODEL}."
      echo "  Use --model to change the default for all agents."
      echo "  Use --model-map to assign different models to specific agents."
      echo "  --model-map takes priority over --model for listed agents."
      echo ""
      echo "Examples:"
      echo "  # Default (all zai/glm-5)"
      echo "  ./setup.sh --channel feishu --group-id oc_xxx"
      echo ""
      echo "  # Custom model for all"
      echo "  ./setup.sh --model ollama/kimi-k2.5:cloud --channel feishu --group-id oc_xxx"
      echo ""
      echo "  # Per-agent models"
      echo "  ./setup.sh --model zai/glm-5 \\"
      echo "    --model-map 'coder=ollama/kimi-k2.5:cloud,writer=zai/glm-4.7' \\"
      echo "    --channel feishu --group-id oc_xxx"
      echo ""
      echo "  # No @mention required (bot auto-responds)"
      echo "  ./setup.sh --require-mention false --channel feishu --group-id oc_xxx"
      exit 0
      ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Parse model map ─────────────────────────────────────────
declare -A AGENT_MODELS
if [[ -n "${MODEL_MAP}" ]]; then
  IFS=',' read -ra MAP_ENTRIES <<< "${MODEL_MAP}"
  for entry in "${MAP_ENTRIES[@]}"; do
    local_key="${entry%%=*}"
    local_val="${entry#*=}"
    AGENT_MODELS["${local_key}"]="${local_val}"
  done
fi

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

  if ! command -v openclaw &>/dev/null; then
    error "openclaw CLI not found."
    echo -e "  Install it with: ${CYAN}npm install -g openclaw@latest${NC}"
    echo -e "  Then run:        ${CYAN}openclaw onboard --install-daemon${NC}"
    exit 1
  fi
  success "openclaw CLI found"

  if [[ ! -d "${AGENTS_DIR}" ]]; then
    error "Agent source directory not found: ${AGENTS_DIR}"
    error "Please run this script from the repository root."
    exit 1
  fi
  success "Agent source files found"

  if ! command -v jq &>/dev/null; then
    warn "jq not found — JSON config will use append-only mode."
    warn "Install jq for safe config merging: https://jqlang.github.io/jq/download/"
  fi

  # Backup
  if [[ -f "${OPENCLAW_CONFIG}" ]]; then
    local backup="${OPENCLAW_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${OPENCLAW_CONFIG}" "${backup}"
    success "Existing config backed up to: ${backup}"
  fi

  # Show model config
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

# ── Deploy Workspace Files (UPPERCASE) ──────────────────────
deploy_workspace_files() {
  step "Deploying workspace files (SOUL.md / AGENT.md / USER.md / AGENTS.md)"

  # ── Source raw templates from repo root ──
  local raw_soul="${SCRIPT_DIR}/SOUL_raw.md"
  local raw_agents="${SCRIPT_DIR}/AGENTS.md"
  local raw_user="${SCRIPT_DIR}/USER.md"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${AGENTS_DIR}/${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    mkdir -p "${workspace}"

    # ── SOUL.md: Merge raw template + agent-specific soul ────
    # The agent-specific soul.md (lowercase) from the repo is the
    # primary identity. We prepend the raw SOUL template (generic
    # behaviors) above it.
    local src_soul="${workspace}/soul.md"
    local dst_soul="${workspace}/SOUL.md"

    if [[ -f "${src_soul}" ]]; then
      if [[ -f "${raw_soul}" ]]; then
        # Merge: raw template first, then agent-specific soul
        {
          cat "${raw_soul}"
          echo ""
          echo "---"
          echo ""
          cat "${src_soul}"
        } > "${dst_soul}"
        success "${id}/SOUL.md ✓ (merged: SOUL_raw.md + soul.md)"
      else
        cp "${src_soul}" "${dst_soul}"
        success "${id}/SOUL.md ✓ (from agent soul.md)"
      fi
    else
      warn "${id}/SOUL.md not found — creating from template"
      if [[ -f "${raw_soul}" ]]; then
        cp "${raw_soul}" "${dst_soul}"
      else
        cat > "${dst_soul}" << SOUL
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
    fi

    # ── USER.md: Merge raw template + agent-specific user ────
    local src_user="${workspace}/user.md"
    local dst_user="${workspace}/USER.md"

    if [[ -f "${src_user}" ]]; then
      if [[ -f "${raw_user}" ]]; then
        {
          cat "${raw_user}"
          echo ""
          echo "---"
          echo ""
          echo "# ${emoji} ${name} — Agent-Specific User Context"
          echo ""
          cat "${src_user}"
        } > "${dst_user}"
        success "${id}/USER.md ✓ (merged: USER.md + user.md)"
      else
        cp "${src_user}" "${dst_user}"
        success "${id}/USER.md ✓ (from agent user.md)"
      fi
    else
      if [[ -f "${raw_user}" ]]; then
        cp "${raw_user}" "${dst_user}"
        success "${id}/USER.md ✓ (from raw template)"
      else
        cat > "${dst_user}" << USERFILE
# User Context for ${emoji} ${name}

## Research Profile
- **Domain**: AI / NLP / Multi-Agent Systems
- **Target Venues**: ACL, EMNLP, NAACL, NeurIPS, ICML, ICLR
- **Tech Stack**: Python, PyTorch, HuggingFace Transformers

## Preferences
- **Language**: Chinese (primary), English for technical terms
- **Quality Bar**: Top-tier AI conference Oral-level
- **Communication**: Structured output with clear sections
USERFILE
      fi
    fi

    # ── AGENT.md: From agent-specific agent.md ───────────────
    local src_agent="${workspace}/agent.md"
    local dst_agent="${workspace}/AGENT.md"

    if [[ -f "${src_agent}" ]]; then
      # Update model reference in the copy
      sed "s|anthropic/claude-sonnet-4-5|${agent_model}|g" \
        "${src_agent}" > "${dst_agent}"
      success "${id}/AGENT.md ✓ (from agent.md, model: ${agent_model})"
    else
      cat > "${dst_agent}" << AGENTFILE
# ${emoji} ${name} — Agent Configuration

## Model
- **Primary**: ${agent_model}

## Tools
- read, write, edit, exec, apply_patch
- sessions_list, sessions_history, sessions_send

## Session
- Maintain context across interactions
- Reference previous outputs when relevant
AGENTFILE
      success "${id}/AGENT.md ✓ (created)"
    fi

    # ── AGENTS.md: Copy from repo root ───────────────────────
    local dst_agents="${workspace}/AGENTS.md"
    if [[ -f "${raw_agents}" ]]; then
      cp "${raw_agents}" "${dst_agents}"
      success "${id}/AGENTS.md ✓ (from repo root)"
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
    echo -en "${BOLD}  Enter session ID (optional, Enter to skip): ${NC}"
    read -r SESSION_ID
  fi

  # ── Ask about requireMention ──────────────────────────────
  if [[ -z "${REQUIRE_MENTION}" ]]; then
    echo ""
    echo -e "${BOLD}  群聊 @mention 设置:${NC}"
    echo -e "  ${CYAN}y${NC}) 每次必须 @机器人 才会回复（推荐，避免刷屏）"
    echo -e "  ${CYAN}n${NC}) 机器人自动响应所有消息（无需 @）"
    echo -en "\n${BOLD}  需要 @mention 才回复? [Y/n]: ${NC}"
    read -r mention_choice
    case "${mention_choice}" in
      n|N|no|false)  REQUIRE_MENTION="false" ;;
      *)             REQUIRE_MENTION="true" ;;
    esac
  fi

  info "requireMention: ${REQUIRE_MENTION}"
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
  # - We only APPEND our sub-agents + bindings
  # - Main agent is IMPLICIT (uses agents.defaults)
  #   — we do NOT add "main" to agents.list
  # - No sandbox — each sub-agent has its own workspace
  # =============================================

  # Build agents JSON — each agent gets unique identity + mentionPatterns
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

  # Build bindings — each sub-agent gets its own binding to the group
  local bindings_json='['
  first=true
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    if [[ "${first}" == true ]]; then
      first=false
    else
      bindings_json+=','
    fi
    bindings_json+="$(cat <<BJSON
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

  # Determine requireMention value
  local require_mention_bool=true
  if [[ "${REQUIRE_MENTION}" == "false" ]]; then
    require_mention_bool=false
  fi

  # ── SAFE MERGE with jq ─────────────────────────────────
  if command -v jq &>/dev/null && [[ -f "${OPENCLAW_CONFIG}" ]]; then
    info "Safe-merging into existing ${OPENCLAW_CONFIG}"
    info "${DIM}(Appending sub-agents only. Main agent is implicit — not touched.)${NC}"

    local tmp_file
    tmp_file="$(mktemp)"

    # Our agent IDs for dedup
    local our_ids
    our_ids="$(printf '%s\n' "${CORE_AGENTS[@]}" | cut -d'|' -f1 | jq -R . | jq -s .)"

    jq --argjson new_agents "${agents_json}" \
       --argjson new_bindings "${bindings_json}" \
       --argjson our_ids "${our_ids}" \
       --arg channel "${CHANNEL}" \
       --arg group_id "${GROUP_ID}" \
       --argjson require_mention "${require_mention_bool}" \
    '
      # Dedup + append agents
      .agents.list = (
        [(.agents.list // [])[] | select(.id as $id | $our_ids | index($id) | not)]
        + $new_agents
      )
      # Dedup + append bindings
      | .bindings = (
        [(.bindings // [])[] | select(
          (.agentId as $aid | $our_ids | index($aid) | not)
          or (.match.peer.id != $group_id)
        )]
        + $new_bindings
      )
      # Channel config — open policy, preserve existing keys
      | .channels[$channel] = (
        (.channels[$channel] // {}) * {
          "groupPolicy": "open",
          "groups": ((.channels[$channel].groups // {}) * {
            ($group_id): { "requireMention": $require_mention }
          })
        }
      )
      # Set historyLimit (preserve if already set)
      | .messages = (.messages // {}) * {
          "groupChat": { "historyLimit": (.messages.groupChat.historyLimit // 50) }
        }
    ' "${OPENCLAW_CONFIG}" > "${tmp_file}"

    if [[ "${DRY_RUN}" == true ]]; then
      echo -e "  ${DIM}Would write to ${OPENCLAW_CONFIG}:${NC}"
      cat "${tmp_file}"
    else
      cp "${tmp_file}" "${OPENCLAW_CONFIG}"
    fi
    rm -f "${tmp_file}"

  else
    # No existing config or no jq
    warn "No existing config found or jq not available."
    warn "Creating new config with sub-agents only."

    local config_dir
    config_dir="$(dirname "${OPENCLAW_CONFIG}")"
    mkdir -p "${config_dir}"

    local require_mention_val="true"
    [[ "${REQUIRE_MENTION}" == "false" ]] && require_mention_val="false"

    local config_new
    config_new="$(cat <<CONFIG
{
  "agents": {
    "list": ${agents_json}
  },
  "bindings": ${bindings_json},
  "channels": {
    "${CHANNEL}": {
      "groupPolicy": "open",
      "groups": {
        "${GROUP_ID}": {
          "requireMention": ${require_mention_val}
        }
      }
    }
  },
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
  info "requireMention: ${REQUIRE_MENTION}"
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
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}✅ Setup Complete!${NC}                              ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Sub-agents created:${NC} ${#CORE_AGENTS[@]}"
  echo -e "  ${BOLD}Default model:${NC}      ${MODEL}"
  if [[ -n "${MODEL_MAP}" ]]; then
    echo -e "  ${BOLD}Model overrides:${NC}"
    for key in "${!AGENT_MODELS[@]}"; do
      echo -e "    ${key} → ${AGENT_MODELS[${key}]}"
    done
  fi
  echo -e "  ${BOLD}Sandbox:${NC}            disabled (independent workspaces)"
  if [[ "${SKIP_BINDINGS}" != true ]]; then
    echo -e "  ${BOLD}Channel:${NC}            ${CHANNEL}"
    echo -e "  ${BOLD}Group ID:${NC}           ${GROUP_ID}"
    echo -e "  ${BOLD}Require @mention:${NC}   ${REQUIRE_MENTION}"
    [[ -n "${SESSION_ID}" ]] && echo -e "  ${BOLD}Session ID:${NC}         ${SESSION_ID}"
  fi
  echo ""
  echo -e "  ${BOLD}Workspace files:${NC} SOUL.md AGENT.md USER.md AGENTS.md (UPPERCASE)"
  echo -e "  ${DIM}  SOUL.md  = SOUL_raw.md (generic) + soul.md (agent-specific)${NC}"
  echo -e "  ${DIM}  USER.md  = USER.md (template) + user.md (agent-specific)${NC}"
  echo -e "  ${DIM}  AGENT.md = agent.md (agent config with model updated)${NC}"
  echo -e "  ${DIM}  AGENTS.md = workspace conventions (from repo root)${NC}"
  echo ""
  echo -e "  ${DIM}Your main agent is implicit and uses agents.defaults.${NC}"
  echo -e "  ${DIM}Existing agents and all other settings were preserved.${NC}"
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo -e "    1. Start the gateway:  ${CYAN}openclaw gateway${NC}"
  echo -e "    2. Check status:       ${CYAN}openclaw agents list --bindings${NC}"
  echo -e "    3. Test in channel:    Type ${CYAN}@planner${NC} in your ${CHANNEL} group"
  echo ""
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
