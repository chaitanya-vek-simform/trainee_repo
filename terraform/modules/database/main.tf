resource "azurerm_private_dns_zone" "main" {
  name                = var.private_dns_zone_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = var.private_dns_zone_link_name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_mysql_flexible_server" "main" {
  name                = var.mysql_server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password

  version  = "8.0.21"
  sku_name = var.mysql_sku

  storage {
    size_gb = 20
  }

  delegated_subnet_id = var.db_subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.main.id

  backup_retention_days = 7

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_mysql_flexible_database" "main" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_mysql_flexible_server_firewall_rule" "azure_services" {
  name                = "AllowAzureServices"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name

  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
