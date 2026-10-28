#!/usr/bin/env bash

# renovate: datasource=helm depName=metrics-server registryUrl=https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server \
  --repo https://kubernetes-sigs.github.io/metrics-server/ \
  --version 3.14.0 \
  --namespace kube-system \
  --values values.yaml
