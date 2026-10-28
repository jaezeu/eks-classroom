#!/usr/bin/env bash

# Values default to the standard (nginx Ingress) file. The Cilium workflow
# passes the Gateway API variant:  ./init.sh gateway-values.yaml
VALUES_FILE="${1:-values.yaml}"

# renovate: datasource=helm depName=argo-cd registryUrl=https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version 10.11.6 \
  --namespace argocd --create-namespace \
  --values "$VALUES_FILE"
