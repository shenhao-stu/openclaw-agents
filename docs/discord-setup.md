# Discord Setup Guide for OpenClaw Agents

This guide is intentionally **idiot-proof** and intentionally **honest**.

There are two layers in the Discord setup:

1. **OpenClaw Agents** — provisions the agent fleet, workspaces, identities, and OpenClaw routing.
2. **An external Discord runtime** — runs the Discord bot, maps channels to projects, and creates or continues Discord threads/sessions.

If you want planner-led child-thread collaboration, you need **both**.

---

## 1. What this repository can and cannot do

### What `./setup.sh` does

- creates the 8 core sub-agents
- assigns identities and workspaces
- writes or updates `~/.openclaw/openclaw.json`
- configures `mentionPatterns` for Discord
- injects a Discord mention guard into agent prompts

### What `./setup.sh` does **not** do

- it does **not** run a Discord bot
- it does **not** create Discord threads by itself
- it does **not** replace an external Discord thread/session runtime

For Discord task orchestration, use your external Discord runtime after OpenClaw fleet setup is complete.

---

## 2. Recommended architecture

Use this mental model:

- **Discord channel = project**
- **Discord thread = task/session**
- **Parent thread = planner / user-facing coordination**
- **Child thread = delegated subtask (coder/reviewer/etc.)**

This mirrors the common Discord thread-based task model:

- dispatch to a **channel** → create a new thread/session
- dispatch to a **thread** → continue an existing thread
- dispatch to a **session mapping** → continue by external session ID

---

## 3. Step-by-step setup

### Step 0 — Install OpenClaw CLI

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
openclaw --version
```

If you will use Discord child-thread orchestration, also make sure your chosen Discord runtime CLI exists.

---

### Step 1 — Clone this repository

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
```

---

### Step 2 — Run OpenClaw fleet setup

#### Option A — Interactive mode (recommended)

```bash
./setup.sh
```

If you choose `discord`, the script will also ask for each agent's Discord user ID so it can prepend real `<@...>` mentions in `mentionPatterns`.

#### Option B — Fully scripted Discord example

```bash
./setup.sh \
  --mode channel \
  --channel discord \
  --group-id 123456789012345678 \
  --require-mention true
```

---

### Step 3 — Create and configure your Discord runtime

Use the Discord runtime of your choice to:

1. create or configure a Discord bot
2. enable required intents
3. install the bot in your server
4. map a project directory to a Discord channel
5. keep the runtime online as the bridge to your local machine

---

### Step 4 — Required Discord settings

Inside the Discord Developer Portal, enable these bot intents:

| Intent | Required | Why |
|---|---:|---|
| Message Content Intent | ✅ | Read prompts from Discord |
| Server Members Intent | ✅ | Resolve mentions and permissions |
| Presence Intent | Optional | Usually not needed |

Recommended bot permissions:

- View Channels
- Send Messages
- Send Messages in Threads
- Read Message History
- Embed Links
- Attach Files
- Add Reactions

---

### Step 5 — Recommended server structure

Follow a thread-based Discord pattern:

- one dedicated Discord server for agent work
- one project channel per codebase
- one work thread per task

Recommended human workflow:

1. use the **project channel** for entry and high-level coordination
2. let **planner** own the parent thread
3. let planner spawn **child threads** for focused subtasks
4. post final summaries back into the parent thread

---

## 4. Planner child-thread workflow

### A. Create a child thread immediately

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --agent planner \
  --name "planner: auth bug triage" \
  --prompt "Open a child thread, coordinate coder and reviewer there, and return a concise final summary to the parent thread."
```

### B. Create a notify-only thread shell

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --notify-only \
  --name "planner: release-readiness review" \
  --prompt "Planner child thread created. Reply here to begin execution. Final results must be summarized in the parent thread."
```

### C. Continue an existing child thread

```bash
./scripts/discord-thread-dispatch.sh \
  --thread <child-thread-id> \
  --agent coder \
  --prompt "Continue from the last checkpoint and produce a concise patch summary."
```

### D. Continue by session ID

```bash
./scripts/discord-thread-dispatch.sh \
  --session <external-session-id> \
  --agent reviewer \
  --prompt "Review the latest patch and list blocker vs non-blocker issues."
```

### E. Use a worktree for isolation

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --agent coder \
  --worktree issue-123 \
  --name "issue-123 fix" \
  --prompt "Implement the fix in an isolated worktree, then summarize diff and test status."
```

---

## 5. Discord mentions: the single most important gotcha

In Discord, real mentions use numeric IDs such as:

```text
<@123456789012345678>
```

Do **not** rely on plain text like `@planner` unless your routing layer explicitly interprets it.

### Bad pattern

Putting mentions only inside a Markdown table or code block:

```markdown
| Agent | Task |
|---|---|
| <@123456789012345678> | Implement auth fix |
```

This often renders as text and may not trigger a real notification.

### Good pattern

Keep the human-readable table if you want, but end with a plain-text mention line:

```text
<@123456789012345678> and <@987654321098765432>, please start the task above now.
```

This is why `setup.sh` injects a Discord mention guard into the agent prompts.

---

## 6. Verification checklist

After setup, verify each layer separately.

### OpenClaw layer

```bash
openclaw agents list --bindings
openclaw gateway
```

### Discord runtime layer

Verify your external Discord runtime separately.

Then confirm:

- the bot is online in Discord
- the project channel exists
- sending a message in the project channel creates or resumes a thread
- `./scripts/discord-thread-dispatch.sh --dry-run ...` renders the command you expect

---

## 7. Troubleshooting

### `setup.sh` succeeded, but Discord child threads still do not work

That usually means your Discord runtime is not running or the project has not been added to a Discord channel yet.

### Manually creating a Discord thread did not start a task

Prefer your runtime's managed thread/session creation path or `./scripts/discord-thread-dispatch.sh ...`.

### The bot sees messages but does not react to the right agent

Re-run `./setup.sh` for Discord and provide the correct Discord numeric user IDs so `mentionPatterns` include `<@...>` first.

### I only want OpenClaw local agent-to-agent communication

Use:

```bash
./setup.sh --mode local
```

That skips Discord-specific routing decisions.

---

## 8. Related files

- `setup.sh`
- `scripts/discord-thread-dispatch.sh`
- `docs/discord-thread-sop.md`
- `docs/installation.md`
- `README.md`
- `README_ZH.md`
