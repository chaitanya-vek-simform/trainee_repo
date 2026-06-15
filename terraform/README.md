# 🏗️ Terraform — Azure Infrastructure for Student Records System

This Terraform project creates the Azure infrastructure for the student records app.

What it provisions:

- **Frontend:** React SPA hosted in Azure Storage static website
- **Backend:** Node.js/Express Docker app on Azure App Service
- **Database:** Private MySQL Flexible Server
- **Routing:** Application Gateway with path-based routing and optional WAF
- **Registry:** Azure Container Registry for backend images
- **Secrets:** Azure Key Vault with managed identity access

If you are new to Terraform, the simplest mental model is:

1. Create the Azure resources that Terraform itself needs first.
2. Fill in `terraform.tfvars` with your values.
3. Run `terraform init`, `terraform plan`, and `terraform apply`.
4. Use the outputs to deploy the backend image and frontend build.

---

## Architecture

```
                    Internet
                       │
                 ┌─────▼─────┐
                 │ Cloudflare │  DNS → A record → App GW IP
                 │    DNS     │
                 └─────┬─────┘
                       │
               ┌───────▼────────┐
               │  App Gateway   │  WAF_v2 (OWASP 3.2)
               │  (WAF + SSL)   │  Custom error pages (403/502)
               └──┬──────────┬──┘
                  │          │
            /api/*│          │ /*
                  │          │
        ┌─────────▼──┐  ┌───▼──────────────┐
        │ App Service │  │ Storage Account  │
        │  (Backend)  │  │   (Frontend)     │
        │  Port 5000  │  │  Static Website  │
        └──────┬──────┘  └──────────────────┘
               │
        ┌──────▼──────┐
        │    MySQL     │
        │  Flex Server │
        │  (Private)   │
        └─────────────┘
```

---

## 📁 File Structure

| File | Purpose |
|---|---|
| `main.tf` | Provider config, resource group |
| `variables.tf` | All input variables with defaults |
| `terraform.tfvars` | Your actual values (⚠️ gitignored) |
| `outputs.tf` | Useful values printed after apply |
| `modules/` | Reusable Terraform modules for each major component |
| `backend.hcl.example` | Template for remote backend config |

Current root Terraform files are intentionally kept small:

- `main.tf` holds the provider, data sources, module wiring, and root outputs.
- `variables.tf` holds the input variables.
- `outputs.tf` is only for output declarations that root consumers will use.

### Module Layout

The root module is now thin and only wires dependencies together. The actual resources live under `modules/`:

- `modules/networking` — VNet, subnets, NSGs
- `modules/database` — MySQL server, database, private DNS link
- `modules/backend-app` — App Service Plan and Linux Web App
- `modules/acr` — Azure Container Registry and root-level AcrPull assignment
- `modules/appgateway` — App Gateway, WAF, identity, routing
- `modules/monitoring` — Log Analytics and diagnostics

Each module now follows the same file pattern:

- `variables.tf` — inputs
- `main.tf` — resources and local values
- `outputs.tf` — outputs exposed to the root module

---

## 🚀 Complete Setup Guide

## Beginner Order

Follow these steps in this order if you are implementing the whole project from scratch:

1. Create the manual Azure resources that Terraform references later: Storage Account, Key Vault, and the backend state storage.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and edit the values.
3. Put the backend config values into `backend.hcl` from `backend.hcl.example`.
4. Run `terraform init`.
5. Run `terraform plan` and review the changes.
6. Run `terraform apply`.
7. Push the backend Docker image to ACR.
8. Build the frontend and upload it to the Storage Account.
9. Point your DNS to the Application Gateway public IP.
10. Enable SSL later if you need HTTPS.

### Remote Backend (Recommended Before First Apply)

Use Azure Blob Storage backend so Terraform state is shared and locked.

Files involved:
- `main.tf` (add `backend "azurerm" {}` inside `terraform` block)
- `backend.hcl.example` (new file with backend values template)
- `README.md` (this section)

1) Create backend resources (one-time)

```bash
az group create \
  --name <BACKEND_RG> \
  --location <BACKEND_LOCATION>

az storage account create \
  --name <BACKEND_STORAGE_NAME> \
  --resource-group <BACKEND_RG> \
  --location <BACKEND_LOCATION> \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2

az storage container create \
  --name tfstate \
  --account-name <BACKEND_STORAGE_NAME>
```

2) Add backend block in `main.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.74"
    }
  }
}
```

3) Create `backend.hcl` from template

```bash
cp backend.hcl.example backend.hcl
```

Example values:

```hcl
resource_group_name  = "<BACKEND_RG>"
storage_account_name = "<BACKEND_STORAGE_NAME>"
container_name       = "tfstate"
key                  = "prod.terraform.tfstate"
```

4) Initialize and migrate state

```bash
terraform init -backend-config=backend.hcl -reconfigure
```

If local state exists, Terraform will prompt to migrate it to remote backend.

5) Environment-safe state key naming

Use one key per environment:
- `dev.terraform.tfstate`
- `staging.terraform.tfstate`
- `prod.terraform.tfstate`

Tip:
- Keep `backend.hcl` out of Git if it contains environment-specific values.
- `.gitignore` in this repo already ignores Terraform state and tfvars.

### Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.5.0)
- [Docker](https://docs.docker.com/get-docker/) (for building backend image)
- [Node.js](https://nodejs.org/) (>= 18, for building frontend)

### What To Prepare Before `terraform apply`

Terraform expects a few Azure resources to already exist:

- A Storage Account for the frontend static website and App Gateway error pages
- A Key Vault that stores the `db-password` secret
- A blob storage account/container for the remote Terraform backend

Without these, `terraform apply` will fail because the root module reads them as data sources.

---

### Step 0 — Authenticate with Azure

```bash
az login
az account set --subscription "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

---

### Step 1 — Create the Resource Group

The resource group must exist before creating manual pre-requisites.

```bash
az group create \
  --name rg-srs-prod \
  --location southeastasia
```

---

### Step 2 — Create Storage Account + Upload Error Pages

> **Why manual?** The App Gateway validates custom error page URLs during creation.
> The HTML files must be publicly accessible _before_ `terraform apply`.

```bash
# Create the Storage Account
az storage account create \
  --name appstoragesrs \
  --resource-group rg-srs-prod \
  --location southeastasia \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access true

# Enable static website hosting
az storage blob service-properties update \
  --account-name appstoragesrs \
  --static-website \
  --index-document index.html \
  --404-document index.html

# Upload custom error pages
az storage blob upload \
  --account-name appstoragesrs \
  --container-name '$web' \
  --name waf-blocked.html \
  --file ../../trainee_frontend/public/waf-blocked.html \
  --content-type "text/html" --overwrite

az storage blob upload \
  --account-name appstoragesrs \
  --container-name '$web' \
  --name waf-502.html \
  --file ../../trainee_frontend/public/waf-502.html \
  --content-type "text/html" --overwrite

# Verify they're accessible (should print 200)
curl -s -o /dev/null -w "%{http_code}" \
  "https://appstoragesrs.z23.web.core.windows.net/waf-blocked.html"
```

---

### Step 3 — Create Key Vault + Store DB Password

> **Why manual?** The backend App Service uses a Key Vault reference for the DB password.
> The secret must exist _before_ `terraform apply` creates the App Service.

```bash
# Create Key Vault with RBAC auth
az keyvault create \
  --name kv-srs-prod \
  --resource-group rg-srs-prod \
  --location southeastasia \
  --enable-rbac-authorization true

# Grant yourself admin access to store secrets
CURRENT_USER=$(az ad signed-in-user show --query id -o tsv)
KV_ID=$(az keyvault show --name kv-srs-prod --query id -o tsv)

az role assignment create \
  --role "Key Vault Administrator" \
  --assignee "$CURRENT_USER" \
  --scope "$KV_ID"

# Store the DB password (use the same value as mysql_admin_password in terraform.tfvars)
az keyvault secret set \
  --vault-name kv-srs-prod \
  --name db-password \
  --value "YOUR_MYSQL_PASSWORD_HERE"

# Verify
az keyvault secret show \
  --vault-name kv-srs-prod \
  --name db-password \
  --query "value" -o tsv
```

---

### Step 4 — Create ACR + Build & Push Backend Image

```bash
# Create the Container Registry
az acr create \
  --name acrsrsprod \
  --resource-group rg-srs-prod \
  --location southeastasia \
  --sku Basic \
  --admin-enabled true

# Option A: Build in Azure (no Docker needed locally)
az acr build \
  --registry acrsrsprod \
  --image trainee-backend:latest \
  ../../trainee_backend

# Option B: Build locally and push
az acr login --name acrsrsprod
docker build -t acrsrsprod.azurecr.io/trainee-backend:latest ../../trainee_backend
docker push acrsrsprod.azurecr.io/trainee-backend:latest

# Verify
az acr repository show-tags --name acrsrsprod --repository trainee-backend -o table
```

---

### Step 5 — Build Frontend

```bash
cd ../../trainee_frontend

# Build with API URL pointing to App Gateway path-based routing
VITE_API_URL=/api npm run build

cd ../terraform
```

---

### Step 6 — Configure Terraform Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Key variables to set:

```hcl
subscription_id      = "your-subscription-id"
mysql_admin_password = "YourStr0ng!Password"  # Must match KV secret
enable_waf           = true                    # WAF_v2 OWASP 3.2
enable_ssl           = false                   # Phase 1 = false (see Step 9)
custom_domain        = "yourdomain.com"
```

---

### Step 7 — Initialize & Apply Terraform

```bash
# Initialize — downloads provider plugins
terraform init -backend-config=backend.hcl -reconfigure

# Preview what will be created
terraform plan

# Create all resources (takes ~15-20 min)
terraform apply
# Type "yes" when prompted

# Save the outputs
terraform output
```

This creates:
- ✅ VNet + 3 subnets (AppGW, Backend, DB) + NSGs
- ✅ MySQL Flexible Server (VNet-integrated)
- ✅ App Service Plan + Linux Web App (pulls image from ACR)
- ✅ Application Gateway (WAF_v2) with path-based routing
- ✅ Log Analytics + Diagnostics
- ✅ RBAC role assignments (AcrPull, Key Vault Secrets User)

If you only want to learn the flow first, do `terraform plan` before `terraform apply`.

---

### Step 8 — Upload Frontend to Storage Account

```bash
# Use the command from terraform output
az storage blob upload-batch \
  --account-name appstoragesrs \
  --source ../../trainee_frontend/dist \
  --destination '$web' \
  --overwrite

# Verify
az storage blob list \
  --account-name appstoragesrs \
  --container-name '$web' \
  --query "[].name" -o tsv
```

---

### Step 9 — Update DNS

Get the App Gateway public IP:

```bash
terraform output app_gateway_ip
# e.g., 20.212.9.145
```

In your DNS provider (Cloudflare), add an **A record**:

| Type | Name | Value | Proxy |
|---|---|---|---|
| `A` | `@` | `20.212.9.145` | DNS only (grey cloud) |

---

### Step 10 — Enable SSL (Phase 2)

> Skip this step if you don't need HTTPS yet.

```bash
# Generate a free Let's Encrypt certificate
certbot certonly --manual --preferred-challenges dns \
  -d yourdomain.com -d "*.yourdomain.com"
# Add the TXT record in Cloudflare when prompted

# Convert to PFX
openssl pkcs12 -export \
  -in /etc/letsencrypt/live/yourdomain.com/fullchain.pem \
  -inkey /etc/letsencrypt/live/yourdomain.com/privkey.pem \
  -out ssl-cert.pfx -passout pass:""

# Upload to Key Vault
az keyvault certificate import \
  --vault-name kv-srs-prod \
  --name ssl-cert-srs \
  --file ssl-cert.pfx

# Flip the switch in terraform.tfvars
#   enable_ssl = false  →  enable_ssl = true

# Apply Phase 2
terraform apply
```

---

## 🔄 Day-to-Day Operations

### Deploying Backend Changes

```bash
# Rebuild and push to ACR
az acr build \
  --registry acrsrsprod \
  --image trainee-backend:latest \
  ./trainee_backend

# Restart App Service to pull new image
az webapp restart \
  --name backend-app-srs-prod \
  --resource-group rg-srs-prod

# Check logs
az webapp log tail \
  --name backend-app-srs-prod \
  --resource-group rg-srs-prod
```

You can also use the Terraform output command:

```bash
terraform output backend_push_command
```

### Deploying Frontend Changes

```bash
cd trainee_frontend
VITE_API_URL=/api npm run build

az storage blob upload-batch \
  --account-name appstoragesrs \
  --source ./dist \
  --destination '$web' \
  --overwrite
```

### Checking Backend Health

```bash
# Direct App Service health
curl https://backend-app-srs-prod.azurewebsites.net/health

# Through App Gateway
curl http://$(terraform output -raw app_gateway_ip)/api/health

# App Gateway backend health
az network application-gateway show-backend-health \
  --name agw-srs-prod \
  --resource-group rg-srs-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table
```

---

## 🧹 Tear Down

```bash
# Destroy all Terraform-managed resources
terraform destroy
# Type "yes" when prompted

# Also delete manual pre-requisites
az storage account delete --name appstoragesrs --resource-group rg-srs-prod -y
az keyvault delete --name kv-srs-prod --resource-group rg-srs-prod
az keyvault purge --name kv-srs-prod --location southeastasia  # free up the name
az acr delete --name acrsrsprod --resource-group rg-srs-prod -y
az group delete --name rg-srs-prod -y
```

### Beginner Checklist

- [ ] Backend backend state storage exists
- [ ] Storage Account exists for the frontend and error pages
- [ ] Key Vault exists and contains `db-password`
- [ ] `terraform.tfvars` is filled in
- [ ] `backend.hcl` exists locally
- [ ] `terraform init` completed successfully
- [ ] `terraform plan` looks correct
- [ ] `terraform apply` completed successfully
- [ ] Backend image pushed to ACR
- [ ] Frontend uploaded to Storage Account
- [ ] DNS points to the Application Gateway IP

---
