# 📚 Documentation - Terraform Pipeline

Bienvenue dans la documentation du projet NYC Taxi Pipeline Infrastructure.

## 📖 Table des matières

| Document | Description |
|----------|-------------|
| [Architecture](./architecture.md) | Vue d'ensemble de l'infrastructure Azure |
| [Getting Started](./getting-started.md) | Guide de démarrage rapide |
| [Scripts](./scripts.md) | Documentation des scripts disponibles |
| [Environments](./environments.md) | Gestion des environnements (dev/rec/prod) |
| [Terraform](./terraform.md) | Configuration et ressources Terraform |
| [Troubleshooting](./troubleshooting.md) | Résolution des problèmes courants |
| [FAQ](./faq.md) | Questions fréquentes |

## 🚀 Démarrage rapide

```powershell
# 1. Vérifier les prérequis
.\scripts\windows\terraform\check-prereqs.ps1

# 2. Configurer le mot de passe PostgreSQL
notepad terraform\environments\secrets.tfvars

# 3. Construire et lancer le workspace
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run.ps1

# 4. Dans le conteneur, déployer
az login --use-device-code
terraform init
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

## 📁 Structure du projet

```
terraform_pipeline/
├── docs/               # 📚 Documentation
├── docker/             # 🐳 Image Docker Terraform
├── scripts/            # 📜 Scripts par plateforme
│   ├── windows/        # PowerShell
│   └── linux/          # Bash
└── terraform/          # ⚙️ Configuration Terraform
    └── environments/   # Configs par environnement
```

## 🔗 Ressources externes

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Brief du projet](../../brief-terraform/BRIEF.md)
