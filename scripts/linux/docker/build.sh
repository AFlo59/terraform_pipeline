#!/bin/bash
# =============================================================================
# Build Script - Terraform Docker Image
# =============================================================================
# Construit l'image Docker pour le workspace Terraform
# Usage: ./build.sh [--no-cache]
# =============================================================================

set -e

# Configuration
IMAGE_NAME="terraform-azure-workspace"
IMAGE_TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
DOCKER_DIR="$PROJECT_ROOT/docker"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[BUILD]${NC} Construction de l'image Docker: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Options de build
BUILD_OPTS=""
if [[ "$1" == "--no-cache" ]]; then
    BUILD_OPTS="--no-cache"
    echo -e "${YELLOW}[INFO]${NC} Mode sans cache activé"
fi

# Vérification du Dockerfile
if [ ! -f "$DOCKER_DIR/Dockerfile" ]; then
    echo -e "${RED}[ERROR]${NC} Dockerfile non trouvé: $DOCKER_DIR/Dockerfile"
    exit 1
fi

# Construction de l'image
echo -e "${GREEN}[INFO]${NC} Contexte de build: $DOCKER_DIR"
docker build $BUILD_OPTS \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f "$DOCKER_DIR/Dockerfile" \
    "$DOCKER_DIR"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Image construite avec succès!"
    echo ""
    echo "Pour démarrer le workspace, exécutez:"
    echo "  ./scripts/linux/docker/run.sh"
else
    echo -e "${RED}[ERROR]${NC} Échec de la construction de l'image"
    exit 1
fi
