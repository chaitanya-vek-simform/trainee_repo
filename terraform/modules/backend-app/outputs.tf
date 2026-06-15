output "service_plan_id" {
  value = azurerm_service_plan.main.id
}

output "principal_id" {
  value = azurerm_linux_web_app.backend.identity[0].principal_id
}

output "default_hostname" {
  value = azurerm_linux_web_app.backend.default_hostname
}

output "name" {
  value = azurerm_linux_web_app.backend.name
}

output "id" {
  value = azurerm_linux_web_app.backend.id
}