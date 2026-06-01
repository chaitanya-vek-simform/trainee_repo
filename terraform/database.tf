resource "azurerm_mysql_flexible_server" "main" {
  name                = var.mysql_server_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password

  version = "8.0.21"

  sku_name = var.mysql_sku

  storage {
    size_gb = 20 # Minimum allowed by Azure MySQL Flexible Server
  }

  delegated_subnet_id = azurerm_subnet.db.id
  private_dns_zone_id = azurerm_private_dns_zone.dnszone-mysql-srs-prod.id

  backup_retention_days = 7

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_mysql_flexible_database" "trainee_db" {
  name                = "db-srs-prod"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_mysql_flexible_server_firewall_rule" "azure_services" {
  name                = "AllowAzureServices"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name

  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
