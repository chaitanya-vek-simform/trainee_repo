resource "azurerm_user_assigned_identity" "appgw" {
  name                = "agw-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_web_application_firewall_policy" "main" {
  count               = var.enable_waf ? 1 : 0
  name                = "waf-policy-srs-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_public_ip" "appgw" {
  name                = "pip-agw-srs-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  allocation_method = "Static"
  sku               = "Standard"

  tags = {
    ManagedBy = "Terraform"
  }
}

locals {
  frontend_port_name = "port-http"
  frontend_ip_name   = "frontend-ip-config"
  listener_name      = "listener-http"

  backend_pool_backend  = "pool-backend"
  backend_pool_frontend = "pool-frontend"

  http_settings_backend  = "settings-backend"
  http_settings_frontend = "settings-frontend"

  url_path_map_name = "url-path-map"
  routing_rule_name = "rule-main"

  agw_sku_name = var.enable_waf ? "WAF_v2" : "Standard_v2"
  agw_sku_tier = var.enable_waf ? "WAF_v2" : "Standard_v2"

  storage_host = replace(
    replace(data.azurerm_storage_account.frontend.primary_web_endpoint, "https://", ""),
    "/",
    ""
  )

  custom_error_url_403 = "${data.azurerm_storage_account.frontend.primary_web_endpoint}waf-blocked.html"
  custom_error_url_502 = "${data.azurerm_storage_account.frontend.primary_web_endpoint}waf-502.html"

  ssl_cert_secret_uri = "${data.azurerm_key_vault.main.vault_uri}secrets/${var.ssl_cert_name}"
}

resource "azurerm_application_gateway" "main" {
  name                = var.app_gateway_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  firewall_policy_id = var.enable_waf ? azurerm_web_application_firewall_policy.main[0].id : null

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }

  sku {
    name     = local.agw_sku_name
    tier     = local.agw_sku_tier
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  dynamic "frontend_port" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name = "port-https"
      port = 443
    }
  }

  dynamic "ssl_certificate" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name                = var.ssl_cert_name
      key_vault_secret_id = local.ssl_cert_secret_uri
    }
  }

  custom_error_configuration {
    status_code           = "HttpStatus403"
    custom_error_page_url = local.custom_error_url_403
  }

  custom_error_configuration {
    status_code           = "HttpStatus502"
    custom_error_page_url = local.custom_error_url_502
  }

  backend_address_pool {
    name  = local.backend_pool_backend
    fqdns = ["${var.backend_app_name}.azurewebsites.net"]
  }

  backend_address_pool {
    name  = local.backend_pool_frontend
    fqdns = [local.storage_host]
  }

  probe {
    name                                      = "probe-backend-health"
    protocol                                  = "Https"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
  }

  backend_http_settings {
    name                                = local.http_settings_backend
    cookie_based_affinity               = "Disabled"
    protocol                            = "Https"
    port                                = 443
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "probe-backend-health"
  }

  backend_http_settings {
    name                                = local.http_settings_frontend
    cookie_based_affinity               = "Disabled"
    protocol                            = "Https"
    port                                = 443
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  dynamic "http_listener" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name                           = "listener-https"
      frontend_ip_configuration_name = local.frontend_ip_name
      frontend_port_name             = "port-https"
      protocol                       = "Https"
      ssl_certificate_name           = var.ssl_cert_name
      host_name                      = var.custom_domain
    }
  }

  dynamic "redirect_configuration" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name                 = "redirect-http-to-https"
      redirect_type        = "Permanent"
      target_listener_name = "listener-https"
      include_path         = true
      include_query_string = true
    }
  }

  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = local.backend_pool_frontend
    default_backend_http_settings_name = local.http_settings_frontend

    path_rule {
      name                       = "api-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = local.backend_pool_backend
      backend_http_settings_name = local.http_settings_backend
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.enable_ssl ? [] : [1]
    content {
      name               = local.routing_rule_name
      rule_type          = "PathBasedRouting"
      http_listener_name = local.listener_name
      url_path_map_name  = local.url_path_map_name
      priority           = 100
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name                        = local.routing_rule_name
      rule_type                   = "Basic"
      http_listener_name          = local.listener_name
      redirect_configuration_name = "redirect-http-to-https"
      priority                    = 100
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name               = "rule-https"
      rule_type          = "PathBasedRouting"
      http_listener_name = "listener-https"
      url_path_map_name  = local.url_path_map_name
      priority           = 90
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }

  depends_on = [
    azurerm_public_ip.appgw,
    azurerm_subnet.appgw,
    azurerm_linux_web_app.backend,
    data.azurerm_storage_account.frontend,
    azurerm_user_assigned_identity.appgw,
  ]
}
