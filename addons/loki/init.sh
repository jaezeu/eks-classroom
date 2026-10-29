#!/usr/bin/env bash

ROOT="$(cd "$(dirname "$0")" && pwd)"

# The OSS Loki chart lives in grafana-community/helm-charts (forked from
# grafana/loki 6.55.0; the grafana/loki chart is Grafana Enterprise Logs only
# from 7.0). Both workflows call this script the same way: the chart dropped
# its CiliumNetworkPolicy flavor in 15.0, so the Kubernetes NetworkPolicy in
# loki-values.yaml is what every cluster gets.
# renovate: datasource=helm depName=loki registryUrl=https://grafana-community.github.io/helm-charts
helm upgrade --install loki loki --repo https://grafana-community.github.io/helm-charts --version 20.0.2 --values "$ROOT/loki-values.yaml" -n loki --create-namespace

# Vector replaces Promtail (deprecated upstream) as the per-node log shipper.
# It runs in this namespace so the Loki network policies and the verify
# job's rollout check cover it.
# renovate: datasource=helm depName=vector registryUrl=https://helm.vector.dev
helm upgrade --install vector vector --repo https://helm.vector.dev --version 0.60.0 --values "$ROOT/vector-values.yaml" -n loki

