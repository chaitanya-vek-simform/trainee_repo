variable "subscription_id" {
  description = "Your Azure Subscription ID. Find it at: portal.azure.com → Subscriptions"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to create all resources in"
  type        = string
  default     = "rg-srs-prod"
}

variable "location" {
  description = "Azure region to deploy to. Example: eastus, westeurope, southindia"
  type        = string
  default     = "southeastasia"
}

variable "environment" {
  description = "Environment tag: dev, staging, or producti0on"
  type        = string
  default     = "prod"
}


variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_appgw_prefix" {
  description = "Subnet for Application Gateway (must be dedicated)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_backend_prefix" {
  description = "Subnet for App Service VNet integration"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_db_prefix" {
  description = "Subnet for MySQL private endpoint"
  type        = string
  default     = "10.0.3.0/24"
}


variable "acr_name" {
  description = "Name of the Azure Container Registry (globally unique, lowercase, 5-50 chars)"
  type        = string
  default     = "acrsrsprod"
}


variable "mysql_server_name" {
  description = "Name of the MySQL Flexible Server (globally unique)"
  type        = string
  default     = "mysql-server-srs-prod"
}

variable "mysql_admin_username" {
  description = "MySQL administrator username"
  type        = string
  default     = "mysqladmin"
}

variable "mysql_admin_password" {
  description = "MySQL administrator password (minimum 8 chars, must include uppercase, lowercase, number, symbol)"
  type        = string
  sensitive   = true
}

variable "mysql_sku" {
  description = "MySQL pricing tier. Burstable_B1ms is cheapest for dev"
  type        = string
  default     = "B_Standard_B1ms"
}


variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "asp-srs-prod"
}

variable "backend_app_name" {
  description = "Name of the backend Web App (globally unique)"
  type        = string
  default     = "backendapp-srs-prod"
}

variable "backend_image_tag" {
  description = "Docker image tag for the backend"
  type        = string
  default     = "latest"
}


variable "storage_account_name" {
  description = "Storage account name (globally unique, lowercase, 3-24 chars, no hyphens)"
  type        = string
  default     = "appstoragesrs"
}


variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
  default     = "agw-srs-prod"
}


variable "enable_waf" {
  description = <<-EOT
    Set to true to enable WAF_v2 tier with OWASP 3.2 ruleset.
    WARNING: Increases App Gateway cost by ~$20-30/month.
    Phase 1 / Student budget → false
    Phase 3 / Production    → true
  EOT
  type        = bool
  default     = false
}

variable "app_service_plan_sku" {
  description = <<-EOT
    App Service Plan pricing tier.
    "F1" = Free (no VNet integration, no always-on) — Phase 1
    "B1" = Basic (~$13/mo, supports VNet integration) — Phase 2+
  EOT
  type        = string
  default     = "B1"
}

variable "custom_domain" {
  description = "Your custom domain name used for the HTTPS listener (e.g. chaitanya-vek.me). Leave blank to skip HTTPS listener."
  type        = string
  default     = "chaitanya-vek.me"
}

variable "enable_ssl" {
  description = <<-EOT
    Set to true ONLY after you have uploaded an SSL certificate to Key Vault.
    Phase 1 (first apply)  → false  — deploys everything, HTTP only
    Phase 2 (after cert)   → true   — adds HTTPS listener + redirect
    Workflow:
      1. terraform apply (enable_ssl = false)
      2. Upload cert to Key Vault manually
      3. Set enable_ssl = true → terraform apply again
  EOT
  type        = bool
  default     = false
}

variable "ssl_cert_name" {
  description = "Name of the SSL certificate stored in Key Vault (must match the name used when importing the cert)"
  type        = string
  default     = "ssl-cert-srs"
}
