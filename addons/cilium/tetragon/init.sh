#!/usr/bin/env bash

# ServiceMonitor CRDs, before this chart renders monitoring.coreos.com resources.
"$(cd "$(dirname "$0")" && pwd)/../../kube-prometheus-stack/install-crds.sh"

# renovate: datasource=helm depName=tetragon registryUrl=https://helm.cilium.io
helm upgrade --install tetragon tetragon --repo https://helm.cilium.io \
  --namespace kube-system \
  --version v1.5.0 \
  --values values.yaml
