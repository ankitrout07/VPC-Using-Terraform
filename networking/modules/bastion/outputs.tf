output "bastion_name" {
  description = "The name of the Bastion Host"
  value       = azurerm_bastion_host.bastion.name
}

output "bastion_public_ip" {
  description = "The public IP address of the Bastion Host"
  value       = azurerm_public_ip.bastion_ip.ip_address
}
