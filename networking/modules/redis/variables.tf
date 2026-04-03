variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the Redis Private Endpoint"
  type        = string
}

variable "vnet_id" {
  description = "ID of the Virtual Network"
  type        = string
}
