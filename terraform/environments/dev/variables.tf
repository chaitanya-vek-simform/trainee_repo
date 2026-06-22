# ─────────────────────────────────────────────────────────────────────────────
# environments/dev/variables.tf — DEV environment variable declarations
# ─────────────────────────────────────────────────────────────────────────────

# ── Azure Identity ─────────────────────────────────────────────────────────────
variable "subscription_id" {
  description = "Azure Subscription ID. Find it: Azure Portal → Subscriptions"
  type        = string
}

# ── Environment Meta ──────────────────────────────────────────────────────────
variable "environment" {
  description = "Environment name — used in all resource names and tags"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name tag applied to the resource group"
  type        = string
  default     = "app-srs"
}

variable "location" {
  description = "Azure region to deploy to (e.g. eastus, centralindia)"
  type        = string
  default     = "centralindia"
}

# ── Resource Group ─────────────────────────────────────────────────────────────
variable "resource_group_name" {
  description = "Name of the Resource Group to create for dev resources"
  type        = string
  default     = "rg-srs-dev"
}

# ── Networking ─────────────────────────────────────────────────────────────────
variable "vnet_address_space" {
  description = "Dev VNet CIDR — use 10.1.0.0/16 to avoid overlap with prod (10.0.0.0/16)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "subnet_appgw_prefix" {
  description = "Subnet CIDR for App Gateway"
  type        = string
  default     = "10.1.1.0/24"
}

variable "subnet_backend_prefix" {
  description = "Subnet CIDR for App Service VNet integration"
  type        = string
  default     = "10.1.2.0/24"
}

variable "subnet_db_prefix" {
  description = "Subnet CIDR for MySQL private endpoint"
  type        = string
  default     = "10.1.3.0/24"
}

# ── Shared ACR (owned by prod) ────────────────────────────────────────────────
variable "acr_name" {
  description = "Name of the SHARED Azure Container Registry (deployed in prod)"
  type        = string
}

variable "acr_resource_group_name" {
  description = "Resource group where the shared ACR lives (prod resource group)"
  type        = string
  default     = "rg-srs-prod"
}

# ── MySQL Database ─────────────────────────────────────────────────────────────
variable "mysql_server_name" {
  description = "MySQL Flexible Server name (must be globally unique)"
  type        = string
  default     = "mysql-srs-dev"
}

variable "mysql_admin_username" {
  description = "MySQL administrator username"
  type        = string
  default     = "mysqladmin"
}

variable "mysql_admin_password" {
  description = "MySQL admin password — supply via terraform.tfvars or CI/CD secret, NEVER commit"
  type        = string
  sensitive   = true
}

variable "mysql_sku" {
  description = "MySQL SKU — Burstable B1ms is cheapest for dev"
  type        = string
  default     = "B_Standard_B1ms"
}

# ── App Service (Backend) ─────────────────────────────────────────────────────
variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "asp-srs-dev"
}

variable "backend_app_name" {
  description = "Name of the backend Web App (must be globally unique)"
  type        = string
  default     = "backendapp-srs-dev"
}

variable "app_service_plan_sku" {
  description = <<-EOT
    App Service Plan SKU for dev.
    "F1" = Free (~$0/mo) — no VNet integration, no always_on
    "B1" = Basic (~$13/mo) — supports VNet integration
    Start with F1, switch to B1 if you need VNet connectivity.
  EOT
  type        = string
  default     = "B1"
}

variable "backend_image_tag" {
  description = "Docker image tag for the dev backend — convention: :dev"
  type        = string
  default     = "dev"
}

# ── Storage Account (Frontend) ─────────────────────────────────────────────────
variable "storage_account_name" {
  description = "Storage Account name for the frontend static website (pre-existing, lowercase, no hyphens)"
  type        = string
}

# ── Key Vault ─────────────────────────────────────────────────────────────────
variable "key_vault_name" {
  description = "Name of the pre-existing Azure Key Vault for dev secrets"
  type        = string
  default     = "kv-srs-dev-cv"
}

# ── Application Gateway ───────────────────────────────────────────────────────
variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
  default     = "agw-srs-dev"
}

variable "enable_waf" {
  description = "WAF disabled in dev — saves ~$20-30/month"
  type        = bool
  default     = false
}

variable "enable_ssl" {
  description = <<-EOT
    false = HTTP only (Phase 1 — recommended for dev)
    true  = HTTPS + HTTP-to-HTTPS redirect (Phase 2, after uploading cert to KV)
  EOT
  type        = bool
  default     = false
}

variable "custom_domain" {
  description = "Custom domain for HTTPS listener (e.g. dev.chaitanya-vek.me). Leave blank to skip."
  type        = string
  default     = ""
}

variable "ssl_cert_name" {
  description = "Name of SSL certificate stored in Key Vault (used only when enable_ssl = true)"
  type        = string
  default     = "ssl-cert-srs-dev"
}

# ── Monitoring ─────────────────────────────────────────────────────────────────
variable "log_retention_days" {
  description = "Log Analytics retention period in days (30 is min and cheapest for dev)"
  type        = number
  default     = 30
}
