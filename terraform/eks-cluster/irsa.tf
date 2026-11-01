# IRSA roles via the purpose-built iam-role-for-service-accounts module (v6):
# each role is trusted only for its exact namespace:serviceaccount pair, and
# the external-dns/ebs-csi policies are the module's maintained least-privilege
# documents instead of hand-written inline ones.

###############################
# ROLE FOR EXTERNAL DNS
###############################
module "external_dns_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  count = var.enable_external_dns ? 1 : 0

  name = "${local.name_prefix}-cluster-externaldns-role"

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = var.external_dns_hosted_zone_arns

  oidc_providers = {
    this = {
      provider_arn = module.eks.oidc_provider_arn
      # addons/r53-externaldns installs into the external-dns namespace
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

###############################
# ROLE FOR EBS CSI DRIVER
###############################

# The EBS CSI driver is installed on every cluster (it provides the default
# StorageClass), so its role has no toggle.
module "ebs_csi_driver_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  name = "${local.name_prefix}-cluster-ebs-csidriver-role"

  attach_ebs_csi_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# The role used to be count-guarded by enable_ebs_csi_driver_role.
moved {
  from = module.ebs_csi_driver_role[0]
  to   = module.ebs_csi_driver_role
}
