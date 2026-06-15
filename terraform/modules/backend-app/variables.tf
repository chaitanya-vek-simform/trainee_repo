variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "app_service_plan_sku" {
  type = string
}

variable "app_service_plan_name" {
  type    = string
  default = "asp-srs-prod"
}

variable "backend_app_name" {
  type    = string
  default = "backendapp-srs-prod"
}

variable "backend_image_tag" {
  type    = string
  default = "latest"
}

variable "backend_subnet_id" {
  type = string
}

variable "acr_login_server" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password_ref" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type = string
}

variable "port" {
  type    = string
  default = "5000"
}