#!/usr/bin/env bash
# ============================================================
#  OpenClaw Agents — One-Command Multi-Agent Setup  (v2.0.0)
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
#    2. Create all sub-agents (openclaw auto-generates AGENTS.md, SOUL.md, USER.md)
#    3. Set visual identities for each agent
#    4. Copy soul.md + user.md source files into each workspace
#    5. Create BOOTSTRAP.md to instruct agent to self-merge on first run
#    6. Append workflow instructions to AGENTS.md
#    7. Configure openclaw.json with routing bindings
#
#  ⚠️ SAFE MERGE: Appends sub-agents to existing config.
#  Does NOT touch your main agent, auth, models, plugins, etc.
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
  echo -e "${CYAN}║${NC}  ${BOLD}🐾 OpenClaw Multi-Agent Setup${NC}  v2.0.0          ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}Agent self-merge · No sandbox · Workflow-aware${NC}  ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

# ── Constants ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/.agents"
OPENCLAW_HOME="${HOME}/.openclaw"
OPENCLAW_CONFIG="${OPENCLAW_HOME}/openclaw.json"
DEFAULT_MODEL="zai/glm-5"

# Agent definitions: id|name|emoji|role
CORE_AGENTS=(
  "planner|Planner|🧠|统筹规划师"
  "ideator|Ideator|💡|创意大师"
  "critic|Critic|🎯|品鉴师"
  "surveyor|Surveyor|📚|文献专家"
  "coder|Coder|💻|代码工程师"
  "writer|Writer|✍️|论文写手"
  "reviewer|Reviewer|🔍|内部审稿人"
  "scout|Scout|📰|学术情报员"
)

# ── Default Flags ───────────────────────────────────────────
CHANNEL=""
GROUP_ID=""
SESSION_ID=""
MODEL="${DEFAULT_MODEL}"
MODEL_MAP=""
SKIP_BINDINGS=false
DRY_RUN=false
REQUIRE_MENTION=""

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
      echo "  --require-mention BOOL Whether agents require @mention to respond (true|false)"
      echo "  --skip-bindings        Skip channel binding configuration"
      echo "  --dry-run              Preview commands without executing"
      echo "  -h, --help             Show this help message"
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
    echo -e "  Install: ${CYAN}npm install -g openclaw@latest${NC}"
    echo -e "  Then:    ${CYAN}openclaw onboard --install-daemon${NC}"
    exit 1
  fi
  success "openclaw CLI found"

  if [[ ! -d "${AGENTS_DIR}" ]]; then
    error "Agent source directory not found: ${AGENTS_DIR}"
    exit 1
  fi
  success "Agent source files found"

  if ! command -v jq &>/dev/null; then
    warn "jq not found — config merge will use fallback mode."
  fi

  # Backup existing config
  if [[ -f "${OPENCLAW_CONFIG}" ]]; then
    local backup="${OPENCLAW_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${OPENCLAW_CONFIG}" "${backup}"
    success "Existing config backed up → ${backup}"
  fi

  info "Default model: ${BOLD}${MODEL}${NC}"
  if [[ -n "${MODEL_MAP}" ]]; then
    info "Per-agent overrides:"
    for key in "${!AGENT_MODELS[@]}"; do
      echo -e "    ${key} → ${AGENT_MODELS[${key}]}"
    done
  fi
}

# ── Step 1: Create Agents ──────────────────────────────────
create_agents() {
  step "Creating ${#CORE_AGENTS[@]} sub-agents"
  info "${DIM}openclaw auto-generates AGENTS.md, SOUL.md, USER.md in each workspace${NC}"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    info "Creating: ${emoji} ${name} (${id}) → model: ${agent_model}"
    run "openclaw agents add ${id} \
      --model '${agent_model}' \
      --workspace '${workspace}' 2>/dev/null || true"

    success "Agent '${id}' created → workspace: ${workspace}"
  done
}

# ── Step 2: Set Identities ─────────────────────────────────
set_identities() {
  step "Setting visual identities"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local display_name="${emoji} ${name}"

    run "openclaw agents set-identity \
      --agent '${id}' \
      --name '${display_name}' 2>/dev/null || true"

    success "'${id}' → ${display_name}"
  done
}

# ── Step 3: Deploy source files + BOOTSTRAP.md ─────────────
deploy_source_files() {
  step "Deploying source files to workspaces"
  info "${DIM}Copying soul.md + user.md → agent will self-merge on first run${NC}"

  local raw_soul="${SCRIPT_DIR}/SOUL_raw.md"
  local raw_user="${SCRIPT_DIR}/USER.md"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local src_dir="${AGENTS_DIR}/${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    mkdir -p "${workspace}"

    # ── Copy agent-specific source files (lowercase) ─────────
    # These are reference files the agent reads during bootstrap.
    if [[ -f "${src_dir}/soul.md" ]]; then
      cp "${src_dir}/soul.md" "${workspace}/_soul_source.md"
      success "${id}/_soul_source.md ✓ (agent identity)"
    fi

    if [[ -f "${src_dir}/user.md" ]]; then
      cp "${src_dir}/user.md" "${workspace}/_user_source.md"
      success "${id}/_user_source.md ✓ (agent user context)"
    fi

    if [[ -f "${src_dir}/agent.md" ]]; then
      # Update model reference
      sed "s|anthropic/claude-sonnet-4-5|${agent_model}|g" \
        "${src_dir}/agent.md" > "${workspace}/_agent_source.md"
      success "${id}/_agent_source.md ✓ (agent config, model: ${agent_model})"
    fi

    # ── Copy raw templates (generic behaviors) ───────────────
    if [[ -f "${raw_soul}" ]]; then
      cp "${raw_soul}" "${workspace}/_soul_raw.md"
    fi

    if [[ -f "${raw_user}" ]]; then
      cp "${raw_user}" "${workspace}/_user_raw.md"
    fi

    # ── Create BOOTSTRAP.md ──────────────────────────────────
    # OpenClaw convention: agent reads BOOTSTRAP.md on first run,
    # follows instructions, then deletes it.
    cat > "${workspace}/BOOTSTRAP.md" << 'BOOTEOF'
# 🐾 OpenClaw Multi-Agent Bootstrap

Welcome! You are a specialized sub-agent in the OpenClaw multi-agent system.
This is your first-run setup. Please follow these steps:

## Step 1: Merge Your Identity

Read the following files in your workspace and merge them into your SOUL.md:

1. `_soul_raw.md` — Generic behavior guidelines (be helpful, have opinions, etc.)
2. `_soul_source.md` — Your specific role, personality, and capabilities

**How to merge**: Combine both into SOUL.md. Put the generic guidelines first,
then your specific identity below. Make it feel like one cohesive document.

## Step 2: Merge User Context

Read and merge into your USER.md:

1. `_user_raw.md` — User template (name, timezone, preferences)
2. `_user_source.md` — Your agent-specific user context (research profile, etc.)

## Step 3: Set Up Agent Config

Read `_agent_source.md` and use it to understand your model config and tools.
You can keep this info in your session memory or merge relevant parts.

## Step 4: Read Your Workflows

Check AGENTS.md for workflow instructions specific to your role.
Understand which workflows you participate in and what you do in each.

## Step 5: Clean Up

After merging, delete this BOOTSTRAP.md and all `_*_source.md` / `_*_raw.md` files.
They are no longer needed — all info is now in your SOUL.md and USER.md.

---

_This bootstrap was generated by the openclaw-agents setup script._
_Repository: https://github.com/shenhao-stu/openclaw-agents_
BOOTEOF
    success "${id}/BOOTSTRAP.md ✓ (first-run self-merge instructions)"

  done
}

# ── Step 4: Append workflow instructions to AGENTS.md ──────
append_workflows() {
  step "Appending workflow instructions to AGENTS.md"

  local wf_dir="${AGENTS_DIR}/workflows"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agents_md="${workspace}/AGENTS.md"

    # If AGENTS.md doesn't exist yet (openclaw agents add not run), create stub
    if [[ ! -f "${agents_md}" ]]; then
      touch "${agents_md}"
    fi

    {
      echo ""
      echo "---"
      echo ""
      echo "# 📋 Workflow Reference for ${emoji} ${name}"
      echo ""
      echo "The following workflows involve you. Read them to understand your role."
      echo ""

      case "${id}" in
        planner)
          echo "## Your Workflows (Orchestrator role in all)"
          echo "- \`/paper-pipeline\` — Orchestrate the entire paper production"
          echo "- \`/brainstorm\` — Prepare context and coordinate brainstorm"
          echo "- \`/rebuttal\` — Coordinate rebuttal strategy and task assignment"
          echo "- \`/daily-digest\` — Receive alerts from Scout"
          echo ""
          for wf in paper-pipeline brainstorm rebuttal daily-digest; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; echo ""; }
          done
          ;;
        ideator)
          echo "## Your Workflows"
          echo "- \`/brainstorm\` — Lead idea generation (Step 2, 4, 6)"
          echo "- \`/paper-pipeline\` — Phase 2 (Idea gen), Phase 3 (Method design)"
          echo ""
          for wf in brainstorm paper-pipeline; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; echo ""; }
          done
          ;;
        critic)
          echo "## Your Workflows"
          echo "- \`/brainstorm\` — Step 5.5: Taste gate (SHARP ≥ 18 to pass)"
          echo "- \`/paper-pipeline\` — Phase 2.5, 3, 6, 7: Taste checkpoints"
          echo ""
          for wf in brainstorm paper-pipeline; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; echo ""; }
          done
          ;;
        surveyor)
          echo "## Your Workflows"
          echo "- \`/brainstorm\` — Step 3: Novelty verification"
          echo "- \`/paper-pipeline\` — Phase 1: Literature survey"
          echo "- \`/rebuttal\` — Provide missing references"
          echo ""
          for wf in brainstorm paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; echo ""; }
          done
          ;;
        coder)
          echo "## Your Workflows"
          echo "- \`/paper-pipeline\` — Phase 4 (Implementation), Phase 5 (Experiments)"
          echo "- \`/rebuttal\` — Supplementary experiments for reviewers"
          echo ""
          for wf in paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; echo ""; }
          done
          ;;
        writer)
          echo "## Your Workflows"
          echo "- \`/paper-pipeline\` — Phase 6 (Draft), Phase 7 (Revision)"
          echo "- \`/rebuttal\` — Step 3-4: Revision + rebuttal writing"
          echo ""
          for wf in paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; echo ""; }
          done
          ;;
        reviewer)
          echo "## Your Workflows"
          echo "- \`/paper-pipeline\` — Phase 7: Internal peer review"
          echo "- \`/rebuttal\` — Step 1 (Analyze), Step 5 (Review rebuttal)"
          echo ""
          for wf in paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; echo ""; }
          done
          ;;
        scout)
          echo "## Your Workflows"
          echo "- \`/daily-digest\` — You lead this end-to-end"
          echo "- \`/paper-pipeline\` — Phase 0: Trend sensing"
          echo "- \`/brainstorm\` — Step 1: Provide recent hot papers"
          echo ""
          for wf in daily-digest paper-pipeline brainstorm; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; echo ""; }
          done
          ;;
      esac
    } >> "${agents_md}"
    success "${id}/AGENTS.md ✓ (workflow instructions appended)"
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
      *) warn "Invalid choice, skipping."; SKIP_BINDINGS=true; return ;;
    esac
  fi

  if [[ -z "${GROUP_ID}" ]]; then
    echo -en "\n${BOLD}  Enter group/chat ID for ${CHANNEL}: ${NC}"
    read -r GROUP_ID
    if [[ -z "${GROUP_ID}" ]]; then
      warn "No group ID, skipping bindings."
      SKIP_BINDINGS=true
      return
    fi
  fi

  if [[ -z "${SESSION_ID}" ]]; then
    echo -en "${BOLD}  Enter session ID (optional, Enter to skip): ${NC}"
    read -r SESSION_ID
  fi

  # Ask about requireMention
  if [[ -z "${REQUIRE_MENTION}" ]]; then
    echo ""
    echo -e "${BOLD}  群聊 @mention 设置:${NC}"
    echo -e "  ${CYAN}y${NC}) 必须 @机器人 才会回复（推荐，避免刷屏）"
    echo -e "  ${CYAN}n${NC}) 机器人自动响应所有消息（无需 @）"
    echo -en "\n${BOLD}  需要 @mention 才回复? [Y/n]: ${NC}"
    read -r mc
    case "${mc}" in
      n|N|no|false)  REQUIRE_MENTION="false" ;;
      *)             REQUIRE_MENTION="true" ;;
    esac
  fi
  info "requireMention: ${REQUIRE_MENTION}"
}

# ── Configure Bindings ──────────────────────────────────────
configure_bindings() {
  if [[ "${SKIP_BINDINGS}" == true ]]; then return; fi

  step "Configuring channel bindings (${CHANNEL})"

  # Build agents JSON
  local agents_json='['
  local first=true
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agent_model
    agent_model="$(get_model "${id}")"
    [[ "${first}" == true ]] && first=false || agents_json+=','
    agents_json+="$(cat <<AJSON
{
      "id": "${id}",
      "name": "${id}",
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

  # Build bindings JSON
  local bindings_json='['
  first=true
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    [[ "${first}" == true ]] && first=false || bindings_json+=','
    bindings_json+="$(cat <<BJSON
{
      "agentId": "${id}",
      "match": {
        "channel": "${CHANNEL}",
        "peer": { "kind": "group", "id": "${GROUP_ID}" }
      }
    }
BJSON
)"
  done
  bindings_json+=']'

  local require_mention_bool=true
  [[ "${REQUIRE_MENTION}" == "false" ]] && require_mention_bool=false

  # ── Safe merge with jq ─────────────────────────────────
  if command -v jq &>/dev/null && [[ -f "${OPENCLAW_CONFIG}" ]]; then
    info "Safe-merging into existing config"
    info "${DIM}(Appending sub-agents. Main agent and all other settings preserved.)${NC}"

    local tmp_file
    tmp_file="$(mktemp)"

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
      # Channel config — open policy, preserve existing keys (appId, appSecret, etc.)
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
    # No existing config — create fresh
    warn "No existing config or jq unavailable. Creating new config."
    local config_dir
    config_dir="$(dirname "${OPENCLAW_CONFIG}")"
    mkdir -p "${config_dir}"

    local rm_val="true"
    [[ "${REQUIRE_MENTION}" == "false" ]] && rm_val="false"

    cat > "${OPENCLAW_CONFIG}" <<CONFIG
{
  "agents": { "list": ${agents_json} },
  "bindings": ${bindings_json},
  "channels": {
    "${CHANNEL}": {
      "groupPolicy": "open",
      "groups": { "${GROUP_ID}": { "requireMention": ${rm_val} } }
    }
  },
  "messages": { "groupChat": { "historyLimit": 50 } }
}
CONFIG
  fi

  success "Bindings configured: ${CHANNEL} → ${GROUP_ID}"
}

# ── Verify ──────────────────────────────────────────────────
verify() {
  step "Verifying setup"
  if [[ "${DRY_RUN}" == true ]]; then
    info "Dry-run mode — skipping verification"
    return
  fi
  openclaw agents list --bindings 2>/dev/null || warn "Could not verify (gateway may not be running)"
  success "Setup complete!"
}

# ── Summary ─────────────────────────────────────────────────
summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}✅ Setup Complete!${NC}                              ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Sub-agents:${NC}         ${#CORE_AGENTS[@]}"
  echo -e "  ${BOLD}Default model:${NC}      ${MODEL}"
  if [[ -n "${MODEL_MAP}" ]]; then
    echo -e "  ${BOLD}Model overrides:${NC}"
    for key in "${!AGENT_MODELS[@]}"; do
      echo -e "    ${key} → ${AGENT_MODELS[${key}]}"
    done
  fi
  if [[ "${SKIP_BINDINGS}" != true ]]; then
    echo -e "  ${BOLD}Channel:${NC}            ${CHANNEL}"
    echo -e "  ${BOLD}Group ID:${NC}           ${GROUP_ID}"
    echo -e "  ${BOLD}Require @mention:${NC}   ${REQUIRE_MENTION}"
  fi
  echo ""
  echo -e "  ${BOLD}What was deployed:${NC}"
  echo -e "  ${DIM}  _soul_source.md  — agent-specific identity (for self-merge)${NC}"
  echo -e "  ${DIM}  _user_source.md  — agent-specific user context${NC}"
  echo -e "  ${DIM}  _soul_raw.md     — generic behavior guidelines${NC}"
  echo -e "  ${DIM}  _user_raw.md     — user template${NC}"
  echo -e "  ${DIM}  BOOTSTRAP.md     — first-run self-merge instructions${NC}"
  echo -e "  ${DIM}  AGENTS.md        — workflow instructions (appended)${NC}"
  echo ""
  echo -e "  ${BOLD}How it works:${NC}"
  echo -e "  Each agent reads BOOTSTRAP.md on first run, merges the source"
  echo -e "  files into its SOUL.md and USER.md, then deletes the bootstrap."
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo -e "    1. Start the gateway:  ${CYAN}openclaw gateway${NC}"
  echo -e "    2. Check agents:       ${CYAN}openclaw agents list --bindings${NC}"
  echo -e "    3. Test in channel:    ${CYAN}@planner${NC} in your ${CHANNEL:-channel} group"
  echo ""
}

# ── Main ────────────────────────────────────────────────────
main() {
  banner
  preflight
  create_agents
  set_identities
  deploy_source_files
  append_workflows
  prompt_channel
  configure_bindings
  verify
  summary
}

main "$@"
