module "github-oidc" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 2.3.0"

  create_oidc_provider = false
  oidc_provider_arn    = data.aws_iam_openid_connect_provider.github.arn
  create_oidc_role     = true

  role_name = "EKSPlatformDeployerRole"

  repositories              = ["jaezeu/eks-classroom"]
  oidc_role_attach_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}