# Installation

This repository now has a **two-layer installation story**:

1. **OpenClaw layer** — `./setup.sh` provisions the agent fleet and OpenClaw routing.
2. **Discord layer** — an external Discord runtime provides the bot, project channels, and thread/session runtime.

If you only want local OpenClaw collaboration, layer 1 is enough.
If you want Discord threads and planner child-thread workflows, you need both layers.

---

## For Humans

Clone the repository and run the setup wizard:

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
./setup.sh
```

Then:

- for local-only mode, use `openclaw chat planner`
- for Discord mode, follow `docs/discord-setup.md`
- for planner child-thread workflows, follow `docs/discord-thread-sop.md`

---

## For LLM Agents

> **IMPORTANT:** Use `curl` to fetch this file, not a summarizing fetcher.

```bash
curl -fsSL https://raw.githubusercontent.com/shenhao-stu/openclaw-agents/main/docs/installation.md
```

### Step 0 — Verify prerequisites

```bash
if command -v openclaw >/dev/null 2>&1; then
  echo "✅ OpenClaw $(openclaw --version) is installed"
else
  echo "❌ OpenClaw is not installed"
  echo "Install with: npm install -g openclaw@latest"
  echo "Then run: openclaw onboard --install-daemon"
fi

if command -v jq >/dev/null 2>&1; then
  echo "✅ jq is installed"
else
  echo "❌ jq is required"
fi
```

If the user wants Discord child-thread workflows, also verify:

```bash
echo "✅ Make sure your chosen Discord runtime CLI is installed"
```

---

### Step 1 — Clone the repository

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
```

---

### Step 2 — Decide the deployment mode

#### Option A — Local Workflow Mode

Use when the user only wants OpenClaw-native agent collaboration:

```bash
./setup.sh --mode local
```

This enables `agentToAgent` routing centered on `planner`.

#### Option B — Channel Mode

Use when the user wants OpenClaw bindings to a chat platform:

```bash
./setup.sh --mode channel --channel <CHANNEL> --group-id <GROUP_ID>
```

Examples:

```bash
./setup.sh --mode channel --channel feishu --group-id oc_xxx
./setup.sh --mode channel --channel telegram --group-id -1001234567890
./setup.sh --mode channel --channel discord --group-id 123456789012345678
```

Optional flags:

```bash
./setup.sh \
  --mode channel \
  --channel discord \
  --group-id 123456789012345678 \
  --model zai/glm-5 \
  --model-map 'coder=ollama/kimi-k2.5:cloud,writer=zai/glm-4.7' \
  --require-mention true
```

---

### Step 3 — Understand what `setup.sh` will configure

The script will:

1. verify `openclaw` and `jq`
2. create 8 sub-agents
3. create per-agent workspaces under `~/.openclaw/workspace-<id>`
4. deploy `_soul_source.md`, `_user_source.md`, `_agent_source.md`, and `BOOTSTRAP.md`
5. append workflow references into each generated `AGENTS.md`
6. update `~/.openclaw/openclaw.json`
7. if `discord` is selected, optionally prepend real `<@...>` mention IDs and inject a Discord mention guard

---

### Step 4 — Verify OpenClaw setup

```bash
openclaw agents list --bindings
openclaw gateway
```

If this is local mode, you can test with:

```bash
openclaw chat planner
```

---

### Step 5 — If Discord is required, install and run your Discord runtime

For Discord thread/session orchestration, run your chosen external Discord runtime.

Once it is running, use this repository's helper to create or continue task threads:

```bash
./scripts/discord-thread-dispatch.sh --channel <project-channel-id> --prompt "Start a planner child thread for this task" --dry-run
./scripts/discord-thread-dispatch.sh --thread <thread-id> --prompt "Continue from the last checkpoint" --dry-run
./scripts/discord-thread-dispatch.sh --session <session-id> --prompt "Summarize the current state" --dry-run
```

See:

- `docs/discord-setup.md`
- `docs/discord-thread-sop.md`

---

### Step 6 — Operator checklist

Before declaring success, verify:

- [ ] OpenClaw CLI installed
- [ ] `jq` installed
- [ ] repository cloned
- [ ] `./setup.sh` completed successfully
- [ ] `openclaw agents list --bindings` works
- [ ] if Discord is used: your external Discord runtime is installed and running
- [ ] if child-thread workflows are needed: `scripts/discord-thread-dispatch.sh` can render a valid dry-run command

Example dry run:

```bash
./scripts/discord-thread-dispatch.sh \
  --channel 123456789012345678 \
  --agent planner \
  --prompt "Create a child thread for auth bug triage" \
  --dry-run
```
