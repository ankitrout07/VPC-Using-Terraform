# modules/acr/variables.tf

variable "project_name" {
  description = "Unique name to prefix all resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for ACR resources"
  type        = string
}

variable "sku" {
  description = "The SKU of the container registry (Basic, Standard, Premium)"
  type        = string
  default     = "Basic"
}

variable "admin_enabled" {
  description = "Whether the admin user is enabled"
  type        = bool
  default     = false
}
