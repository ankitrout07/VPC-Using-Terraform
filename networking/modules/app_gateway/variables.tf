# modules/app_gateway/variables.tf

variable "project_name" {
  description = "Unique name to prefix all resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for Application Gateway resources"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the dedicated subnet for the Application Gateway"
  type        = string
}

variable "sku_name" {
  description = "The SKU name of the Application Gateway"
  type        = string
  default     = "Standard_v2"
}

variable "sku_tier" {
  description = "The SKU tier of the Application Gateway"
  type        = string
  default     = "Standard_v2"
}

variable "capacity" {
  description = "The capacity (instance count) of the Application Gateway"
  type        = number
  default     = 1
}
