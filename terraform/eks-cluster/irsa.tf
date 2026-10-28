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

module "ebs_csi_driver_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  count = var.enable_ebs_csi_driver_role ? 1 : 0

  name = "${local.name_prefix}-cluster-ebs-csidriver-role"

  attach_ebs_csi_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

###############################
# ROLE & BUCKETS FOR LOKI
###############################

# Versioning and access logging are deliberately omitted: these buckets hold
# short-retention log chunks for ephemeral teaching clusters, and Loki manages
# object lifecycles itself (versioning would just accumulate cost).
#tfsec:ignore:aws-s3-enable-versioning tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "loki_chunks" {
  count = var.enable_loki_s3 ? 1 : 0

  bucket_prefix = "${local.name_prefix}-cluster-loki-chunks"
  force_destroy = true
}

#tfsec:ignore:aws-s3-enable-versioning tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "loki_ruler" {
  count = var.enable_loki_s3 ? 1 : 0

  bucket_prefix = "${local.name_prefix}-cluster-loki-ruler"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "loki_chunks" {
  count = var.enable_loki_s3 ? 1 : 0

  bucket                  = aws_s3_bucket.loki_chunks[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "loki_ruler" {
  count = var.enable_loki_s3 ? 1 : 0

  bucket                  = aws_s3_bucket.loki_ruler[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3 (AES256) is sufficient for sandbox log data; a customer-managed KMS
# key would add per-request KMS cost and key lifecycle management for no
# practical gain here.
#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "loki_chunks" {
  count = var.enable_loki_s3 ? 1 : 0

  bucket = aws_s3_bucket.loki_chunks[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "loki_ruler" {
  count = var.enable_loki_s3 ? 1 : 0

  bucket = aws_s3_bucket.loki_ruler[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

module "loki_s3_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  count = var.enable_loki_s3 ? 1 : 0

  name = "${local.name_prefix}-cluster-loki-s3-role"

  # No built-in Loki policy in the module; attach the S3 access inline
  create_inline_policy = true
  inline_policy_permissions = {
    LokiS3 = {
      actions = [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      resources = [
        aws_s3_bucket.loki_chunks[0].arn,
        "${aws_s3_bucket.loki_chunks[0].arn}/*",
        aws_s3_bucket.loki_ruler[0].arn,
        "${aws_s3_bucket.loki_ruler[0].arn}/*"
      ]
    }
  }

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["loki:loki"]
    }
  }

  depends_on = [aws_s3_bucket.loki_chunks, aws_s3_bucket.loki_ruler]
}
