#!/bin/bash
# =============================================================================
# Update Script - Terraform Docker Image
# =============================================================================
# Met à jour l'image Docker en la reconstruisant sans cache
# Usage: ./update.sh
# =============================================================================

set -e

# Configuration
IMAGE_NAME="terraform-azure-workspace"
IMAGE_TAG="latest"
CONTAINER_NAME="terraform-workspace"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[UPDATE]${NC} Mise à jour de l'image Terraform"
echo ""

# Arrêter le conteneur existant si en cours d'exécution
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}[INFO]${NC} Arrêt du conteneur en cours d'exécution..."
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
fi

# Sauvegarde de l'ancienne image (tag)
if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &> /dev/null; then
    echo -e "${YELLOW}[INFO]${NC} Sauvegarde de l'ancienne image..."
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:backup" 2>/dev/null || true
fi

# Reconstruction de l'image
echo -e "${GREEN}[BUILD]${NC} Reconstruction de l'image sans cache..."
"$SCRIPT_DIR/build.sh" --no-cache

if [ $? -eq 0 ]; then
    # Suppression de l'image de backup
    if docker image inspect "${IMAGE_NAME}:backup" &> /dev/null; then
        echo -e "${YELLOW}[CLEANUP]${NC} Suppression de l'ancienne image..."
        docker rmi "${IMAGE_NAME}:backup" 2>/dev/null || true
    fi
    
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Image mise à jour avec succès!"
else
    # Restauration de l'image de backup en cas d'échec
    if docker image inspect "${IMAGE_NAME}:backup" &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} Échec de la mise à jour. Restauration de l'ancienne image..."
        docker tag "${IMAGE_NAME}:backup" "${IMAGE_NAME}:${IMAGE_TAG}"
    fi
    exit 1
fi
