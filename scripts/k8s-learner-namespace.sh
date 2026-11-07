#!/usr/bin/env bash
# Provisions one Kubernetes namespace per learner in an IAM group, following
# the *-eks-activity naming convention enforced by Kyverno.
# Usernames are lowercased and sanitised to meet DNS label constraints.
# Idempotent: uses --dry-run=client | apply so re-runs are safe.
#
# Usage: AWS_PROFILE=<profile> ./scripts/k8s-learner-namespace.sh
#        AWS_PROFILE=<profile> ./scripts/k8s-learner-namespace.sh --group <name>
# Requires: aws cli, kubectl (pointed at target cluster)

set -euo pipefail

usage() {
  echo "Usage: $0 [--group|-g <name>]"
}

group_name=
while (($#)); do
  case "$1" in
    --group|-g)
      if (($# < 2)) || [[ -z "$2" ]]; then
        usage >&2
        exit 2
      fi
      group_name=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$group_name" ]]; then
  available_groups=$(aws iam list-groups \
    --query "Groups[?starts_with(GroupName, 'sctp-cloud-')].GroupName" \
    --output text)
  groups=()
  while IFS= read -r group; do
    if [[ -n "$group" && "$group" != "None" ]]; then
      groups+=("$group")
    fi
  done < <(printf '%s\n' "$available_groups" | tr '\t' '\n')

  if ((${#groups[@]} == 0)); then
    echo "No IAM groups with the 'sctp-cloud-' prefix were found." >&2
    exit 1
  fi

  PS3="Select an IAM group: "
  select selected_group in "${groups[@]}"; do
    if [[ -n "$selected_group" ]]; then
      group_name=$selected_group
      break
    fi
    echo "Invalid selection." >&2
  done

  if [[ -z "$group_name" ]]; then
    echo "No IAM group selected." >&2
    exit 1
  fi
fi

users=$(aws iam get-group \
  --group-name "$group_name" \
  --query 'Users[].UserName' \
  --output text)

while IFS= read -r user; do
  [[ -z "$user" || "$user" == "None" ]] && continue

  ns=$(echo "$user" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g' \
    | sed 's/^-*//;s/-*$//' \
    | cut -c1-49)-eks-activity

  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done < <(printf '%s\n' "$users" | tr '\t' '\n')
