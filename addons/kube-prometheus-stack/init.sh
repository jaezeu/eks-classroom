#!/usr/bin/env bash

# Values default to the standard (nginx Ingress) file. The Cilium workflow
# passes the Gateway API variant:  ./init.sh gateway-values.yaml
# dashboards-values.yaml is the set both clusters can install. The flavor file
# adds only the dataplane that cluster actually runs.
VALUES_FILE="${1:-values.yaml}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
case "$VALUES_FILE" in
  *gateway*) FLAVOR_DASHBOARDS="$ROOT/dashboards-cilium.yaml" ;;
  *) FLAVOR_DASHBOARDS="$ROOT/dashboards-standard.yaml" ;;
esac

# renovate: datasource=helm depName=kube-prometheus-stack registryUrl=https://prometheus-community.github.io/helm-charts
# Loki and Promtail JSON is injected with --set-file, not --values. Those files
# contain Grafana variables ($namespace, $job, $__range). A --values file is
# envsubst'd by scripts/validate-addons.sh, which would erase them.
helm upgrade --install kube-prometheus-stack kube-prometheus-stack --repo https://prometheus-community.github.io/helm-charts --version 92.14.1 \
  --create-namespace \
  --namespace monitoring \
  --values "$VALUES_FILE" \
  --values "$ROOT/dashboards-values.yaml" \
  --values "$FLAVOR_DASHBOARDS" \
  --set-file grafana.dashboards.devops.loki-logs.json="$ROOT/dashboards/loki-logs.json" \
  --set-file grafana.dashboards.devops.promtail.json="$ROOT/dashboards/promtail.json"


