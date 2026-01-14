#!/bin/bash
# =============================================================================
# Entrypoint Script - Terraform + Azure CLI Container
# =============================================================================
# Ce script initialise l'environnement et vérifie la connexion Azure
# =============================================================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Bannière d'accueil
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           Terraform + Azure CLI Workspace                        ║"
echo "║           NYC Taxi Pipeline Infrastructure                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Création des répertoires nécessaires
mkdir -p /workspace/logs
mkdir -p /workspace/.azure

# Affichage des versions
echo -e "${GREEN}[INFO]${NC} Versions installées:"
echo "  - Terraform: $(terraform version -json | jq -r '.terraform_version')"
echo "  - Azure CLI: $(az version -o tsv --query '"azure-cli"')"
echo ""

# Vérification de la connexion Azure
check_azure_login() {
    if az account show &> /dev/null; then
        ACCOUNT_NAME=$(az account show --query "name" -o tsv)
        SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
        echo -e "${GREEN}[OK]${NC} Connecté à Azure"
        echo "  - Subscription: $ACCOUNT_NAME"
        echo "  - ID: $SUBSCRIPTION_ID"
        return 0
    else
        return 1
    fi
}

# Fonction de login via device code
azure_login() {
    echo -e "${YELLOW}[ACTION]${NC} Connexion Azure requise"
    echo ""
    echo -e "${BLUE}Utilisez la méthode device-code pour vous connecter:${NC}"
    echo ""
    az login --use-device-code
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Connexion réussie!"
        check_azure_login
    else
        echo -e "${RED}[ERROR]${NC} Échec de la connexion Azure"
        exit 1
    fi
}

# Vérification initiale de la connexion
if ! check_azure_login; then
    echo -e "${YELLOW}[INFO]${NC} Vous n'êtes pas connecté à Azure"
    echo ""
    read -p "Voulez-vous vous connecter maintenant? (o/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        azure_login
    else
        echo -e "${YELLOW}[WARNING]${NC} Certaines commandes Terraform nécessitent une connexion Azure"
    fi
fi

echo ""
echo -e "${GREEN}[READY]${NC} Workspace Terraform prêt!"
echo ""
echo -e "${BLUE}Commandes utiles:${NC}"
echo "  terraform init      - Initialiser le projet"
echo "  terraform plan      - Prévisualiser les changements"
echo "  terraform apply     - Appliquer les changements"
echo "  terraform destroy   - Détruire l'infrastructure"
echo "  az login --use-device-code  - Se reconnecter à Azure"
echo ""
echo "─────────────────────────────────────────────────────────────────────"
echo ""

# Exécution de la commande passée en argument
exec "$@"
