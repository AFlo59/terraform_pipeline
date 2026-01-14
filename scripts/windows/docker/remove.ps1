# =============================================================================
# Remove Script - Terraform Docker Resources (PowerShell)
# =============================================================================
# Supprime les conteneurs et images Docker du workspace Terraform
# Usage: .\remove.ps1 [-All] [-Image] [-Container]
# =============================================================================

param(
    [switch]$All,
    [switch]$Image,
    [switch]$Container,
    [switch]$Help
)

# Configuration
$ImageName = "terraform-azure-workspace"
$ImageTag = "latest"
$ContainerName = "terraform-workspace"

# Fonctions d'affichage
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-OK { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }

# Aide
if ($Help) {
    Write-Host "Usage: .\remove.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -All        Supprimer conteneur et image"
    Write-Host "  -Image      Supprimer uniquement l'image"
    Write-Host "  -Container  Supprimer uniquement le conteneur"
    Write-Host "  -Help       Afficher cette aide"
    Write-Host ""
    Write-Host "Sans option: supprime tout (equivalent a -All)"
    exit 0
}

# Par defaut, supprimer tout
if (-not $All -and -not $Image -and -not $Container) {
    $All = $true
}

Write-Warn "Nettoyage des ressources Docker"
Write-Host ""

# Fonction de suppression du conteneur
function Remove-TerraformContainer {
    # Arreter le conteneur s'il est en cours d'execution
    $runningContainer = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
    if ($runningContainer) {
        Write-Info "Arret du conteneur: $ContainerName"
        docker stop $ContainerName 2>$null | Out-Null
    }
    
    # Supprimer le conteneur
    $existingContainer = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
    if ($existingContainer) {
        Write-Info "Suppression du conteneur: $ContainerName"
        docker rm $ContainerName 2>$null | Out-Null
        Write-OK "Conteneur supprime"
    }
    else {
        Write-Info "Aucun conteneur a supprimer"
    }
}

# Fonction de suppression de l'image
function Remove-TerraformImage {
    $existingImage = docker image inspect "${ImageName}:${ImageTag}" 2>$null
    if ($existingImage) {
        Write-Info "Suppression de l'image: ${ImageName}:${ImageTag}"
        docker rmi "${ImageName}:${ImageTag}" 2>$null | Out-Null
        Write-OK "Image supprimee"
    }
    else {
        Write-Info "Aucune image a supprimer"
    }
    
    # Supprimer aussi l'image de backup si elle existe
    $backupImage = docker image inspect "${ImageName}:backup" 2>$null
    if ($backupImage) {
        Write-Info "Suppression de l'image backup: ${ImageName}:backup"
        docker rmi "${ImageName}:backup" 2>$null | Out-Null
    }
}

# Execution selon les options
if ($All) {
    Remove-TerraformContainer
    Remove-TerraformImage
}
elseif ($Container) {
    Remove-TerraformContainer
}
elseif ($Image) {
    Remove-TerraformContainer  # On doit d'abord supprimer le conteneur pour supprimer l'image
    Remove-TerraformImage
}

Write-Host ""
Write-Success "Nettoyage termine!"
