variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "mysql_server_name" {
  type    = string
  default = "mysql-server-srs-prod"
}

variable "mysql_admin_username" {
  type = string
}

variable "mysql_admin_password" {
  type      = string
  sensitive = true
}

variable "mysql_sku" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "db_subnet_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "private_dns_zone_name" {
  type    = string
  default = "srs.private.mysql.database.azure.com"
}

variable "private_dns_zone_link_name" {
  type    = string
  default = "dns-link-mysql-srs-prod"
}

variable "database_name" {
  type    = string
  default = "db-srs-prod"
}