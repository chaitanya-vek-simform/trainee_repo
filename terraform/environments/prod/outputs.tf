# ─────────────────────────────────────────────────────────────────────────────
# environments/prod/outputs.tf — PROD environment outputs
# ─────────────────────────────────────────────────────────────────────────────

output "app_gateway_ip" {
  description = "Public IP of the prod Application Gateway — point your DNS A record here"
  value       = module.appgateway.public_ip
}

output "app_gateway_name" {
  description = "Application Gateway resource name"
  value       = module.appgateway.name
}

output "shared_acr_login_server" {
  description = "Shared ACR login server URL — used by BOTH prod and dev for image push/pull"
  value       = module.acr.login_server
}

output "shared_acr_name" {
  description = "Shared ACR resource name — pass this to dev as acr_name in tfvars"
  value       = module.acr.name
}

output "shared_acr_id" {
  description = "Shared ACR resource ID"
  value       = module.acr.id
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = module.acr.admin_username
  sensitive   = true
}

output "mysql_host" {
  description = "MySQL server FQDN — use as DB_HOST in prod backend"
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
  description = "Direct URL of the prod backend App Service (for internal testing only)"
  value       = "https://${module.backend_app.default_hostname}"
}

output "storage_account_name" {
  description = "Frontend storage account name — needed to upload frontend assets"
  value       = data.azurerm_storage_account.frontend.name
}

output "frontend_url" {
  description = "Direct URL of the prod frontend static website"
  value       = data.azurerm_storage_account.frontend.primary_web_endpoint
}

output "resource_group_name" {
  description = "Prod resource group name"
  value       = azurerm_resource_group.main.name
}

output "key_vault_uri" {
  description = "Prod Key Vault URI"
  value       = data.azurerm_key_vault.main.vault_uri
}

output "backend_principal_id" {
  description = "App Service Managed Identity Principal ID — should match Key Vault access policy"
  value       = module.backend_app.principal_id
}

output "appgateway_identity_principal_id" {
  description = "App Gateway User-Assigned Identity Principal ID — should have Key Vault Secrets User role"
  value       = module.appgateway.identity_principal_id
}

output "monitoring_workspace_id" {
  description = "Log Analytics Workspace ID for prod"
  value       = module.monitoring.workspace_id
}

# ── Helper Commands ───────────────────────────────────────────────────────────

output "cmd_push_prod_image" {
  description = "Command to build and push the prod backend Docker image to the shared ACR"
  value       = "az acr build --registry ${module.acr.name} --image trainee-backend:latest ./trainee_backend"
}

output "cmd_push_dev_image" {
  description = "Command to build and push the dev backend Docker image to the shared ACR"
  value       = "az acr build --registry ${module.acr.name} --image trainee-backend:dev ./trainee_backend"
}

output "cmd_upload_frontend" {
  description = "Command to upload the built prod frontend to the Storage Account"
  value       = "az storage blob upload-batch --account-name ${data.azurerm_storage_account.frontend.name} --source ./trainee_frontend/dist --destination '$web' --overwrite"
}
