#!/usr/bin/env bash

# renovate: datasource=helm depName=aws-ebs-csi-driver registryUrl=https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver --repo https://kubernetes-sigs.github.io/aws-ebs-csi-driver --version 2.67.2 \
  --namespace kube-system \
  --values values.yaml
