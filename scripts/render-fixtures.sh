#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "사용법: $0 <렌더링 결과 디렉터리>" >&2
  exit 1
fi

output_dir="$1"
mkdir -p "$output_dir"

helm template fixture-routed charts/lookddak-workload \
  -f ci/fixtures/routed-deployment.yaml \
  > "$output_dir/routed-deployment.yaml"

helm template fixture-autoscaled charts/lookddak-workload \
  -f ci/fixtures/autoscaled-deployment.yaml \
  > "$output_dir/autoscaled-deployment.yaml"

helm template fixture-worker charts/lookddak-workload \
  -f ci/fixtures/worker.yaml \
  > "$output_dir/worker.yaml"

helm template fixture-cronjob charts/lookddak-workload \
  -f ci/fixtures/cronjob.yaml \
  > "$output_dir/cronjob.yaml"

helm template fixture-domain charts/lookddak-domain \
  -f ci/fixtures/domain-policy.yaml \
  > "$output_dir/domain-policy.yaml"

if [[ -f platform/dev/argocd/Chart.yaml ]]; then
  helm dependency build platform/dev/argocd >/dev/null
  helm template argocd platform/dev/argocd \
    --namespace argocd \
    --kube-version 1.36.0 \
    --include-crds \
    > "$output_dir/argocd-dev.yaml"
fi

if [[ -f platform/dev/karpenter/crd/Chart.yaml ]]; then
  helm dependency build platform/dev/karpenter/crd >/dev/null
  helm template karpenter-crd platform/dev/karpenter/crd \
    --namespace kube-system \
    --kube-version 1.36.0 \
    --include-crds \
    > "$output_dir/karpenter-crd-dev.yaml"
fi

if [[ -f platform/dev/karpenter/controller/Chart.yaml ]]; then
  helm dependency build platform/dev/karpenter/controller >/dev/null
  helm template karpenter platform/dev/karpenter/controller \
    --namespace kube-system \
    --kube-version 1.36.0 \
    --skip-crds \
    > "$output_dir/karpenter-controller-dev.yaml"
fi

if [[ -f platform/dev/metrics-server/Chart.yaml ]]; then
  helm dependency build platform/dev/metrics-server >/dev/null
  helm template metrics-server platform/dev/metrics-server \
    --namespace kube-system \
    --kube-version 1.36.0 \
    > "$output_dir/metrics-server-dev.yaml"
fi

# 정적 NodePool 리소스도 Schema와 PR Manifest Diff 검증에 포함한다.
if [[ -f platform/dev/karpenter/nodepool/nodepool.yaml ]]; then
  cp platform/dev/karpenter/nodepool/ec2-nodeclass.yaml "$output_dir/karpenter-ec2nodeclass-dev.yaml"
  cp platform/dev/karpenter/nodepool/nodepool.yaml "$output_dir/karpenter-nodepool-dev.yaml"
fi

echo "Manifest 준비 완료: 공통 Fixture·Argo CD·Karpenter·Metrics Server Chart 및 NodePool 선언"
