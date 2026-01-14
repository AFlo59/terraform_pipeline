# 🚀 Getting Started

Guide de démarrage rapide pour déployer l'infrastructure NYC Taxi Pipeline.

## Prérequis

### Logiciels requis

| Outil | Version | Téléchargement |
|-------|---------|----------------|
| Docker Desktop | Latest | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Azure CLI | >= 2.50 | [docs.microsoft.com](https://docs.microsoft.com/cli/azure/install-azure-cli) |
| Git | Latest | [git-scm.com](https://git-scm.com/) |

### Compte Azure

- Souscription Azure active
- Droits de création de ressources (Contributor ou Owner)

## Étapes d'installation

### Étape 1: Vérifier les prérequis

```powershell
# Windows
cd terraform_pipeline
.\scripts\windows\terraform\check-prereqs.ps1
```

```bash
# Linux/WSL
cd terraform_pipeline
./scripts/linux/terraform/check-prereqs.sh
```

### Étape 2: Configurer les secrets

```powershell
# Éditer le fichier de secrets
notepad terraform\environments\secrets.tfvars
```

Remplacez le mot de passe par défaut :
```hcl
postgres_admin_password = "VotreMotDePasseSecurise123!"
```

> ⚠️ Le mot de passe doit contenir au moins 8 caractères avec majuscules, chiffres et symboles.

### Étape 3: Construire l'image Docker

```powershell
# Windows
.\scripts\windows\docker\build.ps1
```

```bash
# Linux/WSL
./scripts/linux/docker/build.sh
```

### Étape 4: Lancer le workspace Terraform

```powershell
# Windows
.\scripts\windows\docker\run.ps1
```

```bash
# Linux/WSL
./scripts/linux/docker/run.sh
```

### Étape 5: Se connecter à Azure

Dans le conteneur Docker :

```bash
# Le script propose automatiquement la connexion
# Sinon manuellement :
az login --use-device-code
```

1. Ouvrez https://microsoft.com/devicelogin dans votre navigateur
2. Entrez le code affiché
3. Connectez-vous avec votre compte Azure

### Étape 6: Initialiser Terraform

```bash
terraform init
```

### Étape 7: Prévisualiser le déploiement

```bash
terraform plan \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars
```

### Étape 8: Déployer l'ACR (première étape)

```bash
terraform apply \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars \
  -target=azurerm_resource_group.main \
  -target=azurerm_storage_account.main \
  -target=azurerm_container_registry.main
```

### Étape 9: Builder et pusher l'image du pipeline

**Sortez du conteneur** (`exit`) puis :

```powershell
# Dans le dossier brief-terraform
cd ..\brief-terraform

# Récupérer le nom ACR (affiché dans les outputs Terraform)
# ou via Azure Portal

# Se connecter à ACR
az acr login --name <acr-name>

# Builder l'image
docker build -t nyc-taxi-pipeline:latest .

# Tagger l'image
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest

# Pousser vers ACR
docker push <acr-url>/nyc-taxi-pipeline:latest
```

### Étape 10: Finaliser le déploiement

Retournez dans le conteneur Terraform :

```powershell
cd ..\terraform_pipeline
.\scripts\windows\docker\run.ps1
```

Puis déployez le reste :

```bash
terraform apply \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars
```

## Vérification

### Voir les outputs Terraform

```bash
terraform output
```

### Voir les logs du Container App

```bash
az containerapp logs show \
  --name ca-nyctaxi-pipeline-dev \
  --resource-group rg-nyctaxi-dev \
  --follow
```

### Se connecter à PostgreSQL

```bash
psql "postgresql://citus:<PASSWORD>@<HOSTNAME>:5432/citus?sslmode=require"
```

## Nettoyage

```bash
# Détruire toute l'infrastructure
terraform destroy \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars
```

## Prochaines étapes

- 📖 [Configuration des environnements](./environments.md)
- 🔧 [Documentation des scripts](./scripts.md)
- 🐛 [Troubleshooting](./troubleshooting.md)
