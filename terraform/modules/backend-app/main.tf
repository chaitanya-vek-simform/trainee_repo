resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location

  os_type  = "Linux"
  sku_name = var.app_service_plan_sku

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_linux_web_app" "backend" {
  name                = var.backend_app_name
  resource_group_name  = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.main.id

  virtual_network_subnet_id = var.app_service_plan_sku == "F1" ? null : var.backend_subnet_id

  app_settings = {
    DB_HOST       = var.db_host
    DB_USER       = var.db_user
    DB_PASSWORD   = var.db_password_ref
    DB_NAME       = var.db_name
    PORT          = var.port
    WEBSITES_PORT = var.port

    DOCKER_ENABLE_CI = "true"

    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  }

  site_config {
    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name   = "${var.acr_login_server}/trainee-backend:${var.backend_image_tag}"
      docker_registry_url = "https://${var.acr_login_server}"
    }

    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5

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
}
