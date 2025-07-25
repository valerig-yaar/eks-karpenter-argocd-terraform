
# EKS Cluster Deployment with ALB Controller, Karpenter, and ArgoCD

This Terraform project provisions a complete Amazon EKS environment along with key components for scalable workload management, ingress, and GitOps delivery. All resources are built using AWS best practices, Terraform community modules, and IRSA (IAM Roles for Service Accounts) where applicable.

## Features

* **EKS Cluster** using [`terraform-aws-modules/eks`](https://github.com/terraform-aws-modules/terraform-aws-eks)
* **VPC** with public, private, and intra subnets
* **ALB Ingress Controller** via Helm, with IRSA
* **Karpenter** for efficient autoscaling with EC2NodeClass and IRSA
* **ArgoCD** GitOps deployment with NLB and source IP restrictions
* **EBS CSI Driver** and **VPC CNI** with IRSA
* **CloudWatch Logging** for EKS control plane

## Key Components

### VPC

* Built with `terraform-aws-modules/vpc`
* Private/public/intra subnets across 3 AZs
* NAT Gateway enabled
* Tags added for Karpenter discovery and ALB usage

### EKS

* Version: `1.33`
* Public access enabled with CIDR restrictions
* Control plane logs enabled
* One managed node group (Bottlerocket AMI)
* Addons:

  * CoreDNS
  * Kube Proxy
  * VPC CNI (IRSA)
  * EBS CSI Driver (IRSA)
  * Pod Identity Agent

### ALB Controller

* Installed via Helm in `kube-system`
* IRSA enabled with custom role
* Uses AWS ALB to expose ArgoCD Server

### Karpenter

* Deployed via Helm
* Autoscaling queue configured
* Node role has SSM access
* EC2NodeClass can be attached separately
* Discovery tagging enabled

### ArgoCD

* Installed in `argocd` namespace
* NLB with IP target type and CIDR-based allowlist
* HA setup for `redis`, `repo-server`, and `applicationSet`

### IAM Roles

* Custom roles for:

  * ALB Controller
  * VPC CNI
  * EBS CSI Driver
* Configured for IRSA

## Requirements

* Terraform >= 1.3
* AWS CLI installed and configured
* Helm installed
* Backend configuration for state (S3 + DynamoDB) recommended but commented out


## Usage

```bash
terraform init
terraform plan
terraform apply
```

Before running, make sure:

* Your AWS credentials are configured with access to create EKS, IAM, VPC, and related resources.
* `kubectl`, `helm`, and `aws` CLI tools are installed and accessible.

You can optionally use [GitHubA2AWS](https://github.com/valerig-yaar/GitHubA2AWS) to:

* Automate GitHub Actions deployments into this EKS environment
* Set up OIDC trust between GitHub and AWS for secure, short-lived credentials
* Integrate CI/CD workflows that trigger Terraform or ArgoCD updates

This integration is especially useful for managing ArgoCD root apps or syncing app-of-apps flows via GitOps.

## Notes

* Karpenter EC2NodeClasses and Provisioners should be applied separately
* ArgoCD is exposed via NLB with public IPs limited to specific CIDRs
* Helm provider is configured using AWS CLI token for `kubectl`-based auth

## Next Steps or Alternatives

* **Move from NLB to ALB**:
  Transition ArgoCD's service from NLB to ALB to support features like HTTPS termination, URL-based routing, and WAF. This requires:

  * Public domain with Route53 (or external DNS)
  * Valid ACM certificate (in the same region)
  * Optional: Integrate with AWS WAF for additional security

* **Onboard Private Git Repositories via Code**:
  Automate the integration of private Git repositories (e.g., GitHub, GitLab) with ArgoCD using Helm values or ArgoCD App CRDs:

  * Store credentials via Kubernetes Secrets
  * Configure ArgoCD `repository.credentials` and `repositories` via Helm or AppProject manifest

* **Enable SAML Authentication for ArgoCD**:
  Use a corporate IdP (like Okta, Azure AD, or Google Workspace) to configure SAML SSO for ArgoCD:

  * Update `argocd-cm` with SSO connector configuration
  * Enable role-based access control via groups or claims
  * Requires setting redirect URI, IdP metadata, and proper trust between the systems
