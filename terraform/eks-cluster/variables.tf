# Set to true if you're making use of ExternalDNS with Route53
variable "enable_external_dns" {
  description = "Set to true to create IAM role and policies for ExternalDNS with Route53"
  type        = bool
  default     = true
}

# Scope ExternalDNS's Route53 write access to specific hosted zones
variable "external_dns_hosted_zone_arns" {
  description = "Route53 hosted zone ARNs ExternalDNS is allowed to manage records in"
  type        = list(string)
  default     = ["arn:aws:route53:::hostedzone/Z00541411T1NGPV97B5C0"] # sctp-sandbox.com
}


########## Cilium Variables ###########
variable "deploy_node_groups" {
  description = "Set to true to deploy node groups"
  type        = bool
  default     = true
}

variable "enable_default_networking" {
  description = "Set to true for default networking (kube-proxy and vpc-cni). For non-default networking, set to false and use Cilium"
  type        = bool
  default     = true
}

variable "deploy_cluster_addons" {
  type        = bool
  description = "Deploy cluster addons (base and optionally default network addons)"
  default     = true
}

variable "node_instance_types" {
  description = "Instance types for the managed node group. The Cilium workflow passes m6g.xlarge only when the OpenTelemetry demo is selected."
  type        = list(string)
  default     = ["m6g.large"]
}
