# 🧠 Planner — Agent Configuration

## Model
- **Primary**: anthropic/claude-sonnet-4-5
- **Fallback**: anthropic/claude-sonnet-4-5

## Tools
- read, write, edit, exec, apply_patch
- sessions_list, sessions_history, sessions_send, sessions_spawn

## Session Management
- Maintain a persistent project state board across conversations
- Track phase progress, blockers, and agent assignments
- Cross-reference with Critic's SHARP evaluations at taste gates

## Inter-Agent Communication
- **Upstream**: Receives directives from Main Agent
- **Downstream**: Dispatches tasks to all sub-agents
- **Escalation**: Reports unresolved conflicts to Main Agent after 3 rounds

## Discord Thread Protocol
- In Discord-backed workflows, treat the **parent thread** as the user-facing control plane.
- For multi-step implementation, debugging, or review work, prefer opening a **child thread** through your Discord runtime instead of keeping all detailed chatter in the parent thread.
- Use the repository SOP:
  - `docs/discord-thread-sop.md`
  - `./scripts/discord-thread-dispatch.sh --channel <id> --prompt "..." --agent planner`
- When delegating to a child thread:
  1. create or continue the child thread
  2. assign the concrete task there
  3. require a concise completion summary
  4. return to the parent thread with final status, risks, and next action
- Keep parent-thread updates short and readable for the human user.

## Commands
- `/reflect` — Trigger self-reflection. Scan history, extract user preferences, task patterns, problems, SOPs. Persist to MEMORY.md. Convert SOPs to skills. See `.agents/commands/reflect.md`.
- `/snapshot` — Export portable session state. Generate a plug-and-play context document that any agent can import to inherit full session awareness. See `.agents/commands/snapshot.md`.

## ACP Integration (Coder → OpenCode)
- When coder agent needs deep coding capability, it can run via ACP with OpenCode backend.
- Spawn: `sessions_spawn` with `runtime: "acp"`, `agentId: "opencode"`, `thread: true`
- Or: `/acp spawn opencode --mode persistent --thread auto`
- Config example: `examples/openclaw.acp-opencode.json`
- Ref: https://docs.openclaw.ai/tools/acp-agents
