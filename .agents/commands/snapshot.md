# /snapshot — Portable Session State Export

Trigger: user sends `/snapshot` or "导出状态" or "export session state"

Generates a self-contained context document that can be injected into any OpenClaw agent to transfer full session awareness. The receiving agent reads it and understands: who the user is, what they want, what has been done, what failed, and what to do next.

## Procedure

### Phase 1: Analyze

Scan the full conversation history and all available context (MEMORY.md, AGENTS.md, session files).

### Phase 2: Generate

Produce a single Markdown document with this exact structure:

```markdown
# Session Snapshot — <date> <time>

## User Profile
- **Identity**: <name/handle if known>
- **Communication Style**: <formal/casual, language, verbosity preference>
- **Technical Level**: <beginner/intermediate/expert>
- **Key Preferences**: <bullet list of observed preferences>

## Current Context
- **Repository**: <repo path and branch if applicable>
- **Active Project**: <project description>
- **Environment**: <OS, tools, runtime versions observed>
- **Active Configuration**: <key config facts — models, channels, etc.>

## Task State
- **Current Goal**: <what the user is trying to achieve right now>
- **Completed Tasks**: <numbered list with outcomes>
- **In Progress**: <what was being worked on when snapshot was taken>
- **Blocked/Pending**: <items waiting for user input or external dependency>

## Agent Behavior History
- **Approaches That Worked**: <patterns/tools/strategies that succeeded>
- **Approaches That Failed**: <what was tried and abandoned, with reasons>
- **Corrections Received**: <explicit user corrections to agent behavior>
- **Style Requirements**: <formatting, code style, documentation conventions>

## Key Decisions
- <decision>: <rationale>

## Known Issues
- <issue>: <status, workaround if any>

## Handoff Instructions
<1-3 sentences telling the receiving agent exactly what to focus on next>
```

### Phase 3: Deliver

1. Output the snapshot as a code block so the user can copy it.
2. Also save it to `~/.openclaw/snapshots/<agent-id>-<timestamp>.md` for archival.
3. Tell the user:
   - Where the file was saved
   - How to inject it: paste into any agent's `USER.md` or send as the first message in a new session

## Design Principles

- **Plug-and-play**: Any agent reading this document should immediately understand the full context without asking clarifying questions.
- **No secrets**: Strip all tokens, passwords, API keys from the output.
- **Factual**: Only include observed facts, not inferences.
- **Compact**: Aim for 100-200 lines. If the session is long, summarize aggressively.
