# ─────────────────────────────────────────────────────────────────────────────
# environments/prod/variables.tf — PROD environment variable declarations
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
  default     = "prod"
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
  description = "Name of the Resource Group for prod resources"
  type        = string
  default     = "rg-srs-prod"
}

# ── Networking ─────────────────────────────────────────────────────────────────
variable "vnet_address_space" {
  description = "Prod VNet CIDR — use 10.0.0.0/16 (dev uses 10.1.0.0/16 to avoid overlap)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_appgw_prefix" {
  description = "Subnet CIDR for App Gateway"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_backend_prefix" {
  description = "Subnet CIDR for App Service VNet integration"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_db_prefix" {
  description = "Subnet CIDR for MySQL private endpoint"
  type        = string
  default     = "10.0.3.0/24"
}

# ── Shared ACR (owned by prod, referenced by dev) ─────────────────────────────
variable "acr_name" {
  description = "Name of the Shared Azure Container Registry (globally unique, lowercase, 5-50 chars)"
  type        = string
  default     = "acrsrsprod"
}

variable "acr_sku" {
  description = <<-EOT
    ACR pricing tier:
      "Basic"    = No geo-replication, 10 GB storage (~$5/mo)
      "Standard" = No geo-replication, 100 GB storage (~$20/mo) — recommended for prod
      "Premium"  = Geo-replication, private link (~$50/mo)
  EOT
  type        = string
  default     = "Standard"
}

# ── MySQL Database ─────────────────────────────────────────────────────────────
variable "mysql_server_name" {
  description = "MySQL Flexible Server name (must be globally unique)"
  type        = string
  default     = "mysql-srs-prod"
}

variable "mysql_admin_username" {
  description = "MySQL administrator username"
  type        = string
  default     = "mysqladmin"
}

variable "mysql_admin_password" {
  description = "MySQL admin password — supply via CI/CD secret or Key Vault, NEVER commit"
  type        = string
  sensitive   = true
}

variable "mysql_sku" {
  description = <<-EOT
    MySQL pricing tier for prod:
      "B_Standard_B1ms"       = Burstable, 1 vCore (~$14/mo)  — minimum viable
      "B_Standard_B2ms"       = Burstable, 2 vCore (~$28/mo)  — recommended prod starter
      "GP_Standard_D2ds_v4"   = General Purpose, 2 vCore (~$170/mo) — high-traffic prod
  EOT
  type        = string
  default     = "B_Standard_B2ms"
}

# ── App Service (Backend) ─────────────────────────────────────────────────────
variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "asp-srs-prod"
}

variable "backend_app_name" {
  description = "Name of the backend Web App (must be globally unique)"
  type        = string
  default     = "backendapp-srs-prod"
}

variable "app_service_plan_sku" {
  description = <<-EOT
    App Service Plan SKU for prod:
      "B1"  = Basic  (~$13/mo)  — supports VNet integration
      "P1v3"= Premium (~$68/mo) — auto-scaling, deployment slots
  EOT
  type        = string
  default     = "B1"
}

variable "backend_image_tag" {
  description = "Docker image tag for the prod backend — convention: :latest or :stable"
  type        = string
  default     = "latest"
}

# ── Storage Account (Frontend) ─────────────────────────────────────────────────
variable "storage_account_name" {
  description = "Storage Account name for the prod frontend static website (pre-existing, lowercase, no hyphens)"
  type        = string
}

# ── Key Vault ─────────────────────────────────────────────────────────────────
variable "key_vault_name" {
  description = "Name of the pre-existing Azure Key Vault for prod secrets"
  type        = string
  default     = "kv-srs-prod-cv"
}

# ── Application Gateway ───────────────────────────────────────────────────────
variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
  default     = "agw-srs-prod"
}

variable "enable_waf" {
  description = <<-EOT
    Enable WAF_v2 tier with OWASP 3.2 ruleset (recommended for prod).
    WARNING: Increases App Gateway cost by ~$20-30/month.
    Phase 1 → false (faster deploy, lower cost)
    Phase 3 → true  (full security hardening)
  EOT
  type        = bool
  default     = true
}

variable "enable_ssl" {
  description = <<-EOT
    false = HTTP only (Phase 1 — first deployment)
    true  = HTTPS + HTTP-to-HTTPS redirect (Phase 2, after uploading cert to Key Vault)
    Workflow:
      1. terraform apply (enable_ssl = false)
      2. Upload SSL cert to Key Vault manually
      3. Set enable_ssl = true → terraform apply again
  EOT
  type        = bool
  default     = false
}

variable "custom_domain" {
  description = "Custom domain for HTTPS listener (e.g. chaitanya-vek.me)"
  type        = string
  default     = "chaitanya-vek.me"
}

variable "ssl_cert_name" {
  description = "Name of SSL certificate stored in Key Vault"
  type        = string
  default     = "ssl-cert-srs-prod"
}

# ── Monitoring ─────────────────────────────────────────────────────────────────
variable "log_retention_days" {
  description = "Log Analytics retention period in days (90 recommended for prod compliance)"
  type        = number
  default     = 90
}
