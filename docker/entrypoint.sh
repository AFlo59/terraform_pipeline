#!/bin/bash
# =============================================================================
# Entrypoint Script - Terraform + Azure CLI Container
# =============================================================================
# Ce script initialise l'environnement et vérifie la connexion Azure
# =============================================================================

# Note: on n'utilise PAS "set -e" car certaines commandes peuvent échouer
# (ex: az provider register si pas les permissions) sans bloquer le script

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
    
    if az login --use-device-code; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Connexion réussie!"
        check_azure_login
        # Enregistrer les providers Azure après connexion
        register_azure_providers
    else
        echo -e "${RED}[ERROR]${NC} Échec de la connexion Azure"
        echo -e "${YELLOW}[INFO]${NC} Vous pouvez réessayer avec: az login --use-device-code"
        # Ne pas exit, continuer pour permettre l'utilisation du shell
    fi
}

# Fonction pour enregistrer les providers Azure nécessaires
register_azure_providers() {
    echo ""
    echo -e "${BLUE}[PROVIDERS]${NC} Vérification des providers Azure..."
    
    # Liste des providers nécessaires pour ce projet
    PROVIDERS=("Microsoft.App" "Microsoft.ContainerRegistry" "Microsoft.Storage" "Microsoft.OperationalInsights" "Microsoft.DBforPostgreSQL")
    
    # Array pour tracker les providers en attente
    declare -a PENDING_PROVIDERS=()
    
    # Première passe : vérifier et lancer l'enregistrement si nécessaire
    for provider in "${PROVIDERS[@]}"; do
        STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
        
        if [ "$STATE" = "Registered" ]; then
            echo -e "  ${GREEN}✓${NC} $provider"
        elif [ "$STATE" = "Registering" ]; then
            echo -e "  ${YELLOW}⏳${NC} $provider (en cours...)"
            PENDING_PROVIDERS+=("$provider")
        else
            echo -e "  ${YELLOW}→${NC} $provider (enregistrement...)"
            # || true pour ne pas bloquer si pas les permissions
            az provider register --namespace "$provider" &>/dev/null || true
            PENDING_PROVIDERS+=("$provider")
        fi
    done
    
    # Si des providers sont en attente, attendre qu'ils soient tous prêts
    if [ ${#PENDING_PROVIDERS[@]} -gt 0 ]; then
        echo ""
        echo -e "${BLUE}[INFO]${NC} ${#PENDING_PROVIDERS[@]} provider(s) en cours d'enregistrement..."
        echo -e "${BLUE}[INFO]${NC} Attente automatique (max 3 min)..."
        echo ""
        
        # Attendre jusqu'à 3 minutes (36 x 5s)
        MAX_ATTEMPTS=36
        ATTEMPT=0
        
        while [ ${#PENDING_PROVIDERS[@]} -gt 0 ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            ATTEMPT=$((ATTEMPT + 1))
            ELAPSED=$((ATTEMPT * 5))
            
            # Vérifier chaque provider en attente
            STILL_PENDING=()
            for provider in "${PENDING_PROVIDERS[@]}"; do
                STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
                if [ "$STATE" = "Registered" ]; then
                    echo -e "  ${GREEN}✓${NC} $provider ${GREEN}(prêt après ${ELAPSED}s)${NC}"
                else
                    STILL_PENDING+=("$provider")
                fi
            done
            
            PENDING_PROVIDERS=("${STILL_PENDING[@]}")
            
            # Si tous sont prêts, sortir
            if [ ${#PENDING_PROVIDERS[@]} -eq 0 ]; then
                break
            fi
            
            # Afficher progression
            echo -ne "\r  ${YELLOW}⏳${NC} Attente: ${ELAPSED}s / 180s - En attente: ${PENDING_PROVIDERS[*]}   "
            sleep 5
        done
        
        echo ""
        
        # Vérification finale
        if [ ${#PENDING_PROVIDERS[@]} -gt 0 ]; then
            echo -e "${YELLOW}[WARNING]${NC} Providers encore en attente après 3 min:"
            for provider in "${PENDING_PROVIDERS[@]}"; do
                STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
                echo -e "  ${YELLOW}⏳${NC} $provider ($STATE)"
            done
            echo ""
            echo -e "${YELLOW}[INFO]${NC} L'enregistrement continue en arrière-plan."
            echo -e "${YELLOW}[INFO]${NC} Attendez 1-2 min avant terraform apply, ou réessayez si erreur."
        else
            echo -e "${GREEN}[OK]${NC} Tous les providers sont enregistrés!"
        fi
    else
        echo -e "${GREEN}[OK]${NC} Tous les providers sont déjà enregistrés!"
    fi
}

# Fonction pour initialiser Terraform
init_terraform() {
    if [ -f "main.tf" ]; then
        if [ ! -d ".terraform" ]; then
            echo ""
            echo -e "${BLUE}[TERRAFORM]${NC} Initialisation de Terraform..."
            if terraform init; then
                echo -e "${GREEN}[OK]${NC} Terraform initialisé!"
            else
                echo -e "${YELLOW}[WARNING]${NC} Terraform init a rencontré des erreurs"
                echo -e "${YELLOW}[INFO]${NC} Vous pouvez réessayer manuellement: terraform init"
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
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                         COMMANDES UTILES                           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Commandes de base:${NC}"
echo "  terraform plan      - Prévisualiser les changements"
echo "  terraform apply     - Appliquer les changements"
echo "  terraform destroy   - Détruire l'infrastructure"
echo "  terraform output    - Voir les outputs"
echo "  az login --use-device-code  - Se reconnecter à Azure"
echo ""
echo -e "  ${RED}exit${NC}                  - Quitter le workspace"
echo ""
echo -e "${BLUE}───────────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Plan (prévisualiser):${NC}"
echo ""
echo -e "  ${GREEN}DEV:${NC}  terraform plan -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars"
echo -e "  ${YELLOW}REC:${NC}  terraform plan -var-file=environments/rec.tfvars -var-file=environments/secrets.tfvars"
echo -e "  ${RED}PROD:${NC} terraform plan -var-file=environments/prod.tfvars -var-file=environments/secrets.tfvars"
echo ""
echo -e "${BLUE}───────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}Apply (déployer):${NC}"
echo ""
echo -e "  ${GREEN}DEV:${NC}  terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars"
echo -e "  ${YELLOW}REC:${NC}  terraform apply -var-file=environments/rec.tfvars -var-file=environments/secrets.tfvars"
echo -e "  ${RED}PROD:${NC} terraform apply -var-file=environments/prod.tfvars -var-file=environments/secrets.tfvars"
echo ""
echo -e "${BLUE}───────────────────────────────────────────────────────────────────${NC}"
echo -e "${RED}Destroy (supprimer):${NC}"
echo ""
echo -e "  ${GREEN}DEV:${NC}  terraform destroy -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars"
echo -e "  ${YELLOW}REC:${NC}  terraform destroy -var-file=environments/rec.tfvars -var-file=environments/secrets.tfvars"
echo -e "  ${RED}PROD:${NC} terraform destroy -var-file=environments/prod.tfvars -var-file=environments/secrets.tfvars"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Exécution de la commande passée en argument
exec "$@"
