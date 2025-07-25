data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr_public
}

locals {
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Owner       = "ValeriG"
  }
}

variable "alb-service_account_name" {
  type        = string
  default     = "aws-load-balancer-controller-sa"
  description = "ALB Controller service account name"
}

variable "name" {
  type        = string
  default     = "assignment-eks"
  description = "Base name for cluster and resources"
}

variable "region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS region"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.255.0.0/16"
  description = "CIDR block for the VPC"
}

variable "whitelist_cidrs" {
  type = list(string)
  default = [
    "0.0.0.0/0",
  ]
  description = "CIDRs allowed for public access to the EKS control plane and ArgoCD"
}