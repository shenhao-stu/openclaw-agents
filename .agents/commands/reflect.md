# /reflect — Self-Reflection & Experience Consolidation

Trigger: user sends `/reflect` or "请反思" or "reflect and learn"

When triggered, execute the following analysis on the current session history and any available MEMORY.md content.

## Procedure

### Phase 1: Extract

Scan the full conversation history and extract:

1. **User Preferences** — communication style, language, formatting expectations, tool preferences, model preferences, recurring explicit requests ("always do X", "don't do Y")
2. **Task Patterns** — what types of tasks were requested (code, docs, research, config, debug), frequency, complexity level
3. **Decisions Made** — architectural choices, tool selections, design patterns adopted, trade-offs resolved
4. **Problems Encountered** — errors hit, misunderstandings, failed approaches, workarounds applied
5. **SOPs Emerged** — any repeatable workflows that appeared (setup flows, review cycles, deploy procedures)

### Phase 2: Consolidate

Produce a structured summary in this format:

```markdown
## Reflection — <date>

### User Profile
- Communication: <style, language, formality level>
- Preferences: <specific preferences observed>
- Constraints: <time, tooling, environment constraints>

### Task History
- <task-1>: <outcome, key learnings>
- <task-2>: <outcome, key learnings>

### Decisions & Rationale
- <decision>: <why, what alternatives were considered>

### Problems & Solutions
- <problem>: <root cause> → <solution applied>

### Patterns Worth Preserving
- <pattern description>: <when to reuse>
```

### Phase 3: Persist

1. Append the reflection to `MEMORY.md` in the current agent workspace.
2. If any SOP was identified, generate a `SKILL.md` file under `~/.openclaw/skills/<sop-name>/SKILL.md` with proper YAML frontmatter:

```yaml
---
name: <sop-name>
description: <when to trigger this skill, what it does>
---
```

3. Report back to the user:
   - Summary of what was learned
   - List of any new skills created
   - Specific recommendations for future sessions

### Phase 4: Validate

Before saving, verify:
- No secrets, tokens, or passwords in the output
- MEMORY.md content is factual (not hallucinated)
- Skills are genuinely reusable (not one-off fixes)

## Output Format

Reply with the full reflection, then confirm what was saved. Keep the tone direct and factual. Do not pad with filler.
