#!/usr/bin/env bash
# ============================================================
#  OpenClaw Agents — One-Command Multi-Agent Setup  (v2.1.0)
# ============================================================
#  Usage:
#    ./setup.sh                          # Interactive setup
#    ./setup.sh --channel feishu         # Pre-select channel
#    ./setup.sh --group-id oc_xxx        # Default group for all agents
#    ./setup.sh --group-map 'coder=oc_aaa,scout=oc_bbb'   # Per-agent groups
#    ./setup.sh --model zai/glm-5        # Unified model for all agents
#    ./setup.sh --model-map planner=zai/glm-5,coder=ollama/kimi-k2.5:cloud
#    ./setup.sh --skip-bindings          # Skip channel binding
#    ./setup.sh --dry-run                # Preview without executing
#
#  This script will:
#    1. Verify openclaw CLI is installed
#    2. Create all sub-agents (openclaw auto-generates AGENTS.md, SOUL.md, USER.md)
#    3. Set visual identities for each agent
#    4. Copy agent-specific soul.md + user.md into workspace for self-merge
#    5. Create BOOTSTRAP.md so the agent merges on first run
#    6. Append workflow instructions to AGENTS.md
#    7. Configure openclaw.json with per-agent routing bindings
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
  echo -e "${CYAN}║${NC}  ${BOLD}🐾 OpenClaw Multi-Agent Setup${NC}  v2.1.0          ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}Agent self-merge · Per-agent groups · Workflows${NC} ${CYAN}║${NC}"
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
GROUP_ID=""            # Default group ID for all agents
GROUP_MAP=""           # Per-agent group overrides: agent=group_id,...
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
    --group-map)       GROUP_MAP="$2";       shift 2 ;;
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
      echo "  --group-id ID          Default group ID for all agents"
      echo "  --group-map MAP        Per-agent group IDs (comma-separated)"
      echo "                         Example: coder=oc_aaa,scout=oc_bbb"
      echo "                         Agents not listed use --group-id"
      echo "  --model MODEL          Default model for ALL agents (default: ${DEFAULT_MODEL})"
      echo "  --model-map MAP        Per-agent model overrides (comma-separated)"
      echo "  --require-mention BOOL Require @mention to respond (true|false)"
      echo "  --skip-bindings        Skip channel binding configuration"
      echo "  --dry-run              Preview commands without executing"
      echo "  -h, --help             Show this help message"
      echo ""
      echo "Group Binding:"
      echo "  On Feishu, each sub-agent can bind to a different group."
      echo "  Use --group-id for a shared group, --group-map for per-agent groups."
      echo ""
      echo "Examples:"
      echo "  # All agents in one group"
      echo "  ./setup.sh --channel feishu --group-id oc_xxx"
      echo ""
      echo "  # Agents in different groups"
      echo "  ./setup.sh --channel feishu --group-id oc_default \\"
      echo "    --group-map 'coder=oc_dev_group,scout=oc_news_group'"
      echo ""
      echo "  # Custom models"
      echo "  ./setup.sh --model zai/glm-5 \\"
      echo "    --model-map 'coder=ollama/kimi-k2.5:cloud' \\"
      echo "    --channel feishu --group-id oc_xxx"
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
    AGENT_MODELS["${entry%%=*}"]="${entry#*=}"
  done
fi

get_model() {
  local agent_id="$1"
  echo "${AGENT_MODELS[${agent_id}]:-${MODEL}}"
}

# ── Parse group map ─────────────────────────────────────────
declare -A AGENT_GROUPS
if [[ -n "${GROUP_MAP}" ]]; then
  IFS=',' read -ra MAP_ENTRIES <<< "${GROUP_MAP}"
  for entry in "${MAP_ENTRIES[@]}"; do
    AGENT_GROUPS["${entry%%=*}"]="${entry#*=}"
  done
fi

get_group() {
  local agent_id="$1"
  echo "${AGENT_GROUPS[${agent_id}]:-${GROUP_ID}}"
}

# ── Helper: run or preview ──────────────────────────────────
run() {
  if [[ "${DRY_RUN}" == true ]]; then
    echo -e "  ${DIM}\$ $*${NC}"
  else
    eval "$@"
  fi
}

# ── Preflight ──────────────────────────────────────────────
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

  # Backup
  if [[ -f "${OPENCLAW_CONFIG}" ]]; then
    local backup="${OPENCLAW_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${OPENCLAW_CONFIG}" "${backup}"
    success "Config backed up → ${backup}"
  fi

  info "Default model: ${BOLD}${MODEL}${NC}"
}

# ── Step 1: Create Agents ──────────────────────────────────
create_agents() {
  step "Creating ${#CORE_AGENTS[@]} sub-agents"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    info "${emoji} ${name} → model: ${agent_model}"
    run "openclaw agents add ${id} \
      --model '${agent_model}' \
      --workspace '${workspace}' 2>/dev/null || true"

    success "${id} created"
  done
}

# ── Step 2: Set Identities ─────────────────────────────────
set_identities() {
  step "Setting visual identities"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    run "openclaw agents set-identity \
      --agent '${id}' \
      --name '${emoji} ${name}' 2>/dev/null || true"
    success "${id} → ${emoji} ${name}"
  done
}

# ── Step 3: Deploy source files + BOOTSTRAP.md ─────────────
deploy_source_files() {
  step "Deploying source files to workspaces"
  info "${DIM}Agent will self-merge via BOOTSTRAP.md on first run${NC}"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local src_dir="${AGENTS_DIR}/${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    mkdir -p "${workspace}"

    # Copy agent-specific source files (for self-merge)
    [[ -f "${src_dir}/soul.md" ]] && cp "${src_dir}/soul.md" "${workspace}/_soul_source.md"
    [[ -f "${src_dir}/user.md" ]] && cp "${src_dir}/user.md" "${workspace}/_user_source.md"
    if [[ -f "${src_dir}/agent.md" ]]; then
      sed "s|anthropic/claude-sonnet-4-5|${agent_model}|g" \
        "${src_dir}/agent.md" > "${workspace}/_agent_source.md"
    fi

    # Create BOOTSTRAP.md — first-run self-merge instructions
    cat > "${workspace}/BOOTSTRAP.md" << 'BOOTEOF'
# 🐾 OpenClaw Multi-Agent Bootstrap

你是 OpenClaw 多智能体系统中的一个子 Agent。这是你的首次启动。

## 请按顺序执行以下步骤：

### 1. 合并你的身份（SOUL.md）
读取 `_soul_source.md`，这是你的专属身份、能力和人格定义。
将其内容**智能合并**到你现有的 `SOUL.md` 中（保留原有通用行为规范，追加你的专属身份）。

### 2. 合并用户上下文（USER.md）
读取 `_user_source.md`，这是你的 Agent 专属用户上下文。
将其内容合并到你的 `USER.md` 中。

### 3. 了解你的配置
读取 `_agent_source.md`，了解你的模型配置和工具权限。

### 4. 阅读工作流
检查 `AGENTS.md` 底部的工作流指引，了解你参与哪些工作流以及你的职责。

### 5. 清理
合并完成后，删除本文件 (`BOOTSTRAP.md`) 和所有 `_*_source.md` 文件。

---

_Generated by [openclaw-agents](https://github.com/shenhao-stu/openclaw-agents)_
BOOTEOF
    success "${id}: _soul_source.md + _user_source.md + BOOTSTRAP.md ✓"

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

    [[ ! -f "${agents_md}" ]] && touch "${agents_md}"

    {
      echo ""; echo "---"; echo ""
      echo "# 📋 Workflow Reference for ${emoji} ${name}"
      echo ""

      case "${id}" in
        planner)
          echo "## Your Workflows (Orchestrator)"
          echo "- \`/paper-pipeline\` — 全流程统筹"
          echo "- \`/brainstorm\` — 协调头脑风暴"
          echo "- \`/rebuttal\` — 协调 Rebuttal 策略"
          echo "- \`/daily-digest\` — 接收 Scout 预警"
          for wf in paper-pipeline brainstorm rebuttal daily-digest; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo ""; echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; }
          done ;;
        ideator)
          echo "## Your Workflows"
          echo "- \`/brainstorm\` — 主导 Idea 生成 (Step 2, 4, 6)"
          echo "- \`/paper-pipeline\` — Phase 2-3"
          for wf in brainstorm paper-pipeline; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo ""; echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; }
          done ;;
        critic)
          echo "## Your Workflows"
          echo "- \`/brainstorm\` — Step 5.5 品鉴 (SHARP ≥ 18)"
          echo "- \`/paper-pipeline\` — Phase 2.5, 3, 6, 7"
          for wf in brainstorm paper-pipeline; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo ""; echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; }
          done ;;
        surveyor)
          echo "## Your Workflows"
          echo "- \`/brainstorm\` — Step 3 新颖性验证"
          echo "- \`/paper-pipeline\` — Phase 1 文献调研"
          echo "- \`/rebuttal\` — 补充引用"
          for wf in brainstorm paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo ""; echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; }
          done ;;
        coder)
          echo "## Your Workflows"
          echo "- \`/paper-pipeline\` — Phase 4-5 实现+实验"
          echo "- \`/rebuttal\` — 补充实验"
          for wf in paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo ""; echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; }
          done ;;
        writer)
          echo "## Your Workflows"
          echo "- \`/paper-pipeline\` — Phase 6-7 撰写+修改"
          echo "- \`/rebuttal\` — 撰写 Rebuttal"
          for wf in paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo ""; echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; }
          done ;;
        reviewer)
          echo "## Your Workflows"
          echo "- \`/paper-pipeline\` — Phase 7 内部审稿"
          echo "- \`/rebuttal\` — 分析审稿意见 + 审核 Rebuttal"
          for wf in paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo ""; echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; }
          done ;;
        scout)
          echo "## Your Workflows"
          echo "- \`/daily-digest\` — 你全权负责"
          echo "- \`/paper-pipeline\` — Phase 0 趋势感知"
          echo "- \`/brainstorm\` — 提供热门论文"
          for wf in daily-digest paper-pipeline brainstorm; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo ""; echo "---"; echo ""; cat "${wf_dir}/${wf}.md"; }
          done ;;
      esac
    } >> "${agents_md}"
    success "${id}/AGENTS.md ✓"
  done
}

# ── Interactive Channel Setup ───────────────────────────────
prompt_channel() {
  if [[ "${SKIP_BINDINGS}" == true ]]; then
    info "Skipping channel binding (--skip-bindings)"
    return
  fi

  if [[ -z "${CHANNEL}" ]]; then
    echo -e "\n${BOLD}Select a channel:${NC}"
    echo -e "  ${CYAN}1${NC}) feishu   (飞书)"
    echo -e "  ${CYAN}2${NC}) whatsapp"
    echo -e "  ${CYAN}3${NC}) telegram"
    echo -e "  ${CYAN}4${NC}) discord"
    echo -e "  ${CYAN}5${NC}) slack"
    echo -e "  ${CYAN}s${NC}) skip"
    echo -en "\n  Choice [1-5/s]: "
    read -r choice
    case "${choice}" in
      1) CHANNEL="feishu" ;;
      2) CHANNEL="whatsapp" ;;
      3) CHANNEL="telegram" ;;
      4) CHANNEL="discord" ;;
      5) CHANNEL="slack" ;;
      *) SKIP_BINDINGS=true; return ;;
    esac
  fi

  # ── Group ID (default for all agents) ─────────────────────
  if [[ -z "${GROUP_ID}" ]]; then
    echo -en "\n${BOLD}  Default group ID for ${CHANNEL}: ${NC}"
    read -r GROUP_ID
    if [[ -z "${GROUP_ID}" ]]; then
      warn "No group ID, skipping bindings."
      SKIP_BINDINGS=true
      return
    fi
  fi

  # ── Per-agent group overrides ─────────────────────────────
  if [[ -z "${GROUP_MAP}" ]]; then
    echo ""
    echo -e "  ${DIM}Each sub-agent can bind to a different group.${NC}"
    echo -e "  ${DIM}Press Enter to use default group (${GROUP_ID}) for all agents.${NC}"
    echo -en "${BOLD}  Per-agent group overrides (e.g. coder=oc_xxx,scout=oc_yyy): ${NC}"
    read -r GROUP_MAP
    if [[ -n "${GROUP_MAP}" ]]; then
      IFS=',' read -ra MAP_ENTRIES <<< "${GROUP_MAP}"
      for entry in "${MAP_ENTRIES[@]}"; do
        AGENT_GROUPS["${entry%%=*}"]="${entry#*=}"
      done
    fi
  fi

  # ── Ask about requireMention ──────────────────────────────
  if [[ -z "${REQUIRE_MENTION}" ]]; then
    echo ""
    echo -e "  ${CYAN}y${NC}) 必须 @机器人 才回复（推荐）"
    echo -e "  ${CYAN}n${NC}) 自动响应所有消息（无需 @）"
    echo -en "  需要 @mention? [Y/n]: "
    read -r mc
    case "${mc}" in
      n|N|no|false) REQUIRE_MENTION="false" ;;
      *)            REQUIRE_MENTION="true" ;;
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

  # Build bindings JSON — each agent can have a DIFFERENT group-id
  local bindings_json='['
  first=true
  local all_group_ids=()
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local agent_group
    agent_group="$(get_group "${id}")"
    [[ "${first}" == true ]] && first=false || bindings_json+=','
    bindings_json+="$(cat <<BJSON
{
      "agentId": "${id}",
      "match": {
        "channel": "${CHANNEL}",
        "peer": { "kind": "group", "id": "${agent_group}" }
      }
    }
BJSON
)"
    # Collect unique group IDs
    if [[ ! " ${all_group_ids[*]:-} " =~ " ${agent_group} " ]]; then
      all_group_ids+=("${agent_group}")
    fi
  done
  bindings_json+=']'

  local require_mention_bool=true
  [[ "${REQUIRE_MENTION}" == "false" ]] && require_mention_bool=false

  # Build groups config for ALL unique group IDs
  local groups_json="{"
  first=true
  for gid in "${all_group_ids[@]}"; do
    [[ "${first}" == true ]] && first=false || groups_json+=","
    groups_json+="\"${gid}\": { \"requireMention\": ${require_mention_bool} }"
  done
  groups_json+="}"

  # ── Safe merge with jq ─────────────────────────────────
  if command -v jq &>/dev/null && [[ -f "${OPENCLAW_CONFIG}" ]]; then
    info "Safe-merging into existing config"

    local tmp_file
    tmp_file="$(mktemp)"

    local our_ids
    our_ids="$(printf '%s\n' "${CORE_AGENTS[@]}" | cut -d'|' -f1 | jq -R . | jq -s .)"

    jq --argjson new_agents "${agents_json}" \
       --argjson new_bindings "${bindings_json}" \
       --argjson our_ids "${our_ids}" \
       --arg channel "${CHANNEL}" \
       --argjson new_groups "${groups_json}" \
    '
      .agents.list = (
        [(.agents.list // [])[] | select(.id as $id | $our_ids | index($id) | not)]
        + $new_agents
      )
      | .bindings = (
        [(.bindings // [])[] | select(
          .agentId as $aid | $our_ids | index($aid) | not
        )]
        + $new_bindings
      )
      | .channels[$channel] = (
        (.channels[$channel] // {}) * {
          "groupPolicy": "open",
          "groups": ((.channels[$channel].groups // {}) * $new_groups)
        }
      )
      | .messages = (.messages // {}) * {
          "groupChat": { "historyLimit": (.messages.groupChat.historyLimit // 50) }
        }
    ' "${OPENCLAW_CONFIG}" > "${tmp_file}"

    if [[ "${DRY_RUN}" == true ]]; then
      cat "${tmp_file}"
    else
      cp "${tmp_file}" "${OPENCLAW_CONFIG}"
    fi
    rm -f "${tmp_file}"
  else
    warn "No existing config or jq unavailable. Creating new."
    mkdir -p "$(dirname "${OPENCLAW_CONFIG}")"
    cat > "${OPENCLAW_CONFIG}" <<CONFIG
{
  "agents": { "list": ${agents_json} },
  "bindings": ${bindings_json},
  "channels": {
    "${CHANNEL}": {
      "groupPolicy": "open",
      "groups": ${groups_json}
    }
  },
  "messages": { "groupChat": { "historyLimit": 50 } }
}
CONFIG
  fi

  success "Bindings configured"
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local ag
    ag="$(get_group "${id}")"
    echo -e "    ${emoji} ${id} → ${ag}"
  done
}

# ── Verify ──────────────────────────────────────────────────
verify() {
  step "Verifying"
  if [[ "${DRY_RUN}" == true ]]; then info "Dry-run — skipping"; return; fi
  openclaw agents list --bindings 2>/dev/null || warn "Gateway may not be running"
  success "Done!"
}

# ── Summary ─────────────────────────────────────────────────
summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}✅ Setup Complete!${NC}                              ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Agents:${NC}  ${#CORE_AGENTS[@]}  |  ${BOLD}Model:${NC} ${MODEL}"
  if [[ "${SKIP_BINDINGS}" != true ]]; then
    echo -e "  ${BOLD}Channel:${NC} ${CHANNEL}  |  ${BOLD}@mention:${NC} ${REQUIRE_MENTION}"
    if [[ -n "${GROUP_MAP}" ]]; then
      echo -e "  ${BOLD}Group mapping:${NC}"
      for entry in "${CORE_AGENTS[@]}"; do
        IFS='|' read -r id name emoji role <<< "${entry}"
        echo -e "    ${emoji} ${id} → $(get_group "${id}")"
      done
    else
      echo -e "  ${BOLD}Group:${NC}   ${GROUP_ID} (all agents)"
    fi
  fi
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo -e "    1. ${CYAN}openclaw gateway${NC}         — Start gateway"
  echo -e "    2. ${CYAN}openclaw agents list${NC}     — Verify agents"
  echo -e "    3. Message ${CYAN}@planner${NC}         — Test in group"
  echo ""
  echo -e "  ${DIM}Each agent reads BOOTSTRAP.md on first run and self-merges its identity.${NC}"
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
