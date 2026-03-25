# Fortress VNet — Azure AKS 3-Tier Architecture (Terraform)

Production-grade, secure 3-Tier Virtual Network on Azure, fully provisioned with Terraform. Features a private AKS cluster protected by an Application Gateway with WAF.

## Architecture

```
Internet
   │  HTTP / HTTPS
   ▼
[Application Gateway — Static Public IP]
   │  (WAF Enabled + AGIC)
   ▼
[Tier 1: Public Subnets]
   │
   ▼
[Tier 2: Private App Subnets]
  [Private AKS Cluster — Azure CNI]
   │  NAT Gateway (egress only)
   ▼
[Tier 3: Isolated DB Subnets]
  [PostgreSQL Flexible Server v15]
  [Private DNS Zone — no public access]
```

### Tiers

1. **Tier 1: Gateway (Public)**
   - Azure Application Gateway v2 (Standard_v2 / WAF_v2)
   - Integrated Ingress Controller (AGIC) for automated traffic routing
   - Dedicated Public IP for external access

2. **Tier 2: App (Private)**
   - Azure Kubernetes Service (AKS) — Private Cluster
   - Azure CNI Networking for pod-to-vnet connectivity
   - No direct inbound internet access; egress via NAT Gateway for secure updates

3. **Tier 3: DB (Isolated)**
   - Azure PostgreSQL Flexible Server v15
   - Dedicated delegated subnet — zero public access
   - Private DNS Zone (`*.private.postgres.database.azure.com`)

### Security
- **AGIC**: Application Gateway Ingress Controller manages L7 traffic directly to pods.
- **Private AKS**: The Kubernetes API and nodes are not exposed to the public internet.
- **RBAC**: Managed Identities with least-privilege role assignments (Contributor, Network Contributor).
- **NAT Gateway**: Controlled, auditable egress from the AKS nodes.

## Project Structure

```
.
├── backend-init/          # Step 1: Provisions Azure remote state backend
│   ├── main.tf
│   └── outputs.tf
├── networking/            # Step 2: Main infrastructure
│   ├── main.tf            # Root module — wires all modules
│   ├── provider.tf        # AzureRM provider + backend config
│   ├── variables.tf
│   ├── terraform.tfvars   # Your deployment variables (gitignored)
│   ├── outputs.tf
│   └── modules/
│       ├── networking/    # VNet, subnets, NSGs, NAT Gateway, routes
│       ├── aks/           # Private K8s Cluster + AGIC Addon
│       ├── app_gateway/   # Application Gateway v2
│       ├── acr/           # Container Image Registry
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
