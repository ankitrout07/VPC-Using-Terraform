# modules/networking/outputs.tf

output "vnet_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_id" {
  description = "The resource ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public (Tier 1) subnets"
  value       = azurerm_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "IDs of the private app (Tier 2) subnets"
  value       = azurerm_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "IDs of the isolated DB (Tier 3) subnets"
  value       = azurerm_subnet.db[*].id
}

output "gateway_subnet_id" {
  description = "ID of the Application Gateway (Tier 4) subnet"
  value       = azurerm_subnet.gateway.id
}

output "gateway_subnet_id" {
  description = "ID of the Application Gateway (Tier 4) subnet"
  value       = azurerm_subnet.gateway.id
}

output "resource_group_name" {
  description = "Name of the shared resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the shared resource group"
  value       = azurerm_resource_group.main.location
}
