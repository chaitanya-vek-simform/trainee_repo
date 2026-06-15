resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku          = "Basic"
  admin_enabled = true

  tags = {
    ManagedBy = "Terraform"
  }
}

output "login_server" {
  value = azurerm_container_registry.main.login_server
}

output "admin_username" {
  value     = azurerm_container_registry.main.admin_username
  sensitive = true
}

output "name" {
  value = azurerm_container_registry.main.name
}

output "id" {
  value = azurerm_container_registry.main.id
}
