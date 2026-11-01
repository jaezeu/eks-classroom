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
