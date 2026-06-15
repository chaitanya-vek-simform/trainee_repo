variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "app_gateway_name" {
  type    = string
  default = "agw-srs-prod"
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "enable_ssl" {
  type    = bool
  default = false
}

variable "custom_domain" {
  type    = string
  default = ""
}

variable "ssl_cert_name" {
  type    = string
  default = "ssl-cert-srs"
}

variable "ssl_cert_secret_uri" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "backend_app_fqdn" {
  type = string
}

variable "frontend_storage_endpoint" {
  type = string
}

variable "user_assigned_identity_name" {
  type    = string
  default = "agw-identity"
}

variable "public_ip_name" {
  type    = string
  default = "pip-agw-srs-prod"
}

variable "waf_policy_name" {
  type    = string
  default = "waf-policy-srs-prod"
}