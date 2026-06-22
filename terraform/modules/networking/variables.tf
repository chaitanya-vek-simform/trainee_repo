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
  type        = string
  description = "Name of the Virtual Network"
}

variable "subnet_appgw_name" {
  type        = string
  description = "Name of the Application Gateway subnet"
}

variable "subnet_backend_name" {
  type        = string
  description = "Name of the Backend App Service subnet"
}

variable "subnet_db_name" {
  type        = string
  description = "Name of the Database subnet"
}

variable "appgw_nsg_name" {
  type        = string
  description = "Name of the Application Gateway NSG"
}

variable "backend_nsg_name" {
  type        = string
  description = "Name of the Backend NSG"
}

variable "db_nsg_name" {
  type        = string
  description = "Name of the Database NSG"
}