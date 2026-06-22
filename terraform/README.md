# Terraform Infrastructure — Azure 3-Tier Application

A production-ready, modular Terraform codebase that provisions a secure, scalable 3-tier application architecture on **Microsoft Azure**. Infrastructure is fully parameterized for two isolated environments: **dev** and **prod**.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Repository Structure](#3-repository-structure)
4. [Environment Differences](#4-environment-differences)
5. [Initial Azure Setup (One-Time)](#5-initial-azure-setup-one-time)
6. [Deploying the Infrastructure](#6-deploying-the-infrastructure)
   - [Step 1 — Create Terraform Remote Backend Storage](#step-1--create-terraform-remote-backend-storage)
   - [Step 2 — Deploy Prod Environment First (Creates Shared ACR)](#step-2--deploy-prod-environment-first-creates-shared-acr)
   - [Step 3 — Deploy Dev Environment](#step-3--deploy-dev-environment)
7. [Post-Deployment: Publish Your Application](#7-post-deployment-publish-your-application)
8. [Enabling HTTPS / SSL (Phase 2)](#8-enabling-https--ssl-phase-2)
9. [Enabling WAF (Phase 3 — Prod Only)](#9-enabling-waf-phase-3--prod-only)
10. [Switching Between Environments](#10-switching-between-environments)
11. [Destroying Infrastructure](#11-destroying-infrastructure)
12. [Module Reference](#12-module-reference)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Architecture Overview

```
Internet
   │
   ▼
Application Gateway (WAF_v2 optional)    ← Public entry point, SSL termination
   │                          │
   │ /api/*                   │ /* (default)
   ▼                          ▼
App Service                Azure Storage Account
(Node.js backend)          (React/Vite frontend)
   │
   │ MySQL port 3306 (private)
   ▼
Azure MySQL Flexible Server
(inside delegated subnet, no public IP)

Supporting Services:
  Azure Container Registry (ACR)  ← Shared between dev & prod
  Azure Key Vault                 ← Stores DB password + SSL cert per env
  Log Analytics Workspace         ← Diagnostics & monitoring
```

### Request Flow

| Path | Route Target | Protocol |
|------|-------------|----------|
| `/api/*` | Backend Node.js App Service | HTTPS/443 → App Service |
| `/*` (default) | Frontend Storage Account | HTTPS/443 → Static Website |

### Network Isolation

| Subnet | CIDR (Prod) | CIDR (Dev) | Purpose |
|--------|-------------|------------|---------|
| App Gateway | `10.0.1.0/24` | `10.1.1.0/24` | Public ingress only |
| Backend | `10.0.2.0/24` | `10.1.2.0/24` | App Service VNet integration |
| Database | `10.0.3.0/24` | `10.1.3.0/24` | MySQL delegated subnet (private) |

---

## 2. Prerequisites

### Tools Required

| Tool | Version | Install |
|------|---------|---------|
| Terraform | ≥ 1.5.0 | https://developer.hashicorp.com/terraform/install |
| Azure CLI | Latest | https://learn.microsoft.com/en-us/cli/azure/install-azure-cli |
| Docker | Latest | https://docs.docker.com/get-docker/ |

### Azure Requirements

- An active **Azure Subscription** with Contributor access
- Azure CLI authenticated: `az login`

### Pre-existing Azure Resources (Manual Setup Required)

Terraform references these resources as **data sources** — they must exist before running `terraform apply`.

> **Why not manage these in Terraform?**
> Key Vault and Storage Account are "bootstrap" resources. Key Vault must exist before Terraform can read secrets from it. The Storage Account for the frontend is managed separately so it persists across deployments.

**For each environment, you must manually create:**

1. **Azure Key Vault** — stores the database password and SSL certificate
2. **Azure Storage Account** — hosts the static React frontend (`$web` container with static website enabled)

See [Section 5](#5-initial-azure-setup-one-time) for exact commands.

---

## 3. Repository Structure

```
terraform/
├── environments/
│   ├── dev/                          # Dev environment (all files here)
│   │   ├── main.tf                   # Module calls, provider, RG, data sources
│   │   ├── variables.tf              # Dev-specific variable declarations
│   │   ├── outputs.tf                # Dev outputs + helper commands
│   │   ├── terraform.tfvars.example  # Copy to terraform.tfvars and fill in values
│   │   └── backend.hcl.example       # Copy to backend.hcl and fill in storage name
│   └── prod/                         # Prod environment (all files here)
│       ├── main.tf                   # Module calls, provider, RG, data sources
│       ├── variables.tf              # Prod-specific variable declarations
│       ├── outputs.tf                # Prod outputs + helper commands
│       ├── terraform.tfvars.example  # Copy to terraform.tfvars and fill in values
│       └── backend.hcl.example       # Copy to backend.hcl and fill in storage name
├── modules/
│   ├── acr/                          # Azure Container Registry (shared by dev & prod)
│   ├── appgateway/                   # Application Gateway + WAF + SSL + Public IP
│   ├── backend-app/                  # App Service Plan + Linux Web App
│   ├── database/                     # MySQL Flexible Server + Private DNS Zone
│   ├── monitoring/                   # Log Analytics Workspace + Diagnostic Settings
│   └── networking/                   # VNet + 3 Subnets + 3 NSGs
├── ARCHITECTURE.md                   # Detailed architecture documentation
└── .gitignore                        # Ignores *.tfvars, backend.hcl, .terraform/
```

> **Important:** `terraform.tfvars` and `backend.hcl` are `.gitignore`d — never commit them, they contain secrets.

---

## 4. Environment Differences

| Configuration | Dev | Prod |
|---------------|-----|------|
| Resource Group | `rg-srs-dev` | `rg-srs-prod` |
| VNet CIDR | `10.1.0.0/16` | `10.0.0.0/16` |
| ACR | **Data source** (references prod ACR) | **Module** (owns shared ACR) |
| ACR SKU | — | `Standard` |
| MySQL SKU | `B_Standard_B1ms` (1 vCore) | `B_Standard_B2ms` (2 vCores) |
| App Service SKU | `B1` | `B1` → `P1v3` for auto-scaling |
| Image Tag | `:dev` | `:latest` |
| WAF | `false` | `true` (Phase 3) |
| SSL | `false` | `false` → `true` (Phase 2) |
| Key Vault | `kv-srs-dev-cv` | `kv-srs-prod-cv` |
| Log Retention | 30 days | 90 days |
| State File | `dev.terraform.tfstate` | `prod.terraform.tfstate` |

---

## 5. Initial Azure Setup (One-Time)

Run these commands once to bootstrap the manual prerequisites. Substitute your values for anything in `< >`.

### Authenticate

```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

### Create Key Vaults

```bash
# Dev Key Vault
az keyvault create \
  --name kv-srs-dev-cv \
  --resource-group rg-srs-dev \
  --location centralindia \
  --sku standard \
  --enable-rbac-authorization true

# Prod Key Vault
az keyvault create \
  --name kv-srs-prod-cv \
  --resource-group rg-srs-prod \
  --location centralindia \
  --sku standard \
  --enable-rbac-authorization true
```

> **Note:** Create the resource groups first if they don't exist:
> ```bash
> az group create --name rg-srs-dev  --location centralindia
> az group create --name rg-srs-prod --location centralindia
> ```

### Add the DB Password Secret to Each Key Vault

```bash
# Dev — assign yourself access first
az role assignment create \
  --role "Key Vault Administrator" \
  --assignee "<YOUR_USER_OBJECT_ID>" \
  --scope $(az keyvault show --name kv-srs-dev-cv --query id -o tsv)

# Then add the secret
az keyvault secret set \
  --vault-name kv-srs-dev-cv \
  --name "db-password" \
  --value "YourStr0ng!PasswordDev"

# Prod
az role assignment create \
  --role "Key Vault Administrator" \
  --assignee "<YOUR_USER_OBJECT_ID>" \
  --scope $(az keyvault show --name kv-srs-prod-cv --query id -o tsv)

az keyvault secret set \
  --vault-name kv-srs-prod-cv \
  --name "db-password" \
  --value "YourStr0ng!PasswordProd"
```

### Create Storage Accounts (Frontend Hosting)

```bash
# Dev Storage Account
az storage account create \
  --name storagesrsdev \
  --resource-group rg-srs-dev \
  --location centralindia \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2

# Enable static website hosting
az storage blob service-properties update \
  --account-name storagesrsdev \
  --static-website \
  --index-document index.html \
  --404-document index.html

# Prod Storage Account
az storage account create \
  --name storagesrsprod \
  --resource-group rg-srs-prod \
  --location centralindia \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2

az storage blob service-properties update \
  --account-name storagesrsprod \
  --static-website \
  --index-document index.html \
  --404-document index.html
```

### Create Terraform Remote Backend Storage

```bash
# One shared storage account for all Terraform state files
az group create \
  --name rg-tfstate \
  --location centralindia

az storage account create \
  --name <BACKEND_STORAGE_NAME> \
  --resource-group rg-tfstate \
  --location centralindia \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2

az storage container create \
  --name tfstate \
  --account-name <BACKEND_STORAGE_NAME>
```

---

## 6. Deploying the Infrastructure

> **Deploy Order:** Prod **must** be deployed first because it creates the shared ACR that dev references.

### Step 1 — Create Terraform Remote Backend Storage

Done in [Section 5](#create-terraform-remote-backend-storage) above.

---

### Step 2 — Deploy Prod Environment First (Creates Shared ACR)

```bash
cd terraform/environments/prod

# 1. Create your variable file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — fill in subscription_id, passwords, resource names

# 2. Create your backend config
cp backend.hcl.example backend.hcl
# Edit backend.hcl — fill in storage_account_name (the backend storage you created)

# 3. Initialise Terraform with remote backend
terraform init -backend-config=backend.hcl

# 4. Preview the changes
terraform plan -var-file=terraform.tfvars

# 5. Apply (Phase 1 — HTTP only, WAF disabled)
terraform apply -var-file=terraform.tfvars

# 6. Note the outputs — you'll need shared_acr_name for the dev step
terraform output shared_acr_name
terraform output shared_acr_login_server
```

**Key outputs to record:**

| Output | Use |
|--------|-----|
| `app_gateway_ip` | Point your DNS A record here |
| `shared_acr_name` | Copy to dev `terraform.tfvars` as `acr_name` |
| `shared_acr_login_server` | Use to tag and push Docker images |

---

### Step 3 — Deploy Dev Environment

```bash
cd terraform/environments/dev

# 1. Create your variable file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   - Set acr_name to the shared_acr_name output from prod
#   - Set acr_resource_group_name = "rg-srs-prod"
#   - Fill in subscription_id, passwords, resource names

# 2. Create your backend config
cp backend.hcl.example backend.hcl
# Edit backend.hcl — same storage account as prod but key = "dev.terraform.tfstate"

# 3. Initialise Terraform
terraform init -backend-config=backend.hcl

# 4. Preview the changes
terraform plan -var-file=terraform.tfvars

# 5. Apply
terraform apply -var-file=terraform.tfvars
```

---

## 7. Post-Deployment: Publish Your Application

### Push the Backend Docker Image to ACR

```bash
# Log in to ACR
az acr login --name <ACR_NAME>

# Build and push prod image (from repo root)
az acr build \
  --registry <ACR_NAME> \
  --image trainee-backend:latest \
  ./trainee_backend

# Build and push dev image
az acr build \
  --registry <ACR_NAME> \
  --image trainee-backend:dev \
  ./trainee_backend
```

> **Tip:** After a successful push, the App Service will automatically pull the new image if `DOCKER_ENABLE_CI=true` is set (it is, by default).

### Build and Upload the Frontend

```bash
# Build the React/Vite app
cd trainee_frontend
npm install
npm run build
cd ..

# Upload to prod storage
az storage blob upload-batch \
  --account-name <PROD_STORAGE_NAME> \
  --source ./trainee_frontend/dist \
  --destination '$web' \
  --overwrite

# Upload to dev storage
az storage blob upload-batch \
  --account-name <DEV_STORAGE_NAME> \
  --source ./trainee_frontend/dist \
  --destination '$web' \
  --overwrite
```

> **Shortcut:** After applying Terraform, the `cmd_push_prod_image`, `cmd_push_dev_image`, and `cmd_upload_frontend` outputs print the exact commands with your resource names pre-filled.
>
> ```bash
> terraform output cmd_push_prod_image
> terraform output cmd_upload_frontend
> ```

---

## 8. Enabling HTTPS / SSL (Phase 2)

**Do this only after Phase 1 (`enable_ssl = false`) is working correctly.**

### Upload SSL Certificate to Key Vault

```bash
# Import your PFX certificate (replace with your cert path and password)
az keyvault certificate import \
  --vault-name kv-srs-prod-cv \
  --name ssl-cert-srs-prod \
  --file ./your-certificate.pfx \
  --password "<CERT_PASSWORD>"
```

### Enable SSL in Terraform

Edit `terraform/environments/prod/terraform.tfvars`:

```hcl
enable_ssl    = true
custom_domain = "chaitanya-vek.me"
ssl_cert_name = "ssl-cert-srs-prod"
```

Re-apply:

```bash
cd terraform/environments/prod
terraform apply -var-file=terraform.tfvars
```

The App Gateway will now:
- Serve HTTPS on port 443 with your certificate
- Automatically redirect HTTP → HTTPS (301 Permanent)

---

## 9. Enabling WAF (Phase 3 — Prod Only)

**Do this after SSL is working. WAF adds ~$20-30/month.**

Edit `terraform/environments/prod/terraform.tfvars`:

```hcl
enable_waf = true
```

Re-apply:

```bash
cd terraform/environments/prod
terraform apply -var-file=terraform.tfvars
```

The App Gateway switches to `WAF_v2` tier with OWASP 3.2 ruleset in Prevention mode, blocking:
- SQL injection
- Cross-site scripting (XSS)
- Remote code execution
- And 200+ other Layer-7 attacks

---

## 10. Switching Between Environments

**Always run `terraform init -reconfigure` when switching environments.** Terraform remembers the last backend from initialization.

```bash
# Switch to dev
cd terraform/environments/dev
terraform init -backend-config=backend.hcl -reconfigure
terraform plan -var-file=terraform.tfvars

# Switch to prod
cd terraform/environments/prod
terraform init -backend-config=backend.hcl -reconfigure
terraform plan -var-file=terraform.tfvars
```

---

## 11. Destroying Infrastructure

> ⚠️ **Warning:** This permanently deletes all resources including databases. Ensure you have backups.

```bash
# Destroy dev (safe to do first — doesn't affect prod ACR)
cd terraform/environments/dev
terraform destroy -var-file=terraform.tfvars

# Destroy prod (destroys the shared ACR — destroy dev first)
cd terraform/environments/prod
terraform destroy -var-file=terraform.tfvars
```

---

## 12. Module Reference

### `modules/networking`

Provisions the core network topology.

| Input | Description | Example |
|-------|-------------|---------|
| `vnet_address_space` | VNet CIDR | `10.0.0.0/16` |
| `subnet_appgw_prefix` | App Gateway subnet CIDR | `10.0.1.0/24` |
| `subnet_backend_prefix` | Backend subnet CIDR | `10.0.2.0/24` |
| `subnet_db_prefix` | Database subnet CIDR | `10.0.3.0/24` |
| `vnet_name` | VNet resource name | `vnet-srs-prod` |

**Outputs:** `vnet_id`, `appgw_subnet_id`, `backend_subnet_id`, `db_subnet_id`

---

### `modules/database`

Provisions MySQL Flexible Server with full private network isolation.

| Input | Description | Example |
|-------|-------------|---------|
| `mysql_server_name` | Globally unique server name | `mysql-srs-prod` |
| `mysql_sku` | Pricing tier | `B_Standard_B2ms` |
| `mysql_admin_password` | Admin password (sensitive) | — |
| `private_dns_zone_name` | Private DNS zone | `srs-prod.private.mysql.database.azure.com` |

**Outputs:** `hostname`, `name`, `database_name`, `id`

---

### `modules/acr`

Provisions the Azure Container Registry (shared between environments).

| Input | Description | Example |
|-------|-------------|---------|
| `acr_name` | Globally unique ACR name | `acrsrsprod` |
| `acr_sku` | Pricing tier | `Standard` |

**Outputs:** `login_server`, `name`, `id`, `admin_username`

---

### `modules/backend-app`

Provisions App Service Plan + Linux Web App running the containerized backend.

| Input | Description | Example |
|-------|-------------|---------|
| `app_service_plan_sku` | Plan tier | `B1` |
| `backend_app_name` | Globally unique app name | `backendapp-srs-prod` |
| `backend_image_tag` | Docker image tag | `latest` |
| `db_password_ref` | Key Vault reference URI | `@Microsoft.KeyVault(...)` |

**Outputs:** `default_hostname`, `principal_id`, `id`, `name`

---

### `modules/appgateway`

Provisions Application Gateway with optional WAF and SSL.

| Input | Description | Default |
|-------|-------------|---------|
| `enable_waf` | Enable WAF_v2 + OWASP 3.2 | `false` |
| `enable_ssl` | Enable HTTPS listener + redirect | `false` |
| `custom_domain` | HTTPS listener host name | `""` |

**Outputs:** `public_ip`, `name`, `id`, `identity_principal_id`

---

### `modules/monitoring`

Provisions Log Analytics Workspace and App Gateway diagnostic settings.

| Input | Description | Default |
|-------|-------------|---------|
| `workspace_name` | Log Analytics name | — |
| `retention_in_days` | Log retention period | `30` |
| `diagnostic_setting_name` | Diagnostic setting name | — |

**Outputs:** `workspace_id`, `workspace_name`

---

## 13. Troubleshooting

### `Error: Backend configuration changed`
Run `terraform init -backend-config=backend.hcl -reconfigure`. Terraform requires reconfiguration when switching between environments.

### `Error: A resource with the ID already exists`
A resource with the same name exists from a previous deployment. Either import it (`terraform import`) or choose a different name in `terraform.tfvars`.

### `Error: Key Vault secret not found`
The Key Vault or the `db-password` secret doesn't exist yet. Complete [Section 5](#5-initial-azure-setup-one-time) before running `terraform apply`.

### `Error: The subscription is not registered to use namespace`
Register the required Azure provider:
```bash
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.DBforMySQL
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.OperationalInsights
```

### `Error: 409 Conflict — mysql server name already exists`
MySQL server names are globally unique. Choose a different `mysql_server_name` in your `terraform.tfvars`.

### App Service can't pull from ACR
Ensure the `azurerm_role_assignment.webapp_acr_pull` was applied and the App Service identity has the `AcrPull` role on the shared ACR:
```bash
az role assignment list --scope $(az acr show --name <ACR_NAME> --query id -o tsv)
```

### Frontend not loading through App Gateway
The Storage Account static website endpoint must be resolvable by App Gateway. Verify the `primary_web_endpoint` output and that the `$web` container has been uploaded to.
