#!/usr/bin/env bash
# Renders every add-on's Helm chart with the repo's values files and validates
# the output with kubeconform; no cluster needed. Run locally or from CI
# (.github/workflows/manifest-checks.yml).
#
# Each add-on's init.sh stays the single source of truth for chart, version and
# values files: this script shims `helm` and `kubectl` as exported functions so
# that `helm upgrade --install` becomes `helm template` and `kubectl apply`
# becomes schema validation. Values placeholders that the workflows envsubst at
# deploy time are substituted with dummies.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# exported: the helm/kubectl shims run inside each init.sh's child shell
export KUBE_VERSION="${KUBE_VERSION:-1.33.0}"

# Dummy values for the ${...} placeholders normally substituted by the
# cluster-creation workflows.
export CLUSTER_ENDPOINT="example.eks.amazonaws.com"
export REGION="ap-southeast-1"
export CLUSTER_NAME="dummy-cluster"
export EXTERNAL_DNS_ROLE_ARN="arn:aws:iam::111111111111:role/dummy"
export EBS_CSI_ROLE_ARN="arn:aws:iam::111111111111:role/dummy"
export LOKI_S3_ROLE_ARN="arn:aws:iam::111111111111:role/dummy"
export LOKI_CHUNKS_BUCKET="dummy-chunks"
export LOKI_RULER_BUCKET="dummy-ruler"
export EMAIL="dummy@example.com"

kubeconform_cmd() {
  kubeconform \
    -strict -summary \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    -ignore-missing-schemas \
    -kubernetes-version "$KUBE_VERSION" \
    "$@"
}

# Shim: rewrite `helm upgrade --install ...` to `helm template ...`, envsubst
# any --values file, and pipe the rendered manifests through kubeconform.
helm() {
  local args=() prev=""
  for a in "$@"; do
    case "$a" in
      upgrade) args+=(template) ;;
      --install|--wait|--create-namespace) ;; # meaningless for template
      *)
        if [ "$prev" = "--values" ] || [ "$prev" = "-f" ]; then
          local rendered
          rendered="$(mktemp)"
          envsubst < "$a" > "$rendered"
          args+=("$rendered")
        else
          args+=("$a")
        fi
        ;;
    esac
    prev="$a"
  done
  echo "  helm ${args[*]}" >&2
  # --api-versions: the workflows run install-crds.sh before the first add-on,
  # so on a real cluster the ServiceMonitor API exists by the time the chart renders (and
  # charts such as cilium refuse to render ServiceMonitors without it).
  # subshell + pipefail: a failed render must fail the check even though
  # kubeconform would exit 0 on the resulting empty input
  (set -o pipefail; command helm "${args[@]}" --kube-version "$KUBE_VERSION" \
    --api-versions monitoring.coreos.com/v1 --api-versions monitoring.coreos.com/v1/ServiceMonitor \
    | kubeconform_cmd -)
}
export -f helm kubeconform_cmd

# Shim: `kubectl apply -f <path>` validates the file/dir instead of applying;
# `kubectl get crd ...` pretends the CRD exists (validate the Cilium-only
# policies too); everything else is a no-op.
kubectl() {
  case "$1" in
    apply)
      local path=""
      local prev=""
      for a in "$@"; do
        [ "$prev" = "-f" ] && path="$a"
        prev="$a"
      done
      echo "  kubectl apply -f $path -> kubeconform" >&2
      if [ -d "$path" ]; then
        envsubst_dir="$(mktemp -d)"
        for f in "$path"/*.y*ml; do envsubst < "$f" > "$envsubst_dir/$(basename "$f")"; done
        kubeconform_cmd "$envsubst_dir"
      else
        envsubst < "$path" | kubeconform_cmd -
      fi
      ;;
    get) return 0 ;;
    *) return 0 ;;
  esac
}
export -f kubectl

ADDONS=(
  argocd
  cert-manager
  cilium
  cilium/tetragon
  ebs-csi-driver
  kube-prometheus-stack
  kyverno
  metrics-server
  keda
  loki
  opentelemetry-demo
  nginx-ingress
  r53-externaldns
  trivy-operator
)

# Add-ons with a Gateway API variant get validated twice: default values and
# the gateway-* files the Cilium workflow passes.
declare -A GATEWAY_ARGS=(
  [argocd]="gateway-values.yaml"
  [cert-manager]="gateway-values.yaml gateway-cluster-issuer.yaml"
  [kube-prometheus-stack]="gateway-values.yaml"
  [kyverno]="gateway"
  [r53-externaldns]="gateway-values.yaml"
)

rc=0
# bash -e: abort an init.sh on the first failed command, so a broken render in
# a multi-command script (e.g. cert-manager) can't be masked by a later success
for addon in "${ADDONS[@]}"; do
  echo "==> $addon (default values)"
  (cd "$REPO_ROOT/addons/$addon" && bash -e init.sh) || rc=1
  if [ -n "${GATEWAY_ARGS[$addon]:-}" ]; then
    echo "==> $addon (gateway variant)"
    # shellcheck disable=SC2086 # word-splitting the args is intended
    (cd "$REPO_ROOT/addons/$addon" && bash -e init.sh ${GATEWAY_ARGS[$addon]}) || rc=1
  fi
done

exit $rc
