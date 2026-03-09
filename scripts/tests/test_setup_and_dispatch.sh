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

assert_fails_with() {
  local expected="$1"
  shift
  local output
  set +e
  output="$($@ 2>&1)"
  local status=$?
  set -e
  if [[ ${status} -eq 0 ]]; then
    fail "expected command to fail: $*"
  fi
  assert_contains "${output}" "${expected}"
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

manifest_backup="$(mktemp)"
cp "${ROOT_DIR}/agents.yaml" "${manifest_backup}"
restore_manifest() {
  cp "${manifest_backup}" "${ROOT_DIR}/agents.yaml"
}
trap 'restore_manifest; rm -rf "${fake_bin_dir}" "${HOME}" "${manifest_backup}"' EXIT

printf 'Running setup.sh Discord dry-run assertions...\n'
discord_output="$(bash "${SETUP_SCRIPT}" --mode channel --channel discord --group-id guild-123 --dry-run)"
assert_contains "${discord_output}" '"accountId": "planner"'
assert_contains "${discord_output}" '"accountId": "default"'
assert_contains "${discord_output}" '"accounts": {'
assert_contains "${discord_output}" '"model": "ohmyapi/gpt-5.4"'
assert_contains "${discord_output}" '"name": "🧠 Planner"'
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

printf 'Running manifest validation failure assertions...\n'
python3 - <<'PY' "${ROOT_DIR}/agents.yaml"
import sys
path = sys.argv[1]
with open(path, encoding='utf-8') as fh:
    lines = fh.readlines()
with open(path, 'w', encoding='utf-8') as fh:
    for line in lines:
        if 'default: true' not in line:
            fh.write(line)
PY
assert_fails_with 'agents.yaml must define exactly one default agent, found 0' bash "${SETUP_SCRIPT}" --mode local --dry-run
restore_manifest

python3 - <<'PY' "${ROOT_DIR}/agents.yaml"
import sys
path = sys.argv[1]
with open(path, encoding='utf-8') as fh:
    content = fh.read()
content = content.replace('- id: "ideator"', '- id: "planner"', 1)
with open(path, 'w', encoding='utf-8') as fh:
    fh.write(content)
PY
assert_fails_with 'agents.yaml contains duplicate agent id: planner' bash "${SETUP_SCRIPT}" --mode local --dry-run
restore_manifest

printf 'All shell checks passed.\n'
