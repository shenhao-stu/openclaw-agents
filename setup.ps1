###############################################################################
# The Librarian - One-Click Setup (Windows PowerShell)
#
# What this does:
#   1. Checks for Docker Desktop (links to install if missing)
#   2. Asks you to pick a model tier based on your GPU VRAM
#   3. Starts Ollama + OpenClaw Gateway via Docker Compose
#   4. Pulls the selected model
#   5. Builds the sandbox image for isolated agent execution
#   6. Deploys The Librarian's personality (SOUL.md) and skills
#   7. Opens the OpenClaw dashboard in your browser
#
# Usage (run in PowerShell):
#   .\setup.ps1                     # Interactive tier selection
#   .\setup.ps1 -Cpu                # CPU-only mode
#   .\setup.ps1 -Tier 3             # Skip menu, use tier 3 (12GB)
#
# Model Tiers:
#   1  CPU-only   qwen3:4b    (~2.6GB)  Needs 8GB+ RAM
#   2  8GB VRAM   qwen3:8b    (~5GB)    RTX 3060 / 4060
#   3  12GB VRAM  qwen3:14b   (~9.3GB)  RTX 4070 / 3060-12GB
#   4  16GB VRAM  qwen3:32b   (~20GB)   RTX 4080 / 4070Ti-16GB
#   5  32GB VRAM  qwen3:32b   (~20GB)   RTX 4090 / A6000 (Q8 quality)
###############################################################################

param(
    [switch]$Cpu,
    [switch]$Help,
    [ValidateRange(1,5)][int]$Tier = 0
)

$ErrorActionPreference = "Stop"

# -- Banner -------------------------------------------------------------------
Write-Host ""
Write-Host "  +========================================================+" -ForegroundColor Cyan
Write-Host "  |                                                        |" -ForegroundColor Cyan
Write-Host "  |   The Librarian                                        |" -ForegroundColor Cyan
Write-Host "  |   Keeper of the Ancient Code                           |" -ForegroundColor Cyan
Write-Host "  |                                                        |" -ForegroundColor Cyan
Write-Host "  |   A Shiba dev-sage from Shibatopia                     |" -ForegroundColor Cyan
Write-Host "  |   Powered by OpenClaw + Ollama + Qwen3                 |" -ForegroundColor Cyan
Write-Host "  |                                                        |" -ForegroundColor Cyan
Write-Host "  +========================================================+" -ForegroundColor Cyan
Write-Host ""

if ($Help) {
    Write-Host "Usage: .\setup.ps1 [-Cpu] [-Tier <1-5>]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Cpu         Run without GPU (CPU-only inference, uses qwen3:4b)"
    Write-Host "  -Tier <N>    Skip the interactive menu and use tier N directly"
    Write-Host ""
    Write-Host "Tiers:"
    Write-Host "  1  CPU-only   qwen3:4b    (~2.6GB)  Needs 8GB+ RAM"
    Write-Host "  2  8GB VRAM   qwen3:8b    (~5GB)    RTX 3060 / 4060"
    Write-Host "  3  12GB VRAM  qwen3:14b   (~9.3GB)  RTX 4070 / 3060-12GB"
    Write-Host "  4  16GB VRAM  qwen3:32b   (~20GB)   RTX 4080 / 4070Ti-16GB"
    Write-Host "  5  32GB VRAM  qwen3:32b   (~20GB)   RTX 4090 / A6000 (Q8 quality)"
    exit 0
}

function Write-Info($msg)    { Write-Host "[INFO]  $msg" -ForegroundColor Blue }
function Write-Ok($msg)      { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err($msg)     { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# -- Model tier definitions ---------------------------------------------------
$TierModels = @{
    1 = "qwen3:4b"
    2 = "qwen3:8b"
    3 = "qwen3:14b"
    4 = "qwen3:32b"
    5 = "qwen3:32b-q8_0"
}

$TierSizes = @{
    1 = "~2.6GB"
    2 = "~5GB"
    3 = "~9.3GB"
    4 = "~20GB"
    5 = "~34GB"
}

$TierLabels = @{
    1 = "CPU-only    (qwen3:4b)     - Lightweight, needs 8GB+ RAM"
    2 = "8GB VRAM    (qwen3:8b)     - RTX 3060 / 4060"
    3 = "12GB VRAM   (qwen3:14b)    - RTX 4070 / 3060-12GB"
    4 = "16GB VRAM   (qwen3:32b)    - RTX 4080 / 4070Ti-16GB"
    5 = "32GB VRAM   (qwen3:32b Q8) - RTX 4090 / A6000 (best quality)"
}

$TierNotes = @{
    1 = "4B params - lightweight model for CPU inference. Needs 8GB+ system RAM."
    2 = "8B params, Q4_K_M quantization - fits comfortably in 8GB VRAM."
    3 = "14B params, Q4_K_M quantization - strong reasoning, fits 12GB VRAM."
    4 = "32B dense params, Q4_K_M quantization - top-tier local model for 16GB VRAM."
    5 = "32B dense params, Q8_0 quantization - maximum quality for 32GB VRAM."
}

# -- Check Docker -------------------------------------------------------------
Write-Info "Checking for Docker..."

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Err "Docker is not installed."
    Write-Host ""
    Write-Host "  Install Docker Desktop from:"
    Write-Host "    https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  After installing, restart this script."
    exit 1
}

try {
    docker info 2>$null | Out-Null
} catch {
    Write-Err "Docker is not running. Please start Docker Desktop and try again."
    exit 1
}
Write-Ok "Docker is running."

# -- Check Docker Compose -----------------------------------------------------
try {
    docker compose version 2>$null | Out-Null
} catch {
    Write-Err "Docker Compose V2 not found. Please update Docker Desktop."
    exit 1
}
Write-Ok "Docker Compose available."

# -- Tier selection -----------------------------------------------------------
if ($Cpu) { $Tier = 1 }

if ($Tier -eq 0) {
    Write-Host ""
    Write-Host "  Choose your model tier:" -ForegroundColor White
    Write-Host ""
    for ($i = 1; $i -le 5; $i++) {
        Write-Host "    $i)  $($TierLabels[$i])" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  Not sure? Run 'nvidia-smi' to check your VRAM." -ForegroundColor Yellow
    Write-Host "  No GPU? Pick option 1 (CPU-only)." -ForegroundColor Yellow
    Write-Host ""

    do {
        $input = Read-Host "  Enter tier [1-5]"
        $Tier = [int]$input
    } while ($Tier -lt 1 -or $Tier -gt 5)
    Write-Host ""
}

$Model = $TierModels[$Tier]
$ModelSize = $TierSizes[$Tier]
$CpuOnly = ($Tier -eq 1)

Write-Info "Selected: $($TierLabels[$Tier])"
Write-Info "Model: $Model ($ModelSize download)"
Write-Host ""

# -- GPU Check ----------------------------------------------------------------
$composeFiles = @("-f", "docker-compose.yml")

if ($CpuOnly -or $Cpu) {
    Write-Warn "CPU-only mode. Inference will be slower but functional."
    $composeFiles += @("-f", "docker-compose.cpu.yml")
} else {
    $hasGpu = $false
    try {
        $nvsmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
        if ($nvsmi) {
            nvidia-smi 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $hasGpu = $true }
        }
    } catch {}

    if ($hasGpu) {
        Write-Ok "NVIDIA GPU detected."
    } else {
        Write-Warn "No NVIDIA GPU detected. Using CPU-only mode."
        $composeFiles += @("-f", "docker-compose.cpu.yml")
    }
}

# -- Start Services -----------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Info "Pulling Docker images (first run may take a few minutes)..."
& docker compose @composeFiles pull
if ($LASTEXITCODE -ne 0) { Write-Err "Failed to pull images."; exit 1 }

Write-Info "Starting Ollama + OpenClaw Gateway..."
& docker compose @composeFiles up -d ollama openclaw-gateway
if ($LASTEXITCODE -ne 0) { Write-Err "Failed to start services."; exit 1 }

# Wait for Ollama
Write-Info "Waiting for Ollama to initialize..."
$retries = 0
$maxRetries = 30
do {
    Start-Sleep -Seconds 2
    $retries++
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($resp.StatusCode -eq 200) { break }
    } catch {}
    if ($retries -ge $maxRetries) {
        Write-Err "Ollama failed to start after 60 seconds."
        Write-Host "  Check logs: docker compose logs ollama"
        exit 1
    }
} while ($true)
Write-Ok "Ollama is ready."

# Pull model
Write-Info "Pulling $Model ($ModelSize download, one-time operation)..."
Write-Host "  $($TierNotes[$Tier])"
Write-Host ""
& docker exec librarian-ollama ollama pull $Model
if ($LASTEXITCODE -ne 0) { Write-Err "Failed to pull model."; exit 1 }
Write-Ok "Model downloaded and ready."

# -- Update config with selected model ----------------------------------------
Write-Info "Configuring OpenClaw to use $Model..."
$configPath = Join-Path $scriptDir "openclaw" "config.json5"
if (Test-Path $configPath) {
    $content = Get-Content $configPath -Raw
    $content = $content -replace 'name: "qwen3:[^"]*"', "name: `"$Model`""
    Set-Content -Path $configPath -Value $content -NoNewline
    Write-Ok "Config updated: model set to $Model"
} else {
    Write-Warn "Config file not found - you may need to set the model manually."
}

# -- Build Sandbox Image ------------------------------------------------------
Write-Info "Building sandbox image for agent isolation..."
$sandboxExists = docker image inspect openclaw-sandbox:bookworm-slim 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Ok "Sandbox image already exists."
} else {
    $dockerfile = @"
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl jq git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox
"@
    $dockerfile | docker build -t openclaw-sandbox:bookworm-slim -f - .
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to build sandbox image."; exit 1 }
    Write-Ok "Sandbox image built."
}

# Wait for OpenClaw Gateway
Write-Info "Waiting for OpenClaw Gateway to start..."
$retries = 0
do {
    Start-Sleep -Seconds 2
    $retries++
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:18789/healthz" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($resp.StatusCode -eq 200) { break }
    } catch {}
    if ($retries -ge $maxRetries) {
        Write-Err "OpenClaw Gateway failed to start after 60 seconds."
        Write-Host "  Check logs: docker compose logs openclaw-gateway"
        exit 1
    }
} while ($true)
Write-Ok "OpenClaw Gateway is running."

# -- Done! --------------------------------------------------------------------
Write-Host ""
Write-Host "  ========================================================" -ForegroundColor Green
Write-Host "    The Librarian is ready!" -ForegroundColor Green
Write-Host "  ========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Model:  $Model ($($TierLabels[$Tier]))"
Write-Host ""
Write-Host "  Open in your browser:"
Write-Host "    http://localhost:18789" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Useful commands:"
Write-Host "    docker compose logs -f openclaw-gateway   # Watch OpenClaw logs"
Write-Host "    docker compose logs -f ollama             # Watch Ollama logs"
Write-Host "    docker compose down                       # Stop everything"
Write-Host "    docker compose up -d                      # Restart"
Write-Host ""
Write-Host "  Change model tier:" -ForegroundColor Yellow
Write-Host "    docker exec librarian-ollama ollama pull <model>"
Write-Host "    Then update 'model.name' in openclaw/config.json5"
Write-Host ""
Write-Host "  Sandboxing:" -ForegroundColor Yellow
Write-Host "    Agent tool execution runs inside isolated Docker containers."
Write-Host "    Sandbox containers have no network access by default."
Write-Host "    Edit openclaw/config.json5 to adjust sandbox settings."
Write-Host ""
Write-Host "  The Librarian guards the Ancient Lore. May your code be" -ForegroundColor Yellow
Write-Host "  free of Shadowcats." -ForegroundColor Yellow
Write-Host ""

# Open browser
Start-Process "http://localhost:18789"
