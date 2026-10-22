#!/usr/bin/env bash
# Values default to the standard (nginx Ingress) file. The Cilium workflow
# passes the Gateway API variant and then applies gateway-route.yaml:
#   ./init.sh gateway-values.yaml
#
# Runs after addons/kyverno/init.sh. The release lives in the kyverno
# namespace: the namespace-name policy would reject a new namespace, and the
# reporter needs the PolicyReport CRDs Kyverno installs.

VALUES_FILE="${1:-values.yaml}"

# ServiceMonitor CRDs. The chart emits one when monitoring is enabled.
"$(cd "$(dirname "$0")" && pwd)/../kube-prometheus-stack/install-crds.sh"

# renovate: datasource=helm depName=policy-reporter registryUrl=https://kyverno.github.io/policy-reporter
helm upgrade --install policy-reporter policy-reporter \
  --repo https://kyverno.github.io/policy-reporter \
  --version 3.11.1 \
  --namespace kyverno \
  --create-namespace \
  --values "$VALUES_FILE"
