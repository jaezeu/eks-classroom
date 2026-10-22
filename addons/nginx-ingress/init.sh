#!/usr/bin/env bash

# ServiceMonitor CRDs, before this chart renders monitoring.coreos.com resources.
"$(cd "$(dirname "$0")" && pwd)/../kube-prometheus-stack/install-crds.sh"

# renovate: datasource=helm depName=ingress-nginx registryUrl=https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --version 4.15.1 \
  --namespace ingress-nginx \
  --create-namespace \
  --values values.yaml
