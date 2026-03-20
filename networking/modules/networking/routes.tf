# routes.tf

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat_pip" {
  name                = "${var.project_name}-nat-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NAT Gateway for App Tier (Private)
resource "azurerm_nat_gateway" "main" {
  name                = "${var.project_name}-nat-gw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

# Associate NAT Gateway with App Subnets
resource "azurerm_subnet_nat_gateway_association" "app" {
  count          = 2
  subnet_id      = azurerm_subnet.app[count.index].id
  nat_gateway_id = azurerm_nat_gateway.main.id
}