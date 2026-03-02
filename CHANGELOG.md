# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-03-02

### Changed
- 📝 **Workspace files are now UPPERCASE**: `SOUL.md`, `AGENT.md`, `USER.md`, `AGENTS.md`
- 🔀 **SOUL.md merges two sources**: `SOUL_raw.md` (generic behaviors) + agent-specific `soul.md` (identity)
- 🔀 **USER.md merges two sources**: `USER.md` (template) + agent-specific `user.md` (context)
- 🚫 **No sandbox**: Removed all Docker sandbox config — each agent has its own workspace
- 🎯 **No "main" in agents.list**: Main agent is implicit, uses `agents.defaults`

### Added
- ❓ `--require-mention` flag: Choose whether agents need @mention to respond in groups
- 💬 Interactive prompt for requireMention during setup

### Removed
- 🗑️ Docker sandbox configuration (`mode`, `workspaceAccess`, `scope`)
- 🗑️ "main" agent entry from `agents.list` and `bindings`

## [1.1.0] - 2026-03-02

### Changed
- 🛡️ **Safe merge**: `setup.sh` now APPENDS sub-agents to existing `openclaw.json` instead of replacing — your main agent, auth, models, and plugins are preserved
- 🎛️ Default model changed from `anthropic/claude-sonnet-4-5` to `zai/glm-5`
- 💾 Automatic config backup before any changes (`openclaw.json.backup.<timestamp>`)

### Added
- 🎛️ `--model-map` flag for per-agent model customization (e.g., `--model-map 'coder=ollama/kimi-k2.5:cloud'`)
- 📡 Telegram channel config example (`examples/openclaw.telegram.json`)
- 📖 Comprehensive Group Configuration docs (groupPolicy, mentionPatterns, session keys, sandbox, tool restrictions)

### Fixed
- 🐛 `jq -s '.[0] * .[1]'` merge was replacing `agents.list` array instead of appending — now uses proper array concat with dedup

## [1.0.0] - 2026-03-01

### Added
- 🐾 Initial release with 9 core agents (Main + 8 sub-agents)
- 🎯 Critic agent with SHARP taste evaluation framework
- 📋 4 workflow templates (Paper Pipeline, Daily Digest, Brainstorm, Rebuttal)
- 🔧 One-command setup script (`setup.sh`) for automated initialization
- 🐧 Cross-platform support (Linux, macOS, Windows/WSL)
- 📡 Multi-channel binding support (Feishu, WhatsApp, Telegram, Discord)
- 🔒 Core agent protection (8 agents cannot be deleted)
- 🧩 Dynamic custom agent support
- 📖 Comprehensive documentation and contributing guidelines
