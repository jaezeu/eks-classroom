#!/usr/bin/env bash
# Installs the Kyverno admission controller, applies the cluster guardrail
# policies from kyverno-policies/, then installs Policy Reporter (PolicyReport
# UI + Kyverno plugin) into the same namespace.
#
# Policy Reporter defaults to the standard (nginx Ingress) values. The Cilium
# workflow passes "gateway" to select the Gateway API values and apply the
# ListenerSet + HTTPRoute:   ./init.sh gateway
#
# NOTE: run this LAST in the bootstrap order. The policies enforce the
# *-eks-activity namespace naming format and block deletions in protected
# namespaces, which would interfere with other add-on installs. Policy
# Reporter lives in the existing kyverno namespace for the same reason, and
# it needs the PolicyReport CRDs that Kyverno installs.
# The cleanup workflow deletes the ClusterPolicies before uninstalling
# releases for the same reason.
ROOT="$(cd "$(dirname "$0")" && pwd)"
REPORTER_VALUES="$ROOT/policy-reporter-values.yaml"
REPORTER_ROUTE=""
case "${1:-}" in
  *gateway*|*cilium*)
    REPORTER_VALUES="$ROOT/policy-reporter-gateway-values.yaml"
    REPORTER_ROUTE="$ROOT/policy-reporter-gateway-route.yaml"
    ;;
esac

# --wait so the admission webhooks are ready before the policies are applied
# renovate: datasource=helm depName=kyverno registryUrl=https://kyverno.github.io/kyverno/
helm upgrade --install kyverno kyverno --repo https://kyverno.github.io/kyverno/ --version 3.8.1 \
  --namespace kyverno \
  --create-namespace \
  --values "$ROOT/values.yaml" \
  --wait

kubectl apply -f "$ROOT/../../kyverno-policies/"

# The Gateway API guardrail references HTTPRoute/ListenerSet kinds, which only
# exist on Cilium clusters; apply it only where those CRDs are installed.
if kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
  kubectl apply -f "$ROOT/../../kyverno-policies/gateway-api/"
fi

# Policy Reporter: PolicyReport UI and Kyverno plugin, in the kyverno namespace.
# renovate: datasource=helm depName=policy-reporter registryUrl=https://kyverno.github.io/policy-reporter
helm upgrade --install policy-reporter policy-reporter \
  --repo https://kyverno.github.io/policy-reporter \
  --version 3.11.2 \
  --namespace kyverno \
  --values "$REPORTER_VALUES"

if [ -n "$REPORTER_ROUTE" ]; then
  kubectl apply -f "$REPORTER_ROUTE"
fi
