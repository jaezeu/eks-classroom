#!/usr/bin/env bash

ROOT="$(cd "$(dirname "$0")" && pwd)"

# The OSS Loki chart lives in grafana-community/helm-charts (forked from
# grafana/loki 6.55.0; the grafana/loki chart is Grafana Enterprise Logs only
# from 7.0). Both workflows call this script the same way: the chart dropped
# its CiliumNetworkPolicy flavor in 15.0, so the Kubernetes NetworkPolicy in
# loki-values.yaml is what every cluster gets.
# renovate: datasource=helm depName=loki registryUrl=https://grafana-community.github.io/helm-charts
helm upgrade --install loki loki --repo https://grafana-community.github.io/helm-charts --version 20.0.2 --values "$ROOT/loki-values.yaml" -n loki --create-namespace

# renovate: datasource=helm depName=promtail registryUrl=https://grafana.github.io/helm-charts
helm upgrade --install promtail promtail --repo https://grafana.github.io/helm-charts --version 6.17.1 --values promtail-values.yaml -n loki

