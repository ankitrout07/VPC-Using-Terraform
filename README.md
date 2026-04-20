# Fortress VNet — Azure AKS 3-Tier Architecture (Terraform)

Production-grade, secure 3-Tier Virtual Network on Azure, fully provisioned with Terraform. Features a private AKS cluster protected by an Application Gateway with WAF, and a **real-time WebSocket dashboard** for live autoscaling observability.

## Architecture

```
Internet
   │  HTTP / HTTPS
   ▼
[Application Gateway — Static Public IP]
   │  (WAF Enabled + AGIC)
   ▼
[Tier 1: Public Subnets]
   │  [Azure Bastion — Secure Access]
   ▼
[Tier 2: Private App Subnets]
  [Private AKS Cluster — Azure CNI]
   │  ↔ [Redis Cache — Private Endpoint]
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
   - Azure Redis Cache — Secured with Private Endpoint
   - Azure CNI Networking for pod-to-vnet connectivity
   - No direct inbound internet access; egress via NAT Gateway for secure updates

3. **Tier 3: DB (Isolated)**
   - Azure PostgreSQL Flexible Server v15
   - Dedicated delegated subnet — zero public access
   - Private DNS Zone (`*.private.postgres.database.azure.com`)

4. **Tier 1 & 5: Management & Access**
   - Azure Bastion Host — Secure, jump-box free RDP/SSH access
   - Unified Resource Group — All components, including state storage, share a single management container.

### Security
- **AGIC**: Application Gateway Ingress Controller manages L7 traffic directly to pods.
- **Private AKS**: The Kubernetes API and nodes are not exposed to the public internet.
- **RBAC**: Managed Identities with least-privilege role assignments (Contributor, Network Contributor).
- **NAT Gateway**: Controlled, auditable egress from the AKS nodes.

## Real-Time Observability Dashboard

The dashboard is a full-stack Node.js application deployed inside AKS that provides a **"Single Pane of Glass"** for infrastructure monitoring.

### Data Flow
```
Browser (index.html)
   ↕  WebSocket (Socket.io)
Node.js Backend (server.js)
   ↕  @kubernetes/client-node
Kubernetes API Server
   ↓
Live Pod Data (every 2 seconds)
```

### Features
| Feature | Description |
|---------|-------------|
| 📦 **Live Pod Counter** | Real-time pod count with animated scaling tags (`STABLE` / `SCALING UP` / `SCALING DOWN`) |
| 🖥️ **Pod Card Grid** | Per-pod cards showing name, status, IP, and assigned node — updated via WebSocket |
| 📜 **Scaling Event Log** | Auto-logged terminal entries: `HPA Triggered: Scaling from 2 → 8 pods` |
| 🕸️ **Network Topology** | Interactive SVG map with animated data-flow particles (Gateway → AKS → DB) |
| 🛡️ **Security Scanner** | One-click infrastructure scan with visual sweep animation |
| 📊 **Real-Time Metrics** | CPU load, network latency, and active query gauges |

### Autoscaling Visualization
```
ApacheBench → App Gateway → AKS → HPA Detects CPU > 50%
   → New Pods Provisioned (Azure CNI) → AGIC Syncs Backend Pool
   → Dashboard WebSocket Emits Updated Pod List → UI Updates Live
```

| Phase | Pod Counter | Tag | Terminal Log |
|-------|-------------|-----|--------------|
| Before load | 2 | `STABLE` | — |
| During load | 2 → 4 → 8+ | `SCALING UP` | `HPA Triggered: Scaling from 2 → 8 pods` |
| After load | Scales back down | `SCALING DOWN` | `Workload decreased: Scaling down to 2 pods` |

## Project Structure

```
.
├── dashboard/             # Real-Time Dashboard (Node.js + Socket.io + Frontend)
│   ├── server.js          # WebSocket backend — queries K8s API every 2s
│   ├── index.html         # Frontend UI with Socket.io client
│   ├── style.css          # Glassmorphism + pod card styles
│   ├── package.json       # express, socket.io, @kubernetes/client-node
│   └── Dockerfile         # node:20-alpine container
├── k8s/                   # Kubernetes Manifests
│   ├── fortress-app.yaml  # Deployment + Service + RBAC (ServiceAccount)
│   ├── fortress-ingress.yaml  # AGIC Ingress
│   └── hpa.yaml           # HPA: 2-5 replicas, CPU > 50%
├── networking/            # Main Terraform Infrastructure
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
│       ├── database/      # PostgreSQL Flexible Server, Private DNS
│       ├── redis/         # Redis Cache Cluster (Private)
│       └── bastion/       # Azure Bastion Host
├── .github/workflows/
│   └── deploy.yml         # CI/CD: plan on PR, apply on merge to main
├── docs/
│   ├── ARCHITECTURE.md    # Detailed component breakdown
│   ├── FINAL_PROJECT_REPORT.md  # Complete project report
│   ├── PROJECT_DOCUMENTATION.md # Technical documentation
│   ├── HOW_TO_RUN.md      # Full deployment guide (start here)
│   └── autoscaling_verification.md  # HPA/CA testing guide
└── README.md              # This file
```

## Quick Start

See **[HOW_TO_RUN.md](./docs/HOW_TO_RUN.md)** for the full step-by-step guide including CI/CD setup.

```bash
# 1. Deploy infrastructure
cd networking && terraform init && terraform apply -auto-approve

# 2. Build & push the dashboard image
LOGIN_SERVER=$(terraform output -raw acr_login_server)
az acr login --name $(terraform output -raw acr_name)
docker build -t $LOGIN_SERVER/fortress-dashboard:v5-realtime ../dashboard
docker push $LOGIN_SERVER/fortress-dashboard:v5-realtime

# 3. Deploy to AKS
az aks get-credentials --resource-group <RG_NAME> --name <AKS_NAME>
kubectl apply -f ../k8s/fortress-app.yaml
kubectl apply -f ../k8s/fortress-ingress.yaml
kubectl apply -f ../k8s/hpa.yaml

# 4. Open dashboard
open http://$(terraform output -raw app_gateway_public_ip)

# 5. Generate traffic → watch autoscaling live!
ab -n 10000 -c 50 http://$(terraform output -raw app_gateway_public_ip)/
```

## Prerequisites
- Terraform >= 1.0
- Azure CLI (`az login`)
- Node.js >= 18 (for local dashboard development)
- Docker (for building the dashboard image)
- SSH key at `~/.ssh/id_rsa.pub` (`ssh-keygen -t rsa -b 4096`)
- ApacheBench (`ab`) for load testing (optional)

## Documentation

| Document | Description |
|----------|-------------|
| [HOW_TO_RUN.md](./docs/HOW_TO_RUN.md) | Full deployment guide — start here |
| [ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Detailed component breakdown + dashboard architecture |
| [FINAL_PROJECT_REPORT.md](./docs/FINAL_PROJECT_REPORT.md) | Complete project report |
| [PROJECT_DOCUMENTATION.md](./docs/PROJECT_DOCUMENTATION.md) | Technical documentation + WebSocket layer details |
| [autoscaling_verification.md](./docs/autoscaling_verification.md) | HPA/CA testing + dashboard visual verification |
