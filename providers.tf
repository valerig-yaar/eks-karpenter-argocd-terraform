provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

terraform {
  backend "s3" {
    bucket         = "REPLACE_ME"
    key            = "vpc-eks-deployment/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_ME"
    encrypt        = true
  }
}
 
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
