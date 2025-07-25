################################################################################
# ALB Controller (IRSA-based) for EKS - Using Terraform
################################################################################

# Helm release to deploy ALB Controller
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.13.3"

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      region      = var.region
      vpcId       = module.vpc.vpc_id

      serviceAccount = {
        name = var.alb-service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.aws_lb_controller_pod_identity.iam_role_arn
        }
      }
    })
  ]
  depends_on = [module.eks]
}

################################################################################
# Karpenter
################################################################################

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = var.name
  create_pod_identity_association = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

module "karpenter_disabled" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  create = false
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.6.0"
  wait                = false

  values = [
  templatefile("${path.module}/karpenter-values.yaml.tpl", {
    cluster_name       = module.eks.cluster_name
    cluster_endpoint   = module.eks.cluster_endpoint
    interruption_queue = module.karpenter.queue_name
  })
]
  depends_on = [ helm_release.alb_controller ]
}

################################################################################
# ArgoCD
################################################################################

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "8.2.0"

  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      global = {
        domain = ""
      }

      configs = {
        params = {
          server = {
            insecure = true
          }
        }
      }

      redis-ha = {
        enabled = true
      }

      controller = {
        replicas = 1
      }

      server = {
        autoscaling = {
          enabled     = true
          minReplicas = 2
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            "service.beta.kubernetes.io/load-balancer-source-ranges" = join(",", var.whitelist_cidrs)
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
          }
        }
      }

      repoServer = {
        autoscaling = {
          enabled     = true
          minReplicas = 2
        }
      }

      applicationSet = {
        replicas = 2
      }
    })
  ]
}