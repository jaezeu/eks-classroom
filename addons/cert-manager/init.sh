#!/usr/bin/env bash

# Values + ClusterIssuer default to the standard (nginx) files. The Cilium
# workflow passes the Gateway API variants:
#   ./init.sh gateway-values.yaml gateway-cluster-issuer.yaml
VALUES_FILE="${1:-values.yaml}"
ISSUER_FILE="${2:-cluster-issuer.yaml}"

# renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
helm upgrade --install cert-manager cert-manager --repo https://charts.jetstack.io \
  --namespace cert-manager \
  --create-namespace \
  --version v1.20.2 \
  --values "$VALUES_FILE"

kubectl apply -f "$ISSUER_FILE"

