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
        # Enregistrer les providers Azure après connexion
        register_azure_providers
    else
        echo -e "${RED}[ERROR]${NC} Échec de la connexion Azure"
        exit 1
    fi
}

# Fonction pour enregistrer les providers Azure nécessaires
register_azure_providers() {
    echo ""
    echo -e "${BLUE}[PROVIDERS]${NC} Vérification des providers Azure..."
    
    # Liste des providers nécessaires pour ce projet
    PROVIDERS=("Microsoft.App" "Microsoft.ContainerRegistry" "Microsoft.Storage" "Microsoft.OperationalInsights" "Microsoft.DBforPostgreSQL")
    
    for provider in "${PROVIDERS[@]}"; do
        STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
        
        if [ "$STATE" != "Registered" ]; then
            echo -e "${YELLOW}[REGISTER]${NC} Enregistrement de $provider..."
            az provider register --namespace "$provider" --wait &>/dev/null &
        fi
    done
    
    # Attendre spécifiquement Microsoft.App (le plus critique)
    echo -e "${BLUE}[WAIT]${NC} Attente de Microsoft.App (peut prendre 1-2 min)..."
    for i in {1..30}; do
        STATE=$(az provider show --namespace "Microsoft.App" --query "registrationState" -o tsv 2>/dev/null)
        if [ "$STATE" = "Registered" ]; then
            echo -e "${GREEN}[OK]${NC} Microsoft.App enregistré!"
            break
        fi
        sleep 5
    done
    
    echo -e "${GREEN}[OK]${NC} Providers Azure vérifiés"
}

# Fonction pour initialiser Terraform
init_terraform() {
    if [ -f "main.tf" ]; then
        if [ ! -d ".terraform" ]; then
            echo ""
            echo -e "${BLUE}[TERRAFORM]${NC} Initialisation de Terraform..."
            terraform init
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[OK]${NC} Terraform initialisé!"
            fi
        else
            echo -e "${GREEN}[OK]${NC} Terraform déjà initialisé"
        fi
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
else
    # Si déjà connecté, vérifier les providers
    register_azure_providers
fi

# Initialiser Terraform automatiquement si nécessaire
init_terraform

echo ""
echo -e "${GREEN}[READY]${NC} Workspace Terraform prêt!"
echo ""
echo -e "${BLUE}Commandes utiles:${NC}"
echo "  terraform plan      - Prévisualiser les changements"
echo "  terraform apply     - Appliquer les changements"
echo "  terraform destroy   - Détruire l'infrastructure"
echo "  az login --use-device-code  - Se reconnecter à Azure"
echo ""
echo -e "${BLUE}Appliquer (dev):${NC}"
echo "  terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars"
echo ""
echo "─────────────────────────────────────────────────────────────────────"
echo ""

# Exécution de la commande passée en argument
exec "$@"
