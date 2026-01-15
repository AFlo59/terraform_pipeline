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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS_FILE="environments/${ENV}.tfvars"
SECRETS_FILE="environments/secrets.tfvars"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         Terraform Apply - Environment: ${ENV}                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Vérifier que les fichiers tfvars existent
if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouvé: $TFVARS_FILE"
    exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouvé: $SECRETS_FILE"
    echo -e "${YELLOW}[INFO]${NC} Créez-le à partir de secrets.tfvars.example"
    exit 1
fi

# Exécuter terraform apply
echo -e "${GREEN}[APPLY]${NC} Exécution de terraform apply..."
echo ""

if terraform apply -var-file="$TFVARS_FILE" -var-file="$SECRETS_FILE"; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Terraform apply terminé avec succès!"
    echo ""
    
    # Générer le fichier .env
    echo -e "${BLUE}[GENERATE]${NC} Génération du fichier .env..."
    "$SCRIPT_DIR/generate-env.sh" "$ENV"
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    DÉPLOIEMENT TERMINÉ                              ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Fichier .env généré: ${BLUE}/workspace/shared/.env.${ENV}${NC}"
    echo ""
    echo -e "Prochaines étapes:"
    echo "  1. Le data_pipeline peut maintenant utiliser les ressources Azure"
    echo "  2. Lancez le pipeline avec: docker-compose up"
    echo ""
else
    echo ""
    echo -e "${RED}[ERROR]${NC} Terraform apply a échoué!"
    echo -e "${YELLOW}[INFO]${NC} Vérifiez les erreurs ci-dessus"
    exit 1
fi
