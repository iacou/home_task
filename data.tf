data "aws_availability_zones" "available" {}

data "aws_caller_identity" "me" {}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
