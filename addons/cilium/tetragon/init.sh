#!/usr/bin/env bash

# renovate: datasource=helm depName=tetragon registryUrl=https://helm.cilium.io
helm upgrade --install tetragon tetragon --repo https://helm.cilium.io \
  --namespace kube-system \
  --version v1.5.0 \
  --values values.yaml
