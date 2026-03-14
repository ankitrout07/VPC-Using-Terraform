# variables.tf

variable "aws_region" {
  description = "Target region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Base CIDR for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  type    = string
  default = "Fortress-VPC"
}

variable "instance_type" {
  description = "Instance type for application servers"
  type        = string
  default     = "t3.micro"
}

variable "db_name" {
  description = "Name of the RDS database"
  type        = string
  default     = "fortressdb"
}

variable "db_username" {
  description = "Username for RDS"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Password for RDS (sensitve)"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!" # In production, use Secrets Manager
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into Bastion"
  type        = string
  default     = "0.0.0.0/0" # Restricted to user's IP in production
}