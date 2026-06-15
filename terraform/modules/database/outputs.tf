output "hostname" {
  value = azurerm_mysql_flexible_server.main.fqdn
}

output "name" {
  value = azurerm_mysql_flexible_server.main.name
}

output "database_name" {
  value = azurerm_mysql_flexible_database.main.name
}

output "id" {
  value = azurerm_mysql_flexible_server.main.id
}