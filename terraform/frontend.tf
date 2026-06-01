# ─────────────────────────────────────────────────────────────────────────────
# Storage Account — PRE-EXISTING (managed manually, not by Terraform)
#
# MANUAL SETUP REQUIRED before terraform apply:
#   1. az storage account create --name appstoragesrs ...
#   2. az storage blob service-properties update --static-website ...
#   3. Upload waf-blocked.html and waf-502.html to $web container
#
# Reason: App Gateway validates custom error page URLs during creation.
# The files must exist BEFORE terraform creates the App Gateway.
# ─────────────────────────────────────────────────────────────────────────────

data "azurerm_storage_account" "frontend" {
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.main.name
}
