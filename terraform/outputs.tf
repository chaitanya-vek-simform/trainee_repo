output "app_gateway_ip" {
  description = "Public IP of Application Gateway — this is your app's URL"
  value       = module.appgateway.public_ip
}

output "app_gateway_name" {
  description = "Application Gateway resource name"
  value       = module.appgateway.name
}

output "acr_login_server" {
  description = "ACR login server URL — use this to tag and push Docker images"
  value       = module.acr.login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = module.acr.admin_username
  sensitive   = true
}

output "mysql_host" {
  description = "MySQL server FQDN — use as DB_HOST in the backend"
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
  description = "Direct URL of the backend App Service (for testing only)"
  value       = "https://${module.backend_app.default_hostname}"
}

output "storage_account_name" {
  description = "Storage account name — needed to upload frontend files"
  value       = data.azurerm_storage_account.frontend.name
}

output "frontend_url" {
  description = "Direct URL of the frontend static website"
  value       = data.azurerm_storage_account.frontend.primary_web_endpoint
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "backend_push_command" {
  description = "Command to build and push backend Docker image to ACR"
  value       = "az acr build --registry ${module.acr.name} --image trainee-backend:latest ./trainee_backend"
}

output "frontend_upload_command" {
  description = "Command to upload built frontend files to Storage Account"
  value       = "az storage blob upload-batch --account-name ${data.azurerm_storage_account.frontend.name} --source ./trainee_frontend/dist --destination '$web' --overwrite"
}

output "key_vault_uri" {
  description = "Key Vault URI — use to check secrets are stored correctly"
  value       = data.azurerm_key_vault.main.vault_uri
}

output "backend_principal_id" {
  description = "App Service Managed Identity Principal ID — should match Key Vault access policy"
  value       = module.backend_app.principal_id
}
