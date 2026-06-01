# 🏗️ Terraform — Azure Infrastructure for Student Records System

This Terraform configuration provisions a full-stack production environment on Azure:

- **Frontend:** React SPA → Azure Storage Account (Static Website)
- **Backend:** Node.js/Express (Docker) → Azure App Service (Linux Container)
- **Database:** MySQL Flexible Server (VNet-integrated, private access only)
- **Routing:** Application Gateway (WAF_v2) with path-based routing
- **Registry:** Azure Container Registry (ACR) for backend Docker images
- **Secrets:** Azure Key Vault with RBAC + Managed Identity

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
| `networking.tf` | VNet, subnets, NSGs, DNS zone |
| `acr.tf` | Container Registry + AcrPull role |
| `database.tf` | MySQL Flexible Server + firewall |
| `backend.tf` | App Service Plan + Linux Web App |
| `frontend.tf` | Storage Account data source |
| `keyvault.tf` | Key Vault data source + role assignments |
| `appgateway.tf` | Application Gateway, WAF, probes, routing |
| `monitoring.tf` | Log Analytics + diagnostic settings |
| `outputs.tf` | Useful values printed after apply |

---

## 🚀 Complete Setup Guide

### Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.5.0)
- [Docker](https://docs.docker.com/get-docker/) (for building backend image)
- [Node.js](https://nodejs.org/) (>= 18, for building frontend)

---

### Step 0 — Authenticate with Azure

```bash
az login
az account set --subscription "f4d12eb7-f43c-4022-b86c-3c1cd5466bff"
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

cd ../azure-deployment/terraform
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
terraform init

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
terraform output app_gateway_public_ip
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
curl http://$(terraform output -raw app_gateway_public_ip)/api/health

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

---
