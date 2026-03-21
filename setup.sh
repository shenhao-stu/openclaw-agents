#!/usr/bin/env bash
###############################################################################
# The Librarian — One-Click Setup (Linux / macOS)
#
# What this does:
#   1. Checks for Docker (links to install if missing)
#   2. Asks you to pick a model tier based on your GPU VRAM
#   3. Starts Ollama + OpenClaw Gateway via Docker Compose
#   4. Pulls the selected model
#   5. Builds the sandbox image for isolated agent execution
#   6. Deploys The Librarian's personality (SOUL.md) and skills
#   7. Opens the OpenClaw dashboard in your browser
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh                      # Interactive tier selection
#   ./setup.sh --cpu                # CPU-only mode (no GPU)
#   ./setup.sh --tier <1-5>         # Skip menu, pick tier directly
#
# Model Tiers:
#   1) CPU-only  — qwen3:4b    (~2.6GB download, needs 8GB+ RAM)
#   2) 8GB VRAM  — qwen3:8b    (~5GB download)   [RTX 3060/4060]
#   3) 12GB VRAM — qwen3:14b   (~9.3GB download)  [RTX 4070/3060-12GB]
#   4) 16GB VRAM — qwen3:32b   (~20GB download)   [RTX 4080/4070Ti-16GB]
#   5) 32GB VRAM — qwen3:32b   (~20GB, Q8 quality) [RTX 4090/A6000]
###############################################################################

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Banner ──────────────────────────────────────────────────────
echo -e "${CYAN}"
cat << 'BANNER'

  +=========================================================+
  |                                                           |
  |   The Librarian                                           |
  |   Keeper of the Ancient Code                              |
  |                                                           |
  |   A Shiba dev-sage from Shibatopia                        |
  |   Powered by OpenClaw + Ollama + Qwen3                    |
  |                                                           |
  +=========================================================+

BANNER
echo -e "${NC}"

# ── Parse args ──────────────────────────────────────────────────
CPU_ONLY=false
TIER=""
for arg in "$@"; do
  case "$arg" in
    --cpu) CPU_ONLY=true; TIER=1 ;;
    --tier)
      # Next arg is the tier number — handled below
      ;;
    1|2|3|4|5)
      # Accept bare numbers after --tier
      if [ "${PREV_ARG:-}" = "--tier" ]; then
        TIER="$arg"
      fi
      ;;
    --help|-h)
      echo "Usage: ./setup.sh [--cpu] [--tier <1-5>]"
      echo ""
      echo "Options:"
      echo "  --cpu         Run without GPU (CPU-only inference, uses qwen3:4b)"
      echo "  --tier <N>    Skip the interactive menu and use tier N directly"
      echo ""
      echo "Tiers:"
      echo "  1  CPU-only   qwen3:4b    (~2.6GB)  Needs 8GB+ RAM"
      echo "  2  8GB VRAM   qwen3:8b    (~5GB)    RTX 3060 / 4060"
      echo "  3  12GB VRAM  qwen3:14b   (~9.3GB)  RTX 4070 / 3060-12GB"
      echo "  4  16GB VRAM  qwen3:32b   (~20GB)   RTX 4080 / 4070Ti-16GB"
      echo "  5  32GB VRAM  qwen3:32b   (~20GB)   RTX 4090 / A6000 (Q8 quality)"
      exit 0
      ;;
  esac
  PREV_ARG="$arg"
done

# Handle --tier N (two-arg form)
i=0
for arg in "$@"; do
  i=$((i + 1))
  if [ "$arg" = "--tier" ]; then
    # Get next arg
    next_i=$((i + 1))
    j=0
    for a2 in "$@"; do
      j=$((j + 1))
      if [ $j -eq $next_i ]; then
        TIER="$a2"
        break
      fi
    done
  fi
done

# ── Model tier definitions ─────────────────────────────────────
# Each tier: MODEL_TAG  DOWNLOAD_SIZE  DESCRIPTION
tier_model()   {
  case "$1" in
    1) echo "qwen3:4b" ;;
    2) echo "qwen3:8b" ;;
    3) echo "qwen3:14b" ;;
    4) echo "qwen3:32b" ;;
    5) echo "qwen3:32b-q8_0" ;;
  esac
}

tier_size()    {
  case "$1" in
    1) echo "~2.6GB" ;;
    2) echo "~5GB" ;;
    3) echo "~9.3GB" ;;
    4) echo "~20GB" ;;
    5) echo "~34GB" ;;
  esac
}

tier_label()   {
  case "$1" in
    1) echo "CPU-only    (qwen3:4b)     — Lightweight, needs 8GB+ RAM" ;;
    2) echo "8GB VRAM    (qwen3:8b)     — RTX 3060 / 4060" ;;
    3) echo "12GB VRAM   (qwen3:14b)    — RTX 4070 / 3060-12GB" ;;
    4) echo "16GB VRAM   (qwen3:32b)    — RTX 4080 / 4070Ti-16GB" ;;
    5) echo "32GB VRAM   (qwen3:32b Q8) — RTX 4090 / A6000 (best quality)" ;;
  esac
}

# ── Check Docker ────────────────────────────────────────────────
info "Checking for Docker..."
if ! command -v docker &> /dev/null; then
  error "Docker is not installed."
  echo ""
  echo "  Install Docker Desktop from:"
  echo "    https://www.docker.com/products/docker-desktop/"
  echo ""
  echo "  Then re-run this script."
  exit 1
fi

if ! docker info &> /dev/null 2>&1; then
  error "Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi
success "Docker is running."

# ── Check Docker Compose ────────────────────────────────────────
if ! docker compose version &> /dev/null 2>&1; then
  error "Docker Compose V2 not found. Please update Docker Desktop."
  exit 1
fi
success "Docker Compose available."

# ── Tier selection menu ─────────────────────────────────────────
if [ -z "$TIER" ]; then
  echo ""
  echo -e "${BOLD}Choose your model tier:${NC}"
  echo ""
  echo -e "  ${CYAN}1)${NC}  $(tier_label 1)"
  echo -e "  ${CYAN}2)${NC}  $(tier_label 2)"
  echo -e "  ${CYAN}3)${NC}  $(tier_label 3)"
  echo -e "  ${CYAN}4)${NC}  $(tier_label 4)"
  echo -e "  ${CYAN}5)${NC}  $(tier_label 5)"
  echo ""
  echo -e "  ${YELLOW}Not sure? Run 'nvidia-smi' to check your VRAM.${NC}"
  echo -e "  ${YELLOW}No GPU? Pick option 1 (CPU-only).${NC}"
  echo ""

  while true; do
    read -rp "  Enter tier [1-5]: " TIER
    case "$TIER" in
      1|2|3|4|5) break ;;
      *) echo -e "  ${RED}Please enter a number between 1 and 5.${NC}" ;;
    esac
  done
  echo ""
fi

# Validate tier
case "$TIER" in
  1|2|3|4|5) ;;
  *) error "Invalid tier: $TIER (must be 1-5)"; exit 1 ;;
esac

MODEL=$(tier_model "$TIER")
MODEL_SIZE=$(tier_size "$TIER")

if [ "$TIER" = "1" ]; then
  CPU_ONLY=true
fi

info "Selected: $(tier_label "$TIER")"
info "Model: $MODEL ($MODEL_SIZE download)"
echo ""

# ── GPU Check ───────────────────────────────────────────────────
if [ "$CPU_ONLY" = true ]; then
  warn "CPU-only mode. Inference will be slower but functional."
  COMPOSE_FILES="-f docker-compose.yml -f docker-compose.cpu.yml"
else
  if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    success "NVIDIA GPU detected."
    COMPOSE_FILES="-f docker-compose.yml"
  else
    warn "No NVIDIA GPU detected. Falling back to CPU-only mode."
    warn "Use --cpu flag to suppress this warning."
    COMPOSE_FILES="-f docker-compose.yml -f docker-compose.cpu.yml"
    CPU_ONLY=true
  fi
fi

# ── Start Services ──────────────────────────────────────────────
info "Starting The Librarian's workstation..."
echo ""

cd "$(dirname "$0")"

# Pull images first
info "Pulling Docker images (this may take a few minutes on first run)..."
docker compose $COMPOSE_FILES pull

# Start Ollama and OpenClaw Gateway
info "Starting Ollama + OpenClaw Gateway..."
docker compose $COMPOSE_FILES up -d ollama openclaw-gateway

# Wait for Ollama to be ready
info "Waiting for Ollama to initialize..."
RETRIES=0
MAX_RETRIES=30
until curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; do
  RETRIES=$((RETRIES + 1))
  if [ $RETRIES -ge $MAX_RETRIES ]; then
    error "Ollama failed to start after 60 seconds."
    echo "  Check logs: docker compose logs ollama"
    exit 1
  fi
  sleep 2
done
success "Ollama is ready."

# Pull the model
info "Pulling $MODEL ($MODEL_SIZE download, this is a one-time operation)..."
case "$TIER" in
  1) echo "  4B params — lightweight model for CPU inference. Needs 8GB+ system RAM." ;;
  2) echo "  8B params, Q4_K_M quantization — fits comfortably in 8GB VRAM." ;;
  3) echo "  14B params, Q4_K_M quantization — strong reasoning, fits 12GB VRAM." ;;
  4) echo "  32B dense params, Q4_K_M quantization — top-tier local model for 16GB VRAM." ;;
  5) echo "  32B dense params, Q8_0 quantization — maximum quality for 32GB VRAM." ;;
esac
echo ""
docker exec librarian-ollama ollama pull "$MODEL"
success "Model downloaded and ready."

# ── Write model selection to config ─────────────────────────────
# Update the config.json5 with the selected model
info "Configuring OpenClaw to use $MODEL..."
CONFIG_FILE="openclaw/config.json5"
if [ -f "$CONFIG_FILE" ]; then
  # Replace the model name line in config.json5
  sed -i.bak "s|name: \"qwen3:[^\"]*\"|name: \"$MODEL\"|" "$CONFIG_FILE" && rm -f "${CONFIG_FILE}.bak"
  success "Config updated: model set to $MODEL"
else
  warn "Config file not found at $CONFIG_FILE — you may need to set the model manually."
fi

# ── Build Sandbox Image ────────────────────────────────────────
info "Building sandbox image for agent isolation..."
if docker image inspect openclaw-sandbox:bookworm-slim > /dev/null 2>&1; then
  success "Sandbox image already exists."
else
  # Build a minimal sandbox image with common dev tooling
  docker build -t openclaw-sandbox:bookworm-slim -f - . <<'DOCKERFILE'
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Run as non-root
RUN useradd -m -s /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox
DOCKERFILE
  success "Sandbox image built."
fi

# ── Verify OpenClaw Gateway ────────────────────────────────────
info "Waiting for OpenClaw Gateway to start..."
RETRIES=0
until curl -sf http://localhost:18789/healthz > /dev/null 2>&1; do
  RETRIES=$((RETRIES + 1))
  if [ $RETRIES -ge $MAX_RETRIES ]; then
    error "OpenClaw Gateway failed to start after 60 seconds."
    echo "  Check logs: docker compose logs openclaw-gateway"
    exit 1
  fi
  sleep 2
done
success "OpenClaw Gateway is running."

# ── Done! ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}  The Librarian is ready!${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo ""
echo -e "  Model:  ${BOLD}$MODEL${NC} ($(tier_label "$TIER"))"
echo ""
echo "  Open in your browser:"
echo -e "    ${CYAN}http://localhost:18789${NC}"
echo ""
echo "  Useful commands:"
echo "    docker compose logs -f openclaw-gateway   # Watch OpenClaw logs"
echo "    docker compose logs -f ollama             # Watch Ollama logs"
echo "    docker compose down                       # Stop everything"
echo "    docker compose up -d                      # Restart"
echo ""
echo "  Change model tier:"
echo "    docker exec librarian-ollama ollama pull <model>"
echo "    Then update 'model.name' in openclaw/config.json5"
echo ""
echo "  Sandboxing:"
echo "    Agent tool execution runs inside isolated Docker containers."
echo "    Sandbox containers have no network access by default."
echo "    Edit openclaw/config.json5 to adjust sandbox settings."
echo ""
echo -e "  ${YELLOW}The Librarian guards the Ancient Lore. May your code be free"
echo -e "  of Shadowcats.${NC}"
echo ""

# Try to open browser
if command -v xdg-open &> /dev/null; then
  xdg-open "http://localhost:18789" 2>/dev/null || true
elif command -v open &> /dev/null; then
  open "http://localhost:18789" 2>/dev/null || true
fi
