output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "backend_subnet_id" {
  value = azurerm_subnet.backend.id
}

output "db_subnet_id" {
  value = azurerm_subnet.db.id
}

output "appgw_subnet_prefix" {
  value = var.subnet_appgw_prefix
}

output "backend_subnet_prefix" {
  value = var.subnet_backend_prefix
}

output "db_subnet_prefix" {
  value = var.subnet_db_prefix
}