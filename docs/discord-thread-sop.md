# Discord Thread SOP — Parent / Child Thread

Standard Operating Procedure for planner-led Discord thread collaboration using OpenClaw native multi-bot Discord support.

---

## 1. Mental Model

| Concept | Meaning |
|---|---|
| **Parent thread** | User-facing. Planner coordinates. Final summary goes here. |
| **Child thread** | Agent work. Coder, reviewer, surveyor, etc. collaborate here. |
| **Planner** | Thread scheduler. Opens child threads, assigns tasks, returns to parent. |

Each agent has its own Discord bot account. OpenClaw routes by `accountId` → `agentId`.

---

## 2. Flow

```
User @planner in main channel
        ↓
Planner creates child thread (openclaw message thread create)
        ↓
Child thread: planner @coder, @reviewer collaborate
        ↓
Planner posts summary to parent thread, @user
```

---

## 3. Commands

### A. Create a child thread

```bash
openclaw message thread create --channel discord \
  --target channel:<channelId> \
  --thread-name "planner: auth bug triage" \
  --message "Coordinate coder and reviewer. Post summary back in parent." \
  --account planner
```

Or via dispatcher:

```bash
./scripts/discord-thread-dispatch.sh --channel <channelId> \
  --agent planner \
  --name "planner: auth bug triage" \
  --prompt "Coordinate coder and reviewer. Post summary back in parent."
```

### B. Continue an existing thread

```bash
openclaw message send --channel discord \
  --target channel:<threadId> \
  --message "Coder: patch ready. @reviewer please check." \
  --account coder
```

Or via dispatcher:

```bash
./scripts/discord-thread-dispatch.sh --thread <threadId> \
  --agent coder \
  --prompt "Continue from checkpoint. Produce patch summary."
```

### C. One-shot agent turn (no thread)

```bash
openclaw agent --agent planner --message "Summarize today's progress."
```

---

## 4. Planner Rules

1. Keep the **parent thread** human-readable.
2. Move detailed work into a **child thread**.
3. In the child thread: assign subtasks, request status updates, require a final handoff.
4. When complete, post back in the **parent thread**: final outcome, changed files, unresolved risks, explicit `@user` notification.

---

## 5. Worker Rules

1. Treat the child thread as the single source of truth for that subtask.
2. Keep raw execution chatter in the child thread.
3. End with a summary that planner can relay upstream.
4. If blocked, state exactly what is missing.

---

## 6. Operator Checklist

- [ ] `./setup.sh` completed
- [ ] Bot tokens configured per account in `openclaw.json`
- [ ] `openclaw gateway` running
- [ ] All bots online in Discord
- [ ] `openclaw channels status --probe` shows Discord healthy
- [ ] `./scripts/discord-thread-dispatch.sh --channel <id> --agent planner --prompt "test" --dry-run` prints expected command

---

## 7. Troubleshooting

| Problem | Solution |
|---|---|
| Thread created but no response | Check `openclaw logs --follow`, verify bot token and guild config |
| Bot offline | Verify token in `channels.discord.accounts.<agent>.token` |
| Mention not triggering | Use numeric `<@id>` in plain text, not in code blocks |
| Wrong agent responds | Check `bindings[].match.accountId` mapping |
| Permission denied | Verify bot has Send Messages in Threads permission |
