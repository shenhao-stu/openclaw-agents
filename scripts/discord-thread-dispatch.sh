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
OpenClaw Discord thread dispatcher

Purpose:
  Provide a repository-local SOP wrapper for parent-thread → child-thread
  collaboration in Discord-backed deployments.

This script is intentionally generic.
It does NOT hardcode any specific Discord bot/runtime brand.

To execute the generated command, set DISCORD_DISPATCH_CMD to your actual
thread/session dispatcher binary or shell command.

Examples:

  # Dry-run a new planner child thread under a project channel
  ./scripts/discord-thread-dispatch.sh \
    --channel 123456789012345678 \
    --agent planner \
    --name "planner: auth bug triage" \
    --prompt "Open a child thread, coordinate coder + reviewer, and report back in the parent thread." \
    --dry-run

  # Continue an existing child thread
  ./scripts/discord-thread-dispatch.sh \
    --thread 123456789012345679 \
    --agent coder \
    --prompt "Continue from the last checkpoint and post a concise patch summary." \
    --dry-run

Environment:
  DISCORD_DISPATCH_CMD   Required for non-dry-run execution.
                         Example:
                         export DISCORD_DISPATCH_CMD='my-discord-cli send'

Options:
  --channel ID       Create a new child thread under a project channel
  --thread ID        Continue an existing Discord thread
  --session ID       Continue an existing external session ID mapping
  --prompt TEXT      Prompt body for the dispatcher (required)
  --name TEXT        Optional thread title when creating a new child thread
  --agent NAME       Optional agent override, e.g. planner/coder/reviewer
  --model ID         Optional model override
  --worktree NAME    Optional worktree name for isolated execution
  --notify-only      Create a thread shell without immediate AI execution
  --send-at VALUE    Optional scheduled send time (depends on your dispatcher)
  --app-id ID        Optional application/bot ID for validation
  --dry-run          Print the generated command without executing it
  -h, --help         Show this help

Notes:
  - Use exactly one target selector: --channel OR --thread OR --session.
  - This script does not create OpenClaw agents; run ./setup.sh first.
  - This script deliberately avoids binding the repo to any one Discord runtime.
EOF
}

TARGET_KIND=""
TARGET_ID=""
PROMPT=""
THREAD_NAME=""
AGENT_NAME=""
MODEL_ID=""
WORKTREE_NAME=""
SEND_AT=""
APP_ID=""
NOTIFY_ONLY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel|--thread|--session)
      if [[ -n "${TARGET_KIND}" ]]; then
        error "Use only one of --channel, --thread, or --session"
        exit 1
      fi
      TARGET_KIND="${1#--}"
      TARGET_ID="${2:-}"
      shift 2
      ;;
    --prompt)
      PROMPT="${2:-}"
      shift 2
      ;;
    --name)
      THREAD_NAME="${2:-}"
      shift 2
      ;;
    --agent)
      AGENT_NAME="${2:-}"
      shift 2
      ;;
    --model)
      MODEL_ID="${2:-}"
      shift 2
      ;;
    --worktree)
      WORKTREE_NAME="${2:-}"
      shift 2
      ;;
    --send-at)
      SEND_AT="${2:-}"
      shift 2
      ;;
    --app-id)
      APP_ID="${2:-}"
      shift 2
      ;;
    --notify-only)
      NOTIFY_ONLY=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "${TARGET_KIND}" || -z "${TARGET_ID}" ]]; then
  error "You must provide exactly one of --channel, --thread, or --session"
  exit 1
fi

if [[ -z "${PROMPT}" ]]; then
  error "--prompt is required"
  exit 1
fi

BASE_CMD="${DISCORD_DISPATCH_CMD:-}"

CMD_PARTS=()
if [[ -n "${BASE_CMD}" ]]; then
  CMD_PARTS+=("${BASE_CMD}")
else
  CMD_PARTS+=("discord-dispatch" "send")
fi

CMD_PARTS+=("--${TARGET_KIND}" "${TARGET_ID}" "--prompt" "${PROMPT}")

if [[ -n "${THREAD_NAME}" ]]; then
  CMD_PARTS+=("--name" "${THREAD_NAME}")
fi

if [[ -n "${AGENT_NAME}" ]]; then
  CMD_PARTS+=("--agent" "${AGENT_NAME}")
fi

if [[ -n "${MODEL_ID}" ]]; then
  CMD_PARTS+=("--model" "${MODEL_ID}")
fi

if [[ -n "${WORKTREE_NAME}" ]]; then
  CMD_PARTS+=("--worktree" "${WORKTREE_NAME}")
fi

if [[ -n "${SEND_AT}" ]]; then
  CMD_PARTS+=("--send-at" "${SEND_AT}")
fi

if [[ -n "${APP_ID}" ]]; then
  CMD_PARTS+=("--app-id" "${APP_ID}")
fi

if [[ "${NOTIFY_ONLY}" == true ]]; then
  CMD_PARTS+=("--notify-only")
fi

printf -v RENDERED '%q ' "${CMD_PARTS[@]}"

if [[ "${DRY_RUN}" == true ]]; then
  info "Dry run only. Generated dispatcher command:"
  printf '%s\n' "${RENDERED}"
  exit 0
fi

if [[ -z "${DISCORD_DISPATCH_CMD:-}" ]]; then
  error "DISCORD_DISPATCH_CMD is not set. Export your actual Discord dispatcher command first."
  warn "Example: export DISCORD_DISPATCH_CMD='my-discord-cli send'"
  exit 1
fi

info "Dispatching using ${TARGET_KIND}=${TARGET_ID}"
eval "${RENDERED}"
success "Dispatcher command completed"
