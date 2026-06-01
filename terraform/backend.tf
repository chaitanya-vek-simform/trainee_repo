resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  os_type = "Linux"

  sku_name = var.app_service_plan_sku

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_linux_web_app" "backend" {
  name                = var.backend_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  virtual_network_subnet_id = var.app_service_plan_sku == "F1" ? null : azurerm_subnet.backend.id

  app_settings = {
    DB_HOST       = azurerm_mysql_flexible_server.main.fqdn
    DB_USER       = var.mysql_admin_username
    DB_PASSWORD   = local.kv_db_password_ref
    DB_NAME       = azurerm_mysql_flexible_database.trainee_db.name
    PORT          = "5000"
    WEBSITES_PORT = "5000"

    DOCKER_ENABLE_CI = "true"

    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  }

  site_config {
    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name   = "${azurerm_container_registry.main.login_server}/trainee-backend:${var.backend_image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }

    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5  # Remove instance from pool after 5 min of failing health checks

    always_on = var.app_service_plan_sku == "F1" ? false : true
  }

  https_only = true
   
  identity {
    type = "SystemAssigned"
  }

  tags = {
    ManagedBy = "Terraform"
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  depends_on = [
    azurerm_service_plan.main,
    azurerm_mysql_flexible_server.main,
    azurerm_container_registry.main,
    azurerm_subnet_network_security_group_association.backend,
  ]
}
