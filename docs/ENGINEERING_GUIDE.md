# Fortress Engineering Guide

This document provides a deep dive into the infrastructure and application logic of the Fortress project.

## 1. Network Topology
The project utilizes a hub-and-spoke inspired VNet design with strict subnet delegation:
- **App Subnet (`10.0.10.0/24`)**: Hosts the AKS node pool.
- **Data Subnet (`10.0.20.0/24`)**: Delegated specifically to `Microsoft.DBforPostgreSQL/flexibleServers`.
- **Cache Subnet (`10.0.30.0/24`)**: Private endpoint for Azure Cache for Redis.
- **Gateway Subnet (`10.0.40.0/24`)**: Dedicated to Azure Application Gateway.
- **Bastion Subnet (`10.0.50.0/24`)**: Azure Bastion service for secure management.

## 2. Ingress & Connectivity
We use the **Application Gateway Ingress Controller (AGIC)**. 
- The Ingress resource in `k8s/fortress-app.yaml` (or `app_deployment.tf`) creates the backend pools and listeners on the App Gateway automatically.
- **SSL Termination**: Handled at the App Gateway.
- **Private Link**: PostgreSQL and Redis are accessed via Private DNS Zones, ensuring traffic never leaves the Azure backbone.

## 3. Real-Time Telemetry Bridge
The "Live" feel of the dashboard is achieved through a three-tier bridge:
1.  **Azure Monitor SDK**: The Node.js backend uses `@azure/monitor-query` to pull metrics like `TotalRequests` from the App Gateway and `active_connections` from Postgres.
2.  **K8s Client SDK**: Uses `@kubernetes/client-node` to watch pod/node status changes.
3.  **Socket.io**: Every 3 seconds, the backend pushes a consolidated telemetry packet to all connected web clients.

## 4. Chaos Engineering API
To demonstrate resiliency, the backend includes a Chaos API:
- `POST /api/chaos/kill-pod`: Deletes a random pod to show K8s self-healing.
- `POST /api/chaos/simulate-latency`: Blocks the event loop briefly to trigger latency alerts on the frontend chart.

## 5. CI/CD Hardening
The GitHub Actions pipeline is optimized with:
- **Parallel Jobs**: Infrastructure, Build, and Deployment run concurrently.
- **GHA Caching**: Docker layers and Terraform providers are cached to reduce build time from ~10m to ~3m.
- **Safe Substitution**: Use of `sed` to inject sensitive environment variables (like DB passwords) into manifests at deploy-time, avoiding plain-text secrets in the repository.
