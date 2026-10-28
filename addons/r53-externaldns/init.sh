#!/usr/bin/env bash

# Values default to the standard (Ingress + Service sources) file. The Cilium
# workflow passes the Gateway API variant:  ./init.sh gateway-values.yaml
VALUES_FILE="${1:-values.yaml}"

# renovate: datasource=helm depName=external-dns registryUrl=https://kubernetes-sigs.github.io/external-dns/
helm upgrade --install external-dns external-dns --repo https://kubernetes-sigs.github.io/external-dns/ --version 1.21.1 \
  --namespace external-dns \
  --create-namespace \
  --values "$VALUES_FILE"
