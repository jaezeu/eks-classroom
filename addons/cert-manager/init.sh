#!/usr/bin/env bash

# Values + ClusterIssuer default to the standard (nginx) files. The Cilium
# workflow passes the Gateway API variants:
#   ./init.sh gateway-values.yaml gateway-cluster-issuer.yaml
VALUES_FILE="${1:-values.yaml}"
ISSUER_FILE="${2:-cluster-issuer.yaml}"

# The issuer file carries two placeholders, filled from the environment:
#   EMAIL        ACME registration address (the workflows pass secrets.EMAIL_ADDRESS)
#   ACME_SERVER  Let's Encrypt directory URL; defaults to production. The
#                workflows pass the staging URL when staging-certs is on
#                (rehearsals), which keeps those runs off the production
#                quota of 5 duplicate certificates per week.
: "${EMAIL:?set EMAIL to the ACME registration address}"
export ACME_SERVER="${ACME_SERVER:-https://acme-v02.api.letsencrypt.org/directory}"

# renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
helm upgrade --install cert-manager cert-manager --repo https://charts.jetstack.io \
  --namespace cert-manager \
  --create-namespace \
  --version v1.20.2 \
  --values "$VALUES_FILE"

# shellcheck disable=SC2016  # literal ${VAR} names are envsubst syntax, not shell
envsubst '${EMAIL} ${ACME_SERVER}' < "$ISSUER_FILE" | kubectl apply -f -
