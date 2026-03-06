---
name: openclaw-agents
description: Provision and operate an OpenClaw multi-agent fleet with Discord thread collaboration. Use this skill when setting up OpenClaw agents, configuring Discord parent-thread / child-thread workflows, deploying agent workspaces, or orchestrating planner-led multi-agent collaboration. Also use when the user mentions openclaw-agents, agent fleet setup, Discord thread SOP, or multi-agent provisioning.
---

# OpenClaw Agents

AI-agent entrypoint for this repository. Read this file first.

## Quick Orient

- `setup.sh` provisions the OpenClaw fleet, workspaces, icons, and routing.
- Each agent has its own Discord bot account. OpenClaw routes natively via `accountId` bindings.
- `docs/discord-setup.md` — Discord multi-bot configuration.
- `docs/discord-thread-sop.md` — parent-thread / child-thread SOP.

## Workflow

### Local (no Discord)

```bash
./setup.sh --mode local
openclaw gateway
openclaw tui
```

### Discord

```bash
./setup.sh --mode channel --channel discord --group-id <guild-id>
openclaw config set channels.discord.accounts.<agent>.token '"TOKEN"' --json
openclaw gateway
```

### Thread Operations

Create a child thread:

```bash
openclaw message thread create --channel discord \
  --target channel:<channelId> \
  --thread-name "planner: auth bug" \
  --message "Coordinate coder and reviewer." \
  --account planner
```

Send to an existing thread:

```bash
openclaw message send --channel discord \
  --target channel:<threadId> \
  --message "Status update." \
  --account coder
```

One-shot agent turn:

```bash
openclaw agent --agent planner --message "Summarize progress."
```

Dispatcher wrapper:

```bash
./scripts/discord-thread-dispatch.sh --channel <id> --agent planner --prompt "..."
```

## Thread Coordination

1. Parent thread is for the user.
2. Child thread is for agent collaboration.
3. Planner is the scheduler: opens child threads, assigns tasks, returns summaries.
4. Final summary must return to the parent thread and mention the user.

## Architecture

Each agent = one Discord bot account. OpenClaw config:

```json5
{
  bindings: [
    { agentId: "planner", match: { channel: "discord", accountId: "planner" } },
    { agentId: "coder",   match: { channel: "discord", accountId: "coder" } },
    // ...
  ],
  channels: {
    discord: {
      accounts: {
        planner: { token: "...", guilds: { "<guildId>": { ... } } },
        coder:   { token: "...", guilds: { "<guildId>": { ... } } },
      }
    }
  }
}
```

Ref: [Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent), [Discord](https://docs.openclaw.ai/channels/discord)

## External Skill Usage

Use external skills when the task needs repeatable procedural knowledge not encoded in this repo. Typical cases: repo scaffolding, code review, git worktree, technical writing, debugging playbooks.

**Policy:** Prefer trustworthy, well-maintained skills. Do not install random skills.

## ACP Integration (Coder → OpenCode)

The coder agent can delegate to OpenCode (or Claude Code, Codex, Gemini CLI) via OpenClaw's ACP runtime:

```bash
# Install acpx plugin
openclaw plugins install acpx
openclaw config set plugins.entries.acpx.enabled true

# Spawn OpenCode session in a Discord thread
/acp spawn opencode --mode persistent --thread auto
```

Config example: `examples/openclaw.acp-opencode.json`

Ref: [ACP Agents](https://docs.openclaw.ai/tools/acp-agents)

## Built-in Commands

- `/reflect` — Self-reflection. Scans history, extracts preferences, problems, SOPs. Saves to MEMORY.md. Converts SOPs to skills.
- `/snapshot` — Exports portable session state as a plug-and-play document. Any agent can import it to inherit full session awareness.

See `.agents/commands/reflect.md` and `.agents/commands/snapshot.md`.

## Operator Checklist

- [ ] OpenClaw installed (`curl -fsSL https://openclaw.ai/install.sh | bash`)
- [ ] `jq` installed
- [ ] `./setup.sh` completed
- [ ] `openclaw agents list --bindings` shows agents
- [ ] `openclaw gateway` starts
- [ ] If Discord: bot tokens configured per account, bots online in guild

## Pointers

- `README.md` / `README_ZH.md`
- `docs/installation.md`
- `docs/discord-setup.md`
- `docs/discord-thread-sop.md`
- [OpenClaw Docs](https://docs.openclaw.ai/)
- [Discord Channel Docs](https://docs.openclaw.ai/channels/discord)
- [Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)
