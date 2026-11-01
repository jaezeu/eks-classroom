#!/usr/bin/env bash

ROOT="$(cd "$(dirname "$0")" && pwd)"

# VictoriaLogs single-node, replacing the distributed Loki install. One
# StatefulSet on a gp3 volume (the EBS CSI driver is always installed before
# this add-on), one day of retention, no object storage and no IRSA role.
# Both workflows call this script the same way; the chart renders Kubernetes
# NetworkPolicy, which Cilium enforces too.
# renovate: datasource=helm depName=victoria-logs-single registryUrl=https://victoriametrics.github.io/helm-charts/
helm upgrade --install victorialogs victoria-logs-single --repo https://victoriametrics.github.io/helm-charts/ --version 0.13.10 --values "$ROOT/victorialogs-values.yaml" -n victorialogs --create-namespace

# Vector is the per-node log shipper. It runs in this namespace so the
# VictoriaLogs network policies and the verify job's rollout check cover it.
# renovate: datasource=helm depName=vector registryUrl=https://helm.vector.dev
helm upgrade --install vector vector --repo https://helm.vector.dev --version 0.60.0 --values "$ROOT/vector-values.yaml" -n victorialogs
