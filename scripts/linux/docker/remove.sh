#!/bin/bash
# =============================================================================
# Remove Script - Terraform Docker Resources
# =============================================================================
# Supprime les conteneurs et images Docker du workspace Terraform
# Usage: ./remove.sh [--all] [--image] [--container]
# =============================================================================

set -e

# Configuration
IMAGE_NAME="terraform-azure-workspace"
IMAGE_TAG="latest"
CONTAINER_NAME="terraform-workspace"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Arguments
REMOVE_IMAGE=false
REMOVE_CONTAINER=false
REMOVE_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            REMOVE_ALL=true
            shift
            ;;
        --image|-i)
            REMOVE_IMAGE=true
            shift
            ;;
        --container|-c)
            REMOVE_CONTAINER=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -a, --all        Supprimer conteneur et image"
            echo "  -i, --image      Supprimer uniquement l'image"
            echo "  -c, --container  Supprimer uniquement le conteneur"
            echo "  -h, --help       Afficher cette aide"
            echo ""
            echo "Sans option: supprime tout (équivalent à --all)"
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Option inconnue: $1"
            exit 1
            ;;
    esac
done

# Par défaut, supprimer tout
if [ "$REMOVE_ALL" = false ] && [ "$REMOVE_IMAGE" = false ] && [ "$REMOVE_CONTAINER" = false ]; then
    REMOVE_ALL=true
fi

echo -e "${YELLOW}[REMOVE]${NC} Nettoyage des ressources Docker"
echo ""

# Fonction de suppression du conteneur
remove_container() {
    # Arrêter le conteneur s'il est en cours d'exécution
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}[INFO]${NC} Arrêt du conteneur: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME"
    fi
    
    # Supprimer le conteneur
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}[INFO]${NC} Suppression du conteneur: $CONTAINER_NAME"
        docker rm "$CONTAINER_NAME"
        echo -e "${GREEN}[OK]${NC} Conteneur supprimé"
    else
        echo -e "${YELLOW}[INFO]${NC} Aucun conteneur à supprimer"
    fi
}

# Fonction de suppression de l'image
remove_image() {
    if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &> /dev/null; then
        echo -e "${YELLOW}[INFO]${NC} Suppression de l'image: ${IMAGE_NAME}:${IMAGE_TAG}"
        docker rmi "${IMAGE_NAME}:${IMAGE_TAG}"
        echo -e "${GREEN}[OK]${NC} Image supprimée"
    else
        echo -e "${YELLOW}[INFO]${NC} Aucune image à supprimer"
    fi
    
    # Supprimer aussi l'image de backup si elle existe
    if docker image inspect "${IMAGE_NAME}:backup" &> /dev/null; then
        echo -e "${YELLOW}[INFO]${NC} Suppression de l'image backup: ${IMAGE_NAME}:backup"
        docker rmi "${IMAGE_NAME}:backup"
    fi
}

# Exécution selon les options
if [ "$REMOVE_ALL" = true ]; then
    remove_container
    remove_image
elif [ "$REMOVE_CONTAINER" = true ]; then
    remove_container
elif [ "$REMOVE_IMAGE" = true ]; then
    remove_container  # On doit d'abord supprimer le conteneur pour supprimer l'image
    remove_image
fi

echo ""
echo -e "${GREEN}[SUCCESS]${NC} Nettoyage terminé!"
