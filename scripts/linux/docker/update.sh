#!/bin/bash
# =============================================================================
# Update Script - Terraform Docker Image
# =============================================================================
# Met à jour l'image Docker avec plusieurs options
# Usage: ./update.sh [--quick | --full | --pull | --auto]
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
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Fonctions utilitaires
# =============================================================================

check_docker() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker n'est pas en cours d'exécution!"
        echo -e "${YELLOW}[INFO]${NC} Lancez Docker Desktop et réessayez."
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} Docker est en cours d'exécution"
}

show_current_status() {
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
        local created=$(docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Created}}' | cut -d'T' -f1)
        echo -e "  ${GREEN}●${NC} Image: ${IMAGE_NAME}:${IMAGE_TAG}"
        echo -e "      Taille: $size"
        echo -e "      Créée le: $created"
    else
        echo -e "  ${RED}○${NC} Image: ${IMAGE_NAME}:${IMAGE_TAG} (n'existe pas)"
    fi
    
    # Image de base
    if docker image inspect "hashicorp/terraform:1.7.0" &>/dev/null; then
        echo -e "  ${GREEN}●${NC} Image de base: hashicorp/terraform:1.7.0 (présente)"
    else
        echo -e "  ${YELLOW}○${NC} Image de base: hashicorp/terraform:1.7.0 (à télécharger)"
    fi
    
    echo ""
}

show_menu() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║         Mise à jour - Terraform Azure Workspace                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}Choisissez le type de mise à jour:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Mise à jour rapide (avec cache Docker)"
    echo -e "     → Rapide si seuls quelques fichiers ont changé"
    echo ""
    echo -e "  ${YELLOW}2)${NC} Mise à jour complète (sans cache)"
    echo -e "     → Reconstruit tout depuis zéro"
    echo ""
    echo -e "  ${BLUE}3)${NC} Mise à jour + Pull images de base"
    echo -e "     → Télécharge les dernières versions des images de base"
    echo ""
    echo -e "  ${CYAN}4)${NC} Mise à jour + Lancer le conteneur"
    echo -e "     → Met à jour puis démarre automatiquement"
    echo ""
    echo -e "  ${RED}q)${NC} Quitter"
    echo ""
}

stop_container() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}[STOP]${NC} Arrêt du conteneur en cours..."
        docker stop "$CONTAINER_NAME" &>/dev/null
    fi
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}[REMOVE]${NC} Suppression du conteneur..."
        docker rm "$CONTAINER_NAME" &>/dev/null
    fi
}

backup_image() {
    if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null; then
        echo -e "${CYAN}[BACKUP]${NC} Sauvegarde de l'image actuelle..."
        docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:backup" 2>/dev/null || true
    fi
}

cleanup_backup() {
    if docker image inspect "${IMAGE_NAME}:backup" &>/dev/null; then
        echo -e "${CYAN}[CLEANUP]${NC} Suppression de l'ancienne image..."
        docker rmi "${IMAGE_NAME}:backup" &>/dev/null || true
    fi
}

restore_backup() {
    if docker image inspect "${IMAGE_NAME}:backup" &>/dev/null; then
        echo -e "${RED}[RESTORE]${NC} Restauration de l'ancienne image..."
        docker tag "${IMAGE_NAME}:backup" "${IMAGE_NAME}:${IMAGE_TAG}"
        echo -e "${GREEN}[OK]${NC} Ancienne image restaurée"
    fi
}

do_update() {
    local build_option="$1"
    local start_after="$2"
    
    echo ""
    stop_container
    backup_image
    
    echo -e "${GREEN}[BUILD]${NC} Reconstruction de l'image..."
    echo ""
    
    if "$SCRIPT_DIR/build.sh" $build_option; then
        cleanup_backup
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Image mise à jour avec succès!"
        
        if [ "$start_after" = "true" ]; then
            echo ""
            echo -e "${CYAN}[START]${NC} Démarrage du conteneur..."
            "$SCRIPT_DIR/run.sh"
        else
            echo ""
            echo -e "${CYAN}Prochaine étape:${NC}"
            echo "  ./scripts/linux/docker/run.sh"
        fi
    else
        echo ""
        echo -e "${RED}[ERROR]${NC} Échec de la mise à jour!"
        restore_backup
        exit 1
    fi
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# 1. Vérifier Docker
check_docker

# 2. Traitement des arguments CLI
case "$1" in
    --quick|-q)
        show_current_status
        do_update "--auto" "false"
        exit 0
        ;;
    --full|-f)
        show_current_status
        do_update "--no-cache" "false"
        exit 0
        ;;
    --pull|-p)
        show_current_status
        do_update "--pull" "false"
        exit 0
        ;;
    --auto|-a)
        show_current_status
        do_update "--auto" "true"
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  -q, --quick  Mise à jour rapide (avec cache)"
        echo "  -f, --full   Mise à jour complète (sans cache)"
        echo "  -p, --pull   Mise à jour + pull images de base"
        echo "  -a, --auto   Mise à jour + lancer conteneur"
        echo "  -h, --help   Afficher cette aide"
        echo ""
        echo "Sans option: menu interactif"
        exit 0
        ;;
esac

# 3. Mode interactif
show_current_status
show_menu

read -p "Votre choix [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        do_update "--auto" "false"
        ;;
    2)
        do_update "--no-cache" "false"
        ;;
    3)
        do_update "--pull" "false"
        ;;
    4)
        do_update "--auto" "true"
        ;;
    q|Q)
        echo -e "${CYAN}[INFO]${NC} Mise à jour annulée"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Choix invalide"
        exit 1
        ;;
esac
