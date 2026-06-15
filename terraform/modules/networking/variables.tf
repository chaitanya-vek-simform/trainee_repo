variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_address_space" {
  type = string
}

variable "subnet_appgw_prefix" {
  type = string
}

variable "subnet_backend_prefix" {
  type = string
}

variable "subnet_db_prefix" {
  type = string
}

variable "vnet_name" {
  type    = string
  default = "vnet-srs-prod"
}

variable "subnet_appgw_name" {
  type    = string
  default = "subnet-appgw-srs-prod"
}

variable "subnet_backend_name" {
  type    = string
  default = "subnet-backend-srs-prod"
}

variable "subnet_db_name" {
  type    = string
  default = "subnet-db-srs-prod"
}

variable "appgw_nsg_name" {
  type    = string
  default = "nsg-appgw-srs-prod"
}

variable "backend_nsg_name" {
  type    = string
  default = "nsg-backend-srs-prod"
}

variable "db_nsg_name" {
  type    = string
  default = "nsg-db-srs-prod"
}