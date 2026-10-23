#!/usr/bin/env bash

# ServiceMonitor CRDs. The collector chart emits one when serviceMonitor is on.
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/../kube-prometheus-stack/install-crds.sh"

# renovate: datasource=helm depName=opentelemetry-demo registryUrl=https://open-telemetry.github.io/opentelemetry-helm-charts
helm upgrade --install opentelemetry-demo opentelemetry-demo \
  --repo https://open-telemetry.github.io/opentelemetry-helm-charts \
  --version 0.42.6 \
  --namespace otel-demo \
  --create-namespace \
  --values "$ROOT/values.yaml"

# Grafana's dashboard sidecar searches every namespace. Its datasource sidecar
# only searches monitoring, so both objects live there. The dashboard JSON has
# Grafana variables; do not pass grafana.yaml through envsubst.
kubectl apply -f "$ROOT/grafana.yaml"
