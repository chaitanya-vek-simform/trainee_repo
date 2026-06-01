resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-srs-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku               = "PerGB2018"
  retention_in_days = 30 # 30-day retention; increase for production

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_monitor_diagnostic_setting" "appgw" {
  name                       = "agw-diagnostics-srs-prod"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  depends_on = [azurerm_application_gateway.main]
}
