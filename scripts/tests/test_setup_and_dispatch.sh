#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_SCRIPT="${ROOT_DIR}/setup.sh"
DISPATCH_SCRIPT="${ROOT_DIR}/scripts/discord-thread-dispatch.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    fail "expected output to contain: ${needle}"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    fail "expected output not to contain: ${needle}"
  fi
}

fake_bin_dir="$(mktemp -d)"
trap 'rm -rf "${fake_bin_dir}"' EXIT

cat > "${fake_bin_dir}/openclaw" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${fake_bin_dir}/openclaw"

export PATH="${fake_bin_dir}:${PATH}"
export HOME="$(mktemp -d)"
trap 'rm -rf "${fake_bin_dir}" "${HOME}"' EXIT

printf 'Running setup.sh Discord dry-run assertions...\n'
discord_output="$(bash "${SETUP_SCRIPT}" --mode channel --channel discord --group-id guild-123 --dry-run)"
assert_contains "${discord_output}" '"accountId": "planner"'
assert_contains "${discord_output}" '"accountId": "default"'
assert_contains "${discord_output}" '"accounts": {'
assert_not_contains "${discord_output}" '"peer": { "kind": "group", "id": "guild-123" }'

printf 'Running setup.sh non-Discord dry-run assertions...\n'
feishu_output="$(bash "${SETUP_SCRIPT}" --mode channel --channel feishu --group-id oc_demo --dry-run)"
assert_contains "${feishu_output}" '"peer": {'
assert_contains "${feishu_output}" '"kind": "group"'
assert_contains "${feishu_output}" '"id": "oc_demo"'

printf 'Running dispatcher dry-run assertions...\n'
dispatch_create="$(bash "${DISPATCH_SCRIPT}" --channel 123 --agent planner --name "planner: auth bug" --prompt "Coordinate" --dry-run)"
assert_contains "${dispatch_create}" 'openclaw message thread create --channel discord'
assert_contains "${dispatch_create}" '--account planner'

dispatch_thread="$(bash "${DISPATCH_SCRIPT}" --thread 456 --agent coder --prompt "Status" --dry-run)"
assert_contains "${dispatch_thread}" 'openclaw message send --channel discord'
assert_contains "${dispatch_thread}" '--account coder'

dispatch_override="$(bash "${DISPATCH_SCRIPT}" --thread 456 --agent coder --account reviewer --prompt "Status" --dry-run)"
assert_contains "${dispatch_override}" '--account reviewer'

printf 'All shell checks passed.\n'
