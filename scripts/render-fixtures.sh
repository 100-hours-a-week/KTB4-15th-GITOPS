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

echo "Helm Manifest 렌더링 완료: Fixture 5개, Argo CD 1개"
