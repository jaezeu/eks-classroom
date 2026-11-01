output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = replace(module.eks.cluster_endpoint, "https://", "")
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider" {
  value = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "external_dns_role_arn" {
  value = module.external_dns_role.arn
}

output "ebs_csi_driver_role_arn" {
  value = module.ebs_csi_driver_role.arn
}
