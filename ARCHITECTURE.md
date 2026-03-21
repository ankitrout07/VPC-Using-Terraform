# Fortress VNet — Project Architecture Deep Dive

This document walks through **every file and every component** in the project so you can understand exactly what each piece does, why it exists, and how it all fits together.

---

## Table of Contents

1. [Big Picture — How Everything Connects](#1-big-picture)
2. [Root Level Files](#2-root-level-files)
3. [backend-init/ — Remote State Backend](#3-backend-init)
4. [networking/ — Root Module](#4-networking-root-module)
5. [Module: networking — VNet, Subnets, NSGs, Routes](#5-module-networking)
6. [Module: compute — Load Balancer, VMSS, Bastion, Webpage](#6-module-compute)
7. [Module: database — PostgreSQL, Private DNS](#7-module-database)
8. [.github/workflows/ — CI/CD Pipeline](#8-github-actions-cicd)
9. [How Data Flows Between Modules](#9-how-data-flows-between-modules)
10. [Azure Concepts Explained Simply](#10-azure-concepts-explained-simply)

---

## 1. Big Picture

Before diving into files, here's how **everything connects**:

```
You (Terraform CLI or GitHub Actions)
         │
         │  terraform apply
         ▼
 networking/main.tf  ← ROOT: calls all 3 modules
    │         │         │
    ▼         ▼         ▼
module      module    module
networking  compute   database
    │           │         │
    │  passes   │  passes │
    │  subnet   │  RG     │
    │  IDs ─────┘  name ──┘
    ▼
Azure Resources Created:
  VNet, Subnets, NSGs, NAT Gateway
  Load Balancer, VMSS, Bastion VM
  PostgreSQL Server, Private DNS Zone
```

**Terraform state** is stored in Azure Blob Storage (set up by `backend-init/`).

---

## 2. Root Level Files

### `README.md`
The entry point for anyone visiting the repo on GitHub. Explains the project purpose, architecture overview, project structure map, and a quick start. Points to `HOW_TO_RUN.md` for details.

### `HOW_TO_RUN.md`
The authoritative step-by-step deployment guide. Covers:
- Local prerequisites (Terraform, Azure CLI, SSH key)
- Bootstrapping the remote backend
- Deploying the infrastructure
- Accessing the VM webpage, Bastion SSH, and PostgreSQL
- GitHub Actions CI/CD setup
- Teardown instructions

### `.gitignore`
Tells Git what NOT to track. Key exclusions:
- `*.tfstate`, `*.tfstate.backup` — state files contain sensitive infra data
- `.terraform/` — downloaded provider plugins (large, reproducible)
- `*.tfvars` — contains secrets like `db_password`
- `*.tfplan` — plan binaries

---

## 3. `backend-init/` — Remote State Backend

> **Purpose**: Before you can deploy the actual infrastructure, you need somewhere to store Terraform's state file securely. This directory creates that storage.

### `backend-init/main.tf`
The only Terraform config file in this folder. It creates 3 Azure resources:

| Resource | What it is | Why |
|---|---|---|
| `azurerm_resource_group.tfstate` | A logical container for Azure resources | Groups all backend resources together |
| `random_string.storage_account_name` | Generates a random 16-char suffix | Storage account names must be globally unique across all of Azure |
| `azurerm_storage_account.tfstate` | Azure Blob Storage account | The actual storage where `terraform.tfstate` is kept |
| `azurerm_storage_container.tfstate` | A container (like a folder) inside the storage account | Organises state files by project |

**Key config detail:**
```hcl
account_replication_type = "LRS"  # Locally Redundant Storage — 3 copies in same datacenter
container_access_type    = "private"  # Nobody can access this publicly
```

### `backend-init/outputs.tf`
Prints useful values after `terraform apply` so you can copy them into the next step:
- `storage_account_name` — you paste this into `networking/provider.tf`
- `resource_group_name` — the RG holding the backend
- `container_name` — always `tfstate`

---

## 4. `networking/` — Root Module

> **Purpose**: This is the "orchestrator" — it declares which modules to use and wires them together by passing values between them.

### `networking/provider.tf`
Tells Terraform two things:

**1. Which provider plugin to use:**
```hcl
required_providers {
  azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
}
```
The `azurerm` provider is what translates your HCL code into actual Azure API calls. `~> 3.0` means "any 3.x version" (won't auto-upgrade to v4 which may have breaking changes).

**2. Where to store state (remote backend):**
```hcl
# backend "azurerm" {  ← Uncomment this before deploying!
#   storage_account_name = "<from backend-init output>"
#   ...
# }
```
When commented out → state saved locally in `terraform.tfstate`.
When active → state saved in Azure Blob Storage (safe, shareable, lockable).

### `networking/variables.tf`
Declares all the configuration knobs that can be tuned. Every variable here can be set in `terraform.tfvars` or overridden on the CLI.

| Variable | Default | Purpose |
|---|---|---|
| `location` | `Central India` | Which Azure region to deploy in |
| `vnet_address_space` | `10.0.0.0/16` | The IP range for the entire virtual network |
| `project_name` | `Fortress-VNet` | Prefix added to every resource name |
| `vm_size` | `Standard_D2s_v3` | CPU/RAM size for VMSS app instances |
| `db_name` | `fortressdb` | Name of the PostgreSQL database |
| `admin_username` | `adminuser` | SSH username for all VMs |
| `admin_password` | `ChangeMe123!` | VM password (SSH keys are also used) |
| `db_password` | _(no default — required)_ | PostgreSQL admin password. Must be supplied via tfvars or secret |
| `ssh_allowed_source` | `*` | Which IP can SSH to the Bastion (use your IP in production!) |

### `networking/terraform.tfvars`
The actual values you supply for the variables above. This file is **gitignored** because it contains the database password. Never commit this.
```hcl
location           = "Central India"
vnet_address_space = "10.0.0.0/16"
project_name       = "Fortress-VNet"
db_password        = "SuperSecretPassword123!"
```

### `networking/main.tf`
**The most important file.** It's the glue. It calls the three modules and passes data between them:

```hcl
module "networking" { ... }           # Creates VNet, subnets, NSGs

module "compute" {
  app_subnet_ids = module.networking.app_subnet_ids  # Uses networking's output
}

module "database" {
  vnet_id = module.networking.vnet_id   # Uses networking's output
}
```
Without this file, none of the modules would be called and nothing would be deployed.

### `networking/outputs.tf`
After deployment, Terraform prints these to your terminal:
- `lb_public_ip` — paste into your browser to see the webpage
- `bastion_public_ip` — SSH address to reach private VMs
- `db_server_fqdn` — PostgreSQL hostname (only reachable inside the VNet)
- `vnet_name` — name of the created VNet
- `app_subnet_ids` — list of app subnet IDs

---

## 5. Module: `networking` — VNet, Subnets, NSGs, NAT

> **Purpose**: Creates the network foundation everything else sits on — the VNet, all subnets, security rules, and NAT Gateway.

### `modules/networking/variables.tf`
Declares what this module needs from the outside:
- `project_name`, `location`, `vnet_address_space`, `ssh_allowed_source`

### `modules/networking/vpc.tf`
Creates the core network infrastructure:

| Resource | What it does |
|---|---|
| `azurerm_resource_group.main` | One RG for the entire project. All resources go here. |
| `azurerm_virtual_network.main` | The VNet — a private isolated network in Azure using `10.0.0.0/16` |
| `azurerm_subnet.public[0..1]` | 2 public subnets: `10.0.0.0/24` and `10.0.1.0/24` — for LB and Bastion |
| `azurerm_subnet.app[0..1]` | 2 app subnets: `10.0.10.0/24` and `10.0.11.0/24` — private, for VMSS |
| `azurerm_subnet.db[0..1]` | 2 DB subnets: `10.0.20.0/24` and `10.0.21.0/24` — isolated, for PostgreSQL |

**Why `count = 2` for each?** For high availability across 2 availability zones. Even if one zone goes down, the other keeps running.

**How `cidrsubnet` works:**
```hcl
cidrsubnet("10.0.0.0/16", 8, 0)   # → 10.0.0.0/24  (public subnet 0)
cidrsubnet("10.0.0.0/16", 8, 1)   # → 10.0.1.0/24  (public subnet 1)
cidrsubnet("10.0.0.0/16", 8, 10)  # → 10.0.10.0/24 (app subnet 0)
cidrsubnet("10.0.0.0/16", 8, 20)  # → 10.0.20.0/24 (db subnet 0)
```

### `modules/networking/security.tf`
Creates 4 NSGs (Network Security Groups — like firewalls) and attaches them to subnets:

**ALB NSG** (on public subnets):
- ✅ Allow HTTP port 80 from anywhere
- ✅ Allow HTTPS port 443 from anywhere
- ✅ Allow SSH port 22 from `ssh_allowed_source`

**App NSG** (on app subnets):
- ✅ Allow HTTP port 80 from `VirtualNetwork` only (not internet)
- ✅ Allow port 8080 from `VirtualNetwork` (e.g. for app servers)
- ✅ Allow SSH port 22 from `VirtualNetwork` (only from Bastion)

**DB NSG** (on DB subnets):
- ✅ Allow PostgreSQL port 5432 from `VirtualNetwork` (app tier only)
- ❌ Deny ALL other inbound traffic (explicit deny-all at priority 4096)

**Bastion NSG** (on Bastion VM NIC):
- ✅ Allow SSH port 22 from `ssh_allowed_source`

### `modules/networking/routes.tf`
Creates the NAT Gateway for the App tier's outbound internet access:

| Resource | What it does |
|---|---|
| `azurerm_public_ip.nat_pip` | A static public IP for the NAT Gateway |
| `azurerm_nat_gateway.main` | The NAT Gateway — translates private IPs to public for egress |
| `azurerm_nat_gateway_public_ip_association` | Links the IP to the gateway |
| `azurerm_subnet_nat_gateway_association.app` | Attaches the NAT Gateway to both app subnets |

**Why NAT Gateway?** App VMs have no public IP. Without NAT, they can't reach the internet at all (can't run `apt-get`, pull Docker images, etc.). NAT lets them reach out but nothing can reach in.

### `modules/networking/outputs.tf`
Exports values the other modules need:
- `vnet_id`, `vnet_name`
- `public_subnet_ids` → used by compute module (Bastion NIC)
- `app_subnet_ids` → used by compute module (VMSS NIC)
- `db_subnet_ids` → used by database module
- `resource_group_name`, `resource_group_location`

---

## 6. Module: `compute` — Load Balancer, VMSS, Bastion, Webpage

> **Purpose**: Deploys all the compute resources — the Load Balancer that receives traffic, the auto-scaling VM group that serves the webpage, and the Bastion jump host for SSH access.

### `modules/compute/variables.tf`
What this module receives:
- `project_name`, `location`, `resource_group_name`
- `vm_size`, `admin_username`, `ssh_allowed_source`
- `app_subnet_ids` — where to put VMSS NICs
- `public_subnet_ids` — where to put Bastion NIC

### `modules/compute/compute.tf`
Creates all compute resources:

**Load Balancer setup (3 resources work together):**
```
Internet → azurerm_public_ip.lb_pip (Static Public IP)
         → azurerm_lb.main (Standard Load Balancer)
         → azurerm_lb_backend_address_pool.app_pool (group of VMs)
         → azurerm_lb_rule.http (route port 80 to VMs)
         → azurerm_lb_probe.http_probe (health check: GET / on port 80)
```
The probe checks every VM every 5 seconds. If a VM fails the health check, the LB stops sending it traffic.

**Virtual Machine Scale Set (VMSS):**
```hcl
instances = 2            # Run 2 VMs at all times
sku       = var.vm_size  # Standard_D2s_v3 = 2 vCPU, 8GB RAM

custom_data = filebase64("${path.module}/init.sh")  # Run init.sh on first boot
```
The VMSS automatically registers both instances with the load balancer backend pool.

**Bastion Host:**
A regular single VM (`Standard_B1s` — cheap, just a jump box) with a Public IP. You SSH into this first, then SSH from here into the private app VMs.

### `modules/compute/init.sh`
A shell script that runs **automatically on first boot** of every VMSS instance (via Azure cloud-init). It:
1. Runs `apt-get update && apt-get install -y nginx`
2. Enables and starts Nginx
3. Writes the full Fortress VNet dashboard HTML to `/var/www/html/index.html`
4. Reloads Nginx to serve the page

This is how **the webpage gets deployed without any manual steps.**

### `modules/compute/outputs.tf`
- `lb_public_ip` → printed in root outputs so you can open it in a browser
- `bastion_public_ip` → printed so you can SSH in
- `vmss_id` → resource ID of the scale set

---

## 7. Module: `database` — PostgreSQL, Private DNS

> **Purpose**: Deploys a fully isolated PostgreSQL Flexible Server that's only reachable from within the VNet. No public internet access at all.

### `modules/database/variables.tf`
What this module receives:
- `project_name`, `location`, `resource_group_name`
- `db_name`, `admin_username`, `db_password`
- `db_subnet_ids` — existing subnets (for reference)
- `vnet_id` — needed to link the Private DNS Zone

### `modules/database/database.tf`
Creates the database layer in 5 steps:

**Step 1 — Random suffix:**
```hcl
random_string.db_suffix  # e.g. "a3f9kz"
```
PostgreSQL server names must be globally unique across all of Azure. Appending a random string guarantees no collisions.

**Step 2 — Dedicated delegated subnet:**
```hcl
azurerm_subnet.postgres_delegated  # 10.0.30.0/24
delegation {
  service_delegation { name = "Microsoft.DBforPostgreSQL/flexibleServers" }
}
```
PostgreSQL Flexible Server **requires its own dedicated subnet** with a delegation. It can't share a subnet with VMs. The delegation grants the PostgreSQL service permission to inject network interfaces into this subnet.

**Step 3 — Private DNS Zone:**
```hcl
azurerm_private_dns_zone.postgres
# name: "fortress-vnet-a3f9kz.private.postgres.database.azure.com"
```
When your app connects to `fortress-vnet-a3f9kz.private.postgres.database.azure.com`, this DNS zone resolves it to the server's **private IP** (10.0.30.x). No public DNS record exists.

**Step 4 — VNet Link:**
```hcl
azurerm_private_dns_zone_virtual_network_link.postgres
```
Links the Private DNS Zone to your VNet so that only VMs inside your VNet can resolve the PostgreSQL hostname. VMs outside the VNet get no DNS response.

**Step 5 — PostgreSQL Flexible Server:**
```hcl
azurerm_postgresql_flexible_server.db {
  version              = "15"       # Latest stable PostgreSQL
  sku_name             = "B_Standard_B1ms"  # 1 vCore, 2GB RAM — dev/staging size
  storage_mb           = 32768      # 32GB storage
  backup_retention_days = 7         # 7 days of automatic backups
}
```

**Step 6 — Database:**
```hcl
azurerm_postgresql_flexible_server_database.main {
  name    = var.db_name   # "fortressdb"
  charset = "utf8"
}
```

### `modules/database/outputs.tf`
- `db_server_fqdn` → the internal hostname (only resolvable inside VNet)
- `db_server_name` → just the server name
- `db_name` → database name

---

## 8. `.github/workflows/deploy.yml` — CI/CD Pipeline

> **Purpose**: Automates `terraform plan` and `terraform apply` so you don't have to run them manually every time you make a change.

### Triggers
```yaml
on:
  push:        { branches: [main], paths: ['networking/**'] }
  pull_request: { branches: [main], paths: ['networking/**'] }
```
Only runs when files inside `networking/` change. Pushing a change to `README.md` won't trigger it.

### Steps

| Step | What happens |
|---|---|
| `actions/checkout@v4` | Downloads the repo code to the runner |
| `hashicorp/setup-terraform@v3` | Installs Terraform 1.5.7 on the runner |
| `terraform init` | Downloads AzureRM provider, connects to remote backend |
| `terraform validate` | Checks syntax — catches typos before wasting a plan |
| `terraform plan` | Calculates what will change. `db_password` is pulled from `secrets.TF_DB_PASSWORD` |
| Post Plan to PR | Comments the plan output on the PR so reviewers can see what will change |
| `terraform apply` | Only runs on merge to `main`. Deploys the changes to Azure. |

### Azure Authentication
The workflow authenticates to Azure using a Service Principal — 4 secrets stored in GitHub:
```
AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID
```

---

## 9. How Data Flows Between Modules

This is the full picture of how values move through the codebase:

```
terraform.tfvars
  └─ location, project_name, db_password, etc.
       │
       ▼
networking/variables.tf  (declared)
       │
       ▼
networking/main.tf  (passed to modules)
  ├─── module "networking"
  │      inputs:  location, project_name, vnet_address_space, ssh_allowed_source
  │      outputs: vnet_id, vnet_name, public_subnet_ids, app_subnet_ids,
  │               db_subnet_ids, resource_group_name, resource_group_location
  │
  ├─── module "compute"
  │      inputs:  location, project_name, resource_group_name ← from module.networking
  │               app_subnet_ids ← from module.networking.app_subnet_ids
  │               public_subnet_ids ← from module.networking.public_subnet_ids
  │      outputs: lb_public_ip, bastion_public_ip, vmss_id
  │
  └─── module "database"
         inputs:  location, project_name, resource_group_name ← from module.networking
                  vnet_id ← from module.networking.vnet_id
                  db_subnet_ids ← from module.networking.db_subnet_ids
                  db_password ← from var.db_password (root variable)
         outputs: db_server_fqdn, db_server_name, db_name

networking/outputs.tf  (surfaces to terminal)
  ├── lb_public_ip       ← module.compute.lb_public_ip
  ├── bastion_public_ip  ← module.compute.bastion_public_ip
  ├── db_server_fqdn     ← module.database.db_server_fqdn
  ├── vnet_name          ← module.networking.vnet_name
  └── app_subnet_ids     ← module.networking.app_subnet_ids
```

---

## 10. Azure Concepts Explained Simply

| Concept | Simple Explanation |
|---|---|
| **Resource Group** | A folder in Azure. All related resources go in one RG. Delete the RG = delete everything inside. |
| **VNet** | A private network you own inside Azure. Like your home Wi-Fi — only your devices connect. |
| **Subnet** | A section of the VNet. Like floors in a building — each tier gets its own floor. |
| **NSG** | A firewall for a subnet. Rules decide what traffic is allowed in and out. |
| **Load Balancer** | Sits in front of your VMs. Receives all HTTP traffic and distributes it evenly across VMs. |
| **VMSS** | A group of VMs that all run the same config. Add/remove instances based on load. |
| **NAT Gateway** | Lets private VMs reach the internet outbound (for updates, downloads) without exposing them inbound. |
| **Bastion Host** | A single VM with a public IP that acts as a "gateway" for SSH. You SSH here first, then hop to private VMs. |
| **PostgreSQL Flexible Server** | A managed database — Azure handles backups, updates, HA. You just use it. |
| **Private DNS Zone** | An internal-only DNS. Your DB hostname resolves to a private IP only from inside your VNet. |
| **Delegated Subnet** | A subnet reserved exclusively for one Azure service (PostgreSQL in this case). |
| **Remote Backend** | Stores Terraform state in Azure Blob Storage instead of locally. Enables team collaboration and CI/CD. |
| **Service Principal** | An identity (like a service account) that GitHub Actions uses to authenticate with Azure. |
