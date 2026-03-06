<p align="center">
  <img src="https://img.shields.io/badge/OpenClaw-Multi--Agent-blue?style=for-the-badge" alt="OpenClaw">
  <br/>
  <img src="https://img.shields.io/badge/version-3.1.0-brightgreen?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/agents-9-orange?style=flat-square" alt="Agents">
  <img src="https://img.shields.io/badge/discord-thread%20orchestration-purple?style=flat-square" alt="Discord Threads">
</p>

<h1 align="center">🐾 OpenClaw Agents</h1>

<p align="center">
  <strong>OpenClaw agent fleet + Discord thread orchestration SOP</strong>
  <br/>
  <em>Provision a multi-agent team with OpenClaw, then run planner-led Discord parent-thread / child-thread collaboration.</em>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-how-it-works">How It Works</a> •
  <a href="#-discord-model">Discord Model</a> •
  <a href="#-agents">Agents</a> •
  <a href="#-planner-child-thread-sop">Planner Child-Thread SOP</a> •
  <a href="#-repository-structure">Repository Structure</a> •
  <a href="./README_ZH.md">简体中文</a>
</p>

---

## ✨ What this repository is

**OpenClaw Agents** is a ready-to-run agent fleet for OpenClaw.

It gives you:

- 8 core sub-agents + 1 main orchestrator identity
- per-agent workspaces
- bootstrap files for self-merge
- OpenClaw routing config for local or channel mode
- planner-centered collaboration patterns
- a documented Discord workflow built around **parent-thread / child-thread collaboration**

The key design decision in this branch is simple:

- **OpenClaw Agents** handles the **agent fleet**
- **An external Discord runtime** handles the **Discord bot, channels, threads, and session transport**

That split is deliberate and truthful.

---

## 🚀 Quick Start

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
./setup.sh
```

If you want Discord task threads after the OpenClaw setup succeeds, configure your preferred Discord runtime and then create or continue threads with:

```bash
./scripts/discord-thread-dispatch.sh --channel <project-channel-id> --prompt "Start a planner child thread for this task" --dry-run
```

Detailed guides:

- `docs/installation.md`
- `docs/discord-setup.md`
- `docs/discord-thread-sop.md`

---

## 🧠 How It Works

### Layer 1 — OpenClaw fleet provisioning

`./setup.sh` does the following:

1. verifies `openclaw` and `jq`
2. creates 8 core sub-agents
3. creates workspaces under `~/.openclaw/workspace-<id>`
4. deploys `_soul_source.md`, `_user_source.md`, `_agent_source.md`, and `BOOTSTRAP.md`
5. appends workflow references into each generated `AGENTS.md`
6. updates `~/.openclaw/openclaw.json`
7. if `discord` is selected, optionally prepends real `<@...>` mention IDs

### Layer 2 — Discord thread/session runtime

This repository assumes you have some **external Discord runtime** for channels, threads, and session transport.

It provides:

- one Discord channel per project
- one Discord thread per task/session
- `send --channel` to create a new task thread
- `send --thread` or `send --session` to continue work
- optional `--worktree` isolation
- optional `--notify-only` thread shells

This is why the docs in this repo now describe a **Discord runtime-backed** workflow instead of pretending `setup.sh` can create child threads by itself.

---

## 💬 Discord Model

Use this mental model:

- **Discord channel = project**
- **Discord thread = task / session**
- **Parent thread = planner-facing control plane**
- **Child thread = delegated subtask execution**

### Why this matters

The repo already defines planner as the coordination hub, but the repo itself is not a Discord bot runtime.

So the practical implementation is:

- use OpenClaw for the agents
- use your Discord runtime for the thread/session transport
- keep the parent thread readable
- move implementation chatter into child threads
- have planner summarize results back to the user

---

## 🤖 Agents

| Agent | ID | Role |
|---|---|---|
| 🐾 OpenClaw | `main` | Root orchestrator / final arbiter |
| 🧠 Planner | `planner` | Task decomposition, routing, coordination |
| 💡 Ideator | `ideator` | Idea generation and framing |
| 🎯 Critic | `critic` | Taste gate / SHARP evaluation |
| 📚 Surveyor | `surveyor` | Literature review and gap finding |
| 💻 Coder | `coder` | Implementation and experiments |
| ✍️ Writer | `writer` | Drafting and technical writing |
| 🔍 Reviewer | `reviewer` | Review, quality gates, veto |
| 📰 Scout | `scout` | Trend and paper monitoring |

### Planner is special

Planner is the only role in this repo explicitly positioned to:

- coordinate all other agents
- maintain project state
- spawn or route follow-up work
- summarize progress back to the user

That is why planner is the natural owner of parent-thread → child-thread orchestration.

---

## 🧵 Planner Child-Thread SOP

### Create a child thread immediately

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --agent planner \
  --name "planner: auth bug triage" \
  --prompt "Open a child thread, coordinate coder and reviewer there, and summarize the final result back in the parent thread."
```

### Create a thread shell first

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --notify-only \
  --name "planner: release review" \
  --prompt "Planner child thread created. Reply here to begin execution. Final summary must go back to the parent thread."
```

### Continue an existing child thread

```bash
./scripts/discord-thread-dispatch.sh \
  --thread <thread-id> \
  --agent coder \
  --prompt "Continue from the last checkpoint and post a patch summary."
```

### Continue by session ID

```bash
./scripts/discord-thread-dispatch.sh \
  --session <session-id> \
  --agent reviewer \
  --prompt "Review the latest changes and split issues into blockers and non-blockers."
```

### Isolated git worktree

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --agent coder \
  --worktree issue-123 \
  --name "issue-123 fix" \
  --prompt "Implement the fix in an isolated worktree and report test status."
```

See `docs/discord-thread-sop.md` for the full SOP.

---

## ⚠️ The Discord mention rule you must not ignore

Discord mentions are real only when they use numeric IDs like:

```text
<@123456789012345678>
```

Do not hide them only inside tables or code blocks.

Bad:

```markdown
| Agent | Task |
|---|---|
| <@123456789012345678> | Implement auth fix |
```

Good:

```text
<@123456789012345678>, please start the task above now.
```

This is why `setup.sh` injects a Discord mention guard into every agent workspace when Discord mode is selected.

---

## 🔧 Setup Modes

### Local Workflow Mode

```bash
./setup.sh --mode local
```

Use this when you want OpenClaw-native `agentToAgent` collaboration without Discord.

### Channel Mode

```bash
./setup.sh --mode channel --channel feishu --group-id oc_xxx
./setup.sh --mode channel --channel telegram --group-id -1001234567890
./setup.sh --mode channel --channel discord --group-id 123456789012345678
```

Useful flags:

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

## ✅ Verification

### OpenClaw side

```bash
openclaw agents list --bindings
openclaw gateway
```

### Discord runtime side

Verify that your external Discord runtime is online and attached to the right project channel/thread layer.

Then confirm:

- the bot is online
- the project channel exists
- sending a message creates or resumes a thread
- `./scripts/discord-thread-dispatch.sh --dry-run ...` renders the expected command

---

## 📁 Repository Structure

```text
openclaw-agents/
├── setup.sh                     # OpenClaw fleet setup and routing
├── agents.yaml                  # Manifest/reference metadata
├── docs/
│   ├── installation.md          # Installation guide
│   ├── discord-setup.md         # Discord setup guide
│   └── discord-thread-sop.md    # Parent/child thread SOP
├── scripts/
│   └── discord-thread-dispatch.sh # Generic Discord thread dispatcher wrapper
├── examples/
│   ├── openclaw.local.json
│   ├── openclaw.feishu.json
│   ├── openclaw.telegram.json
│   └── openclaw.whatsapp.json
└── .agents/
    ├── planner/
    ├── ideator/
    ├── critic/
    ├── surveyor/
    ├── coder/
    ├── writer/
    ├── reviewer/
    ├── scout/
    └── workflows/
```

---

## 📚 Related Docs

- [Installation](docs/installation.md)
- [Discord Setup Guide](docs/discord-setup.md)
- [Discord Thread SOP](docs/discord-thread-sop.md)
- [简体中文 README](README_ZH.md)

---

## 📄 License

[MIT](LICENSE)
