#!/usr/bin/env bash
# Installs Cilium into kube-system. Expects values.yaml to already have
# ${CLUSTER_ENDPOINT} substituted (the workflow envsubst's it beforehand).

# 1.20.0-pre.4 is the first release with Gateway API ListenerSet support
# (cilium/cilium#46303), required by the per-add-on ListenerSets in
# addons/*/gateway-route.yaml. Move to stable 1.20.x once released.
# renovate: datasource=helm depName=cilium registryUrl=https://helm.cilium.io/
helm upgrade --install cilium cilium --repo https://helm.cilium.io/ --version 1.20.0-pre.4 \
  --namespace kube-system \
  --values values.yaml \
  --values spire.yaml
