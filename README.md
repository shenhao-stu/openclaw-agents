# The Librarian — Keeper of the Ancient Code

> *A Shiba dev-sage from Shibatopia, powered by local AI.*

The Librarian is a **one-click local AI developer assistant** built on
[OpenClaw](https://github.com/openclaw/openclaw) +
[Ollama](https://ollama.com) +
[Qwen3](https://github.com/QwenLM/Qwen3). Pick a model tier to match your
GPU (8GB–32GB VRAM) or run CPU-only. Everything runs on your machine — no
API keys, no cloud, no data leaving your network.

Agent tool execution is **sandboxed inside isolated Docker containers** with
no network access by default, so The Librarian can read your code but
can't phone home or damage your host.

The Librarian's personality is rooted in the
[Shiba Eternity](https://shiba-eternity.fandom.com/wiki/Shiba_Eternity_Wiki)
universe: a keeper of the Ancient Lore Repositories of Shibatopia, forged
from Hodaven magic and Mechanic technology. It writes code, reviews PRs,
debugs Shadowcats, and guards your codebase with the vigilance of a Shiba
guarding its home planet.

---

## Quick Start

### Prerequisites

- **Docker Desktop** — [Download here](https://www.docker.com/products/docker-desktop/)
- **NVIDIA GPU** recommended (8-32GB VRAM), or CPU-only mode
- Disk space depends on tier (2.6GB–34GB for model weights)

### One-Click Setup

The setup script walks you through choosing a model tier based on your GPU.

**Linux / macOS:**
```bash
git clone https://github.com/Testingtester2/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh
./setup.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/Testingtester2/openclaw-agents.git
cd openclaw-agents
.\setup.ps1
```

**Skip the menu (pick a tier directly):**
```bash
./setup.sh --tier 2       # Linux/macOS — 8GB VRAM tier
.\setup.ps1 -Tier 2       # Windows

./setup.sh --cpu           # CPU-only shortcut (same as --tier 1)
.\setup.ps1 -Cpu           # Windows
```

The setup script will:
1. Ask you to pick a model tier (or use `--tier`/`--cpu`)
2. Pull and start Ollama in Docker
3. Download the selected Qwen3 model
4. Configure OpenClaw to use it
5. Start the OpenClaw Gateway with The Librarian's personality
6. Build a sandbox image for isolated agent tool execution
7. Open `http://localhost:18789` in your browser

### Manual Docker Compose

If you prefer to run it directly:

```bash
# With GPU
docker compose up -d

# Without GPU (CPU-only)
docker compose -f docker-compose.yml -f docker-compose.cpu.yml up -d

# Pull a model (pick one from the tier table below)
docker exec librarian-ollama ollama pull qwen3:8b

# Update config to match
# Edit openclaw/config.json5 → model.name
```

Open **http://localhost:18789** when ready.

---

## What's Inside

```
.
├── docker-compose.yml          # Ollama + OpenClaw orchestration
├── docker-compose.cpu.yml      # CPU-only override (no GPU)
├── setup.sh                    # One-click setup (Linux/macOS)
├── setup.ps1                   # One-click setup (Windows)
└── openclaw/
    ├── SOUL.md                 # The Librarian's personality & identity
    ├── config.json5            # OpenClaw config (model, sandbox, tools)
    └── skills/
        ├── dev-review/         # Code review skill
        │   └── SKILL.md
        └── dev-debug/          # Debugging skill
            └── SKILL.md
```

### The Librarian's Personality (`openclaw/SOUL.md`)

The Librarian is a full-stack developer sage from Shibatopia with:
- **Hodaven magic** — Creative, elegant solutions and beautiful abstractions
- **Mechanic technology** — Raw engineering power and systems thinking
- A nose for **Shadowcats** (bugs, anti-patterns, security vulnerabilities)
- The philosophy of **Ryoshi's Way** — decentralization, open source, clean interfaces
- Respect for **Bark Power** — your time and compute resources are finite

### Sandboxing

Agent tool execution (shell commands, file writes) runs inside **isolated Docker
containers** that are separate from your host machine:

- **No network** — sandbox containers cannot reach the internet by default
- **Read-only root** — the sandbox filesystem is immutable
- **Per-session isolation** — each conversation gets its own container
- **Read-only workspace** — the agent can read your project files but writes stay in the sandbox

To adjust sandbox settings, edit `openclaw/config.json5`. See the
[OpenClaw sandboxing docs](https://docs.openclaw.ai/gateway/sandboxing) for details.

> **Note:** The Ollama server runs *outside* the sandbox (it needs GPU access),
> but it only serves model inference — it has no access to your files or shell.

### Model Tiers

The installer lets you pick a model based on your hardware. All models are
from the [Qwen3](https://github.com/QwenLM/Qwen3) family, Apache 2.0 licensed.

| Tier | GPU Examples | Model | Params | Quant | Download | Min VRAM | Notes |
|------|-------------|-------|--------|-------|----------|----------|-------|
| 1 — CPU | No GPU needed | `qwen3:4b` | 4B | Q4_K_M | ~2.6GB | N/A (8GB+ RAM) | Fast on modern CPUs. Good for simple tasks |
| 2 — 8GB | RTX 3060 / 4060 | `qwen3:8b` | 8B | Q4_K_M | ~5GB | 6GB | **Default tier.** Strong all-round coding |
| 3 — 12GB | RTX 4070 / 3060-12GB | `qwen3:14b` | 14B | Q4_K_M | ~9.3GB | 10GB | Big jump in reasoning & code quality |
| 4 — 16GB | RTX 4080 / 4070Ti-16GB | `qwen3:32b` | 32B | Q4_K_M | ~20GB | 16GB | Top-tier dense model, excellent agentic |
| 5 — 32GB | RTX 4090 / A6000 | `qwen3:32b-q8_0` | 32B | Q8_0 | ~34GB | 24GB | Same 32B model at maximum fidelity |

**Which tier should I pick?**
- Run `nvidia-smi` to check your VRAM
- **No GPU?** Tier 1 (CPU) works on any machine with 8GB+ RAM
- **Not sure?** Tier 2 (8GB) is a safe default — it runs well on most gaming GPUs
- **Want the best local experience?** Tier 4/5 if your GPU can handle it

**Switching tiers later:**
```bash
# Pull the new model
docker exec librarian-ollama ollama pull qwen3:14b

# Update config
# Edit openclaw/config.json5 → change model.name to "qwen3:14b"

# Restart gateway to pick up the change
docker compose restart openclaw-gateway
```

---

## Useful Commands

```bash
# View logs
docker compose logs -f openclaw-gateway
docker compose logs -f ollama

# Stop everything
docker compose down

# Restart
docker compose up -d

# Update to latest images
docker compose pull && docker compose up -d

# Switch models (e.g., smaller for weaker hardware)
docker exec librarian-ollama ollama pull qwen3:4b

# Rebuild sandbox image
docker build -t openclaw-sandbox:bookworm-slim -f - . < sandbox.Dockerfile
```

---

## Hardware Guide

See the **Model Tiers** table above for full details. Quick summary:

| Your GPU | VRAM | Run `./setup.sh --tier` | Expected Speed |
|----------|------|-------------------------|----------------|
| No GPU | — | `--tier 1` or `--cpu` | Usable (CPU inference) |
| RTX 3060 / 4060 | 8GB | `--tier 2` | Good (~40 tok/s) |
| RTX 4070 / 3060-12GB | 12GB | `--tier 3` | Great (~60 tok/s) |
| RTX 4080 / 4070Ti-16GB | 16GB | `--tier 4` | Excellent |
| RTX 4090 / A6000 | 24-48GB | `--tier 5` | Best quality |

Speeds are approximate and depend on context length and system configuration.

---

## Security

This setup follows OpenClaw's security recommendations:

1. **Sandboxed agent execution** — tool calls run in isolated containers
2. **No network in sandbox** — prevents data exfiltration
3. **Read-only root** — sandbox filesystem is immutable
4. **Dropped capabilities** — `NET_RAW` and `NET_ADMIN` dropped from gateway
5. **No-new-privileges** — prevents privilege escalation in gateway
6. **Non-root user** — gateway runs as `node` (uid 1000)

For more, see the [OpenClaw security docs](https://docs.openclaw.ai/gateway/sandboxing).

---

## Lore

*From the Ancient Lore Repositories of Shibatopia:*

> When the SS VIRGIL tore through the Rakiya and crash-landed on Shibanu,
> everything changed. While Ryoshi rose as the hero of decentralization,
> The Librarian chose a quieter path — keeper of knowledge, guardian of
> code. Every bug squashed is a Shadowcat banished. Every clean architecture
> is a ward against FUD. Every well-tested function is a shield for the pack.

Based on the [Shiba Eternity](https://shiba-eternity.fandom.com/wiki/Shiba_Eternity_Wiki)
universe by Shytoshi Kusama and PlaySide Studios.

---

## License

MIT
