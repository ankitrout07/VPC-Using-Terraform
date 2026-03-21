# main.tf - Root module: wires networking, compute and database together.

# ── Networking module ──────────────────────────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  location           = var.location
  vnet_address_space = var.vnet_address_space
  ssh_allowed_source = var.ssh_allowed_source
}

# ── Compute module ─────────────────────────────────────────────────────────────
module "compute" {
  source = "./modules/compute"

  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  app_subnet_ids      = module.networking.app_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  ssh_allowed_source  = var.ssh_allowed_source
}

# ── Database module ────────────────────────────────────────────────────────────
module "database" {
  source = "./modules/database"

  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  db_name             = var.db_name
  admin_username      = var.admin_username
  db_password         = var.db_password
  db_subnet_ids       = module.networking.db_subnet_ids
  vnet_id             = module.networking.vnet_id
}
