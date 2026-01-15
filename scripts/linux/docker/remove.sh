#!/bin/bash
# =============================================================================
# Remove Script - Terraform Docker Resources
# =============================================================================
# Supprime les conteneurs, images et volumes Docker du workspace Terraform
# Usage: ./remove.sh [--all | --container | --image | --volumes | --prune]
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
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Fonctions utilitaires
# =============================================================================

# Vérifier si Docker tourne
check_docker() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker n'est pas en cours d'exécution!"
        echo -e "${YELLOW}[INFO]${NC} Lancez Docker Desktop et réessayez."
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} Docker est en cours d'exécution"
}

# Afficher l'état actuel
show_status() {
    echo ""
    echo -e "${CYAN}État actuel:${NC}"
    
    # Conteneur
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "  ${GREEN}●${NC} Conteneur: ${CONTAINER_NAME} (en cours d'exécution)"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "  ${YELLOW}●${NC} Conteneur: ${CONTAINER_NAME} (arrêté)"
    else
        echo -e "  ${RED}○${NC} Conteneur: ${CONTAINER_NAME} (n'existe pas)"
    fi
    
    # Image
    if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null; then
        local size=$(docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Size}}' | awk '{printf "%.1f MB", $1/1024/1024}')
        echo -e "  ${GREEN}●${NC} Image: ${IMAGE_NAME}:${IMAGE_TAG} ($size)"
    else
        echo -e "  ${RED}○${NC} Image: ${IMAGE_NAME}:${IMAGE_TAG} (n'existe pas)"
    fi
    
    # Image backup
    if docker image inspect "${IMAGE_NAME}:backup" &>/dev/null; then
        echo -e "  ${YELLOW}●${NC} Image backup: ${IMAGE_NAME}:backup (existe)"
    fi
    
    # Volumes dangling
    local dangling=$(docker volume ls -qf dangling=true | wc -l)
    if [ "$dangling" -gt 0 ]; then
        echo -e "  ${YELLOW}●${NC} Volumes orphelins: $dangling"
    fi
    
    # Images dangling
    local dangling_images=$(docker images -qf dangling=true | wc -l)
    if [ "$dangling_images" -gt 0 ]; then
        echo -e "  ${YELLOW}●${NC} Images orphelines: $dangling_images"
    fi
    
    echo ""
}

# Afficher le menu
show_menu() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║         Nettoyage - Terraform Azure Workspace                    ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}Que voulez-vous supprimer ?${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Conteneur uniquement (garde l'image pour rebuild rapide)"
    echo -e "  ${YELLOW}2)${NC} Conteneur + Image (nettoyage complet du projet)"
    echo -e "  ${RED}3)${NC} TOUT + Prune (conteneur, image, volumes orphelins, cache)"
    echo ""
    echo -e "  ${CYAN}4)${NC} Supprimer uniquement les volumes orphelins"
    echo -e "  ${CYAN}5)${NC} Supprimer uniquement les images orphelines (dangling)"
    echo ""
    echo -e "  ${RED}q)${NC} Quitter sans rien faire"
    echo ""
}

# Supprimer le conteneur
remove_container() {
    echo ""
    # Arrêter si en cours
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}[STOP]${NC} Arrêt du conteneur: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" &>/dev/null
    fi
    
    # Supprimer
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}[REMOVE]${NC} Suppression du conteneur: $CONTAINER_NAME"
        docker rm "$CONTAINER_NAME" &>/dev/null
        echo -e "${GREEN}[OK]${NC} Conteneur supprimé"
    else
        echo -e "${CYAN}[INFO]${NC} Aucun conteneur à supprimer"
    fi
}

# Supprimer l'image
remove_image() {
    # Image principale
    if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null; then
        echo -e "${YELLOW}[REMOVE]${NC} Suppression de l'image: ${IMAGE_NAME}:${IMAGE_TAG}"
        docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null
        echo -e "${GREEN}[OK]${NC} Image supprimée"
    else
        echo -e "${CYAN}[INFO]${NC} Image principale n'existe pas"
    fi
    
    # Image backup
    if docker image inspect "${IMAGE_NAME}:backup" &>/dev/null; then
        echo -e "${YELLOW}[REMOVE]${NC} Suppression de l'image backup"
        docker rmi "${IMAGE_NAME}:backup" &>/dev/null
        echo -e "${GREEN}[OK]${NC} Image backup supprimée"
    fi
}

# Supprimer les volumes orphelins
remove_dangling_volumes() {
    local volumes=$(docker volume ls -qf dangling=true)
    if [ -n "$volumes" ]; then
        echo -e "${YELLOW}[REMOVE]${NC} Suppression des volumes orphelins..."
        docker volume prune -f &>/dev/null
        echo -e "${GREEN}[OK]${NC} Volumes orphelins supprimés"
    else
        echo -e "${CYAN}[INFO]${NC} Aucun volume orphelin"
    fi
}

# Supprimer les images orphelines
remove_dangling_images() {
    local images=$(docker images -qf dangling=true)
    if [ -n "$images" ]; then
        echo -e "${YELLOW}[REMOVE]${NC} Suppression des images orphelines..."
        docker image prune -f &>/dev/null
        echo -e "${GREEN}[OK]${NC} Images orphelines supprimées"
    else
        echo -e "${CYAN}[INFO]${NC} Aucune image orpheline"
    fi
}

# Nettoyage complet (prune)
full_prune() {
    echo ""
    echo -e "${RED}[PRUNE]${NC} Nettoyage complet Docker..."
    docker system prune -f &>/dev/null
    echo -e "${GREEN}[OK]${NC} Cache Docker nettoyé"
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# 1. Vérifier Docker
check_docker

# 2. Traitement des arguments CLI
case "$1" in
    --all|-a)
        show_status
        remove_container
        remove_image
        remove_dangling_volumes
        remove_dangling_images
        echo -e "\n${GREEN}[SUCCESS]${NC} Nettoyage complet terminé!"
        exit 0
        ;;
    --container|-c)
        remove_container
        echo -e "\n${GREEN}[SUCCESS]${NC} Conteneur supprimé!"
        exit 0
        ;;
    --image|-i)
        remove_container
        remove_image
        echo -e "\n${GREEN}[SUCCESS]${NC} Image supprimée!"
        exit 0
        ;;
    --volumes|-v)
        remove_dangling_volumes
        echo -e "\n${GREEN}[SUCCESS]${NC} Volumes nettoyés!"
        exit 0
        ;;
    --prune|-p)
        remove_container
        remove_image
        full_prune
        echo -e "\n${GREEN}[SUCCESS]${NC} Prune complet terminé!"
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  -c, --container  Supprimer uniquement le conteneur"
        echo "  -i, --image      Supprimer conteneur + image"
        echo "  -v, --volumes    Supprimer les volumes orphelins"
        echo "  -a, --all        Supprimer tout (conteneur, image, volumes)"
        echo "  -p, --prune      Supprimer tout + prune Docker"
        echo "  -h, --help       Afficher cette aide"
        echo ""
        echo "Sans option: menu interactif"
        exit 0
        ;;
esac

# 3. Mode interactif
show_status
show_menu

read -p "Votre choix [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        remove_container
        echo -e "\n${GREEN}[SUCCESS]${NC} Conteneur supprimé! L'image est conservée pour un rebuild rapide."
        ;;
    2)
        remove_container
        remove_image
        echo -e "\n${GREEN}[SUCCESS]${NC} Conteneur et image supprimés!"
        ;;
    3)
        echo -e "\n${RED}[WARNING]${NC} Ceci va supprimer le conteneur, l'image ET nettoyer le cache Docker."
        read -p "Confirmer? (o/n) [n]: " confirm
        if [[ "$confirm" =~ ^[Oo]$ ]]; then
            remove_container
            remove_image
            remove_dangling_volumes
            remove_dangling_images
            full_prune
            echo -e "\n${GREEN}[SUCCESS]${NC} Nettoyage complet terminé!"
        else
            echo -e "${YELLOW}[CANCEL]${NC} Opération annulée"
        fi
        ;;
    4)
        remove_dangling_volumes
        echo -e "\n${GREEN}[SUCCESS]${NC} Volumes orphelins supprimés!"
        ;;
    5)
        remove_dangling_images
        echo -e "\n${GREEN}[SUCCESS]${NC} Images orphelines supprimées!"
        ;;
    q|Q)
        echo -e "${CYAN}[INFO]${NC} Aucune action effectuée"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Choix invalide"
        exit 1
        ;;
esac
