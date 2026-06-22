variable "resource_group_name" {
  type        = string
  description = "Resource group for the Log Analytics Workspace"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "app_gateway_id" {
  type        = string
  description = "Resource ID of the Application Gateway to configure diagnostics for"
}

variable "workspace_name" {
  type        = string
  description = "Name of the Log Analytics Workspace"
}

variable "retention_in_days" {
  type        = number
  description = "Log retention period in days (min 30, max 730)"
  default     = 30
}

variable "diagnostic_setting_name" {
  type        = string
  description = "Name of the Monitor Diagnostic Setting for the App Gateway"
}