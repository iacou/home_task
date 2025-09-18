# --- VPC ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0.1"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr

  azs            = var.azs
  public_subnets = var.public_subnets

  map_public_ip_on_launch = true
}

# --- EKS cluster ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.3.1"

  name                   = "${var.name}-eks"
  kubernetes_version     = var.k8s_version
  endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }


  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]
      ami_type       = "AL2023_x86_64_STANDARD"
      disk_size      = 8
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }
}

# --- IAM roles for RBAC ---
data "aws_iam_policy_document" "trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.me.account_id]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_admin" {
  name               = "${var.name}-eks-admin"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role" "eks_readonly" {
  name               = "${var.name}-eks-readonly"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

module "aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.8"

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.eks_admin.arn
      username = "eks-admin"
      groups   = ["system:masters"]
    },
    {
      rolearn  = aws_iam_role.eks_readonly.arn
      username = "eks-readonly"
      groups   = ["read-only"]
    },
  ]
  depends_on = [module.eks]
}

# --- RBAC binding for read-only group ---
resource "kubernetes_cluster_role_binding" "readonly" {
  metadata { name = "read-only-view" }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind = "Group"
    name = "read-only"
  }
  depends_on = [module.eks]
}

# --- Atlantis ---
resource "kubernetes_namespace" "atlantis" {
  metadata { name = "atlantis" }
  depends_on = [module.eks]
}

resource "kubernetes_secret" "atlantis" {
  metadata {
    name      = "atlantis-secrets"
    namespace = kubernetes_namespace.atlantis.metadata[0].name
  }
  data = {
    github_token  = var.github_token
    github_secret = var.github_webhook_secret
  }
  type       = "Opaque"
  depends_on = [module.eks]
}

resource "helm_release" "atlantis" {
  name       = "atlantis"
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  namespace  = kubernetes_namespace.atlantis.metadata[0].name
  version    = var.atlantis_chart_version

  values = [yamlencode({
    orgAllowlist  = "github.com/${var.github_owner}/${var.github_repo}"
    vcsSecretName = "atlantis-secrets"
    github = {
      user  = var.github_user
      token = "" # injected via secret
    }
    service = { type = "LoadBalancer" }
    volumeClaim = {
      enabled = false # use emptydir for home task
    }
    extraVolumes = [
      {
        name     = "atlantis-data"
        emptyDir = {}
      }
    ]

    extraVolumeMounts = [
      {
        name      = "atlantis-data"
        mountPath = "/atlantis-data"
      }
    ]
  })]

  depends_on = [module.eks]
}

# --- Wait for Atlantis LB and create GitHub webhook ---
data "kubernetes_service" "atlantis" {
  metadata {
    name      = helm_release.atlantis.name
    namespace = kubernetes_namespace.atlantis.metadata[0].name
  }
  depends_on = [helm_release.atlantis]
}

resource "github_repository_webhook" "atlantis" {
  repository = var.github_repo
  active     = true
  configuration {
    url          = "http://${data.kubernetes_service.atlantis.status[0].load_balancer[0].ingress[0].hostname}/events"
    content_type = "json"
    secret       = var.github_webhook_secret
  }
  events     = ["pull_request", "issue_comment", "push"]
  depends_on = [data.kubernetes_service.atlantis]
}
