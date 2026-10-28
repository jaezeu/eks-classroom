#!/usr/bin/env bash

ROOT="$(cd "$(dirname "$0")" && pwd)"

# The Cilium workflow passes "cilium" so Loki emits CiliumNetworkPolicy.
# Any other invocation keeps the Kubernetes NetworkPolicy in loki-values.yaml.
FLAVOR_VALUES=()
case "${1:-}" in
  *cilium*) FLAVOR_VALUES=(--values "$ROOT/networkpolicy-cilium.yaml") ;;
esac

# grafana/loki chart 7.x is maintained for Grafana Enterprise Logs only. 6.55.0 is
# the last OSS release from that repo; renovate.json caps this dependency at <7.
# The OSS successor is the grafana-community/loki chart (different major
# numbering and values), which is a separate migration.
# renovate: datasource=helm depName=loki registryUrl=https://grafana.github.io/helm-charts
helm upgrade --install loki loki --repo https://grafana.github.io/helm-charts --version 6.55.0 --values "$ROOT/loki-values.yaml" "${FLAVOR_VALUES[@]}" -n loki --create-namespace

# renovate: datasource=helm depName=promtail registryUrl=https://grafana.github.io/helm-charts
helm upgrade --install promtail promtail --repo https://grafana.github.io/helm-charts --version 6.17.1 --values promtail-values.yaml -n loki

