#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "사용법: $0 <fe|be|ai|crawler> <렌더링 결과 디렉터리> [소스 루트]" >&2
  exit 1
fi

image_group="$1"
output_dir="$2"
source_root="${3:-.}"

case "$image_group" in
  fe)
    workloads=("web:web-bff")
    ;;
  be)
    workloads=(
      "identity:identity-api"
      "commerce:commerce-api"
      "chat:chat-api"
      "fitting:fitting-api"
      "fitting:fitting-worker"
    )
    ;;
  ai)
    workloads=(
      "identity:body-image-validator"
      "chat:chat-ai"
      "fitting:vton-orchestrator"
    )
    ;;
  crawler)
    workloads=("commerce:price-crawler")
    ;;
  *)
    echo "지원하지 않는 이미지 그룹입니다: $image_group" >&2
    exit 1
    ;;
esac

mkdir -p "$output_dir"

for entry in "${workloads[@]}"; do
  domain="${entry%%:*}"
  workload="${entry#*:}"
  helm template "$workload" "$source_root/charts/lookddak-workload" \
    --namespace "lookddak-$domain" \
    --kube-version 1.36.0 \
    -f "$source_root/environments/dev/images.yaml" \
    -f "$source_root/environments/dev/domains/$domain/workloads/$workload.yaml" \
    > "$output_dir/$workload-dev.yaml"
done

echo "Dev $image_group 이미지 영향 워크로드 렌더링 완료: ${workloads[*]}"
