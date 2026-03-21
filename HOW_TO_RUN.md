# How to Run — Fortress VNet (Azure 3-Tier Architecture)

## Prerequisites

Before starting, ensure you have:

| Tool | Version | Install |
|------|---------|---------|
| **Terraform** | >= 1.0 | [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) |
| **Azure CLI** | Latest | [docs.microsoft.com/cli/azure/install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| **SSH Key Pair** | RSA at `~/.ssh/id_rsa.pub` | `ssh-keygen -t rsa -b 4096` |

---

## Step 1 — Authenticate with Azure

```bash
az login
```

Verify you're targeting the right subscription:

```bash
az account show
# Switch if needed:
az account set --subscription "<your-subscription-id>"
```

---

## Step 2 — Bootstrap the Remote Backend

This creates the Azure Storage Account that securely stores your Terraform state.

```bash
cd backend-init
terraform init
terraform apply
```

Type `yes` when prompted.

> **Important:** Copy the `storage_account_name` value from the output — you'll need it in Step 3.

---

## Step 3 — Configure the Remote Backend (Optional but Recommended)

Open `networking/provider.tf` and **uncomment** the backend block, then fill in your value:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-mgmt-prod"
  storage_account_name = "<paste-your-storage_account_name-here>"
  container_name       = "tfstate"
  key                  = "networking-azure.terraform.tfstate"
}
```

> If you skip this step, state will be stored locally in `networking/terraform.tfstate`. That's fine for testing.

---

## Step 4 — Customize Variables (Optional)

Open `networking/terraform.tfvars` and adjust if needed:

```hcl
location           = "Central India"   # Azure region
vnet_address_space = "10.0.0.0/16"    # VNet CIDR
project_name       = "Fortress-VNet"   # Prefix for all resources
db_password        = "YourSecretPass!" # Change this!
```

> ⚠️ **Never commit `terraform.tfvars` to Git** — it contains your DB password. It's already in `.gitignore`.

---

## Step 5 — Deploy the Infrastructure

```bash
cd ../networking

# Clean slate (if re-running after a previous attempt)
rm -rf .terraform .terraform.lock.hcl

# Initialize Terraform (downloads providers, connects to backend)
terraform init

# Preview what will be created
terraform plan

# Deploy everything
terraform apply
```

Type `yes` when prompted.

---

## Step 6 — Access Your Infrastructure

After a successful `terraform apply`, note the outputs:

```
lb_public_ip       = "x.x.x.x"        ← Open this in your browser
bastion_public_ip  = "y.y.y.y"        ← SSH jump host
db_server_fqdn     = "fortress-pg-xxx.private.postgres.database.azure.com"
```

### View the Webpage

Open your browser and navigate to:
```
http://<lb_public_ip>
```

The Fortress VNet architecture dashboard will be served by Nginx on the VMSS instances.

> **Note:** It may take 2–3 minutes after `apply` completes for the VMs to finish booting and Nginx to start.

### SSH into the Bastion Host

```bash
ssh adminuser@<bastion_public_ip>
```

### SSH into Private App Instances (via Bastion)

```bash
# From the Bastion host, SSH into the private VMSS instances
ssh adminuser@<private-ip-of-app-vm>
```

### Connect to the Database

The PostgreSQL server is only accessible from within the VNet:

```bash
# From an App tier VM:
psql -h <db_server_fqdn> -U adminuser -d fortressdb
```

---

## Teardown — Destroy All Resources

> ⚠️ This will permanently delete all Azure resources and incur no further charges.

```bash
# 1. Destroy the main infrastructure
cd networking
terraform destroy

# 2. Destroy the remote backend
cd ../backend-init
terraform destroy
```

Type `yes` at each prompt.

---

## Architecture Summary

```
Internet
   │  HTTP/HTTPS
   ▼
[Load Balancer — Public IP]
   │
   ▼
[Tier 1: Public Subnet]   ←──── Bastion Host (SSH)
   │
   ▼
[Tier 2: Private App Subnet]
  [VMSS — Ubuntu 22.04 + Nginx]
   │  NAT Gateway (egress)
   ▼
[Tier 3: Isolated DB Subnet]
  [PostgreSQL Flexible Server v15]
  [Private DNS Zone — no public access]
```

---


## Common Issues

| Problem | Fix |
|---------|-----|
| `Error: No subscription found` | Run `az login` and `az account set` |
| `ssh-key not found` | Run `ssh-keygen -t rsa -b 4096` to create `~/.ssh/id_rsa.pub` |
| VM not serving webpage after apply | Wait 2–3 min for cloud-init to complete |
| `Backend config changed` error on re-init | Run `rm -rf .terraform` then `terraform init` again |
| PostgreSQL subnet delegation error | Ensure `10.0.30.0/24` doesn't overlap with existing VNet ranges |

---

## CI/CD — GitHub Actions Workflow

The workflow at `.github/workflows/deploy.yml` automatically runs `terraform plan` on every PR and `terraform apply` on every merge to `main`. Follow these steps once to activate it.

### Step 1 — Create an Azure Service Principal

This gives GitHub Actions permission to deploy to Azure:

```bash
az ad sp create-for-rbac \
  --name "fortress-vnet-github" \
  --role Contributor \
  --scopes /subscriptions/<your-subscription-id>
```

Note the output — you'll need `clientId`, `clientSecret`, `subscriptionId`, and `tenantId`.

### Step 2 — Add GitHub Secrets

Go to your GitHub repo → **Settings → Secrets and variables → Actions → New repository secret** and add all 5:

| Secret Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `clientId` from SP output |
| `AZURE_CLIENT_SECRET` | `clientSecret` from SP output |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `AZURE_TENANT_ID` | `tenantId` from SP output |
| `TF_DB_PASSWORD` | Your database password |

### Step 3 — Enable the Remote Backend

Open `networking/provider.tf`, uncomment the backend block and fill in your storage account name (from `backend-init` output in Step 2 above):

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-mgmt-prod"
  storage_account_name = "<your-storage-account-name>"
  container_name       = "tfstate"
  key                  = "networking-azure.terraform.tfstate"
}
```

### Step 4 — Push to GitHub

```bash
git add .
git commit -m "feat: complete fortress-vnet infrastructure"
git push origin main
```

### How the Workflow Behaves

| Event | What Happens |
|---|---|
| Open a Pull Request | Runs `validate` + `plan`, posts full plan output as a PR comment |
| Merge PR to `main` | Runs `validate` + `plan` + `apply` automatically |
| Push directly to `main` | Same as merge — full apply runs |
