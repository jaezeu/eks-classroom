#!/usr/bin/env bash
# Prometheus Operator CRDs shipped with kube-prometheus-stack, including
# ServiceMonitor. Other charts create ServiceMonitors, and several of them
# install before the monitoring stack (or with monitoring left off). Applying
# the CRDs here lets those releases succeed either way.
#
# No-op when the ServiceMonitor CRD is already present. Server-side apply is
# required: these CRDs are larger than kubectl's last-applied annotation limit.
set -euo pipefail

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  exit 0
fi

# Keep in lockstep with addons/kube-prometheus-stack/init.sh.
# renovate: datasource=helm depName=kube-prometheus-stack registryUrl=https://prometheus-community.github.io/helm-charts
chart_version=86.2.2

crds="$(mktemp)"
trap 'rm -f "$crds"' EXIT

helm show crds kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version "$chart_version" >"$crds"

kubectl apply --server-side --force-conflicts -f "$crds"
kubectl wait --for=condition=Established crd/servicemonitors.monitoring.coreos.com --timeout=180s
