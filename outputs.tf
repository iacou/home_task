output "cluster_name" {
  value = module.eks.cluster_name
}

output "atlantis_url" {
  value = "http://${data.kubernetes_service.atlantis.status[0].load_balancer[0].ingress[0].hostname}"
}

