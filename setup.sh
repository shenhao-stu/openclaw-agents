#!/usr/bin/env bash

set -euo pipefail

VERSION="4.2.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✖${NC}  $*" >&2; }
step()    { echo -e "\n${MAGENTA}▸${NC} ${BOLD}$*${NC}"; }

usage() {
  cat <<'EOF'
OpenClaw Agents — Setup (Kimaki-style SOP)

Purpose:
  Provision the OpenClaw agent fleet and routing. One command, guided flow.
  Discord uses OpenClaw native multi-bot routing (one bot account per agent).

Usage:
  ./setup.sh                    Interactive wizard
  ./setup.sh --mode local       Local agent-to-agent only
  ./setup.sh --mode channel --channel discord --group-id <guild-id>

Modes:
  --mode local            Local workflow (agentToAgent, no Discord)
  --mode channel          Channel bindings (feishu|whatsapp|telegram|discord|slack)

Channel flags:
  --channel CHANNEL       Platform name
  --group-id ID           Shared group/channel/guild ID
  --group-map MAP         Per-agent IDs: coder=oc_dev,scout=oc_news
  --require-mention BOOL  true|false (default: true)

Universal:
  --model MODEL           Default model
  --model-map MAP         Per-agent overrides: coder=...,planner=...
  --dry-run               Preview only, no writes
  -h, --help              This help

SOP Steps (what this script does):
  1. Preflight: openclaw, jq
  2. Create 8 core sub-agents + workspaces
  3. Deploy bootstrap + source files
  4. Append workflow refs to AGENTS.md
  5. Deploy openclaw-icons to workspaces
  6. Update ~/.openclaw/openclaw.json
  7. If Discord: mentionPatterns + mention guard

Discord runtime (separate):
  Discord uses OpenClaw native multi-bot routing. Each agent = one bot account.
  AI agents should read `SKILL.md` before operating this repo.
  See: docs/discord-setup.md, docs/discord-thread-sop.md, SKILL.md
  Dispatch: ./scripts/discord-thread-dispatch.sh --channel X --agent planner --prompt "..."
EOF
}

banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${BOLD}🐾 OpenClaw Multi-Agent Setup${NC}  v${VERSION}               ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}OpenClaw fleet + Discord thread SOP${NC}                ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/.agents"
OPENCLAW_HOME="${HOME}/.openclaw"
OPENCLAW_CONFIG="${OPENCLAW_HOME}/openclaw.json"
DEFAULT_MODEL="zai/glm-5"

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

MODE=""
CHANNEL=""
GROUP_ID=""
GROUP_MAP=""
MODEL="${DEFAULT_MODEL}"
MODEL_MAP=""
REQUIRE_MENTION=""
DRY_RUN=false

declare -A AGENT_MODELS
declare -A AGENT_GROUPS

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --channel) CHANNEL="${2:-}"; shift 2 ;;
    --group-id) GROUP_ID="${2:-}"; shift 2 ;;
    --group-map) GROUP_MAP="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --model-map) MODEL_MAP="${2:-}"; shift 2 ;;
    --require-mention) REQUIRE_MENTION="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -n "${MODEL_MAP}" ]]; then
  IFS=',' read -ra MODEL_ENTRIES <<< "${MODEL_MAP}"
  for entry in "${MODEL_ENTRIES[@]}"; do
    AGENT_MODELS["${entry%%=*}"]="${entry#*=}"
  done
fi

if [[ -n "${GROUP_MAP}" ]]; then
  IFS=',' read -ra GROUP_ENTRIES <<< "${GROUP_MAP}"
  for entry in "${GROUP_ENTRIES[@]}"; do
    AGENT_GROUPS["${entry%%=*}"]="${entry#*=}"
  done
fi

get_model() {
  local agent_id="$1"
  echo "${AGENT_MODELS[${agent_id}]:-${MODEL}}"
}

get_group() {
  local agent_id="$1"
  echo "${AGENT_GROUPS[${agent_id}]:-${GROUP_ID}}"
}

run() {
  if [[ "${DRY_RUN}" == true ]]; then
    echo -e "  ${DIM}$*${NC}"
  else
    eval "$@"
  fi
}

preflight() {
  step "[1/8] Preflight checks"

  if ! command -v openclaw >/dev/null 2>&1; then
    error "openclaw CLI not found. Install: curl -fsSL https://openclaw.ai/install.sh | bash"
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    error "jq not found. Install jq before running setup.sh"
    exit 1
  fi

  if [[ ! -d "${AGENTS_DIR}" ]]; then
    error "Agent source directory not found: ${AGENTS_DIR}"
    exit 1
  fi

  mkdir -p "${OPENCLAW_HOME}"
  if [[ ! -f "${OPENCLAW_CONFIG}" ]]; then
    echo '{}' > "${OPENCLAW_CONFIG}"
    success "Created fresh config → ${OPENCLAW_CONFIG}"
  else
    local backup="${OPENCLAW_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${OPENCLAW_CONFIG}" "${backup}"
    success "Config backed up → ${backup}"
  fi
}

create_agents() {
  step "[2/8] Creating ${#CORE_AGENTS[@]} core sub-agents"
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agent_model
    agent_model="$(get_model "${id}")"
    info "${emoji} ${name} → ${agent_model}"
    run "openclaw agents add '${id}' --model '${agent_model}' --workspace '${workspace}' 2>/dev/null || true"
  done
}

set_identities() {
  step "[3/8] Setting agent identities"
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    run "openclaw agents set-identity --agent '${id}' --name '${emoji} ${name}' 2>/dev/null || true"
  done
}

deploy_source_files() {
  step "[4/8] Deploying bootstrap and source files"
  info "Agents will self-merge from BOOTSTRAP.md on first run"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local src_dir="${AGENTS_DIR}/${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    mkdir -p "${workspace}"
    [[ -f "${src_dir}/soul.md" ]] && cp "${src_dir}/soul.md" "${workspace}/_soul_source.md"
    [[ -f "${src_dir}/user.md" ]] && cp "${src_dir}/user.md" "${workspace}/_user_source.md"

    if [[ -f "${src_dir}/agent.md" ]]; then
      sed "s|anthropic/claude-sonnet-4-5|${agent_model}|g" "${src_dir}/agent.md" > "${workspace}/_agent_source.md"
    fi

    cat > "${workspace}/BOOTSTRAP.md" <<'BOOTEOF'
# 🐾 OpenClaw Multi-Agent Bootstrap

你是 OpenClaw 多智能体系统中的一个子 Agent。这是你的首次启动。

## 请按顺序执行以下步骤：
1. 读取 `_soul_source.md`，将其合并进当前 `SOUL.md`
2. 读取 `_user_source.md`，将其合并进当前 `USER.md`
3. 读取 `_agent_source.md` 了解你的工具、模型和通信约定
4. 阅读 `AGENTS.md` 底部追加的工作流参考
5. 完成后删除 `BOOTSTRAP.md` 和所有 `_*_source.md`
BOOTEOF
  done
}

deploy_openclaw_icons() {
  step "[5/8] Deploying openclaw-icons to workspaces"
  local icons_dir="${SCRIPT_DIR}/openclaw-icons"
  if [[ ! -d "${icons_dir}" ]]; then
    warn "openclaw-icons not found at ${icons_dir}; skipping"
    return
  fi
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    mkdir -p "${workspace}/.icons"
    if [[ -d "${icons_dir}/svg" ]]; then
      cp -r "${icons_dir}/svg" "${workspace}/.icons/" 2>/dev/null || true
    fi
    if [[ -d "${icons_dir}/png" ]]; then
      cp -r "${icons_dir}/png" "${workspace}/.icons/" 2>/dev/null || true
    fi
  done
  success "Icons deployed to agent workspaces"
}

append_workflows() {
  step "[6/8] Appending workflow references"
  local workflow_dir="${AGENTS_DIR}/workflows"

  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agents_md="${workspace}/AGENTS.md"
    [[ ! -f "${agents_md}" ]] && touch "${agents_md}"

    {
      echo ""
      echo "---"
      echo "# 📋 Workflow Reference for ${emoji} ${name}"
      echo ""
      case "${id}" in
        planner)
          for wf in paper-pipeline brainstorm rebuttal daily-digest; do
            [[ -f "${workflow_dir}/${wf}.md" ]] && { echo "---"; cat "${workflow_dir}/${wf}.md"; }
          done
          ;;
        ideator|critic)
          for wf in brainstorm paper-pipeline; do
            [[ -f "${workflow_dir}/${wf}.md" ]] && { echo "---"; cat "${workflow_dir}/${wf}.md"; }
          done
          ;;
        surveyor)
          for wf in brainstorm paper-pipeline rebuttal; do
            [[ -f "${workflow_dir}/${wf}.md" ]] && { echo "---"; cat "${workflow_dir}/${wf}.md"; }
          done
          ;;
        coder|writer|reviewer)
          for wf in paper-pipeline rebuttal; do
            [[ -f "${workflow_dir}/${wf}.md" ]] && { echo "---"; cat "${workflow_dir}/${wf}.md"; }
          done
          ;;
        scout)
          for wf in daily-digest paper-pipeline brainstorm; do
            [[ -f "${workflow_dir}/${wf}.md" ]] && { echo "---"; cat "${workflow_dir}/${wf}.md"; }
          done
          ;;
      esac
    } >> "${agents_md}"
  done
}

prompt_mode_and_channel() {
  if [[ -z "${MODE}" ]]; then
    echo -e "\n${BOLD}Select deployment mode:${NC}"
    echo -e "  ${CYAN}1${NC}) Channel Mode (OpenClaw bindings for chat platforms)"
    echo -e "  ${CYAN}2${NC}) Local Workflow Mode (OpenClaw agentToAgent only)"
    echo -en "  Choice [1-2]: "
    read -r mode_choice
    case "${mode_choice}" in
      2) MODE="local" ;;
      *) MODE="channel" ;;
    esac
  fi

  if [[ "${MODE}" == "local" ]]; then
    info "Selected Local Workflow Mode"
    return
  fi

  if [[ -z "${CHANNEL}" ]]; then
    echo -e "\n${BOLD}Select a channel:${NC}"
    echo -e "  ${CYAN}1${NC}) feishu"
    echo -e "  ${CYAN}2${NC}) whatsapp"
    echo -e "  ${CYAN}3${NC}) telegram"
    echo -e "  ${CYAN}4${NC}) discord"
    echo -e "  ${CYAN}5${NC}) slack"
    echo -en "  Choice [1-5]: "
    read -r channel_choice
    case "${channel_choice}" in
      1) CHANNEL="feishu" ;;
      2) CHANNEL="whatsapp" ;;
      3) CHANNEL="telegram" ;;
      4) CHANNEL="discord" ;;
      5) CHANNEL="slack" ;;
      *) error "Invalid channel choice"; exit 1 ;;
    esac
  fi

  if [[ -z "${GROUP_ID}" && -z "${GROUP_MAP}" ]]; then
    echo -e "\n${BOLD}How should ${CHANNEL} bindings be assigned?${NC}"
    echo -e "  ${CYAN}1${NC}) One shared group/channel for all agents"
    echo -e "  ${CYAN}2${NC}) One binding per agent"
    echo -en "  Choice [1-2]: "
    read -r group_choice

    if [[ "${group_choice}" == "2" ]]; then
      for entry in "${CORE_AGENTS[@]}"; do
        IFS='|' read -r id name emoji role <<< "${entry}"
        echo -en "  ${emoji} ${name} group/channel ID: "
        read -r gid
        if [[ -n "${gid}" ]]; then
          AGENT_GROUPS["${id}"]="${gid}"
        fi
      done
      GROUP_ID="per_agent_routing"
    else
      echo -en "\n  Shared group/channel ID: "
      read -r GROUP_ID
    fi
  fi

  if [[ -z "${REQUIRE_MENTION}" ]]; then
    echo -e "\n${BOLD}Require @mention before an agent replies?${NC}"
    echo -en "  Choice [Y/n]: "
    read -r mention_choice
    case "${mention_choice}" in
      n|N|no) REQUIRE_MENTION="false" ;;
      *) REQUIRE_MENTION="true" ;;
    esac
  fi
}

configure_discord_mentions() {
  if [[ "${CHANNEL}" != "discord" ]]; then
    return
  fi

  step "Discord-specific mention configuration"
  echo -e "${YELLOW}Discord requires real numeric mentions like <@123...>.${NC}"
  echo -e "${DIM}Tip: enable Developer Mode, then right-click the bot/user avatar and copy the user ID.${NC}"
  echo ""

  declare -A DISCORD_IDS
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    echo -en "  ${emoji} ${name} Discord user ID (optional): "
    read -r discord_id
    if [[ -n "${discord_id}" ]]; then
      DISCORD_IDS["${id}"]="${discord_id}"
    fi
  done

  if [[ ${#DISCORD_IDS[@]} -gt 0 ]]; then
    local discord_agents_json='['
    local first=true
    for entry in "${CORE_AGENTS[@]}"; do
      IFS='|' read -r id name emoji role <<< "${entry}"
      local discord_id="${DISCORD_IDS[${id}]:-}"
      local mention_patterns
      [[ "${first}" == true ]] && first=false || discord_agents_json+=','

      if [[ -n "${discord_id}" ]]; then
        mention_patterns="[\"<@${discord_id}>\", \"@${id}\", \"${id}\", \"@${name}\"]"
      else
        mention_patterns="[\"@${id}\", \"${id}\", \"@${name}\"]"
      fi

      discord_agents_json+="$(cat <<EOF
{
  \"id\": \"${id}\",
  \"groupChat\": {
    \"mentionPatterns\": ${mention_patterns},
    \"historyLimit\": 50
  }
}
EOF
)"
    done
    discord_agents_json+=']'

    local tmp_discord
    tmp_discord="$(mktemp)"
    jq --argjson discord_agents "${discord_agents_json}" '
      .agents.list = [(.agents.list // [])[] |
        (.id as $aid |
          ($discord_agents | map(.id) | index($aid)) as $idx |
          if $idx != null then . * ($discord_agents[$idx]) else . end)
      ]
    ' "${OPENCLAW_CONFIG}" > "${tmp_discord}"

    if [[ "${DRY_RUN}" == true ]]; then
      cat "${tmp_discord}"
    else
      cp "${tmp_discord}" "${OPENCLAW_CONFIG}"
    fi
    rm -f "${tmp_discord}"
    success "Discord mentionPatterns updated"
  fi

  step "Injecting Discord mention guard into agent prompts"
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local soul_src="${workspace}/_soul_source.md"
    if [[ -f "${soul_src}" ]] && ! grep -q "Discord 通信极度重要警告" "${soul_src}" 2>/dev/null; then
      cat >> "${soul_src}" <<'EOF'

## [ Discord 通信极度重要警告 ]
🚨🚨🚨 极度重要警告 🚨🚨🚨
当你需要在 Discord 中指派任务时，不能把 `<@数字ID>` 只放在 Markdown 表格、代码块或列表结构里。
如果 mention 被包在这些格式里，Discord 往往会把它当成普通文本，目标对象不会被真正通知。
正确做法是在消息末尾追加一行纯文本指派，例如：
「<@1478488144499183749> 和 <@1478488715226648770>，请立刻开始执行上述任务！」
在复杂任务里，优先引导 Planner 使用 Discord 子线程，而不是在同一条长消息里挤满多轮协作。
EOF
      success "Mention guard injected for ${emoji} ${name}"
    fi
  done
}

configure_config() {
  step "[7/8] Generating openclaw.json routing"

  local agents_json
  agents_json="$(for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agent_model
    agent_model="$(get_model "${id}")"
    jq -n \
      --arg id "${id}" \
      --arg name "${name}" \
      --arg emoji "${emoji}" \
      --arg workspace "${workspace}" \
      --arg model "${agent_model}" \
      '{
        id: $id,
        name: $id,
        workspace: $workspace,
        model: $model,
        identity: { name: ($emoji + " " + $name) },
        groupChat: {
          mentionPatterns: [("@" + $id), $id, ("@" + $name)],
          historyLimit: 50
        }
      }'
  done | jq -s .)"

  local our_ids
  our_ids="$(printf '%s\n' "${CORE_AGENTS[@]}" | cut -d'|' -f1 | jq -R . | jq -s .)"
  local tmp_file
  tmp_file="$(mktemp)"
  local tmp_agents
  tmp_agents="$(mktemp)"
  printf '%s' "${agents_json}" > "${tmp_agents}"

  if [[ "${MODE}" == "local" ]]; then
    jq --slurpfile new_agents "${tmp_agents}" --argjson our_ids "${our_ids}" '
      $new_agents[0] as $agents |
      .agents = (.agents // {})
      | .agents.list = (
          [(.agents.list // [])[] | select(.id as $id | $our_ids | index($id) | not)]
          + $agents
        )
      | .tools = (.tools // {}) * {
          "agentToAgent": {
            "enabled": true,
            "allow": [
              { "from": "*", "to": "planner" },
              { "from": "planner", "to": "*" },
              { "from": "ideator", "to": "critic" },
              { "from": "critic", "to": "ideator" },
              { "from": "writer", "to": "reviewer" },
              { "from": "reviewer", "to": "writer" }
            ]
          }
        }
    ' "${OPENCLAW_CONFIG}" > "${tmp_file}"
  else
    local bindings_json='['
    local all_group_ids=()
    first=true

    for entry in "${CORE_AGENTS[@]}"; do
      IFS='|' read -r id name emoji role <<< "${entry}"
      local agent_group
      agent_group="$(get_group "${id}")"
      [[ "${first}" == true ]] && first=false || bindings_json+=','
      bindings_json+="$(cat <<EOF
{
  \"agentId\": \"${id}\",
  \"match\": {
    \"channel\": \"${CHANNEL}\",
    \"peer\": { \"kind\": \"group\", \"id\": \"${agent_group}\" }
  }
}
EOF
)"
      if [[ ! " ${all_group_ids[*]:-} " =~ " ${agent_group} " ]]; then
        all_group_ids+=("${agent_group}")
      fi
    done
    bindings_json+=']'

    local require_mention_bool=true
    [[ "${REQUIRE_MENTION}" == "false" ]] && require_mention_bool=false

    local groups_json="{"
    first=true
    for gid in "${all_group_ids[@]}"; do
      [[ "${first}" == true ]] && first=false || groups_json+="," 
      groups_json+="\"${gid}\": { \"requireMention\": ${require_mention_bool} }"
    done
    groups_json+="}"

    jq --slurpfile new_agents "${tmp_agents}" \
       --argjson new_bindings "${bindings_json}" \
       --argjson our_ids "${our_ids}" \
       --arg channel "${CHANNEL}" \
       --argjson new_groups "${groups_json}" '
      $new_agents[0] as $agents |
      .agents = (.agents // {})
      | .agents.list = (
          [(.agents.list // [])[] | select(.id as $id | $our_ids | index($id) | not)]
          + $agents
        )
      | .bindings = (
          [(.bindings // [])[] | select(.agentId as $aid | $our_ids | index($aid) | not)]
          + $new_bindings
        )
      | .channels = (.channels // {})
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
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    cat "${tmp_file}"
  else
    cp "${tmp_file}" "${OPENCLAW_CONFIG}"
  fi
  rm -f "${tmp_file}" "${tmp_agents}"

  configure_discord_mentions
  success "Config updated → ${OPENCLAW_CONFIG}"
}

verify_setup() {
  step "[8/8] Verifying setup"
  if [[ "${DRY_RUN}" == true ]]; then
    warn "Dry run enabled; skipping live verification commands"
    return
  fi

  openclaw agents list --bindings 2>/dev/null || warn "openclaw agents list --bindings returned non-zero"
}

summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}✅ Setup Complete${NC}                                      ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Mode:${NC}    $( [[ "${MODE}" == "local" ]] && echo "Local Workflow (agentToAgent)" || echo "Channel (${CHANNEL})" )"
  echo -e "  ${BOLD}Agents:${NC}  ${#CORE_AGENTS[@]}"
  echo -e "  ${BOLD}Model:${NC}   ${MODEL}"
  if [[ "${MODE}" == "channel" ]]; then
    echo -e "  ${BOLD}@mention:${NC} ${REQUIRE_MENTION}"
    echo -e "  ${BOLD}Bindings:${NC}"
    for entry in "${CORE_AGENTS[@]}"; do
      IFS='|' read -r id name emoji role <<< "${entry}"
      echo -e "    ${emoji} ${id} → $(get_group "${id}")"
    done
  fi

  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo -e "    1. ${CYAN}openclaw gateway${NC}"

  if [[ "${MODE}" == "channel" && "${CHANNEL}" == "discord" ]]; then
    echo -e "    2. Configure bot tokens: ${CYAN}openclaw config set channels.discord.accounts.<agent>.token '\"TOKEN\"' --json${NC}"
    echo -e "    3. Read ${CYAN}docs/discord-setup.md${NC}"
    echo -e "    4. Read ${CYAN}SKILL.md${NC} for AI-agent SOP"
    echo -e "    5. Create child threads: ${CYAN}./scripts/discord-thread-dispatch.sh --channel <id> --agent planner --prompt \"...\"${NC}"
  elif [[ "${MODE}" == "channel" ]]; then
    echo -e "    2. Test in the bound group by mentioning ${CYAN}@planner${NC}"
  else
    echo -e "    2. Run ${CYAN}openclaw tui${NC} or ${CYAN}openclaw dashboard${NC}"
    echo -e "    3. Read ${CYAN}SKILL.md${NC} for AI-agent SOP and recommended skills"
  fi

  echo ""
  echo -e "  ${BOLD}AI Agent Entry:${NC} read ${CYAN}SKILL.md${NC}"
  echo ""
}

main() {
  banner
  preflight
  create_agents
  set_identities
  deploy_source_files
  deploy_openclaw_icons
  append_workflows
  prompt_mode_and_channel
  configure_config
  verify_setup
  summary
}

main "$@"
