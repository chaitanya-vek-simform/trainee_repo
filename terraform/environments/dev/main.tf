# ─────────────────────────────────────────────────────────────────────────────
# environments/dev/main.tf
#
# DEV environment root configuration.
# Provisions all infrastructure for the dev tier.
# Uses the SHARED ACR from the prod environment (reference via data source).
#
# Usage:
#   terraform init -backend-config=backend.hcl -reconfigure
#   terraform plan  -var-file=terraform.tfvars
#   terraform apply -var-file=terraform.tfvars
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  # Backend config is injected at init time via backend.hcl
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.74"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ── Resource Group ─────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ── Pre-existing Resources (Data Sources) ─────────────────────────────────────

# Frontend static website storage account (created manually — see README prerequisites)
data "azurerm_storage_account" "frontend" {
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.main.name
}

# Shared Key Vault for dev — stores dev DB password and SSL certs
data "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  resource_group_name = azurerm_resource_group.main.name
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  key_vault_id = data.azurerm_key_vault.main.id
}

# ── Shared ACR (owned by prod, referenced by dev) ─────────────────────────────
# Dev pushes images with the :dev tag; prod uses :latest / :stable
data "azurerm_container_registry" "shared" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

# ── Locals ────────────────────────────────────────────────────────────────────
locals {
  # Key Vault reference — DB password resolved at runtime by App Service identity
  kv_db_password_ref = "@Microsoft.KeyVault(SecretUri=${data.azurerm_key_vault_secret.db_password.versionless_id})"
}

# ── Module: Networking ─────────────────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  vnet_address_space    = var.vnet_address_space
  subnet_appgw_prefix   = var.subnet_appgw_prefix
  subnet_backend_prefix = var.subnet_backend_prefix
  subnet_db_prefix      = var.subnet_db_prefix

  # Environment-specific names — no hardcoded prod names
  vnet_name           = "vnet-srs-${var.environment}"
  subnet_appgw_name   = "subnet-appgw-srs-${var.environment}"
  subnet_backend_name = "subnet-backend-srs-${var.environment}"
  subnet_db_name      = "subnet-db-srs-${var.environment}"
  appgw_nsg_name      = "nsg-appgw-srs-${var.environment}"
  backend_nsg_name    = "nsg-backend-srs-${var.environment}"
  db_nsg_name         = "nsg-db-srs-${var.environment}"
}

# ── Module: Database ──────────────────────────────────────────────────────────
module "database" {
  source = "../../modules/database"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  mysql_server_name          = var.mysql_server_name
  mysql_admin_username       = var.mysql_admin_username
  mysql_admin_password       = var.mysql_admin_password
  mysql_sku                  = var.mysql_sku
  db_subnet_id               = module.networking.db_subnet_id
  vnet_id                    = module.networking.vnet_id

  # Environment-scoped DNS — prevents private DNS conflicts with prod
  private_dns_zone_name      = "srs-${var.environment}.private.mysql.database.azure.com"
  private_dns_zone_link_name = "dns-link-mysql-srs-${var.environment}"
  database_name              = "trainee_db"
}

# ── Module: Backend App Service ───────────────────────────────────────────────
module "backend_app" {
  source = "../../modules/backend-app"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  app_service_plan_sku  = var.app_service_plan_sku
  app_service_plan_name = var.app_service_plan_name
  backend_app_name      = var.backend_app_name
  backend_image_tag     = var.backend_image_tag
  backend_subnet_id     = module.networking.backend_subnet_id

  # Reference the shared ACR
  acr_login_server = data.azurerm_container_registry.shared.login_server

  db_host         = module.database.hostname
  db_user         = var.mysql_admin_username
  db_password_ref = local.kv_db_password_ref
  db_name         = module.database.database_name
}

# Grant dev App Service the AcrPull role on the SHARED ACR
resource "azurerm_role_assignment" "webapp_acr_pull" {
  scope                = data.azurerm_container_registry.shared.id
  role_definition_name = "AcrPull"
  principal_id         = module.backend_app.principal_id
}

# ── Module: Application Gateway ───────────────────────────────────────────────
module "appgateway" {
  source = "../../modules/appgateway"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  app_gateway_name      = var.app_gateway_name
  enable_waf            = var.enable_waf   # false for dev
  enable_ssl            = var.enable_ssl   # false for dev Phase 1
  custom_domain         = var.custom_domain
  ssl_cert_name         = var.ssl_cert_name
  ssl_cert_secret_uri   = "${data.azurerm_key_vault.main.vault_uri}secrets/${var.ssl_cert_name}"
  key_vault_id          = data.azurerm_key_vault.main.id
  subnet_id             = module.networking.appgw_subnet_id
  backend_app_fqdn      = module.backend_app.default_hostname
  frontend_storage_endpoint = data.azurerm_storage_account.frontend.primary_web_endpoint

  # Environment-specific resource names
  user_assigned_identity_name = "agw-identity-srs-${var.environment}"
  public_ip_name              = "pip-agw-srs-${var.environment}"
  waf_policy_name             = "waf-policy-srs-${var.environment}"
}

# ── Module: Monitoring ────────────────────────────────────────────────────────
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  app_gateway_id          = module.appgateway.id
  workspace_name          = "law-srs-${var.environment}"
  retention_in_days       = var.log_retention_days
  diagnostic_setting_name = "agw-diagnostics-srs-${var.environment}"
}
