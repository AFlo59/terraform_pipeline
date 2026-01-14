# 🚀 Terraform Pipeline - NYC Taxi Infrastructure

Infrastructure as Code pour le projet NYC Taxi Pipeline sur Azure.

## 📋 Vue d'ensemble

Ce dossier contient:
- **docker/** : Image Docker avec Terraform + Azure CLI
- **scripts/** : Scripts organisés par plateforme et fonction
  - `windows/` : Scripts PowerShell pour Windows
  - `linux/` : Scripts Bash pour WSL/Linux
- **terraform/** : Configuration Terraform pour Azure

## 🏗️ Architecture déployée

```
┌─────────────────────────────────────────────────────────────────┐
│                        AZURE CLOUD                               │
│                                                                  │
│  ┌──────────────┐    ┌──────────────────┐    ┌──────────────┐  │
│  │   Storage    │    │  Container Apps   │    │  Cosmos DB   │  │
│  │   Account    │───▶│   Environment     │───▶│  PostgreSQL  │  │
│  │  raw/proc    │    │   + Pipeline App  │    │   (Citus)    │  │
│  └──────────────┘    └──────────────────┘    └──────────────┘  │
│                             │                                   │
│  ┌──────────────┐    ┌──────┴───────┐                          │
│  │  Container   │    │     Log      │                          │
│  │  Registry    │    │   Analytics  │                          │
│  └──────────────┘    └──────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## 🛠️ Prérequis

- **Docker Desktop** installé et en cours d'exécution
- **Compte Azure** avec une souscription active
- **Azure CLI** installé localement (pour les commandes initiales)

## 🚀 Démarrage rapide

### 1. Construire l'image Docker

```powershell
# Windows (PowerShell)
.\scripts\windows\docker\build.ps1
```

```bash
# Linux / WSL
chmod +x scripts/linux/**/*.sh
./scripts/linux/docker/build.sh
```

### 2. Lancer le workspace Terraform interactif

```powershell
# Windows (PowerShell)
.\scripts\windows\docker\run.ps1
```

```bash
# Linux / WSL
./scripts/linux/docker/run.sh
```

### 3. Dans le conteneur : Se connecter à Azure

```bash
# Le script d'entrée vous proposera de vous connecter
# Ou manuellement:
az login --use-device-code
```

Suivez les instructions pour vous authentifier via https://microsoft.com/devicelogin

### 4. Initialiser et déployer Terraform

```bash
# Initialiser le projet
terraform init

# Créer le fichier de variables
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec vos valeurs

# Prévisualiser les changements
terraform plan

# Appliquer les changements
terraform apply
```

## 📁 Structure des fichiers

```
terraform_pipeline/
├── docker/
│   ├── Dockerfile           # Image Terraform + Azure CLI
│   └── entrypoint.sh        # Script d'initialisation
├── scripts/
│   ├── windows/             # 🪟 Scripts PowerShell (Windows)
│   │   ├── docker/
│   │   │   ├── build.ps1    # Construire l'image
│   │   │   ├── run.ps1      # Lancer le workspace
│   │   │   ├── update.ps1   # Mettre à jour l'image
│   │   │   └── remove.ps1   # Supprimer l'image
│   │   └── terraform/
│   │       ├── deploy.ps1       # Déployer par environnement
│   │       └── check-prereqs.ps1 # Vérifier les prérequis
│   └── linux/               # 🐧 Scripts Bash (WSL/Linux)
│       ├── docker/
│       │   ├── build.sh
│       │   ├── run.sh
│       │   ├── update.sh
│       │   └── remove.sh
│       └── terraform/
│           ├── deploy.sh
│           └── check-prereqs.sh
├── terraform/
│   ├── providers.tf         # Configuration des providers
│   ├── variables.tf         # Définition des variables
│   ├── main.tf              # Ressources Azure
│   ├── outputs.tf           # Outputs après déploiement
│   └── environments/        # Configs par environnement
│       ├── dev.tfvars       # Développement
│       ├── rec.tfvars       # Recette (staging)
│       ├── prod.tfvars      # Production
│       ├── secrets.tfvars   # 🔐 Secrets (gitignore)
│       └── secrets.tfvars.example
├── .gitignore
└── README.md
```

## 📝 Configuration

### Gestion des environnements

Le projet supporte 3 environnements avec des configurations adaptées :

| Environnement | Fichier | Usage |
|---------------|---------|-------|
| **dev** | `environments/dev.tfvars` | Développement local, ressources minimales |
| **rec** | `environments/rec.tfvars` | Recette/Staging, tests pré-production |
| **prod** | `environments/prod.tfvars` | Production, haute disponibilité |

### Configuration des secrets

```bash
# Créer le fichier de secrets (à ne jamais commiter !)
cp environments/secrets.tfvars.example environments/secrets.tfvars

# Éditer avec votre mot de passe PostgreSQL
nano environments/secrets.tfvars
```

### Déploiement par environnement

```powershell
# Windows (PowerShell)
# Prévisualiser (dev)
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action plan

# Déployer en dev
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action apply

# Déployer en recette
.\scripts\windows\terraform\deploy.ps1 -Env rec -Action apply

# Détruire l'environnement dev
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action destroy
```

```bash
# Linux / WSL
./scripts/linux/terraform/deploy.sh dev plan
./scripts/linux/terraform/deploy.sh dev apply
./scripts/linux/terraform/deploy.sh rec apply
./scripts/linux/terraform/deploy.sh dev destroy
```

### Différences entre environnements

| Ressource | Dev | Rec | Prod |
|-----------|-----|-----|------|
| ACR SKU | Basic | Standard | Premium |
| PostgreSQL vCores | 1 | 2 | 4 |
| PostgreSQL Storage | 32 GB | 64 GB | 128 GB |
| Container CPU | 0.5 | 1.0 | 2.0 |
| Container Memory | 1 Gi | 2 Gi | 4 Gi |
| Min Replicas | 0 | 0 | 1 |
| Max Replicas | 1 | 2 | 5 |
| Log Retention | 30j | 60j | 90j |

## 🔧 Scripts disponibles

### Build

```powershell
# Construire l'image
.\scripts\build.ps1

# Construire sans cache
.\scripts\build.ps1 -NoCache
```

### Run

```powershell
# Mode interactif
.\scripts\run.ps1

# Exécuter une commande
.\scripts\run.ps1 -Cmd "terraform plan"

# En arrière-plan
.\scripts\run.ps1 -Detach
```

### Update

```powershell
# Mettre à jour l'image (rebuild sans cache)
.\scripts\update.ps1
```

### Remove

```powershell
# Supprimer tout (conteneur + image)
.\scripts\remove.ps1

# Supprimer uniquement le conteneur
.\scripts\remove.ps1 -Container

# Supprimer uniquement l'image
.\scripts\remove.ps1 -Image
```

## 🔄 Workflow complet

### Phase 1: Déploiement initial

```bash
# Dans le conteneur Docker
terraform init
terraform plan
terraform apply
```

### Phase 2: Build et push de l'image NYC Taxi

```bash
# Sortir du conteneur
exit

# Depuis le dossier brief-terraform (hors Docker)
cd ../brief-terraform
az acr login --name <acr-name>  # Nom affiché dans les outputs
docker build -t nyc-taxi-pipeline:latest .
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest
```

### Phase 3: Vérification

```bash
# Voir les logs du Container App
az containerapp logs show --name <app-name> --resource-group <rg-name> --follow
```

## ⚠️ Points d'attention

1. **Ordre d'exécution**:
   - Terraform crée l'ACR en premier
   - L'image Docker doit être poussée vers ACR **avant** que Container Apps ne démarre

2. **Authentification Azure**:
   - Utilisez `az login --use-device-code` dans le conteneur
   - Les credentials sont persistées dans le volume `/workspace`

3. **Secrets**:
   - Ne commitez jamais `terraform.tfvars` avec des mots de passe
   - Utilisez `.gitignore` pour exclure les fichiers sensibles

4. **Cosmos DB SKU**:
   - Utilisez **BurstableMemoryOptimized** pour 1 vCore (obligatoire)

## 🔍 Vérification des prérequis

Avant de commencer, vérifiez que tous les outils sont installés :

```powershell
# Windows (PowerShell)
.\scripts\windows\terraform\check-prereqs.ps1
```

```bash
# Linux / WSL
./scripts/linux/terraform/check-prereqs.sh
```

Ce script vérifie :
- ✅ Docker installé et en cours d'exécution
- ✅ Azure CLI installé et connecté
- ✅ Fichiers de configuration présents
- ✅ secrets.tfvars configuré correctement

## 🐛 Troubleshooting

### Erreur: "Image not found" lors du déploiement Container App

**Cause** : L'image Docker n'a pas été poussée vers ACR avant `terraform apply`.

**Solution** :
```bash
# 1. Déployer d'abord uniquement l'ACR
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars \
  -target=azurerm_resource_group.main \
  -target=azurerm_container_registry.main

# 2. Builder et pousser l'image (depuis brief-terraform/)
az acr login --name <acr-name>
docker build -t nyc-taxi-pipeline:latest .
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest

# 3. Puis déployer le reste
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

### Erreur: "InvalidSkuForServerEdition" Cosmos DB

**Cause** : Utilisation de GeneralPurpose avec 1 vCore.

**Solution** : Le code utilise déjà `BurstableMemoryOptimized` (correct pour 1 vCore).

### Erreur: "Connection refused" PostgreSQL

**Cause** : Règle de firewall manquante.

**Solution** : Vérifiez que la règle `AllowAzureServices` (0.0.0.0) est créée.

### Erreur: "az login" échoue dans le conteneur

**Cause** : Pas de navigateur dans le conteneur Docker.

**Solution** : Utilisez le mode device-code :
```bash
az login --use-device-code
```
Puis ouvrez https://microsoft.com/devicelogin dans votre navigateur.

### Les logs Container App sont vides

**Cause** : Le container n'a pas encore démarré ou a crashé.

**Solution** :
```bash
# Vérifier l'état des révisions
az containerapp revision list --name <app-name> --resource-group <rg-name> -o table

# Voir les événements
az containerapp show --name <app-name> --resource-group <rg-name> --query "properties.latestRevisionFqdn"
```

### Terraform state lock

**Cause** : Une opération Terraform précédente a été interrompue.

**Solution** :
```bash
terraform force-unlock <LOCK_ID>
```

## 🗑️ Nettoyage

```powershell
# Windows - Détruire l'infrastructure Azure
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action destroy

# Windows - Supprimer les ressources Docker locales
.\scripts\windows\docker\remove.ps1
```

```bash
# Linux - Détruire l'infrastructure Azure
./scripts/linux/terraform/deploy.sh dev destroy

# Linux - Supprimer les ressources Docker locales
./scripts/linux/docker/remove.sh
```

## 📚 Ressources

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Cosmos DB for PostgreSQL](https://learn.microsoft.com/en-us/azure/cosmos-db/postgresql/)
- [Brief du projet](../brief-terraform/BRIEF.md)
