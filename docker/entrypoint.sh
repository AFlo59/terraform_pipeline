#!/bin/bash
# =============================================================================
# Entrypoint Script - Terraform + Azure CLI Container
# =============================================================================
# Ce script initialise l'environnement et vÃ©rifie la connexion Azure
# =============================================================================

# Note: on n'utilise PAS "set -e" car certaines commandes peuvent Ã©chouer
# (ex: az provider register si pas les permissions) sans bloquer le script

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# BanniÃ¨re d'accueil
echo -e "${BLUE}"
echo "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
echo "â•‘           Terraform + Azure CLI Workspace                        â•‘"
echo "â•‘           NYC Taxi Pipeline Infrastructure                       â•‘"
echo "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
echo -e "${NC}"

# CrÃ©ation des rÃ©pertoires nÃ©cessaires
mkdir -p /workspace/logs
mkdir -p /workspace/.azure

# Affichage des versions
echo -e "${GREEN}[INFO]${NC} Versions installÃ©es:"
echo "  - Terraform: $(terraform version -json | jq -r '.terraform_version')"
echo "  - Azure CLI: $(az version -o tsv --query '"azure-cli"')"
echo ""

# VÃ©rification de la connexion Azure
check_azure_login() {
    if az account show &> /dev/null; then
        ACCOUNT_NAME=$(az account show --query "name" -o tsv)
        SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
        echo -e "${GREEN}[OK]${NC} ConnectÃ© Ã  Azure"
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
    echo -e "${BLUE}Utilisez la mÃ©thode device-code pour vous connecter:${NC}"
    echo ""
    
    if az login --use-device-code; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Connexion rÃ©ussie!"
        check_azure_login
        # Enregistrer les providers Azure aprÃ¨s connexion
        register_azure_providers
    else
        echo -e "${RED}[ERROR]${NC} Ã‰chec de la connexion Azure"
        echo -e "${YELLOW}[INFO]${NC} Vous pouvez rÃ©essayer avec: az login --use-device-code"
        # Ne pas exit, continuer pour permettre l'utilisation du shell
    fi
}

# Fonction pour enregistrer les providers Azure nÃ©cessaires
register_azure_providers() {
    echo ""
    echo -e "${BLUE}[PROVIDERS]${NC} VÃ©rification des providers Azure..."
    
    # Liste des providers nÃ©cessaires pour ce projet
    PROVIDERS=("Microsoft.App" "Microsoft.ContainerRegistry" "Microsoft.Storage" "Microsoft.OperationalInsights" "Microsoft.DBforPostgreSQL")
    
    # Array pour tracker les providers en attente
    declare -a PENDING_PROVIDERS=()
    
    # PremiÃ¨re passe : vÃ©rifier et lancer l'enregistrement si nÃ©cessaire
    for provider in "${PROVIDERS[@]}"; do
        STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
        
        if [ "$STATE" = "Registered" ]; then
            echo -e "  ${GREEN}âœ“${NC} $provider"
        elif [ "$STATE" = "Registering" ]; then
            echo -e "  ${YELLOW}â³${NC} $provider (en cours...)"
            PENDING_PROVIDERS+=("$provider")
        else
            echo -e "  ${YELLOW}â†’${NC} $provider (enregistrement...)"
            # || true pour ne pas bloquer si pas les permissions
            az provider register --namespace "$provider" &>/dev/null || true
            PENDING_PROVIDERS+=("$provider")
        fi
    done
    
    # Si des providers sont en attente, attendre qu'ils soient tous prÃªts
    if [ ${#PENDING_PROVIDERS[@]} -gt 0 ]; then
        echo ""
        echo -e "${BLUE}[INFO]${NC} ${#PENDING_PROVIDERS[@]} provider(s) en cours d'enregistrement..."
        echo -e "${BLUE}[INFO]${NC} Attente automatique (max 3 min)..."
        echo ""
        
        # Attendre jusqu'Ã  3 minutes (36 x 5s)
        MAX_ATTEMPTS=36
        ATTEMPT=0
        
        while [ ${#PENDING_PROVIDERS[@]} -gt 0 ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            ATTEMPT=$((ATTEMPT + 1))
            ELAPSED=$((ATTEMPT * 5))
            
            # VÃ©rifier chaque provider en attente
            STILL_PENDING=()
            for provider in "${PENDING_PROVIDERS[@]}"; do
                STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
                if [ "$STATE" = "Registered" ]; then
                    echo -e "  ${GREEN}âœ“${NC} $provider ${GREEN}(prÃªt aprÃ¨s ${ELAPSED}s)${NC}"
                else
                    STILL_PENDING+=("$provider")
                fi
            done
            
            PENDING_PROVIDERS=("${STILL_PENDING[@]}")
            
            # Si tous sont prÃªts, sortir
            if [ ${#PENDING_PROVIDERS[@]} -eq 0 ]; then
                break
            fi
            
            # Afficher progression
            echo -ne "\r  ${YELLOW}â³${NC} Attente: ${ELAPSED}s / 180s - En attente: ${PENDING_PROVIDERS[*]}   "
            sleep 5
        done
        
        echo ""
        
        # VÃ©rification finale
        if [ ${#PENDING_PROVIDERS[@]} -gt 0 ]; then
            echo -e "${YELLOW}[WARNING]${NC} Providers encore en attente aprÃ¨s 3 min:"
            for provider in "${PENDING_PROVIDERS[@]}"; do
                STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
                echo -e "  ${YELLOW}â³${NC} $provider ($STATE)"
            done
            echo ""
            echo -e "${YELLOW}[INFO]${NC} L'enregistrement continue en arriÃ¨re-plan."
            echo -e "${YELLOW}[INFO]${NC} Attendez 1-2 min avant terraform apply, ou rÃ©essayez si erreur."
        else
            echo -e "${GREEN}[OK]${NC} Tous les providers sont enregistrÃ©s!"
        fi
    else
        echo -e "${GREEN}[OK]${NC} Tous les providers sont dÃ©jÃ  enregistrÃ©s!"
    fi
}

# Fonction pour initialiser Terraform
init_terraform() {
    if [ -f "main.tf" ]; then
        if [ ! -d ".terraform" ]; then
            echo ""
            echo -e "${BLUE}[TERRAFORM]${NC} Initialisation de Terraform..."
            if terraform init; then
                echo -e "${GREEN}[OK]${NC} Terraform initialisÃ©!"
            else
                echo -e "${YELLOW}[WARNING]${NC} Terraform init a rencontrÃ© des erreurs"
                echo -e "${YELLOW}[INFO]${NC} Vous pouvez rÃ©essayer manuellement: terraform init"
            fi
        else
            echo -e "${GREEN}[OK]${NC} Terraform dÃ©jÃ  initialisÃ©"
        fi
    fi
}

# VÃ©rification initiale de la connexion
if ! check_azure_login; then
    echo -e "${YELLOW}[INFO]${NC} Vous n'Ãªtes pas connectÃ© Ã  Azure"
    echo ""
    read -p "Voulez-vous vous connecter maintenant? (o/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        azure_login
    else
        echo -e "${YELLOW}[WARNING]${NC} Certaines commandes Terraform nÃ©cessitent une connexion Azure"
    fi
else
    # Si dÃ©jÃ  connectÃ©, vÃ©rifier les providers
    register_azure_providers
fi

# Initialiser Terraform automatiquement si nÃ©cessaire
init_terraform

# =============================================================================
# CrÃ©ation des commandes simplifiÃ©es (disponibles dans le shell)
# =============================================================================

# CrÃ©er le fichier de fonctions bash ET l'ajouter au .bashrc
cat > /root/.terraform-helpers.sh << 'HELPERS_EOF'
#!/bin/bash
# Commandes simplifiÃ©es pour Terraform

# Couleurs
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_NC='\033[0m'

# Fonction plan
plan() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: plan [dev|rec|prod]"
        return 1
    fi
    echo -e "${_BLUE}[PLAN]${_NC} Environnement: ${_GREEN}$env${_NC}"
    terraform plan -var-file="environments/${env}.tfvars" -var-file="environments/secrets.tfvars"
}

# Fonction apply (avec gÃ©nÃ©ration .env automatique)
apply() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: apply [dev|rec|prod]"
        return 1
    fi
    echo -e "${_GREEN}[APPLY]${_NC} Environnement: ${_GREEN}$env${_NC}"
    
    if terraform apply -var-file="environments/${env}.tfvars" -var-file="environments/secrets.tfvars"; then
        echo ""
        echo -e "${_BLUE}[GENERATE]${_NC} GÃ©nÃ©ration du fichier .env..."
        if [ -f "./scripts/generate-env.sh" ]; then
            ./scripts/generate-env.sh "$env"
        else
            echo -e "${_YELLOW}[WARNING]${_NC} Script generate-env.sh non trouvÃ©"
        fi
    fi
}

# Fonction destroy (avec suppression .env automatique)
destroy() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: destroy [dev|rec|prod]"
        return 1
    fi
    echo -e "${_RED}[DESTROY]${_NC} Environnement: ${_YELLOW}$env${_NC}"
    
    if terraform destroy -var-file="environments/${env}.tfvars" -var-file="environments/secrets.tfvars"; then
        # Supprimer le fichier .env correspondant
        local env_file="/workspace/shared/.env.${env}"
        if [ -f "$env_file" ]; then
            echo -e "${_YELLOW}[CLEANUP]${_NC} Suppression de $env_file..."
            rm -f "$env_file"
            echo -e "${_GREEN}[OK]${_NC} Fichier .env supprimÃ©"
        fi
    fi
}

# Fonction output
output() {
    terraform output "$@"
}

# Fonction pour rÃ©gÃ©nÃ©rer le .env sans redÃ©ployer
genenv() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: genenv [dev|rec|prod]"
        return 1
    fi
    if [ -f "./scripts/generate-env.sh" ]; then
        ./scripts/generate-env.sh "$env"
    else
        echo -e "${_RED}[ERROR]${_NC} Script generate-env.sh non trouvÃ©"
    fi
}

# Fonction help
tfhelp() {
    echo ""
    echo -e "${_BLUE}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${_NC}"
    echo -e "${_BLUE}                    COMMANDES DISPONIBLES                           ${_NC}"
    echo -e "${_BLUE}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${_NC}"
    echo ""
    echo -e "${_GREEN}Commandes simplifiÃ©es:${_NC}"
    echo "  plan [env]     - PrÃ©visualiser (dÃ©faut: dev)"
    echo "  apply [env]    - DÃ©ployer + gÃ©nÃ©rer .env (dÃ©faut: dev)"
    echo "  destroy [env]  - DÃ©truire + supprimer .env (dÃ©faut: dev)"
    echo "  output         - Voir les outputs Terraform"
    echo "  genenv [env]   - RÃ©gÃ©nÃ©rer le .env sans redÃ©ployer"
    echo "  tfhelp         - Afficher cette aide"
    echo ""
    echo -e "${_YELLOW}Environnements:${_NC} dev, rec, prod"
    echo ""
    echo -e "${_BLUE}Exemples:${_NC}"
    echo "  plan dev       - PrÃ©visualiser l'environnement dev"
    echo "  apply dev      - DÃ©ployer dev + gÃ©nÃ©rer shared/.env.dev"
    echo "  destroy prod   - DÃ©truire prod + supprimer shared/.env.prod"
    echo ""
    echo -e "${_BLUE}Autres commandes:${_NC}"
    echo "  az login --use-device-code  - Se reconnecter Ã  Azure"
    echo "  terraform [cmd]             - Commandes Terraform directes"
    echo -e "  ${_RED}exit${_NC}                        - Quitter le workspace"
    echo ""
    echo -e "${_BLUE}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${_NC}"
}
HELPERS_EOF

# Ajouter au .bashrc pour que les fonctions soient disponibles dans le shell interactif
if ! grep -q "terraform-helpers" /root/.bashrc 2>/dev/null; then
    echo "" >> /root/.bashrc
    echo "# Terraform helper functions" >> /root/.bashrc
    echo "source /root/.terraform-helpers.sh" >> /root/.bashrc
fi

# Sourcer les fonctions pour la session actuelle
source /root/.terraform-helpers.sh

echo ""
echo -e "${GREEN}[READY]${NC} Workspace Terraform prÃªt!"
echo ""

# Afficher l'aide automatiquement
tfhelp

# ExÃ©cution de la commande passÃ©e en argument
exec "$@"
