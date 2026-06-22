variable "resource_group_name" {
  type        = string
  description = "Resource group where the ACR will be deployed"
}

variable "location" {
  type        = string
  description = "Azure region for the ACR"
}

variable "acr_name" {
  type        = string
  description = "Name of the Azure Container Registry (globally unique, lowercase, 5-50 chars)"
}

variable "acr_sku" {
  type        = string
  description = "ACR pricing tier: Basic (dev), Standard (prod), or Premium (geo-replication)"
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be one of: Basic, Standard, Premium."
  }
}