#!/usr/bin/env bash
# Installs Cilium into kube-system. Expects values.yaml to already have
# ${CLUSTER_ENDPOINT} substituted (the workflow envsubst's it beforehand).

# Cilium 1.20 added Gateway API ListenerSet support (cilium/cilium#46303),
# required by the per-add-on ListenerSets in addons/*/gateway-route.yaml.
# 1.20.x needs the Gateway API v1.6.1+ CRDs, which the Cilium workflow applies
# before this install.
# renovate: datasource=helm depName=cilium registryUrl=https://helm.cilium.io/
helm upgrade --install cilium cilium --repo https://helm.cilium.io/ --version 1.20.4 \
  --namespace kube-system \
  --values values.yaml
