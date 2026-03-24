# modules/acr/acr.tf

resource "random_string" "acr_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_container_registry" "main" {
  name                = "${lower(replace(var.project_name, "-", ""))}acr${random_string.acr_suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  tags = {
    Environment = "Production"
    Project     = var.project_name
  }
}
