# VPC-Using-Terraform

Production-grade 3-Tier VPC architecture on AWS using Terraform. 

## Architecture
This project implements a secure, highly-available 3-tier architecture:

1.  **Tier 1: Web (Public)**
    *   Application Load Balancer (ALB)
    *   Bastion Host for SSH access
    *   Internet Gateway (IGW)
2.  **Tier 2: App (Private)**
    *   Auto Scaling Group (ASG) with Amazon Linux 2023
    *   Instances are isolated from direct internet access
    *   Egress traffic via NAT Gateway
3.  **Tier 3: DB (Isolated)**
    *   RDS PostgreSQL Instance
    *   Subnets have no internet route

### Security
- **Security Groups**: Stateful firewalls restricting traffic between tiers.
- **NAT Gateway**: Controlled egress for private instances.
- **Remote State**: AzureRM backend (configurable in `provider.tf`).

## Prerequisites
- Terraform >= 1.0
- AWS CLI configured
- Azure CLI configured and authenticated (`az login`)

## Setup

### Step 1: Bootstrap Azure Backend
This creates the Azure Resource Group, Storage Account, and Container to hold the Terraform state for the AWS infrastructure.

1. Navigate to the `backend-init/` directory:
   ```bash
   cd backend-init
   ```
2. Initialize and deploy the backend:
   ```bash
   terraform init
   terraform apply
   ```
3. Take note of the `storage_account_name` value output by Terraform. You will need to plug this into the provider config in Step 2.

### Step 2: Deploy Fortress VPC (AWS)
This deploys the actual AWS infrastructure (VPC, Subnets, EC2, RDS) using the Azure state bucket.

1. Navigate to the `networking/` directory:
   ```bash
   cd ../networking
   ```
2. Update `provider.tf` and replace `<YOUR_AZURE_STORAGE_ACCOUNT_NAME>` with the output from Step 1.
3. Fill in values for `terraform.tfvars`.
4. Run Terraform to deploy the infrastructure:
   ```bash
   terraform init
   terraform apply
   ```
