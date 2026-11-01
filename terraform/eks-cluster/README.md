# EKS Cluster

Terraform for the cluster itself: VPC, EKS control plane, node groups and the
IRSA roles. The comments in the `.tf` files carry the detail; this file is
just orientation.

## Usage

Pick a `.tfvars` file for the mode you want:

- `standard-wo-nodegroup.tfvars` - standard EKS without initial node groups
- `cilium-wo-nodegroup.tfvars` - Cilium mode, no node groups yet (install Cilium first)
- `cilium-with-nodegroup.tfvars` - Cilium mode with node groups (second apply, after Cilium is in)

One boolean variable in `variables.tf` toggles an optional IRSA resource,
defaulting to `true`:

- `enable_external_dns` - IAM role for ExternalDNS with Route53

The EBS CSI driver role is always created: the driver is installed on every
cluster. VictoriaLogs keeps logs on an EBS volume, so there are no log
buckets. Everything IRSA-related lives in `irsa.tf`.
