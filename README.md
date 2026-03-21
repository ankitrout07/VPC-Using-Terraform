# Fortress VNet — Azure 3-Tier Architecture (Terraform)

Production-grade, secure 3-Tier Virtual Network on Azure, fully provisioned with Terraform. Includes a Nginx-served web dashboard on every app VM.

## Architecture

```
Internet
   │  HTTP / HTTPS
   ▼
[Load Balancer — Static Public IP]
   │
   ▼
[Tier 1: Public Subnets]  ←──── Bastion Host (SSH jump)
   │
   ▼
[Tier 2: Private App Subnets]
  [VMSS — Ubuntu 22.04 + Nginx webpage]
   │  NAT Gateway (egress only)
   ▼
[Tier 3: Isolated DB Subnets]
  [PostgreSQL Flexible Server v15]
  [Private DNS Zone — no public access]
```

### Tiers

1. **Tier 1: Web (Public)**
   - Standard Public Load Balancer with HTTP health probe
   - Bastion Host VM for SSH jump access to private instances

2. **Tier 2: App (Private)**
   - Virtual Machine Scale Set (VMSS) — Ubuntu 22.04 LTS, 2 instances
   - Serves an architecture dashboard webpage via Nginx
   - No direct inbound internet access; egress via NAT Gateway

3. **Tier 3: DB (Isolated)**
   - Azure PostgreSQL Flexible Server v15
   - Dedicated delegated subnet — zero public access
   - Private DNS Zone (`*.private.postgres.database.azure.com`)

### Security
- **NSGs**: 4 rulesets restricting traffic per-tier (HTTP, SSH, PostgreSQL port 5432)
- **Bastion Host**: Only entry point for SSH into private instances
- **NAT Gateway**: Controlled, auditable egress from the app tier
- **Remote State**: AzureRM backend in `networking/provider.tf` (configure before deploying)

## Project Structure

```
.
├── backend-init/          # Step 1: Provisions Azure remote state backend
│   ├── main.tf
│   └── outputs.tf
├── networking/            # Step 2: Main infrastructure
│   ├── main.tf            # Root module — wires all 3 modules
│   ├── provider.tf        # AzureRM provider + backend config
│   ├── variables.tf
│   ├── terraform.tfvars   # Your deployment variables (gitignored)
│   ├── outputs.tf
│   └── modules/
│       ├── networking/    # VNet, subnets, NSGs, NAT Gateway, routes
│       ├── compute/       # Load Balancer, VMSS, Bastion, init.sh webpage
│       └── database/      # PostgreSQL Flexible Server, Private DNS
├── .github/workflows/
│   └── deploy.yml         # CI/CD: plan on PR, apply on merge to main
├── HOW_TO_RUN.md          # Full deployment guide (start here)
└── README.md              # This file
```

## Quick Start

See **[HOW_TO_RUN.md](./HOW_TO_RUN.md)** for the full step-by-step guide including CI/CD setup.

```bash
# 1. Bootstrap remote backend
cd backend-init && terraform init && terraform apply

# 2. Deploy infrastructure
cd ../networking && terraform init && terraform apply

# 3. Open in browser
http://<lb_public_ip>
```

## Prerequisites
- Terraform >= 1.0
- Azure CLI (`az login`)
- SSH key at `~/.ssh/id_rsa.pub` (`ssh-keygen -t rsa -b 4096`)
