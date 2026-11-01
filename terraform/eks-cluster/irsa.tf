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

  name = "${local.name_prefix}-cluster-externaldns-role"

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [data.aws_route53_zone.base.arn]

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

###############################
# ROLE FOR EBS CSI DRIVER
###############################
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
