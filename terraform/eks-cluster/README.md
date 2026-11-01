# EKS Cluster

Terraform for the cluster itself: VPC, EKS control plane, node groups and the
IRSA roles. The comments in the `.tf` files carry the detail; this file is
just orientation.

## Usage

Pick a `.tfvars` file for the mode you want:

- `standard-wo-nodegroup.tfvars` - standard EKS without initial node groups
- `cilium-wo-nodegroup.tfvars` - Cilium mode, no node groups yet (install Cilium first)
- `cilium-with-nodegroup.tfvars` - Cilium mode with node groups (second apply, after Cilium is in)

Both IRSA roles are always created; no variable toggles them. The ExternalDNS
role is scoped to the Route53 hosted zone looked up by name in `data.tf`, so
a fork changes the domain there rather than a zone ID. The EBS CSI driver
role is unconditional because the driver is installed on every cluster.
VictoriaLogs keeps logs on an EBS volume, so there are no log buckets.
Everything IRSA-related lives in `irsa.tf`.
