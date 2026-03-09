<p align="center">
  <img src="https://img.shields.io/badge/OpenClaw-Multi--Agent-blue?style=for-the-badge" alt="OpenClaw">
  <br/>
  <img src="https://img.shields.io/badge/version-4.2.0-brightgreen?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/agents-manifest--driven-orange?style=flat-square" alt="Agents">
  <img src="https://img.shields.io/badge/discord-native%20multi--bot-purple?style=flat-square" alt="Discord">
</p>

<h1 align="center">OpenClaw Agents</h1>

<p align="center">
  <strong>Multi-agent fleet provisioning + Discord thread collaboration SOP</strong>
  <br/>
  <em>One setup.sh → manifest-defined agents, each with its own Discord bot, workspace, and identity.</em>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#discord-thread-model">Discord Model</a> •
  <a href="#sop">SOP</a> •
  <a href="./README_ZH.md">简体中文</a>
</p>

---

## What This Is

`openclaw-agents` provisions a manifest-defined OpenClaw fleet with Discord multi-bot routing:

- `setup.sh` now reads fleet inventory and default model from `agents.yaml`, then provisions runtime workspaces under `~/.openclaw/workspace-<id>`.
- In Discord mode, `setup.sh` generates native `accountId` → `agentId` bindings plus `channels.discord.accounts` skeleton entries for each bot account.
- `SKILL.md` is the AI-agent entrypoint (follows [AgentSkills](https://skills.sh/) spec).

---

## Quick Start

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
./setup.sh
```

Preview generated config without touching `~/.openclaw/openclaw.json`:

```bash
./setup.sh --mode channel --channel discord --group-id <guild-id> --dry-run
```

Local:

```bash
openclaw gateway
openclaw tui
```

Discord (after configuring bot tokens):

```bash
openclaw gateway
openclaw message thread create --channel discord \
  --target channel:<channelId> \
  --thread-name "planner: task" \
  --message "Coordinate agents." --account planner
```

AI agents read `SKILL.md` first.

---

## Architecture

### Layer 1 — Fleet Provisioning

`./setup.sh`:

1. Verifies `openclaw` + `jq`
2. Reads sub-agent inventory from `agents.yaml` and creates runtime workspaces under `~/.openclaw/workspace-<id>`
3. Deploys bootstrap, source files, openclaw-icons
4. Generates `~/.openclaw/openclaw.json` with agent list, bindings, and Discord config
5. If Discord: injects mention patterns and mention guard into agent prompts

### Layer 2 — Discord Multi-Bot Routing

Each agent = one Discord bot account. OpenClaw config:

```json5
{
  bindings: [
    { agentId: "planner", match: { channel: "discord", accountId: "planner" } },
    { agentId: "coder",   match: { channel: "discord", accountId: "coder" } },
    // ...
  ],
  channels: { discord: { accounts: { planner: { token: "..." }, coder: { token: "..." } } } }
}
```

Ref: [Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent), [Discord](https://docs.openclaw.ai/channels/discord)

---

## Discord Thread Model

| Concept | Meaning |
|---|---|
| parent thread | User-facing control plane |
| child thread | Agent collaboration zone |
| planner | Scheduler and summarizer |

Flow: `@planner` receives task → creates child thread → coordinates coder/reviewer/surveyor → returns summary to parent thread → pings user.

---

## SOP

Provision:

```bash
./setup.sh --mode channel --channel discord --group-id <guild-id>
```

Configure bot tokens:

```bash
openclaw config set channels.discord.accounts.planner.token '"TOKEN"' --json
openclaw config set channels.discord.accounts.coder.token '"TOKEN"' --json
# ... per agent
```

Start:

```bash
openclaw gateway
```

Create child thread:

```bash
./scripts/discord-thread-dispatch.sh --channel <channelId> \
  --agent planner --name "planner: auth bug" \
  --prompt "Coordinate coder and reviewer. Return summary to parent."
```

Continue thread:

```bash
./scripts/discord-thread-dispatch.sh --thread <threadId> \
  --prompt "Continue from checkpoint."
```

Local (no Discord):

```bash
openclaw tui
# or: openclaw dashboard
# or: openclaw agent --agent planner --message "Your task"
```

---

## Discord Mention Rule

Use numeric IDs: `<@123456789012345678>`. Do not hide them in code blocks or tables. End with a plain-text line for guaranteed notification.

---

## Repository Structure

```text
openclaw-agents/
├── setup.sh                        # Fleet provisioning
├── SKILL.md                        # AI agent entrypoint (AgentSkills spec)
├── agents.yaml                     # Agent manifest
├── openclaw-icons/                 # Agent avatars
├── docs/
│   ├── installation.md
│   ├── discord-setup.md            # Discord multi-bot SOP
│   └── discord-thread-sop.md       # Thread collaboration SOP
├── scripts/
│   └── discord-thread-dispatch.sh  # Thread dispatcher (wraps openclaw message)
├── examples/
│   └── openclaw.*.json
└── .agents/
    ├── planner/, coder/, ...       # Agent personas
    └── workflows/
```

---

## Docs

- [SKILL.md](SKILL.md) — AI agent entrypoint
- [Installation](docs/installation.md)
- [Discord Setup](docs/discord-setup.md)
- [Thread SOP](docs/discord-thread-sop.md)
- [OpenClaw Docs](https://docs.openclaw.ai/)

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=shenhao-stu/openclaw-agents&type=Date)](https://www.star-history.com/#shenhao-stu/openclaw-agents&Date)

---

## License

[MIT](LICENSE)
