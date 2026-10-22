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
helm upgrade --install kube-prometheus-stack kube-prometheus-stack --repo https://prometheus-community.github.io/helm-charts --version 86.2.2 \
  --create-namespace \
  --namespace monitoring \
  --values "$VALUES_FILE" \
  --values "$ROOT/dashboards-values.yaml" \
  --values "$FLAVOR_DASHBOARDS"


