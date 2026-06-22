# ─────────────────────────────────────────────────────────────────────────────
# environments/dev/outputs.tf — DEV environment outputs
# ─────────────────────────────────────────────────────────────────────────────

output "app_gateway_ip" {
  description = "Public IP of the dev Application Gateway"
  value       = module.appgateway.public_ip
}

output "app_gateway_name" {
  description = "Application Gateway resource name"
  value       = module.appgateway.name
}

output "shared_acr_login_server" {
  description = "Shared ACR login server — tag dev images: <login_server>/trainee-backend:dev"
  value       = data.azurerm_container_registry.shared.login_server
}

output "mysql_host" {
  description = "MySQL server FQDN — use as DB_HOST in dev backend"
  value       = module.database.hostname
}

output "mysql_server_name" {
  description = "MySQL server resource name"
  value       = module.database.name
}

output "mysql_admin_username" {
  description = "MySQL admin username"
  value       = var.mysql_admin_username
}

output "backend_url" {
  description = "Direct URL of the dev backend App Service (for testing)"
  value       = "https://${module.backend_app.default_hostname}"
}

output "storage_account_name" {
  description = "Frontend storage account name — needed to upload frontend files"
  value       = data.azurerm_storage_account.frontend.name
}

output "frontend_url" {
  description = "Direct URL of the dev frontend static website"
  value       = data.azurerm_storage_account.frontend.primary_web_endpoint
}

output "resource_group_name" {
  description = "Dev resource group name"
  value       = azurerm_resource_group.main.name
}

output "key_vault_uri" {
  description = "Dev Key Vault URI"
  value       = data.azurerm_key_vault.main.vault_uri
}

output "backend_principal_id" {
  description = "App Service Managed Identity Principal ID — should match KV access policy"
  value       = module.backend_app.principal_id
}

output "monitoring_workspace_id" {
  description = "Log Analytics Workspace ID for dev"
  value       = module.monitoring.workspace_id
}

# ── Helper Commands ───────────────────────────────────────────────────────────

output "cmd_push_dev_image" {
  description = "Command to build and push the dev backend Docker image to the shared ACR"
  value       = "az acr build --registry ${data.azurerm_container_registry.shared.name} --image trainee-backend:dev ./trainee_backend"
}

output "cmd_upload_frontend" {
  description = "Command to upload the built dev frontend to the Storage Account"
  value       = "az storage blob upload-batch --account-name ${data.azurerm_storage_account.frontend.name} --source ./trainee_frontend/dist --destination '$web' --overwrite"
}
