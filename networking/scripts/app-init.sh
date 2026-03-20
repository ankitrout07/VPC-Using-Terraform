# Inside modules/compute/main.tf
resource "azurerm_linux_virtual_machine" "app_server" {
  name                = "Fortress-App-VM"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s" # Production minimum for Docker
  admin_username      = "ubuntu"
  
  # Injecting the Startup Script
  custom_data = base64encode(templatefile("${path.module}/../../scripts/app-init.sh", {
    db_fqdn = var.db_server_fqdn
  }))

  network_interface_ids = [azurerm_network_interface.app_nic.id]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS" # Production performance
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}