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

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Project     = "app-srs-prod"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "azurerm_storage_account" "frontend" {
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.main.name
}

data "azurerm_key_vault" "main" {
  name                = "kv-srs-prod"
  resource_group_name = azurerm_resource_group.main.name
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  key_vault_id = data.azurerm_key_vault.main.id
}

locals {
  kv_db_password_ref = "@Microsoft.KeyVault(SecretUri=${data.azurerm_key_vault_secret.db_password.versionless_id})"
}

module "networking" {
  source = "./modules/networking"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  vnet_address_space    = var.vnet_address_space
  subnet_appgw_prefix   = var.subnet_appgw_prefix
  subnet_backend_prefix = var.subnet_backend_prefix
  subnet_db_prefix      = var.subnet_db_prefix
}

module "database" {
  source = "./modules/database"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  mysql_server_name    = var.mysql_server_name
  mysql_admin_username = var.mysql_admin_username
  mysql_admin_password = var.mysql_admin_password
  mysql_sku            = var.mysql_sku
  db_subnet_id         = module.networking.db_subnet_id
  vnet_id              = module.networking.vnet_id
}

module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  acr_name            = var.acr_name
}

module "backend_app" {
  source = "./modules/backend-app"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  app_service_plan_sku = var.app_service_plan_sku
  app_service_plan_name = var.app_service_plan_name
  backend_app_name     = var.backend_app_name
  backend_image_tag    = var.backend_image_tag
  backend_subnet_id    = module.networking.backend_subnet_id
  acr_login_server     = module.acr.login_server
  db_host              = module.database.hostname
  db_user              = var.mysql_admin_username
  db_password_ref      = local.kv_db_password_ref
  db_name              = module.database.database_name
}

resource "azurerm_role_assignment" "webapp_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.backend_app.principal_id
}

module "appgateway" {
  source = "./modules/appgateway"

  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  app_gateway_name          = var.app_gateway_name
  enable_waf                = var.enable_waf
  enable_ssl                = var.enable_ssl
  custom_domain             = var.custom_domain
  ssl_cert_name             = var.ssl_cert_name
  ssl_cert_secret_uri       = "${data.azurerm_key_vault.main.vault_uri}secrets/${var.ssl_cert_name}"
  key_vault_id              = data.azurerm_key_vault.main.id
  subnet_id                 = module.networking.appgw_subnet_id
  backend_app_fqdn          = module.backend_app.default_hostname
  frontend_storage_endpoint = data.azurerm_storage_account.frontend.primary_web_endpoint
}

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  app_gateway_id      = module.appgateway.id
}