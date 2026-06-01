# ─────────────────────────────────────────────────────────────────────────────
# Key Vault — PRE-EXISTING (managed manually, not by Terraform)
#
# MANUAL SETUP REQUIRED before terraform apply:
#   az keyvault create --name kv-srs-prod --resource-group rg-srs-prod \
#     --location southeastasia --enable-rbac-authorization true
#   az keyvault secret set --vault-name kv-srs-prod \
#     --name db-password --value "<password>"
#
# Reason: Backend App Service references KV secret via KeyVault reference.
# The secret must exist BEFORE terraform creates the App Service.
# ─────────────────────────────────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "main" {
  name                = "kv-srs-prod"
  resource_group_name = azurerm_resource_group.main.name
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  key_vault_id = data.azurerm_key_vault.main.id
}

# ── Role Assignments ──────────────────────────────────────────────────────────
# Grant App Service Managed Identity access to read the DB password secret

resource "azurerm_role_assignment" "appservice_kv_secrets" {
  scope                = data.azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}

# Grant App Gateway Managed Identity access to read SSL cert from KV
resource "azurerm_role_assignment" "appgw_kv_secrets" {
  scope                = data.azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.appgw.principal_id
}

# ── Key Vault Reference for App Service app_settings ─────────────────────────
locals {
  kv_db_password_ref = "@Microsoft.KeyVault(SecretUri=${data.azurerm_key_vault_secret.db_password.versionless_id})"
}
