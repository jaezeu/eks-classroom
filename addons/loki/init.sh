#!/usr/bin/env bash

ROOT="$(cd "$(dirname "$0")" && pwd)"

# The Cilium workflow passes "cilium" so Loki emits CiliumNetworkPolicy.
# Any other invocation keeps the Kubernetes NetworkPolicy in loki-values.yaml.
FLAVOR_VALUES=()
case "${1:-}" in
  *cilium*) FLAVOR_VALUES=(--values "$ROOT/networkpolicy-cilium.yaml") ;;
esac

# renovate: datasource=helm depName=loki registryUrl=https://grafana.github.io/helm-charts
helm upgrade --install loki loki --repo https://grafana.github.io/helm-charts --version 6.29.0 --values "$ROOT/loki-values.yaml" "${FLAVOR_VALUES[@]}" -n loki --create-namespace

# renovate: datasource=helm depName=promtail registryUrl=https://grafana.github.io/helm-charts
helm upgrade --install promtail promtail --repo https://grafana.github.io/helm-charts --version 6.17.1 --values promtail-values.yaml -n loki

