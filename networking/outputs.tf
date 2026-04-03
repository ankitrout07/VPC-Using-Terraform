output "vnet_name" {
  description = "The name of the VNet"
  value       = module.networking.vnet_name
}

output "aks_cluster_name" {
  description = "Name of the Azure Kubernetes Service cluster"
  value       = module.aks.cluster_name
}

output "app_gateway_public_ip" {
  description = "Public IP of the Application Gateway"
  value       = module.app_gateway.public_ip
}

output "acr_login_server" {
  description = "The login server for the Azure Container Registry"
  value       = module.acr.login_server
}

output "db_server_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server (resolve inside VNet only)"
  value       = module.database.db_server_fqdn
}

output "app_subnet_ids" {
  description = "IDs of the private App tier subnets"
  value       = module.networking.app_subnet_ids
}

output "state_storage_account_name" {
  value       = azurerm_storage_account.tfstate.name
  description = "The name of the Azure Storage Account for Terraform state storage."
}

output "state_container_name" {
  value       = azurerm_storage_container.tfstate.name
  description = "The name of the Storage Container for Terraform state storage."
}

output "mgmt_resource_group_name" {
  value = azurerm_resource_group.tfstate.name
}

output "resource_group_name" {
  description = "The main resource group name"
  value       = module.networking.resource_group_name
}

output "redis_hostname" {
  description = "The hostname of the Redis instance"
  value       = module.redis.redis_hostname
}

output "redis_port" {
  description = "The SSL port of the Redis instance"
  value       = module.redis.redis_port
}

output "bastion_name" {
  description = "The name of the Bastion Host"
  value       = module.bastion.bastion_name
}
