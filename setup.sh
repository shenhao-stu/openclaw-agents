#!/usr/bin/env bash
# ============================================================
#  OpenClaw Agents — One-Command Multi-Agent Setup  (v2.2.0)
# ============================================================
#  Usage:
#    ./setup.sh                          # Interactive setup (asks for mode)
#    ./setup.sh --mode local             # Local Workflow Mode (agentToAgent)
#    ./setup.sh --mode channel --channel feishu --group-id oc_xxx
#
#    [Channel Mode Options]
#    --channel feishu            Pre-select channel
#    --group-id oc_xxx           Default group for all agents
#    --group-map 'coder=oc_1..'  Per-agent groups
#
#    [Universal Options]
#    --model zai/glm-5           Unified model for all agents
#    --model-map planner=...     Per-agent model overrides
#    --dry-run                   Preview config changes
#
#  This script will:
#    1. Verify openclaw CLI is installed
#    2. Create all sub-agents (openclaw auto-generates AGENTS.md, SOUL.md, USER.md)
#    3. Deploy BOOTSTRAP.md + source files so agents self-merge
#    4. Append workflow instructions to AGENTS.md
#    5. Configure openclaw.json:
#       - [Channel Mode] routing bindings (single or per-agent groups)
#       - [Local Mode] agentToAgent tool for inter-agent communication
# ============================================================

set -euo pipefail

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
banner()  {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${BOLD}🐾 OpenClaw Multi-Agent Setup${NC}  v2.2.0          ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}Self-Merge · Multi-Group · Local/Channel Modes${NC}  ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
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
DRY_RUN=false
REQUIRE_MENTION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)            MODE="$2";            shift 2 ;;
    --channel)         CHANNEL="$2";         shift 2 ;;
    --group-id)        GROUP_ID="$2";        shift 2 ;;
    --group-map)       GROUP_MAP="$2";       shift 2 ;;
    --model)           MODEL="$2";           shift 2 ;;
    --model-map)       MODEL_MAP="$2";       shift 2 ;;
    --require-mention) REQUIRE_MENTION="$2"; shift 2 ;;
    --dry-run)         DRY_RUN=true;         shift ;;
    -h|--help)
      echo "Usage: ./setup.sh [OPTIONS]"
      echo "Options:"
      echo "  --mode Mode            Deployment mode: 'channel' or 'local'"
      echo "  --channel CHANNEL      Channel type (feishu|whatsapp|telegram|discord|slack)"
      echo "  --group-id ID          Default group ID for all agents"
      echo "  --group-map MAP        Per-agent group IDs (e.g. coder=oc_aaa,scout=oc_bbb)"
      echo "  --model MODEL          Default model"
      exit 0
      ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Map Parsers ─────────────────────────────────────────────
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

run() {
  if [[ "${DRY_RUN}" == true ]]; then
    echo -e "  ${DIM}\$ $*${NC}"
  else
    eval "$@"
  fi
}

preflight() {
  step "Preflight checks"
  if ! command -v openclaw &>/dev/null; then
    error "openclaw CLI not found."
    exit 1
  fi
  if [[ ! -d "${AGENTS_DIR}" ]]; then
    error "Agent source directory not found: ${AGENTS_DIR}"
    exit 1
  fi
  if [[ -f "${OPENCLAW_CONFIG}" ]]; then
    local backup="${OPENCLAW_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${OPENCLAW_CONFIG}" "${backup}"
    success "Config backed up → ${backup}"
  fi
}

create_agents() {
  step "Creating ${#CORE_AGENTS[@]} sub-agents"
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agent_model
    agent_model="$(get_model "${id}")"

    info "${emoji} ${name} → model: ${agent_model}"
    run "openclaw agents add ${id} --model '${agent_model}' --workspace '${workspace}' 2>/dev/null || true"
  done
}

set_identities() {
  step "Setting visual identities"
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    run "openclaw agents set-identity --agent '${id}' --name '${emoji} ${name}' 2>/dev/null || true"
  done
}

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
    [[ -f "${src_dir}/soul.md" ]] && cp "${src_dir}/soul.md" "${workspace}/_soul_source.md"
    [[ -f "${src_dir}/user.md" ]] && cp "${src_dir}/user.md" "${workspace}/_user_source.md"
    if [[ -f "${src_dir}/agent.md" ]]; then
      sed "s|anthropic/claude-sonnet-4-5|${agent_model}|g" "${src_dir}/agent.md" > "${workspace}/_agent_source.md"
    fi

    cat > "${workspace}/BOOTSTRAP.md" << 'BOOTEOF'
# 🐾 OpenClaw Multi-Agent Bootstrap

你是 OpenClaw 多智能体系统中的一个子 Agent。这是你的首次启动。

## 请按顺序执行以下步骤：
1. **合并你的身份（SOUL.md）**：读取 `_soul_source.md`，追加合并到现有的 `SOUL.md` 中。
2. **合并用户上下文（USER.md）**：读取 `_user_source.md`，合并到你的 `USER.md` 中。
3. **了解配置**：读取 `_agent_source.md`。
4. **阅读工作流**：检查 `AGENTS.md` 底部的工作流指引。
5. **清理**：删除本文件 (`BOOTSTRAP.md`) 和所有 `_*_source.md` 文件。
BOOTEOF
  done
}

append_workflows() {
  step "Appending workflow instructions to AGENTS.md"
  local wf_dir="${AGENTS_DIR}/workflows"
  for entry in "${CORE_AGENTS[@]}"; do
    IFS='|' read -r id name emoji role <<< "${entry}"
    local workspace="${OPENCLAW_HOME}/workspace-${id}"
    local agents_md="${workspace}/AGENTS.md"
    [[ ! -f "${agents_md}" ]] && touch "${agents_md}"

    {
      echo ""; echo "---"; echo "# 📋 Workflow Reference for ${emoji} ${name}"; echo ""
      case "${id}" in
        planner)
          for wf in paper-pipeline brainstorm rebuttal daily-digest; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; cat "${wf_dir}/${wf}.md"; }
          done ;;
        ideator|critic)
          for wf in brainstorm paper-pipeline; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; cat "${wf_dir}/${wf}.md"; }
          done ;;
        surveyor)
          for wf in brainstorm paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; cat "${wf_dir}/${wf}.md"; }
          done ;;
        coder|writer|reviewer)
          for wf in paper-pipeline rebuttal; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; cat "${wf_dir}/${wf}.md"; }
          done ;;
        scout)
          for wf in daily-digest paper-pipeline brainstorm; do
            [[ -f "${wf_dir}/${wf}.md" ]] && { echo "---"; cat "${wf_dir}/${wf}.md"; }
          done ;;
      esac
    } >> "${agents_md}"
  done
}

prompt_mode_and_channel() {
  if [[ -z "${MODE}" ]]; then
    echo -e "\n${BOLD}Select Deployment Mode:${NC}"
    echo -e "  ${CYAN}1${NC}) Channel Mode (Deploy to Feishu, WhatsApp, Telegram, etc.)"
    echo -e "  ${CYAN}2${NC}) Local Workflow Mode (CLI only, agents talk via agentToAgent)"
    echo -en "  Choice [1-2]: "
    read -r m
    case "${m}" in
      2) MODE="local" ;;
      *) MODE="channel" ;;
    esac
  fi

  if [[ "${MODE}" == "local" ]]; then
    info "Selected Local Workflow Mode (agentToAgent configuration)"
    return
  fi

  # Channel Mode Prompts
  if [[ -z "${CHANNEL}" ]]; then
    echo -e "\n${BOLD}Select a channel:${NC}"
    echo -e "  ${CYAN}1${NC}) feishu   (飞书)"
    echo -e "  ${CYAN}2${NC}) whatsapp"
    echo -e "  ${CYAN}3${NC}) telegram"
    echo -e "  ${CYAN}4${NC}) discord"
    echo -e "  ${CYAN}5${NC}) slack"
    echo -e "  ${CYAN}s${NC}) skip / switch to local"
    echo -en "  Choice [1-5/s]: "
    read -r choice
    case "${choice}" in
      1) CHANNEL="feishu" ;;
      2) CHANNEL="whatsapp" ;;
      3) CHANNEL="telegram" ;;
      4) CHANNEL="discord" ;;
      5) CHANNEL="slack" ;;
      *) MODE="local"; return ;;
    esac
  fi

  if [[ -z "${GROUP_ID}" && -z "${GROUP_MAP}" ]]; then
    echo -e "\n${BOLD}How do you want to assign group IDs for ${CHANNEL}?${NC}"
    echo -e "  ${CYAN}1${NC}) All agents in ONE shared group"
    echo -e "  ${CYAN}2${NC}) Paste an INDIVIDUAL group ID for EACH agent"
    echo -en "  Choice [1-2]: "
    read -r gc
    if [[ "${gc}" == "2" ]]; then
      echo ""
      for entry in "${CORE_AGENTS[@]}"; do
        IFS='|' read -r id name emoji role <<< "${entry}"
        echo -en "  Group ID for ${BOLD}${emoji} ${name}${NC}: "
        read -r gid
        if [[ -n "${gid}" ]]; then
          AGENT_GROUPS["${id}"]="${gid}"
        fi
      done
      # Set a dummy default so logic passes
      GROUP_ID="per_agent_routing"
    else
      echo -en "\n${BOLD}  Paste the shared group ID: ${NC}"
      read -r GROUP_ID
    fi
  fi

  if [[ -z "${REQUIRE_MENTION}" ]]; then
    echo -e "\n${BOLD}  Require @mention to trigger agent?${NC} (y=必须@, n=自动回复所有消息)"
    echo -en "  Choice [Y/n]: "
    read -r mc
    case "${mc}" in
      n|N|no) REQUIRE_MENTION="false" ;;
      *)      REQUIRE_MENTION="true" ;;
    esac
  fi
}

configure_config() {
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

  local our_ids
  our_ids="$(printf '%s\n' "${CORE_AGENTS[@]}" | cut -d'|' -f1 | jq -R . | jq -s .)"

  local tmp_file
  tmp_file="$(mktemp)"

  if [[ "${MODE}" == "local" ]]; then
    step "Configuring Local Workflow Mode (agentToAgent)"
    # Enable agentToAgent for planner coordinating other agents, and some peering
    jq --argjson new_agents "${agents_json}" --argjson our_ids "${our_ids}" '
      .agents.list = (
        [(.agents.list // [])[] | select(.id as $id | $our_ids | index($id) | not)]
        + $new_agents
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
    step "Configuring Channel Bindings (${CHANNEL})"
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
        [(.bindings // [])[] | select(.agentId as $aid | $our_ids | index($aid) | not)]
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
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    cat "${tmp_file}"
  else
    cp "${tmp_file}" "${OPENCLAW_CONFIG}"
  fi
  rm -f "${tmp_file}"
  
	if [[ "${CHANNEL}" == "discord" ]]; then
		step "Discord Client ID Configuration"
		echo -e "\n${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
		echo -e "${YELLOW}║${NC} ${BOLD}Discord 多 Agent 协作配置${NC}                                    ${YELLOW}║${NC}"
		echo -e "${YELLOW}╠════════════════════════════════════════════════════════════════╣${NC}"
		echo -e "${YELLOW}║${NC} Discord 的 @mention 机制与飞书/Telegram 不同：              ${YELLOW}║${NC}"
		echo -e "${YELLOW}║${NC} - 飞书/Telegram: @planner 可直接触发                         ${YELLOW}║${NC}"
		echo -e "${YELLOW}║${NC} - Discord: 需要 <@123456789012345678> 格式的数字 ID           ${YELLOW}║${NC}"
		echo -e "${YELLOW}║${NC}                                                                ${YELLOW}║${NC}"
		echo -e "${YELLOW}║${NC} ${CYAN}如何获取 Discord Client ID:${NC}                               ${YELLOW}║${NC}"
		echo -e "${YELLOW}║${NC}  1. 打开 Discord 设置 -> 高级 -> 启用「开发者模式」          ${YELLOW}║${NC}"
		echo -e "${YELLOW}║${NC}  2. 右键点击 Agent 的头像 -> 「复制用户 ID」                 ${YELLOW}║${NC}"
		echo -e "${YELLOW}║${NC}  3. 在下方粘贴对应的 ID                                       ${YELLOW}║${NC}"
		echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
		echo ""
		echo -e "${DIM}(直接按 Enter 跳过，稍后可手动编辑 openclaw.json)${NC}\n"
		
		declare -A DISCORD_IDS
		for entry in "${CORE_AGENTS[@]}"; do
			IFS='|' read -r id name emoji role <<< "${entry}"
			echo -en " ${BOLD}${emoji} ${name}${NC} 的 Discord Client ID: "
			read -r discord_id
			if [[ -n "${discord_id}" ]]; then
				DISCORD_IDS["${id}"]="${discord_id}"
			fi
		done
		
		if [[ ${#DISCORD_IDS[@]} -gt 0 ]]; then
			step "Updating Discord mention patterns"
			local discord_agents_json='['
			local first=true
			for entry in "${CORE_AGENTS[@]}"; do
				IFS='|' read -r id name emoji role <<< "${entry}"
				local discord_id="${DISCORD_IDS[${id}]:-}"
				[[ "${first}" == true ]] && first=false || discord_agents_json+=','
				local mention_patterns
				if [[ -n "${discord_id}" ]]; then
					mention_patterns="[\"<@${discord_id}>\", \"@${id}\", \"${id}\", \"@${name}\"]"
				else
					mention_patterns="[\"@${id}\", \"${id}\", \"@${name}\"]"
				fi
				discord_agents_json+=$(cat <<DAJSON
{
  "id": "${id}",
  "groupChat": {
    "mentionPatterns": ${mention_patterns},
    "historyLimit": 50
  }
}
DAJSON
)
			done
			discord_agents_json+=']'
			
			local tmp_discord
			tmp_discord="$(mktemp)"
			jq --argjson discord_agents "${discord_agents_json}" '
				.agents.list = [.agents.list[] | 
					(.id as $aid | 
						($discord_agents | map(.id) | index($aid)) as $idx |
						if $idx != null then
							. * ($discord_agents[$idx])
						else
							.
						end
					)
				]
			' "${OPENCLAW_CONFIG}" > "${tmp_discord}"
			cp "${tmp_discord}" "${OPENCLAW_CONFIG}"
			rm -f "${tmp_discord}"
			success "Discord mention patterns configured"
		fi
		
		step "Injecting Discord Mention Guard"
		for entry in "${CORE_AGENTS[@]}"; do
			IFS='|' read -r id name emoji role <<< "${entry}"
			local workspace="${OPENCLAW_HOME}/workspace-${id}"
			local soul_src="${workspace}/_soul_source.md"
			
			if [[ -f "${soul_src}" ]]; then
				if ! grep -q "Discord 通信极度重要警告" "${soul_src}" 2>/dev/null; then
					cat >> "${soul_src}" << 'SOULWARN'

## [ Discord 通信极度重要警告 ]
🚨🚨🚨 极度重要警告 🚨🚨🚨
当你需要指派任务给其他 Agent 时，你 **绝对不能** 只把他们的 `<@数字ID>` 写在 Markdown 表格或者代码块 (```) 里！
如果你把 `<@数字ID>` 放在表格里，Discord 系统就会判定那是普通文本，**对方根本收不到任何消息，永远不会回复你！**
你必须在回复的最后，像人类一样，用一段没有任何格式的纯文本直接说：
「<@1478488144499183749> 和 <@1478488715226648770>，请立刻开始执行上述任务！」
如果不这么做，你的任务指派将 **必定失败**。
SOULWARN
					success "Mention Guard injected for ${emoji} ${name}"
				fi
			fi
		done
	fi

	success "Config openclaw.json updated"

summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}✅ Setup Complete!${NC}                              ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Mode:${NC}    $( [[ "${MODE}" == "local" ]] && echo "Local Workflow (agentToAgent)" || echo "Channel (${CHANNEL})" )"
  echo -e "  ${BOLD}Agents:${NC}  ${#CORE_AGENTS[@]}  |  ${BOLD}Default Model:${NC} ${MODEL}"
  if [[ "${MODE}" == "channel" ]]; then
    echo -e "  ${BOLD}@mention:${NC} ${REQUIRE_MENTION}"
    echo -e "  ${BOLD}Group Bindings:${NC}"
    for entry in "${CORE_AGENTS[@]}"; do
      IFS='|' read -r id name emoji role <<< "${entry}"
      echo -e "    ${emoji} ${id} → $(get_group "${id}")"
    done
  fi
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo -e "    1. ${CYAN}openclaw gateway${NC}         — Start gateway"
  if [[ "${MODE}" == "channel" ]]; then
    echo -e "    2. Test in group:    Message ${CYAN}@planner${NC}"
  else
    echo -e "    2. Run workflow:     ${CYAN}openclaw chat planner${NC}"
    echo -e "       Then say: 'Start the paper-pipeline workflow'"
  fi
  echo ""
}

main() {
  banner
  preflight
  create_agents
  set_identities
  deploy_source_files
  append_workflows
  prompt_mode_and_channel
  configure_config
  if [[ "${DRY_RUN}" != true ]]; then
    openclaw agents list --bindings 2>/dev/null || true
  fi
  summary
}

main "$@"
