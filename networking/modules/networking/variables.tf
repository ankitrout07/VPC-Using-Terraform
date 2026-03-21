# modules/networking/variables.tf

variable "project_name" {
  description = "Unique name to prefix all resources"
  type        = string
}

variable "location" {
  description = "Azure region to deploy in"
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR block for the virtual network"
  type        = string
}

variable "ssh_allowed_source" {
  description = "Source IP range allowed to SSH into Bastion"
  type        = string
  default     = "*"
}
