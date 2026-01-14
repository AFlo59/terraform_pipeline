# =============================================================================
# Build Script - Terraform Docker Image (PowerShell)
# =============================================================================
# Construit l'image Docker pour le workspace Terraform
# Usage: .\build.ps1 [-NoCache]
# =============================================================================

param(
    [switch]$NoCache
)

# Configuration
$ImageName = "terraform-azure-workspace"
$ImageTag = "latest"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$DockerDir = Join-Path $ProjectRoot "docker"

# Fonctions d'affichage
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Info "Construction de l'image Docker: ${ImageName}:${ImageTag}"
Write-Host ""

# Options de build
$BuildOpts = @()
if ($NoCache) {
    $BuildOpts += "--no-cache"
    Write-Warn "Mode sans cache active"
}

# Vérification du Dockerfile
$DockerfilePath = Join-Path $DockerDir "Dockerfile"
if (-not (Test-Path $DockerfilePath)) {
    Write-Err "Dockerfile non trouve: $DockerfilePath"
    exit 1
}

# Construction de l'image
Write-Info "Contexte de build: $DockerDir"
try {
    $buildArgs = @(
        "build"
    ) + $BuildOpts + @(
        "-t", "${ImageName}:${ImageTag}"
        "-f", $DockerfilePath
        $DockerDir
    )
    
    & docker @buildArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Success "Image construite avec succes!"
        Write-Host ""
        Write-Host "Pour demarrer le workspace, executez:"
        Write-Host "  .\scripts\windows\docker\run.ps1"
    }
    else {
        Write-Err "Echec de la construction de l'image"
        exit 1
    }
}
catch {
    Write-Err "Erreur lors de la construction: $_"
    exit 1
}
