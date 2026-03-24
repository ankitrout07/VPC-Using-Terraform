# modules/aks/variables.tf

variable "project_name" {
  description = "Unique name to prefix all resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for AKS resources"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.30.3"
}

variable "node_vm_size" {
  description = "SKU for the AKS node pool VMs (Standard_B2s is 2 vCPU, 4GB RAM)"
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 1
}

variable "vnet_subnet_id" {
  description = "ID of the subnet where AKS nodes and pods will reside"
  type        = string
}
