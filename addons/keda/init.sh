#!/usr/bin/env bash

ROOT="$(cd "$(dirname "$0")" && pwd)"

# The Cilium workflow passes "cilium" so KEDA emits CiliumNetworkPolicy.
# Any other invocation keeps the Kubernetes NetworkPolicy in values.yaml.
FLAVOR_VALUES=()
case "${1:-}" in
  *cilium*) FLAVOR_VALUES=(--values "$ROOT/networkpolicy-cilium.yaml") ;;
esac

# renovate: datasource=helm depName=keda registryUrl=https://kedacore.github.io/charts
helm upgrade --install keda keda \
  --repo https://kedacore.github.io/charts \
  --version 2.21.0 \
  --namespace monitoring \
  --create-namespace \
  --values "$ROOT/values.yaml" \
  "${FLAVOR_VALUES[@]}"
