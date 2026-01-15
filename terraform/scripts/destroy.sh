#!/bin/bash
# =============================================================================
# Terraform Destroy Wrapper - Destroy + Remove .env
# =============================================================================
# Usage: ./scripts/destroy.sh <environment>
# Example: ./scripts/destroy.sh dev
# =============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Vérifier l'argument
if [ -z "$1" ]; then
    echo -e "${RED}[ERROR]${NC} Environnement requis!"
    echo ""
    echo "Usage: $0 <environment>"
    echo ""
    echo "Environnements disponibles:"
    echo -e "  ${GREEN}dev${NC}   - Développement"
    echo -e "  ${YELLOW}rec${NC}   - Recette"
    echo -e "  ${RED}prod${NC}  - Production"
    echo ""
    exit 1
fi

ENV=$1
SHARED_DIR="/workspace/shared"
ENV_FILE="${SHARED_DIR}/.env.${ENV}"
TFVARS_FILE="environments/${ENV}.tfvars"
SECRETS_FILE="environments/secrets.tfvars"

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         Terraform Destroy - Environment: ${ENV}                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Vérifier que les fichiers tfvars existent
if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouvé: $TFVARS_FILE"
    exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouvé: $SECRETS_FILE"
    exit 1
fi

# Avertissement
echo -e "${RED}⚠️  ATTENTION ⚠️${NC}"
echo ""
echo "Cette action va SUPPRIMER toutes les ressources Azure de l'environnement ${ENV}:"
echo "  - Storage Account et ses données"
echo "  - Container Registry et ses images"
echo "  - Base de données PostgreSQL et ses données"
echo "  - Container App"
echo "  - Log Analytics"
echo ""
echo -e "${YELLOW}Cette action est IRRÉVERSIBLE !${NC}"
echo ""

# Demander confirmation
read -p "Êtes-vous sûr de vouloir continuer? (tapez 'yes' pour confirmer): " confirm

if [ "$confirm" != "yes" ]; then
    echo ""
    echo -e "${YELLOW}[CANCEL]${NC} Opération annulée"
    exit 0
fi

echo ""
echo -e "${RED}[DESTROY]${NC} Exécution de terraform destroy..."
echo ""

if terraform destroy -var-file="$TFVARS_FILE" -var-file="$SECRETS_FILE"; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Terraform destroy terminé avec succès!"
    
    # Supprimer le fichier .env
    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}[CLEANUP]${NC} Suppression de ${ENV_FILE}..."
        rm -f "$ENV_FILE"
        echo -e "${GREEN}[OK]${NC} Fichier .env supprimé"
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    DESTRUCTION TERMINÉE                             ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Toutes les ressources Azure de l'environnement ${ENV} ont été supprimées."
    echo ""
else
    echo ""
    echo -e "${RED}[ERROR]${NC} Terraform destroy a échoué!"
    echo -e "${YELLOW}[INFO]${NC} Certaines ressources peuvent encore exister"
    echo -e "${YELLOW}[INFO]${NC} Vérifiez dans le portail Azure"
    exit 1
fi
