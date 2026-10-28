#!/usr/bin/env bash

# renovate: datasource=helm depName=tetragon registryUrl=https://helm.cilium.io
helm upgrade --install tetragon tetragon --repo https://helm.cilium.io \
  --namespace kube-system \
  --version 1.7.1 \
  --values values.yaml
