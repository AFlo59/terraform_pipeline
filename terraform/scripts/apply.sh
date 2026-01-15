#!/bin/bash
# =============================================================================
# Terraform Apply Wrapper - Apply + Generate .env
# =============================================================================
# Usage: ./scripts/apply.sh <environment>
# Example: ./scripts/apply.sh dev
# =============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# VÃ©rifier l'argument
if [ -z "$1" ]; then
    echo -e "${RED}[ERROR]${NC} Environnement requis!"
    echo ""
    echo "Usage: $0 <environment>"
    echo ""
    echo "Environnements disponibles:"
    echo -e "  ${GREEN}dev${NC}   - DÃ©veloppement"
    echo -e "  ${YELLOW}rec${NC}   - Recette"
    echo -e "  ${RED}prod${NC}  - Production"
    echo ""
    exit 1
fi

ENV=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS_FILE="environments/${ENV}.tfvars"
SECRETS_FILE="environments/secrets.tfvars"

echo -e "${BLUE}"
echo "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
echo "â•‘         Terraform Apply - Environment: ${ENV}                    â•‘"
echo "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
echo -e "${NC}"

# VÃ©rifier que les fichiers tfvars existent
if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouvÃ©: $TFVARS_FILE"
    exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouvÃ©: $SECRETS_FILE"
    echo -e "${YELLOW}[INFO]${NC} CrÃ©ez-le Ã  partir de secrets.tfvars.example"
    exit 1
fi

# ExÃ©cuter terraform apply
echo -e "${GREEN}[APPLY]${NC} ExÃ©cution de terraform apply..."
echo ""

if terraform apply -var-file="$TFVARS_FILE" -var-file="$SECRETS_FILE"; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Terraform apply terminÃ© avec succÃ¨s!"
    echo ""
    
    # GÃ©nÃ©rer le fichier .env
    echo -e "${BLUE}[GENERATE]${NC} GÃ©nÃ©ration du fichier .env..."
    "$SCRIPT_DIR/generate-env.sh" "$ENV"
    
    echo ""
    echo -e "${GREEN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo -e "${GREEN}                    DÃ‰PLOIEMENT TERMINÃ‰                              ${NC}"
    echo -e "${GREEN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo ""
    echo -e "Fichier .env gÃ©nÃ©rÃ©: ${BLUE}/workspace/shared/.env.${ENV}${NC}"
    echo ""
    echo -e "Prochaines Ã©tapes:"
    echo "  1. Le data_pipeline peut maintenant utiliser les ressources Azure"
    echo "  2. Lancez le pipeline avec: docker-compose up"
    echo ""
else
    echo ""
    echo -e "${RED}[ERROR]${NC} Terraform apply a Ã©chouÃ©!"
    echo -e "${YELLOW}[INFO]${NC} VÃ©rifiez les erreurs ci-dessus"
    exit 1
fi
