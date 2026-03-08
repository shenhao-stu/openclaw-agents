# Discord Setup — SOP

OpenClaw native multi-bot Discord configuration. Each agent gets its own Discord bot account. OpenClaw routes inbound messages to the correct agent via `accountId` bindings.

---

## Architecture

```
Discord Guild
├── #project-channel
│   ├── @planner-bot  →  agentId: planner  (accountId: planner)
│   ├── @coder-bot    →  agentId: coder    (accountId: coder)
│   ├── @reviewer-bot →  agentId: reviewer (accountId: reviewer)
│   └── ...
└── Threads
    ├── "planner: auth bug"   (child thread, agent collaboration)
    └── "planner: release v2" (child thread, agent collaboration)
```

Parent thread = user-facing. Child thread = agent work. Planner coordinates both.

---

## Step 0 — Prerequisites

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon
sudo apt install jq   # or: brew install jq
```

---

## Step 1 — Create Discord Bots

Go to [Discord Developer Portal](https://discord.com/developers/applications). Create **one application per agent** (or at minimum: one for planner, one shared default).

For each bot:

1. Application → Bot → Reset Token → copy token
2. Bot → Privileged Gateway Intents → enable **Message Content Intent** + **Server Members Intent**
3. OAuth2 → URL Generator → scopes: `bot`, `applications.commands`
4. Bot Permissions: View Channels, Send Messages, Send Messages in Threads, Read Message History, Embed Links, Attach Files, Add Reactions
5. Copy invite URL → add bot to your guild

Repeat for each agent that needs its own bot identity.

---

## Step 2 — Run Setup

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
./setup.sh --mode channel --channel discord --group-id <your-guild-id>
```

For a config preview without writing local OpenClaw state:

```bash
./setup.sh --mode channel --channel discord --group-id <your-guild-id> --dry-run
```

---

## Step 3 — Configure Bot Tokens

Set each agent's bot token. Do NOT send tokens in chat.

```bash
openclaw config set channels.discord.enabled true --json

# Per-account tokens
openclaw config set channels.discord.accounts.planner.token  '"BOT_TOKEN_PLANNER"'  --json
openclaw config set channels.discord.accounts.coder.token    '"BOT_TOKEN_CODER"'    --json
openclaw config set channels.discord.accounts.reviewer.token '"BOT_TOKEN_REVIEWER"' --json
openclaw config set channels.discord.accounts.default.token  '"BOT_TOKEN_DEFAULT"'  --json
# ... repeat for ideator, critic, surveyor, writer, scout
```

Or edit `~/.openclaw/openclaw.json` directly:

```json5
{
  channels: {
    discord: {
      enabled: true,
      groupPolicy: "open",
      accounts: {
        planner: {
          token: "BOT_TOKEN_PLANNER",
          streaming: "partial",
          guilds: {
            "<guildId>": {
              users: ["<yourUserId>"],
              channels: {
                "<channelId>": { allow: true, requireMention: true }
              }
            }
          }
        },
        // ... same structure for each agent account
      }
    }
  }
}
```

---

## Step 4 — Configure Bindings

Each account routes to its agent:

```json5
{
  bindings: [
    { agentId: "planner",  match: { channel: "discord", accountId: "planner" } },
    { agentId: "coder",    match: { channel: "discord", accountId: "coder" } },
    { agentId: "reviewer", match: { channel: "discord", accountId: "reviewer" } },
    { agentId: "ideator",  match: { channel: "discord", accountId: "ideator" } },
    { agentId: "critic",   match: { channel: "discord", accountId: "critic" } },
    { agentId: "surveyor", match: { channel: "discord", accountId: "surveyor" } },
    { agentId: "writer",   match: { channel: "discord", accountId: "writer" } },
    { agentId: "scout",    match: { channel: "discord", accountId: "scout" } },
    { agentId: "main",     match: { channel: "discord", accountId: "default" } }
  ]
}
```

`setup.sh` now generates the `accountId` bindings automatically and initializes empty `channels.discord.accounts.<agent>` entries plus `channels.discord.accounts.default`. After setup, you still need to fill in real bot tokens and, if desired, richer guild/channel allowlists.

---

## Step 5 — Start Gateway and Verify

```bash
openclaw gateway
openclaw agents list --bindings
openclaw channels status --probe
```

All bots should show as online in Discord.

---

## Step 6 — Thread Operations

Create a child thread:

```bash
openclaw message thread create --channel discord \
  --target channel:<channelId> \
  --thread-name "planner: auth bug" \
  --message "Coordinate coder and reviewer." \
  --account planner
```

Send to thread:

```bash
openclaw message send --channel discord \
  --target channel:<threadId> \
  --message "Coder reporting: patch ready for review." \
  --account coder
```

Dispatcher wrapper:

```bash
./scripts/discord-thread-dispatch.sh --channel <channelId> --agent planner \
  --name "planner: auth bug" --prompt "Coordinate coder + reviewer."
```

---

## Discord Mention Rule

Use numeric IDs: `<@123456789012345678>`. Do not put mentions only in tables or code blocks. End with a plain text line:

```
<@123456789012345678>, please start the task above.
```

`setup.sh` injects this rule into agent prompts when Discord mode is selected.

---

## Verification Checklist

- [ ] `openclaw agents list --bindings` shows all agents
- [ ] `openclaw gateway` runs without errors
- [ ] All Discord bots online in guild
- [ ] `openclaw channels status --probe` shows Discord healthy
- [ ] Thread creation works: `./scripts/discord-thread-dispatch.sh --channel <id> --agent planner --prompt "test" --dry-run`

---

## References

- [OpenClaw Discord docs](https://docs.openclaw.ai/channels/discord)
- [Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)
- [discord-thread-sop.md](discord-thread-sop.md)
- [installation.md](installation.md)
