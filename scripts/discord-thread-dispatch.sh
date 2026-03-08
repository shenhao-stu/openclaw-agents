#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "%b\n" "${BLUE}ℹ${NC}  $*"; }
success() { printf "%b\n" "${GREEN}✔${NC}  $*"; }
warn() { printf "%b\n" "${YELLOW}⚠${NC}  $*"; }
error() { printf "%b\n" "${RED}✖${NC}  $*" >&2; }

usage() {
  cat <<'EOF'
OpenClaw Discord Thread Dispatcher

SOP wrapper for parent-thread / child-thread collaboration using
OpenClaw native Discord support (openclaw message).

Each agent has its own Discord bot account. OpenClaw routes by
accountId → agentId via bindings in openclaw.json.

Usage:
  ./scripts/discord-thread-dispatch.sh --channel <id> --agent planner --prompt "..."
  ./scripts/discord-thread-dispatch.sh --thread <id> --prompt "Continue..."

Examples:

  # Create a new child thread under a channel
  ./scripts/discord-thread-dispatch.sh \
    --channel 1478466947208446106 \
    --agent planner \
    --name "planner: auth bug triage" \
    --prompt "Coordinate coder + reviewer. Report back in parent thread." \
    --dry-run

  # Continue an existing thread
  ./scripts/discord-thread-dispatch.sh \
    --thread 1234567890123456789 \
    --prompt "Continue from checkpoint." \
    --dry-run

  # One-shot agent turn (no thread)
  ./scripts/discord-thread-dispatch.sh \
    --agent planner \
    --message "Summarize today's progress" \
    --dry-run

Options:
  --channel ID       Target channel for new thread creation
  --thread ID        Existing thread to continue
  --prompt TEXT       Prompt / message body (required)
  --name TEXT         Thread title (only with --channel)
  --agent NAME        Agent account to use (planner/coder/reviewer/...)
  --account NAME      Explicit accountId override
  --notify-only       Create thread shell without AI execution
  --dry-run           Print the openclaw command without executing
  -h, --help          Show this help

Prereqs:
  - openclaw installed and gateway running
  - Discord channel configured in openclaw.json
  - Bot tokens set per account
EOF
}

TARGET_KIND=""
TARGET_ID=""
PROMPT=""
THREAD_NAME=""
AGENT_NAME=""
ACCOUNT_NAME=""
NOTIFY_ONLY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel)
      [[ -n "${TARGET_KIND}" ]] && { error "Use only one of --channel or --thread"; exit 1; }
      TARGET_KIND="channel"
      TARGET_ID="${2:-}"
      shift 2
      ;;
    --thread)
      [[ -n "${TARGET_KIND}" ]] && { error "Use only one of --channel or --thread"; exit 1; }
      TARGET_KIND="thread"
      TARGET_ID="${2:-}"
      shift 2
      ;;
    --prompt)       PROMPT="${2:-}"; shift 2 ;;
    --name)         THREAD_NAME="${2:-}"; shift 2 ;;
    --agent)        AGENT_NAME="${2:-}"; shift 2 ;;
    --account)      ACCOUNT_NAME="${2:-}"; shift 2 ;;
    --notify-only)  NOTIFY_ONLY=true; shift ;;
    --dry-run)      DRY_RUN=true; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              error "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "${PROMPT}" ]]; then
  error "--prompt is required"
  exit 1
fi

if [[ -n "${ACCOUNT_NAME}" && -z "${AGENT_NAME}" && -z "${TARGET_KIND}" ]]; then
  warn "--account is ignored for one-shot agent mode; use --agent to choose the agent"
fi

if ! command -v openclaw >/dev/null 2>&1; then
  error "openclaw CLI not found. Install: curl -fsSL https://openclaw.ai/install.sh | bash"
  exit 1
fi

ACCOUNT="${ACCOUNT_NAME:-${AGENT_NAME:-default}}"

build_cmd() {
  local cmd_parts=()

  if [[ "${TARGET_KIND}" == "channel" ]]; then
    cmd_parts=(openclaw message thread create --channel discord)
    cmd_parts+=(--target "channel:${TARGET_ID}")
    if [[ -n "${THREAD_NAME}" ]]; then
      cmd_parts+=(--thread-name "${THREAD_NAME}")
    fi
    cmd_parts+=(--message "${PROMPT}")
    cmd_parts+=(--account "${ACCOUNT}")

  elif [[ "${TARGET_KIND}" == "thread" ]]; then
    cmd_parts=(openclaw message send --channel discord)
    cmd_parts+=(--target "channel:${TARGET_ID}")
    cmd_parts+=(--message "${PROMPT}")
    cmd_parts+=(--account "${ACCOUNT}")

  else
    cmd_parts=(openclaw agent)
    cmd_parts+=(--agent "${AGENT_NAME:-planner}")
    cmd_parts+=(--message "${PROMPT}")
  fi

  printf '%q ' "${cmd_parts[@]}"
}

RENDERED="$(build_cmd)"

if [[ "${DRY_RUN}" == true ]]; then
  info "Dry run. Generated command:"
  printf '%s\n' "${RENDERED}"
  exit 0
fi

if [[ "${NOTIFY_ONLY}" == true ]]; then
  info "Notify-only: creating thread shell without AI execution"
fi

info "Dispatching via openclaw (account=${ACCOUNT}, target=${TARGET_KIND:-agent})"
eval "${RENDERED}"
success "Done"
