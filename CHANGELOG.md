# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.2.0] - 2026-03-06

### Added
- **ACP OpenCode integration** — Coder agent can delegate to OpenCode/Claude Code/Codex via `acpx` plugin. Config example: `examples/openclaw.acp-opencode.json`. Ref: [ACP Agents](https://docs.openclaw.ai/tools/acp-agents).
- **`/reflect` command** — Self-reflection prompt. Scans history, extracts user preferences, task patterns, problems. Converts SOPs to skills. Saves to MEMORY.md. See `.agents/commands/reflect.md`.
- **`/snapshot` command** — Portable session state export. Generates plug-and-play context document for cross-agent handoff. See `.agents/commands/snapshot.md`.
- **Self-evolution skill** — `~/.openclaw/skills/openclaw-agents-ops/SKILL.md` installed for fleet-wide operational knowledge.

### Changed
- **Blog rewritten** — Technical tutorial style matching linux.do community norms. Step-by-step with TOC, blockquote tips,踩坑合集.

## [4.1.0] - 2026-03-06

### Changed
- **`skills.md` → `SKILL.md`** — Renamed to follow the [AgentSkills](https://skills.sh/) spec with YAML frontmatter (`name` + `description`).
- **Discord: native multi-bot architecture** — Removed kimaki dependency entirely. Each agent has its own Discord bot account. OpenClaw routes natively via `accountId` → `agentId` bindings. Thread creation uses `openclaw message thread create`.
- **`discord-thread-dispatch.sh`** — Rewritten to wrap `openclaw message` commands instead of kimaki. Supports `--channel` (thread create), `--thread` (thread reply), and agent one-shot.
- **CLI commands corrected** — Replaced non-existent `openclaw chat planner` with official commands: `openclaw tui` (terminal), `openclaw dashboard` (browser), `openclaw agent --agent planner --message "..."` (one-shot). Ref: [OpenClaw CLI docs](https://docs.openclaw.ai/cli/).
- **Install command corrected** — Changed `npm install -g openclaw@latest` to `curl -fsSL https://openclaw.ai/install.sh | bash` per official docs.
- **All docs rewritten** — `discord-setup.md`, `discord-thread-sop.md`, `installation.md`, `README.md`, `README_ZH.md` updated to reflect native multi-bot architecture. All commands verified against [docs.openclaw.ai](https://docs.openclaw.ai/).

## [4.0.0] - 2026-03-06

### Added
- **`SKILL.md`** — AI-agent entrypoint with YAML frontmatter.
- **openclaw-icons integration** — `setup.sh` deploys `openclaw-icons/` (svg, png) to each agent workspace.

### Changed
- **setup.sh** — SOP-style 8-step flow, openclaw-icons deployment. Version bump to 4.0.0.
- **docs/** — Rewritten as step-by-step SOPs.
- **README.md / README_ZH.md** — Aligned with v4.0.0.

### Fixed
- `setup.sh` JSON generation: replaced heredoc string concatenation with `jq -n` to avoid invalid JSON.

---

## [3.1.0] - 2026-03-06

### Changed
- Reframed the repository around a truthful two-layer model: **OpenClaw Agents for fleet provisioning** and **an external Discord runtime for thread/session orchestration**.
- Fully rewrote `setup.sh` into a clearer SOP-style wizard with stronger preflight checks (`openclaw` + `jq`), automatic empty-config bootstrapping, Discord guidance, and explicit post-setup next steps.
- Rewrote `docs/discord-setup.md` and `docs/installation.md` so they no longer promise non-existent Discord runtime features from this repository.
- Rewrote both `README.md` and `README_ZH.md` to align versioning, setup flow, and the planner child-thread model.

### Added
- Added `scripts/discord-thread-dispatch.sh`, a generic wrapper for planner-led parent-thread / child-thread collaboration without binding the repository to one specific Discord runtime.
- Added `docs/discord-thread-sop.md`, a focused SOP for parent-thread / child-thread orchestration, notify-only thread shells, and worktree-backed subtasks.
- Added explicit operator guidance in `setup.sh` and the docs for when to use OpenClaw local `agentToAgent` versus external Discord thread runtimes.

### Fixed
- Removed stale documentation references to deleted tools like `setup_discord.py`.
- Removed stale references to unsupported flags and config structures that were never implemented by the current `setup.sh`.
- Fixed the long-standing mismatch between docs that claimed Discord child-thread support and the actual repo, which only contained provisioning/config logic.

## [3.0.0] - 2026-03-06

### Changed (Breaking)
- Refactored Discord configuration toward interactive setup and mention-pattern handling inside `setup.sh`.

### Added
- Added stronger Discord-specific guidance and mention guard injection for agent workspaces.

## [2.3.0] - 2026-03-06

### Changed
- Refactored Discord configuration flow to move setup logic into `setup.sh`.

## [2.2.0] - 2026-03-02

### Added
- Added dual mode support: `channel` and `local`.
- Added local workflow mode using OpenClaw `agentToAgent`.
- Added interactive per-agent group routing.

## [2.1.0] - 2026-03-02

### Added
- Added group-map support for per-agent group bindings.

## [2.0.0] - 2026-03-02

### Changed
- Switched to self-merge bootstrap architecture for per-agent workspace files.

## [1.2.0] - 2026-03-02

### Changed
- Standardized workspace file names and mention gating behavior.

## [1.1.0] - 2026-03-02

### Changed
- Changed setup flow to append into existing `openclaw.json` instead of replacing it.

## [1.0.0] - 2026-03-01

### Added
- Initial release with 9 core agents and one-command setup.
