variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "app_gateway_id" {
  type = string
}

variable "workspace_name" {
  type    = string
  default = "law-srs-prod"
}

variable "retention_in_days" {
  type    = number
  default = 30
}