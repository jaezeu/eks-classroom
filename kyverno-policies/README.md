# Kyverno Policies

Cluster-wide [Kyverno](https://kyverno.io/) `ClusterPolicy` resources that
enforce guardrails on this shared learning cluster. All policies run in
**Enforce** mode (violating requests are rejected at admission).

> Requires the Kyverno admission controller to be installed in the cluster
> first (`kyverno` namespace). The cluster creation workflows have a
> **kyverno** toggle that installs it via [addons/kyverno](../addons/kyverno/)
> and applies these policies automatically (as the last bootstrap step).

## Policies

| Policy | Enforces |
|--------|----------|
| [disallow-default-namespace](disallow-default-namespace.yaml) | Blocks creating resources in the `default` namespace, forcing workloads into named namespaces. |
| [restrict-namespace-name-format](restrict-namespace-name-format.yaml) | New namespace names must match the `*-eks-activity` format. |
| [restrict-ingress-hosts](restrict-ingress-hosts.yaml) | Ingress hosts must fall under `*.sctp-sandbox.com` (standard cluster). |
| [gateway-api/restrict-gateway-hostnames](gateway-api/restrict-gateway-hostnames.yaml) | Same domain guardrail for `HTTPRoute`/`ListenerSet` hostnames (Cilium cluster; applied only where the Gateway API CRDs exist). |
| [prevent-deletion-in-protected-namespaces](prevent-deletion-in-protected-namespaces.yaml) | Blocks deletion of **any** resource inside protected namespaces (`kube-system`, `ingress-nginx`, `cert-manager`, `external-dns`, `argocd`, `kyverno`). |
| [prevent-protected-namespace-deletion](prevent-protected-namespace-deletion.yaml) | Blocks deletion of the protected namespaces themselves. |

## Apply

```bash
# all policies (non-recursive; skips gateway-api/)
kubectl apply -f kyverno-policies/

# Gateway API guardrail, Cilium clusters only (needs the Gateway API CRDs)
kubectl apply -f kyverno-policies/gateway-api/

# or a single policy
kubectl apply -f kyverno-policies/disallow-default-namespace.yaml
```

## Customising

The protected namespace list, hostname suffix (`*.sctp-sandbox.com`) and
namespace naming pattern (`*-eks-activity`) are environment-specific. Edit the
relevant YAML before applying to a different cluster.
