#!/usr/bin/env bash
# Installs the Kyverno admission controller, then applies the cluster
# guardrail policies from kyverno-policies/.
#
# NOTE: run this LAST in the bootstrap order. The policies enforce the
# *-eks-activity namespace naming format and block deletions in protected
# namespaces, which would interfere with other add-on installs.
# The cleanup workflow deletes the ClusterPolicies before uninstalling
# releases for the same reason.

# ServiceMonitor CRDs, before this chart renders monitoring.coreos.com resources.
"$(cd "$(dirname "$0")" && pwd)/../kube-prometheus-stack/install-crds.sh"

# --wait so the admission webhooks are ready before the policies are applied
# renovate: datasource=helm depName=kyverno registryUrl=https://kyverno.github.io/kyverno/
helm upgrade --install kyverno kyverno --repo https://kyverno.github.io/kyverno/ --version 3.8.1 \
  --namespace kyverno \
  --create-namespace \
  --values values.yaml \
  --wait

kubectl apply -f ../../kyverno-policies/

# The Gateway API guardrail references HTTPRoute/ListenerSet kinds, which only
# exist on Cilium clusters; apply it only where those CRDs are installed.
if kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
  kubectl apply -f ../../kyverno-policies/gateway-api/
fi
