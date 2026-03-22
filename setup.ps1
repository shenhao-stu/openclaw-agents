###############################################################################
# The Librarian - One-Click Setup (Windows PowerShell)
#
# What this does:
#   1. Asks how you want to install (Docker or native on host)
#   2. Asks you to pick a model tier based on your GPU VRAM
#   3. Installs Ollama + OpenClaw Gateway
#   4. Pulls the selected model
#   5. Deploys The Librarian's personality (SOUL.md) and skills
#   6. Opens the OpenClaw dashboard in your browser
#
# Usage (run in PowerShell):
#   .\setup.ps1                     # Interactive setup
#   .\setup.ps1 -Docker             # Docker mode (skip install-mode prompt)
#   .\setup.ps1 -Native             # Native mode (recommended for VMs)
#   .\setup.ps1 -Cpu                # CPU-only mode
#   .\setup.ps1 -Tier 3             # Skip menu, use tier 3 (16GB)
#   .\setup.ps1 -Tier 4 -Coder      # Use qwen3-coder instead of qwen3.5
#
# Model Tiers:
#   1  CPU-only   qwen3.5:4b            (~3.4GB)  Needs 8GB+ RAM
#   2  8GB VRAM   qwen3.5:9b            (~6.6GB)  RTX 3060 / 4060
#   3  16GB VRAM  qwen3.5:27b           (~17GB)   RTX 4080 / 4070Ti-16GB
#   4  24GB VRAM  qwen3.5:35b           (~24GB)   RTX 4090
#                 or qwen3-coder:30b-a3b (~19GB, code-specialized MoE)
#   5  48GB VRAM  qwen3.5:35b-q8_0      (~35GB)   A6000 / dual GPU (Q8)
#                 or qwen3-coder:30b-a3b-q8_0 (~32GB, code-specialized MoE Q8)
###############################################################################

param(
    [switch]$Cpu,
    [switch]$Coder,
    [switch]$Help,
    [switch]$Docker,
    [switch]$Native,
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
Write-Host "  |   Powered by OpenClaw + Ollama + Qwen3.5               |" -ForegroundColor Cyan
Write-Host "  |                                                        |" -ForegroundColor Cyan
Write-Host "  +========================================================+" -ForegroundColor Cyan
Write-Host ""

if ($Help) {
    Write-Host "Usage: .\setup.ps1 [-Docker|-Native] [-Cpu] [-Tier <1-5>] [-Coder]"
    Write-Host ""
    Write-Host "Install modes:"
    Write-Host "  -Docker      Run everything in Docker containers (needs Docker Desktop)"
    Write-Host "  -Native      Install directly on the host (recommended for VMs)"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Cpu         Run without GPU (CPU-only inference, uses qwen3.5:4b)"
    Write-Host "  -Tier <N>    Skip the interactive menu and use tier N directly"
    Write-Host "  -Coder       Use qwen3-coder (code-specialized) instead of qwen3.5 for tiers 4-5"
    Write-Host ""
    Write-Host "Tiers:"
    Write-Host "  1  CPU-only   qwen3.5:4b            (~3.4GB)  Needs 8GB+ RAM"
    Write-Host "  2  8GB VRAM   qwen3.5:9b            (~6.6GB)  RTX 3060 / 4060"
    Write-Host "  3  16GB VRAM  qwen3.5:27b           (~17GB)   RTX 4080 / 4070Ti-16GB"
    Write-Host "  4  24GB VRAM  qwen3.5:35b           (~24GB)   RTX 4090"
    Write-Host "              or qwen3-coder:30b-a3b   (~19GB)   with -Coder"
    Write-Host "  5  48GB VRAM  qwen3.5:35b-q8_0      (~35GB)   A6000 / dual GPU (Q8)"
    Write-Host "              or qwen3-coder:30b-a3b-q8_0 (~32GB) with -Coder (Q8)"
    exit 0
}

function Write-Info($msg)    { Write-Host "[INFO]  $msg" -ForegroundColor Blue }
function Write-Ok($msg)      { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err($msg)     { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# -- Check / Install Git ------------------------------------------------------
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Info "Git is not installed. Installing via winget..."
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        winget install Git.Git --accept-package-agreements --accept-source-agreements
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-Err "Could not install git. Please install from https://git-scm.com and re-run."
        exit 1
    }
    Write-Ok "Git installed."
} else {
    Write-Ok "Git is available."
}

# -- Model tier definitions ---------------------------------------------------
$TierModels = @{
    1 = "qwen3.5:4b"
    2 = "qwen3.5:9b"
    3 = "qwen3.5:27b"
    4 = "qwen3.5:35b"
    5 = "qwen3.5:35b-q8_0"
}

$TierSizes = @{
    1 = "~3.4GB"
    2 = "~6.6GB"
    3 = "~17GB"
    4 = "~24GB"
    5 = "~35GB"
}

$TierLabels = @{
    1 = "CPU-only    (qwen3.5:4b)             - Lightweight, needs 8GB+ RAM"
    2 = "8GB VRAM    (qwen3.5:9b)             - RTX 3060 / 4060"
    3 = "16GB VRAM   (qwen3.5:27b)            - RTX 4080 / 4070Ti-16GB"
    4 = "24GB VRAM   (qwen3.5:35b)            - RTX 4090"
    5 = "48GB VRAM   (qwen3.5:35b-q8_0)       - A6000 / dual GPU (best)"
}

$TierNotes = @{
    1 = "4B params - lightweight model for CPU inference. Needs 8GB+ system RAM."
    2 = "9B params, Q4_K_M quantization - fits comfortably in 8GB VRAM."
    3 = "27B params, Q4_K_M quantization - strong reasoning, 256K context."
    4 = "35B params, Q4_K_M quantization - best quality dense model for 24GB VRAM."
    5 = "35B params, Q8_0 - max quality for 48GB+ VRAM."
}

# Coder model alternatives for tiers 4-5
$CoderModels = @{
    4 = "qwen3-coder:30b-a3b"
    5 = "qwen3-coder:30b-a3b-q8_0"
}

$CoderSizes = @{
    4 = "~19GB"
    5 = "~32GB"
}

$CoderNotes = @{
    4 = "30B MoE (3.3B active), Q4_K_M - code-specialized, fast inference, 256K context."
    5 = "30B MoE (3.3B active), Q8_0 - max quality code-specialized agent."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# -- Install mode selection ---------------------------------------------------
$InstallMode = ""
if ($Docker) { $InstallMode = "docker" }
if ($Native) { $InstallMode = "native" }

if ($InstallMode -eq "") {
    Write-Host ""
    Write-Host "  How would you like to install The Librarian?" -ForegroundColor White
    Write-Host ""
    Write-Host "    1)  Docker - Run everything in containers" -ForegroundColor Cyan
    Write-Host "        Easy to install and remove. Requires Docker Desktop."
    Write-Host ""
    Write-Host "    2)  Native - Install directly on this machine" -ForegroundColor Cyan
    Write-Host "        Better GPU performance, no Docker needed."
    Write-Host "        Recommended: run this inside a VM for easy cleanup." -ForegroundColor Yellow
    Write-Host ""

    do {
        $modeInput = Read-Host "  Enter choice [1/2]"
    } while ($modeInput -ne "1" -and $modeInput -ne "2")

    if ($modeInput -eq "1") { $InstallMode = "docker" } else { $InstallMode = "native" }
    Write-Host ""
}

Write-Info "Install mode: $InstallMode"

# -- Tier selection -----------------------------------------------------------
if ($Cpu -and $Tier -gt 0 -and $Tier -ne 1) {
    Write-Warn "-Cpu flag overrides -Tier $Tier. Using tier 1 (CPU-only)."
}
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

# -- Model variant selection (tiers 4-5) --------------------------------------
$UseCoder = $Coder

if ($Tier -ge 4 -and -not $Coder) {
    Write-Host ""
    Write-Host "  Choose your model variant for tier $Tier`:" -ForegroundColor White
    Write-Host ""
    Write-Host "    a)  qwen3.5  - General-purpose, strong agentic reasoning, 256K context" -ForegroundColor Cyan
    Write-Host "        $($TierModels[$Tier]) ($($TierSizes[$Tier]) download)"
    Write-Host ""
    Write-Host "    b)  qwen3-coder - Code-specialized MoE (3.3B active params, very fast)" -ForegroundColor Cyan
    Write-Host "        $($CoderModels[$Tier]) ($($CoderSizes[$Tier]) download)"
    Write-Host ""

    do {
        $variant = Read-Host "  Enter variant [a/b]"
    } while ($variant -ne "a" -and $variant -ne "A" -and $variant -ne "b" -and $variant -ne "B")

    if ($variant -eq "b" -or $variant -eq "B") { $UseCoder = $true }
    Write-Host ""
}

if ($UseCoder -and $Tier -ge 4) {
    $Model = $CoderModels[$Tier]
    $ModelSize = $CoderSizes[$Tier]
    $ModelNote = $CoderNotes[$Tier]
} else {
    $Model = $TierModels[$Tier]
    $ModelSize = $TierSizes[$Tier]
    $ModelNote = $TierNotes[$Tier]
}

$CpuOnly = ($Tier -eq 1)

Write-Info "Selected: $($TierLabels[$Tier])"
Write-Info "Model: $Model ($ModelSize download)"
Write-Host ""

###############################################################################
#                           DOCKER INSTALL PATH                               #
###############################################################################
if ($InstallMode -eq "docker") {

    # -- Check / Install Docker ------------------------------------------------
    Write-Info "Checking for Docker..."

    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Write-Warn "Docker is not installed."
        Write-Host ""

        # Try winget first, fall back to manual instructions
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-Host "  Install Docker Desktop now via winget?" -ForegroundColor White
            $installChoice = Read-Host "  Install Docker? [Y/n]"
            if ($installChoice -eq "" -or $installChoice -eq "Y" -or $installChoice -eq "y") {
                Write-Info "Installing Docker Desktop via winget..."
                winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
                Write-Host ""
                Write-Warn "Docker Desktop installed. Please open it from the Start menu to start the daemon,"
                Write-Warn "then re-run this script."
                exit 0
            }
        }

        Write-Err "Docker is not installed."
        Write-Host ""
        Write-Host "  Install Docker Desktop from:"
        Write-Host "    https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  After installing and starting it, re-run this script."
        exit 1
    }

    try {
        docker info 2>$null | Out-Null
    } catch {
        Write-Err "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    }
    Write-Ok "Docker is running."

    # -- Check Docker Compose -------------------------------------------------
    try {
        docker compose version 2>$null | Out-Null
    } catch {
        Write-Err "Docker Compose V2 not found. Please update Docker Desktop."
        exit 1
    }
    Write-Ok "Docker Compose available."

    # -- GPU Check ------------------------------------------------------------
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

    # -- Start Services -------------------------------------------------------
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
    Write-Host "  $ModelNote"
    Write-Host ""
    & docker exec librarian-ollama ollama pull $Model
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to pull model."; exit 1 }
    Write-Ok "Model downloaded and ready."

    # -- Update config with selected model ------------------------------------
    Write-Info "Configuring OpenClaw to use $Model..."
    $configPath = Join-Path $scriptDir "openclaw" "config.json5"
    if (Test-Path $configPath) {
        $content = Get-Content $configPath -Raw
        $content = $content -replace 'name: "[^"]*"', "name: `"$Model`""
        Set-Content -Path $configPath -Value $content -NoNewline
        Write-Ok "Config updated: model set to $Model"
    } else {
        Write-Warn "Config file not found - you may need to set the model manually."
    }

    # -- Build Sandbox Image --------------------------------------------------
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

    # -- Done (Docker) --------------------------------------------------------
    Write-Host ""
    Write-Host "  ========================================================" -ForegroundColor Green
    Write-Host "    The Librarian is ready!  (Docker mode)" -ForegroundColor Green
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

} # end Docker path

###############################################################################
#                           NATIVE INSTALL PATH                               #
###############################################################################
if ($InstallMode -eq "native") {

    # -- Install Ollama -------------------------------------------------------
    Write-Info "Checking for Ollama..."
    $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollamaCmd) {
        Write-Ok "Ollama is already installed."
    } else {
        Write-Info "Installing Ollama..."
        # Download and run the Windows installer
        $ollamaInstaller = Join-Path $env:TEMP "OllamaSetup.exe"
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $ollamaInstaller
        Start-Process -FilePath $ollamaInstaller -Args "/SILENT" -Wait
        Remove-Item $ollamaInstaller -ErrorAction SilentlyContinue

        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
        if (-not $ollamaCmd) {
            Write-Err "Ollama installation failed. Please install manually from https://ollama.com"
            exit 1
        }
        Write-Ok "Ollama installed."
    }

    # -- Start Ollama ---------------------------------------------------------
    Write-Info "Starting Ollama..."
    $ollamaRunning = $false
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($resp.StatusCode -eq 200) { $ollamaRunning = $true }
    } catch {}

    if ($ollamaRunning) {
        Write-Ok "Ollama is already running."
    } else {
        # Start Ollama in background
        Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
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
                Write-Host "  Try running 'ollama serve' manually in another terminal."
                exit 1
            }
        } while ($true)
        Write-Ok "Ollama is running."
    }

    # -- Pull model -----------------------------------------------------------
    Write-Info "Pulling $Model ($ModelSize download, one-time operation)..."
    Write-Host "  $ModelNote"
    Write-Host ""
    & ollama pull $Model
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to pull model."; exit 1 }
    Write-Ok "Model downloaded and ready."

    # -- Install Node.js (if needed) ------------------------------------------
    Write-Info "Checking for Node.js..."
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        Write-Ok "Node.js $(node --version) is installed."
    } else {
        Write-Info "Installing Node.js via winget..."
        try {
            winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        } catch {
            Write-Err "Could not auto-install Node.js. Please install Node.js 18+ from https://nodejs.org"
            exit 1
        }
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if (-not $nodeCmd) {
            Write-Err "Node.js installation failed. Please install from https://nodejs.org and re-run."
            exit 1
        }
        Write-Ok "Node.js installed ($(node --version))."
    }

    # -- Install OpenClaw Gateway ---------------------------------------------
    Write-Info "Installing OpenClaw Gateway..."
    $openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($openclawCmd) {
        Write-Ok "OpenClaw Gateway is already installed."
    } else {
        & npm install -g @openclaw/gateway
        if ($LASTEXITCODE -ne 0) {
            Write-Err "OpenClaw Gateway installation failed."
            Write-Host "  Try: npm install -g @openclaw/gateway"
            exit 1
        }
        Write-Ok "OpenClaw Gateway installed."
    }

    # -- Deploy configuration -------------------------------------------------
    $openclawDir = Join-Path $env:USERPROFILE ".openclaw"
    Write-Info "Deploying configuration to $openclawDir..."
    New-Item -ItemType Directory -Path $openclawDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $openclawDir "skills") -Force | Out-Null

    # Copy personality and skills
    Copy-Item (Join-Path $scriptDir "openclaw" "SOUL.md") (Join-Path $openclawDir "SOUL.md") -Force
    $skillsSrc = Join-Path $scriptDir "openclaw" "skills" "*"
    if (Test-Path (Join-Path $scriptDir "openclaw" "skills")) {
        Copy-Item $skillsSrc (Join-Path $openclawDir "skills") -Recurse -Force
    }

    # Write native config
    $nativeConfig = @"
{
  // -- The Librarian -- OpenClaw Configuration (native install) ---
  //
  // Model: $Model via local Ollama
  // Install mode: native (no Docker sandboxing)

  // Model provider configuration
  model: {
    provider: "ollama",
    name: "$Model",
    ollama: {
      baseUrl: "http://localhost:11434"
    }
  },

  // Gateway settings
  gateway: {
    bind: "lan"
  },

  // Tool approval policies
  tools: {
    requireApproval: [
      "shell:rm",
      "shell:sudo",
      "write:C:\\Windows\\*",
      "write:C:\\Program Files\\*"
    ]
  }
}
"@
    Set-Content -Path (Join-Path $openclawDir "config.json5") -Value $nativeConfig -NoNewline
    Write-Ok "Config deployed: model set to $Model"

    # -- Start OpenClaw Gateway -----------------------------------------------
    Write-Info "Starting OpenClaw Gateway..."
    $gatewayRunning = $false
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:18789/healthz" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($resp.StatusCode -eq 200) { $gatewayRunning = $true }
    } catch {}

    if ($gatewayRunning) {
        Write-Ok "OpenClaw Gateway is already running."
    } else {
        $configArg = Join-Path $openclawDir "config.json5"
        $logFile = Join-Path $openclawDir "gateway.log"
        Start-Process -FilePath "openclaw" -ArgumentList "serve","--config",$configArg -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $logFile

        $retries = 0
        $maxRetries = 30
        do {
            Start-Sleep -Seconds 2
            $retries++
            try {
                $resp = Invoke-WebRequest -Uri "http://localhost:18789/healthz" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
                if ($resp.StatusCode -eq 200) { break }
            } catch {}
            if ($retries -ge $maxRetries) {
                Write-Err "OpenClaw Gateway failed to start after 60 seconds."
                Write-Host "  Check logs: Get-Content $logFile"
                exit 1
            }
        } while ($true)
        Write-Ok "OpenClaw Gateway is running."
    }

    # -- Done (Native) --------------------------------------------------------
    Write-Host ""
    Write-Host "  ========================================================" -ForegroundColor Green
    Write-Host "    The Librarian is ready!  (native install)" -ForegroundColor Green
    Write-Host "  ========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Model:  $Model ($($TierLabels[$Tier]))"
    Write-Host ""
    Write-Host "  Open in your browser:"
    Write-Host "    http://localhost:18789" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Useful commands:"
    Write-Host "    Get-Content ~\.openclaw\gateway.log -Tail 50   # Watch gateway logs"
    Write-Host "    ollama ps                                       # Check running models"
    Write-Host "    ollama stop $Model                              # Unload model from VRAM"
    Write-Host ""
    Write-Host "  Change model:" -ForegroundColor Yellow
    Write-Host "    ollama pull <model>"
    Write-Host "    Then update 'model.name' in ~\.openclaw\config.json5"
    Write-Host ""
    Write-Host "  Stop everything:" -ForegroundColor Yellow
    Write-Host "    Stop-Process -Name openclaw                     # Stop gateway"
    Write-Host "    ollama stop $Model                              # Unload model"
    Write-Host ""
    Write-Host "  Config: $openclawDir\config.json5"
    Write-Host ""
    Write-Host "  NOTE: Native mode does not include Docker sandboxing." -ForegroundColor Yellow
    Write-Host "  For isolation, run this setup inside a VM." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  The Librarian guards the Ancient Lore. May your code be" -ForegroundColor Yellow
    Write-Host "  free of Shadowcats." -ForegroundColor Yellow
    Write-Host ""

} # end Native path

# Open browser
Start-Process "http://localhost:18789"
