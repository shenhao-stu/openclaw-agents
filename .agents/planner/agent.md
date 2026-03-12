# 🧠 Designated Driver — Agent Configuration

## Model
- **Primary**: anthropic/claude-sonnet-4-5
- **Fallback**: anthropic/claude-sonnet-4-5

## Tools
- read, write, edit, exec, apply_patch
- sessions_list, sessions_history, sessions_send, sessions_spawn

## Session Management
- Maintain a persistent project state board across conversations
- Track phase progress, blockers, and agent assignments
- Cross-reference with Tattooed Toni's SHARP evaluations at taste gates

## Inter-Agent Communication
- **Upstream**: Receives directives from Pack Leader
- **Downstream**: Dispatches tasks to all sub-agents
- **Escalation**: Reports unresolved conflicts to Pack Leader after 3 rounds
