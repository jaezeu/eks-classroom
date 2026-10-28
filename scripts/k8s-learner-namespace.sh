#!/usr/bin/env bash
# Provisions one Kubernetes namespace per learner in the sctp-ce-12-learner
# IAM group, following the *-eks-activity naming convention enforced by Kyverno.
# Usernames are lowercased and sanitised to meet DNS label constraints.
# Idempotent: uses --dry-run=client | apply so re-runs are safe.
#
# Usage: AWS_PROFILE=<profile> ./scripts/k8s-learner-namespace.sh
# Requires: aws cli, kubectl (pointed at target cluster)

aws iam get-group \
  --group-name sctp-ce-12-learner \
  --query 'Users[].UserName' \
  --output text | \
tr '\t' '\n' | \
while read user; do
  ns=$(echo "$user" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g' \
    | sed 's/^-*//;s/-*$//' \
    | cut -c1-49)-eks-activity

  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
