<p align="center">
  <img src="https://img.shields.io/badge/OpenClaw-Multi--Agent-blue?style=for-the-badge" alt="OpenClaw">
  <br/>
  <img src="https://img.shields.io/badge/version-1.2.0-brightgreen?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/agents-9-orange?style=flat-square" alt="Agents">
  <img src="https://img.shields.io/badge/channels-feishu%20%7C%20whatsapp%20%7C%20telegram%20%7C%20discord-purple?style=flat-square" alt="Channels">
</p>

<h1 align="center">🐾 OpenClaw Agents</h1>

<p align="center">
  <strong>One-command multi-agent initialization for <a href="https://docs.openclaw.ai">OpenClaw</a></strong>
  <br/>
  <em>Ship an entire AI agent fleet to your chat group in 60 seconds. Default model: <code>zai/glm-5</code></em>
</p>

<p align="center">
  <a href="#-installation">Installation</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-agents">Agents</a> •
  <a href="#-channel-support">Channels</a> •
  <a href="#-workflows">Workflows</a> •
  <a href="#-customization">Customization</a> •
  <a href="#-contributing">Contributing</a>
</p>

---

## ✨ What Is This?

**OpenClaw Agents** is a ready-to-deploy multi-agent configuration kit for [OpenClaw](https://docs.openclaw.ai). It provisions **9 specialized AI agents** as a collaborative team — complete with identities, workspace files, routing rules, and channel bindings — using a single setup command.

### What You Get

- 🤖 **9 pre-configured agents** with rich emoji identities for instant recognition in chat
- 📝 **Full workspace files** — `soul.md`, `agent.md`, `user.md` for every agent
- 🔗 **Channel routing** — auto-configured bindings for Feishu, WhatsApp, Telegram, Discord
- 📋 **4 workflow templates** — Paper Pipeline, Daily Digest, Brainstorm, Rebuttal
- ⚔️ **Adversarial collaboration** — Ideator↔Critic and Writer↔Reviewer creative tension
- 🎯 **SHARP taste gates** — quality checkpoints enforced by the Critic agent
- 🛡️ **Safe merge** — appends agents to existing config, never overwrites your main agent
- 🎛️ **Flexible model** — unified model or per-agent customization via `--model-map`
- 🧩 **Extensible** — add custom agents via `agents.yaml`

---

## 📦 Installation

### For Humans

Paste this into your LLM agent session (Claude Code, Antigravity, Cursor, etc.):

```
Fetch the OpenClaw Agents installation guide and set up the multi-agent system by following:
curl -s https://raw.githubusercontent.com/shenhao-stu/openclaw-agents/main/docs/installation.md
```

Or just run it yourself:

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh
./setup.sh
```

### For LLM Agents

> **IMPORTANT: Use `curl` to fetch this file, NOT WebFetch.** WebFetch summarizes content and loses critical details like CLI flags and config examples. Always use:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/shenhao-stu/openclaw-agents/main/docs/installation.md
> ```

If you're an LLM Agent helping set up OpenClaw Agents, follow the [full installation guide](docs/installation.md). Here's the summary:

#### Step 0: Prerequisites

```bash
# Verify OpenClaw CLI is installed
if command -v openclaw &> /dev/null; then
    echo "OpenClaw $(openclaw --version) is installed"
else
    echo "Installing OpenClaw..."
    npm install -g openclaw@latest
    openclaw onboard --install-daemon
fi
```

#### Step 1: Ask User About Configuration

Ask the user these questions:

1. **Which channel do you use?** → `--channel feishu|whatsapp|telegram|discord|slack`
2. **What is your group/chat ID?** → `--group-id <ID>`
   - Feishu: `oc_xxxxxxxxx` (chat_id)
   - WhatsApp: `xxxxx@g.us`
   - Telegram: `-1001234567890`
   - Discord: guild ID
3. **Which LLM model?** (default: `zai/glm-5`) → `--model <MODEL>`
   - Want different models per agent? → `--model-map 'coder=ollama/kimi-k2.5:cloud,writer=zai/glm-4.7'`
4. **需要 @mention 才回复吗？** → `--require-mention true|false`
   - `true`（默认）：群里必须 @机器人 才会回复，不 @ 不会触发
   - `false`：机器人自动响应所有消息，无需 @
5. **Do you need a session ID for group routing?** → `--session-id <ID>` (optional)

#### Step 2: Clone and Run Setup

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh
./setup.sh --channel <CHANNEL> --group-id <GROUP_ID> --model <MODEL>
```

**Examples:**
- Feishu group: `./setup.sh --channel feishu --group-id oc_b1c331592eaa36d06a7e5df05d08a890`
- No @mention required: `./setup.sh --require-mention false --channel feishu --group-id oc_xxx`
- Per-agent models: `./setup.sh --model-map 'coder=ollama/kimi-k2.5:cloud,writer=zai/glm-4.7' --channel feishu --group-id oc_xxx`
- Agents only (no channel): `./setup.sh --skip-bindings`
- Dry-run preview: `./setup.sh --dry-run --channel feishu --group-id oc_xxx`

The script will:
1. ✅ Verify `openclaw` CLI is installed
2. 🤖 Create 8 sub-agents via `openclaw agents add` (each with independent workspace)
3. 🎨 Set emoji identities via `openclaw agents set-identity`
4. 📝 Deploy `SOUL.md` / `AGENT.md` / `USER.md` / `AGENTS.md` (UPPERCASE, merged from templates)
5. 🔗 Configure `openclaw.json` with channel bindings (no sandbox)
6. ✅ Verify the entire setup

#### Step 3: Verify Setup

```bash
openclaw agents list --bindings    # Should show all 8 agents with channel bindings
openclaw channels status --probe   # Should show channel connected
```

#### Step 4: Start the Gateway

```bash
openclaw gateway
```

Then mention any agent in your chat group to test. Each agent will respond with its distinct emoji identity.

> ⚠️ **Warning**: Do not modify the 8 core agent IDs (`planner`, `ideator`, `critic`, `surveyor`, `coder`, `writer`, `reviewer`, `scout`). These are protected and referenced throughout the workflow system.

---

## 🏗 Architecture

```
                         ┌──────────────┐
                         │   👤 User    │
                         └──────┬───────┘
                                │
                    ┌───────────▼───────────┐
                    │  🐾 OpenClaw Main     │
                    │  (Audit · Manage · Arbitrate)
                    └───────────┬───────────┘
                                │
                         ┌──────▼───────┐
                         │  🧠 Planner  │ ◄── Orchestration Hub
                         └──────┬───────┘
                                │
       ┌────────────────────────┼────────────────────────┐
       │                        │                        │
 ┌─────▼─────┐           ┌─────▼─────┐           ┌─────▼─────┐
 │ 💡Ideator │◄── ⚔️ ──►│ 🎯 Critic │           │ 📰 Scout  │
 │  Creative  │           │   Taste    │           │   Intel    │
 └─────┬─────┘           └─────┬─────┘           └───────────┘
       │                       │
 ┌─────▼─────┐           ┌─────▼─────┐
 │ 📚Surveyor│           │ 💻 Coder  │
 │  Research  │           │ Engineer   │
 └─────┬─────┘           └─────┬─────┘
       │                       │
       └───────────┬───────────┘
             ┌─────▼─────┐
             │ ✍️ Writer │
             │  Author    │
             └─────┬─────┘
                   │
             ┌─────▼─────┐
             │ 🔍Reviewer│ ◄── Quality Gate
             │  Reviewer  │
             └───────────┘
```

### Adversarial Collaboration

The system is built on **productive tension** between agents:

| Axis | Agents | Dynamic |
|------|--------|---------|
| **Creativity vs. Taste** | 💡 Ideator ↔ 🎯 Critic | Forge top-tier ideas through rigorous debate |
| **Writing vs. Review** | ✍️ Writer ↔ 🔍 Reviewer | Polish papers through iterative feedback |

- **🎯 Critic** holds ultimate **taste veto** — no idea passes Phase 2.5 without SHARP ≥ 18
- **🔍 Reviewer** holds ultimate **quality veto** — paper cannot submit without Reviewer's Accept

---

## 🤖 Agents

### Core Fleet (🔒 Protected)

| # | Agent | ID | Identity | Role |
|---|-------|----|----------|------|
| 0 | **Main** | `main` | 🐾 OpenClaw | System orchestrator, audit, final arbiter |
| 1 | **Planner** | `planner` | 🧠 Planner | Task decomposition, progress tracking, coordination |
| 2 | **Ideator** | `ideator` | 💡 Ideator | Idea generation, novelty assessment, contribution framing |
| 3 | **Critic** | `critic` | 🎯 Critic | SHARP taste evaluation, anti-pattern detection |
| 4 | **Surveyor** | `surveyor` | 📚 Surveyor | Literature search, research gap identification |
| 5 | **Coder** | `coder` | 💻 Coder | Algorithm implementation, experiment execution |
| 6 | **Writer** | `writer` | ✍️ Writer | Paper writing, LaTeX formatting |
| 7 | **Reviewer** | `reviewer` | 🔍 Reviewer | Internal peer review, rebuttal strategy |
| 8 | **Scout** | `scout` | 📰 Scout | Daily paper digest, trend monitoring |

### Per-Agent Workspace

Each agent has three core files inside `.agents/<agent_id>/`:

| File | Purpose | Customize When... |
|------|---------|-------------------|
| `soul.md` | 🧬 Identity, personality, decision principles | You want to change agent behavior |
| `agent.md` | ⚙️ Model, tools, sandbox, inter-agent protocols | You want to change model or tool access |
| `user.md` | 👤 User context, research profile, preferences | You want to adapt to a different research domain |

---

## 📡 Channel & Group Configuration

> **Docs**: [Groups](https://docs.openclaw.ai/channels/groups) · [Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)

### Supported Channels

| Channel | Group ID Format | Example | Docs |
|---------|----------------|---------|------|
| **Feishu** (飞书) | `oc_xxxxxxxxx` | `oc_b1c331592eaa36d06a7e5df05d08a890` | [Feishu docs](https://docs.openclaw.ai/channels/feishu) |
| **WhatsApp** | `xxxxx@g.us` | `120363999999999999@g.us` | [WhatsApp docs](https://docs.openclaw.ai/channels/whatsapp) |
| **Telegram** | Negative integer | `-1001234567890` | [Telegram docs](https://docs.openclaw.ai/channels/telegram) |
| **Discord** | Guild ID | `1234567890` | [Discord docs](https://docs.openclaw.ai/channels/discord) |
| **Slack** | Team + Channel | `T0123/C0123` | [Slack docs](https://docs.openclaw.ai/channels/slack) |

### Group Policy

OpenClaw uses a three-tier access control model for groups:

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `"open"` | All groups allowed (**default**) | Personal servers, trusted teams |
| `"allowlist"` | Only listed groups allowed | Multi-tenant / production |
| `"disabled"` | All group messages dropped | DM-only bots |

```jsonc
{
  "channels": {
    "feishu": {
      "groupPolicy": "open",                    // ← all groups allowed
      "groups": {
        "oc_YOUR_GROUP_ID": {
          "requireMention": true               // ← must @mention to trigger
        }
      }
    }
  }
}
```

### Mention Gating

You can choose whether agents require `@mention` to respond in groups:

| Setting | Behavior |
|---------|----------|
| `requireMention: true` (**default**) | Agents only respond when @mentioned. Messages without @ are stored for context but don't trigger a reply. |
| `requireMention: false` | Agents auto-respond to all group messages. No @mention needed. |

```bash
# Default: require @mention
./setup.sh --channel feishu --group-id oc_xxx

# Auto-respond without @mention
./setup.sh --require-mention false --channel feishu --group-id oc_xxx
```

Each agent has unique `mentionPatterns`:

```jsonc
{
  "agents": {
    "list": [
      {
        "id": "planner",
        "name": "💡 Planner",
        "groupChat": {
          "mentionPatterns": ["@planner", "planner", "@Planner"],
          "historyLimit": 50
        }
      }
    ]
  }
}
```

> **How it works**: Type `@planner 请分解这个任务` in the group, and only the 💡 Planner agent will respond.

Messages that don't match any mention pattern are **stored for context** but don't trigger a reply — this allows agents to follow the conversation passively.

### Session Keys

Each agent gets an isolated session per group:

```
agent:<agentId>:<channel>:group:<groupId>
```

| Session | Key Example |
|---------|-------------|
| Planner in Feishu group | `agent:planner:feishu:group:oc_xxx` |
| Coder in Telegram group | `agent:coder:telegram:group:-1001234567890` |
| Main in DM | `agent:main:main` |

Telegram forum topics add `:topic:<threadId>` for per-topic isolation.

### Workspace & Tool Restrictions

Each sub-agent has its **own independent workspace** (no Docker sandbox). The setup script deploys UPPERCASE workspace files:

| File | Content |
|------|---------|
| `SOUL.md` | Merged: `SOUL_raw.md` (generic behaviors) + agent-specific `soul.md` (identity) |
| `USER.md` | Merged: `USER.md` (template) + agent-specific `user.md` (context) |
| `AGENT.md` | Agent configuration with model settings |
| `AGENTS.md` | Workspace conventions (from repo root) |

You can restrict tools per group or per sender:

```jsonc
{
  "channels": {
    "telegram": {
      "groups": {
        "-1001234567890": {
          "tools": {
            "deny": ["exec", "write"]                   // block risky tools
          },
          "toolsBySender": {
            "id:123456789": { "alsoAllow": ["exec"] }   // override for trusted user
          }
        }
      }
    }
  }
}
```

### Display Labels

Agents show as `<emoji> <name>` in chat (configured via `identity.name`):

| What You Type | Who Replies |
|--------------|-------------|
| `@planner 分解一下任务` | 🧠 Planner |
| `@critic 评估这个 idea` | 🎯 Critic |
| `@coder 跑一下实验` | 💻 Coder |
| `@writer 写 related work` | ✍️ Writer |

### Pre-built Examples

| Channel | Config | Key Features |
|---------|--------|-------------|
| Feishu | [`openclaw.feishu.json`](examples/openclaw.feishu.json) | All 9 agents, open policy, mention gating |
| WhatsApp | [`openclaw.whatsapp.json`](examples/openclaw.whatsapp.json) | DM pairing, open policy |
| Telegram | [`openclaw.telegram.json`](examples/openclaw.telegram.json) | Tool restrictions per group |

---

## 📋 Workflows

| Workflow | Slash Command | Description |
|----------|--------------|-------------|
| 📋 Paper Pipeline | `/paper-pipeline` | Full 9-phase paper production with taste gates |
| 📰 Daily Digest | `/daily-digest` | Scout-led daily paper summarization |
| 💡 Brainstorm | `/brainstorm` | Rapid idea generation and evaluation |
| 🔄 Rebuttal | `/rebuttal` | Reviewer response preparation |

### Taste Gates (品鉴节点)

The Critic agent enforces quality at four critical checkpoints:

| Gate | Checkpoint | Pass Criteria |
|------|-----------|---------------|
| 🎯 Idea Confirmation | SHARP score + Soul Questions | SHARP ≥ 18 |
| 🎯 Method Design | Elegance + Parsimony | Parsimony ≥ 4 |
| 🎯 First Draft | Narrative quality + Memorability | ≥ 1 clear hook |
| 🎯 Pre-submission | Full quality judgment | Critic says "worth submitting" |

---

## 🧩 Customization

### Model Configuration

The default model is **`zai/glm-5`**. You have three options:

#### Option A: Same model for all agents (default)

```bash
# Uses zai/glm-5 for all 8 sub-agents
./setup.sh --channel feishu --group-id oc_xxx
```

#### Option B: Change the unified model

```bash
# All agents use the same custom model
./setup.sh --model ollama/kimi-k2.5:cloud --channel feishu --group-id oc_xxx
```

#### Option C: Different models per agent

```bash
# Default is zai/glm-5, but coder and writer get different models
./setup.sh \
  --model zai/glm-5 \
  --model-map 'coder=ollama/kimi-k2.5:cloud,writer=zai/glm-4.7,scout=zai/glm-4.7-flash' \
  --channel feishu --group-id oc_xxx
```

`--model-map` takes priority over `--model` for specified agents. Agents not in the map use the `--model` default.

### Adding Custom Agents

1. Add the agent definition to `agents.yaml`:

```yaml
agents:
  # ... existing agents ...
  - id: "math-prover"
    name: "🔢 Math Prover"
    emoji: "🔢"
    role: "Theorem proving, convergence analysis"
    model: "zai/glm-5"
    protected: false
    workspace: ".agents/math-prover"
```

2. Re-run `./setup.sh` or add manually:

```bash
openclaw agents add math-prover --model zai/glm-5 --workspace .agents/math-prover
openclaw agents set-identity --agent math-prover --name "🔢 Math Prover"
```

---

## 📁 Repository Structure

```
openclaw-agents/
├── setup.sh                          # 🚀 One-command setup script
├── agents.yaml                       # 📋 Agent manifest (source of truth)
├── soul.md                           # 🐾 Main Agent definition
├── README.md                         # 📖 This file
├── LICENSE                           # MIT License
├── CONTRIBUTING.md                   # Contribution guidelines
├── CHANGELOG.md                      # Version history
├── docs/
│   └── installation.md               # 📖 Full installation guide (for LLM agents)
├── examples/
│   ├── openclaw.feishu.json          # Feishu config example
│   ├── openclaw.whatsapp.json        # WhatsApp config example
│   └── openclaw.telegram.json        # Telegram config example
└── .agents/
    ├── planner/                      # 🧠 soul.md + agent.md + user.md
    ├── ideator/                      # 💡 soul.md + agent.md + user.md
    ├── critic/                       # 🎯 soul.md + agent.md + user.md
    ├── surveyor/                     # 📚 soul.md + agent.md + user.md
    ├── coder/                        # 💻 soul.md + agent.md + user.md
    ├── writer/                       # ✍️ soul.md + agent.md + user.md
    ├── reviewer/                     # 🔍 soul.md + agent.md + user.md
    ├── scout/                        # 📰 soul.md + agent.md + user.md
    └── workflows/
        ├── paper-pipeline.md         # 📋 End-to-end paper workflow
        ├── daily-digest.md           # 📰 Daily paper digest
        ├── brainstorm.md             # 💡 Idea brainstorming
        └── rebuttal.md               # 🔄 Rebuttal preparation
```

---

## 🔧 CLI Reference

### Setup Script Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--channel` | Channel type (feishu/whatsapp/telegram/discord/slack) | Interactive prompt |
| `--group-id` | Group/chat ID for channel binding | Interactive prompt |
| `--session-id` | Session ID for group routing | None |
| `--model` | Default LLM model for all agents | `zai/glm-5` |
| `--model-map` | Per-agent model overrides (`id=model,...`) | None |
| `--require-mention` | Require @mention to respond in groups (`true`/`false`) | `true` |
| `--skip-bindings` | Skip channel binding setup | `false` |
| `--dry-run` | Preview commands without executing | `false` |
| `-h, --help` | Show help | — |

> 🛡️ **Safe Merge**: The setup script **appends** sub-agents to your existing `openclaw.json`. Main agent is implicit (uses `agents.defaults`). No sandbox — each agent has its own workspace. A backup is created automatically.

### OpenClaw Commands

```bash
openclaw agents list --bindings       # List all agents and bindings
openclaw agents add <id>              # Add a new agent
openclaw agents set-identity          # Set agent display name
openclaw channels status --probe      # Check channel connectivity
openclaw gateway                      # Start the gateway
openclaw gateway restart              # Restart after config changes
```

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- 🐛 **Bug Reports** — Open a GitHub Issue
- 💡 **New Agents** — Submit a PR with agent files + `agents.yaml` update
- 📋 **Workflows** — Share your research process templates
- 📖 **Docs** — Improve guides and examples

---

## 📄 License

[MIT](LICENSE) — Use freely, modify openly, share generously.

---

<p align="center">
  <strong>Built with ❤️ for the AI research community</strong>
  <br/>
  <sub>Powered by <a href="https://docs.openclaw.ai">OpenClaw</a> 🦞</sub>
</p>
