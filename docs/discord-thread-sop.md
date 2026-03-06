# Discord Thread SOP for OpenClaw Agents

This document explains the repository's intended Discord collaboration model.

- **OpenClaw Agents** provides the agent fleet, identities, workspaces, and routing conventions.
- **An external Discord runtime** provides project channels, task threads, and session transport.

The repository intentionally avoids binding itself to a single external Discord runtime brand.

---

## 1. Mental model

- **Discord channel = project**
- **Discord thread = task/session**
- **Parent thread = planner / user-facing coordination**
- **Child thread = delegated implementation or review subtask**

---

## 2. Recommended planner workflow

### Pattern A — Create a child thread immediately

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --agent planner \
  --name "planner: auth bug triage" \
  --prompt "Open a child thread for this auth bug. Coordinate coder and reviewer there. When done, post a concise final summary back in the parent thread and @mention the user." \
  --dry-run
```

### Pattern B — Create a notify-only child thread shell first

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --notify-only \
  --name "planner: release-readiness review" \
  --prompt "Planner child thread created. Reply here to start execution. Final results must be summarized in the parent thread." \
  --dry-run
```

### Pattern C — Continue an existing worker thread

```bash
./scripts/discord-thread-dispatch.sh \
  --thread <child-thread-id> \
  --agent coder \
  --prompt "Continue from the last checkpoint. Produce a patch summary and list open risks." \
  --dry-run
```

### Pattern D — Continue by external session ID

```bash
./scripts/discord-thread-dispatch.sh \
  --session <external-session-id> \
  --agent reviewer \
  --prompt "Review the latest patch and split issues into blockers and non-blockers." \
  --dry-run
```

---

## 3. Collaboration rules for planner and child agents

### Planner rules

1. Keep the **parent thread** human-readable.
2. Move detailed back-and-forth work into a **child thread**.
3. In the child thread:
   - assign the concrete subtask,
   - request status updates,
   - ask for blocker reports,
   - require a final handoff summary.
4. When the child thread is complete, post back in the **parent thread**:
   - final outcome,
   - changed files or deliverables,
   - unresolved risks,
   - an explicit `@user` notification if needed.

### Worker rules

1. Treat the child thread as the single source of truth for that subtask.
2. Keep raw execution chatter in the child thread.
3. End with a summary that planner can paste or relay upstream.
4. If blocked, say exactly what is missing instead of bouncing between threads.

---

## 4. What this repo does not claim

This repository does **not** implement Discord thread creation by itself.

It does **not** ship a Discord bot runtime.

The child-thread flow depends on an **external Discord runtime** being installed and running.

That distinction is intentional so the docs stay truthful.

---

## 5. Minimum operator checklist

Before using planner child threads, confirm all of the following:

- `./setup.sh` has already provisioned the OpenClaw agents
- a Discord runtime is installed and running
- the project is linked to a Discord channel
- you know the project channel ID or existing child thread ID
- `./scripts/discord-thread-dispatch.sh --dry-run ...` renders the command shape you expect

---

## 6. Troubleshooting

### The child thread was created but work did not start

Prefer using your Discord runtime's managed thread/session creation path instead of manually creating a Discord thread by hand.

### The planner should create a thread shell first

Use `--notify-only`.

### I need to resume the same discussion later

Use `--thread <thread-id>` or `--session <session-id>`.

### I need clean git isolation

Use `--worktree <name>` if your external runtime supports it.
