# Installation — SOP

Two layers:

1. **OpenClaw layer** — `./setup.sh` reads fleet inventory/default model from `agents.yaml` and provisions the runtime agent fleet.
2. **Discord layer** — OpenClaw native multi-bot routing. Each agent = one Discord bot account.

For local-only collaboration, layer 1 is enough.

---

## For Humans

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon
```

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
./setup.sh
```

Then:

- **Local mode**: `openclaw tui` or `openclaw dashboard`
- **AI agent entry**: `less SKILL.md`
- **Discord mode**: [docs/discord-setup.md](discord-setup.md)
- **Thread SOP**: [docs/discord-thread-sop.md](discord-thread-sop.md)

---

## For AI Agents

```bash
curl -fsSL https://raw.githubusercontent.com/shenhao-stu/openclaw-agents/main/docs/installation.md
```

### Step 0 — Prerequisites

```bash
command -v openclaw >/dev/null 2>&1 || { echo "Install: curl -fsSL https://openclaw.ai/install.sh | bash"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Install jq"; exit 1; }
```

### Step 1 — Clone

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
```

### Step 2 — Mode

`agents.yaml` is the source of truth for setup inventory and per-agent default models. Runtime workspaces are still created under `~/.openclaw/workspace-<id>`, so the manifest `workspace` field continues to refer to the repo-side persona source directory.


**Local:**
```bash
./setup.sh --mode local
```

**Discord:**
```bash
./setup.sh --mode channel --channel discord --group-id <guild-id>
```

### Step 3 — Verify

```bash
openclaw agents list --bindings
openclaw gateway
```

### Step 4 — Run

**Local:**
```bash
openclaw tui
# or: openclaw agent --agent planner --message "Your task"
```

**Discord (create child thread):**
```bash
./scripts/discord-thread-dispatch.sh --channel <channel-id> --prompt "Task description" --agent planner
```

### Step 5 — Checklist

- [ ] `openclaw` and `jq` installed
- [ ] `./setup.sh` completed
- [ ] `openclaw agents list --bindings` works
- [ ] If Discord: bot tokens configured, `openclaw channels status --probe` healthy
