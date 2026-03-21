# modules/compute/variables.tf

variable "project_name" {
  description = "Unique name to prefix all resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for compute resources"
  type        = string
}

variable "vm_size" {
  description = "SKU size for the VMSS instances"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  description = "Admin username for SSH access"
  type        = string
  default     = "adminuser"
}

variable "app_subnet_ids" {
  description = "List of subnet IDs to place the VMSS NICs into"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of subnet IDs for the Bastion host NIC"
  type        = list(string)
}

variable "ssh_allowed_source" {
  description = "Source IP range allowed to SSH into Bastion"
  type        = string
  default     = "*"
}
