# vpc.tf

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# --- TIER 1: PUBLIC ---
resource "azurerm_subnet" "public" {
  count                = 2
  name                 = "${var.project_name}-public-subnet-${count.index}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, count.index)]
}

# --- TIER 2: PRIVATE APP ---
resource "azurerm_subnet" "app" {
  count                = 2
  name                 = "${var.project_name}-app-subnet-${count.index}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, count.index + 10)]
}

# --- TIER 3: ISOLATED DB ---
resource "azurerm_subnet" "db" {
  count                = 2
  name                 = "${var.project_name}-db-subnet-${count.index}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, count.index + 20)]
}

# --- TIER 4: GATEWAY ---
resource "azurerm_subnet" "gateway" {
  name                 = "${var.project_name}-gateway-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, 40)] # 10.0.40.0/24
}

# --- TIER 5: BASTION ---
# Must be named exactly 'AzureBastionSubnet'
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, 50)] # 10.0.50.0/24
}

# --- TIER 6: REDIS / PRIVATE SERVICES ---
resource "azurerm_subnet" "redis" {
  name                 = "${var.project_name}-redis-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, 30)] # 10.0.30.0/24
}