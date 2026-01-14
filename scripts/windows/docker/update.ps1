# =============================================================================
# Update Script - Terraform Docker Image (PowerShell)
# =============================================================================
# Met a jour l'image Docker en la reconstruisant sans cache
# Usage: .\update.ps1
# =============================================================================

# Configuration
$ImageName = "terraform-azure-workspace"
$ImageTag = "latest"
$ContainerName = "terraform-workspace"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Fonctions d'affichage
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Update { param($Message) Write-Host "[UPDATE] $Message" -ForegroundColor Green }

Write-Update "Mise a jour de l'image Terraform"
Write-Host ""

# Arreter le conteneur existant si en cours d'execution
$runningContainer = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
if ($runningContainer) {
    Write-Info "Arret du conteneur en cours d'execution..."
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
}

# Sauvegarde de l'ancienne image (tag)
$existingImage = docker image inspect "${ImageName}:${ImageTag}" 2>$null
if ($existingImage) {
    Write-Info "Sauvegarde de l'ancienne image..."
    docker tag "${ImageName}:${ImageTag}" "${ImageName}:backup" 2>$null
}

# Reconstruction de l'image
Write-Host "[BUILD] Reconstruction de l'image sans cache..." -ForegroundColor Green
try {
    & "$ScriptDir\build.ps1" -NoCache
    
    if ($LASTEXITCODE -eq 0) {
        # Suppression de l'image de backup
        $backupImage = docker image inspect "${ImageName}:backup" 2>$null
        if ($backupImage) {
            Write-Warn "Suppression de l'ancienne image..."
            docker rmi "${ImageName}:backup" 2>$null | Out-Null
        }
        
        Write-Host ""
        Write-Success "Image mise a jour avec succes!"
    }
    else {
        throw "Build failed"
    }
}
catch {
    # Restauration de l'image de backup en cas d'echec
    $backupImage = docker image inspect "${ImageName}:backup" 2>$null
    if ($backupImage) {
        Write-Err "Echec de la mise a jour. Restauration de l'ancienne image..."
        docker tag "${ImageName}:backup" "${ImageName}:${ImageTag}"
    }
    exit 1
}
