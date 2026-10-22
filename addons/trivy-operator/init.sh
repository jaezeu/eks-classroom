#!/usr/bin/env bash

# ServiceMonitor CRDs, before this chart renders monitoring.coreos.com resources.
"$(cd "$(dirname "$0")" && pwd)/../kube-prometheus-stack/install-crds.sh"

# renovate: datasource=helm depName=trivy-operator registryUrl=https://aquasecurity.github.io/helm-charts
helm upgrade --install trivy-operator trivy-operator --repo https://aquasecurity.github.io/helm-charts --version 0.37.0 \
  --namespace trivy-system \
  --create-namespace \
  --values values.yaml
