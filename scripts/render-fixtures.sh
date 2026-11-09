#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "사용법: $0 <렌더링 결과 디렉터리>" >&2
  exit 1
fi

output_dir="$1"
mkdir -p "$output_dir"
helm_dependency_build="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helm-dependency-build.sh"

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

# 실제 Commerce values도 렌더링해 미완성 필수값과 두 Crawler CronJob을 CI에서 검증한다.
helm template commerce-api charts/lookddak-workload \
  --namespace lookddak-commerce \
  --kube-version 1.36.0 \
  -f environments/dev/images.yaml \
  -f environments/dev/domains/commerce/workloads/commerce-api.yaml \
  > "$output_dir/commerce-api-dev.yaml"

helm template price-crawler charts/lookddak-workload \
  --namespace lookddak-commerce \
  --kube-version 1.36.0 \
  -f environments/dev/images.yaml \
  -f environments/dev/domains/commerce/workloads/price-crawler.yaml \
  > "$output_dir/price-crawler-dev.yaml"

helm template commerce-domain charts/lookddak-domain \
  --namespace lookddak-commerce \
  --kube-version 1.36.0 \
  -f environments/dev/domains/commerce/domain.yaml \
  > "$output_dir/commerce-domain-dev.yaml"

# 실제 Fitting values도 함께 렌더링해 역할별 Queue·Secret·Route 설정을 검증한다.
for workload in fitting-api fitting-worker vton-orchestrator; do
  helm template "$workload" charts/lookddak-workload \
    --namespace lookddak-fitting \
    --kube-version 1.36.0 \
    -f environments/dev/images.yaml \
    -f "environments/dev/domains/fitting/workloads/$workload.yaml" \
    > "$output_dir/$workload-dev.yaml"
done

helm template fitting-domain charts/lookddak-domain \
  --namespace lookddak-fitting \
  --kube-version 1.36.0 \
  -f environments/dev/domains/fitting/domain.yaml \
  > "$output_dir/fitting-domain-dev.yaml"

helm template fixture-domain charts/lookddak-domain \
  -f ci/fixtures/domain-policy.yaml \
  > "$output_dir/domain-policy.yaml"

if [[ -f platform/dev/argocd/Chart.yaml ]]; then
  "$helm_dependency_build" platform/dev/argocd >/dev/null
  helm template argocd platform/dev/argocd \
    --namespace argocd \
    --kube-version 1.36.0 \
    --include-crds \
    > "$output_dir/argocd-dev.yaml"
fi

if [[ -f platform/prod/argocd/Chart.yaml ]]; then
  "$helm_dependency_build" platform/prod/argocd >/dev/null
  helm template argocd platform/prod/argocd \
    --namespace argocd \
    --kube-version 1.36.0 \
    --include-crds \
    > "$output_dir/argocd-prod.yaml"
fi

if [[ -f platform/dev/karpenter/crd/Chart.yaml ]]; then
  "$helm_dependency_build" platform/dev/karpenter/crd >/dev/null
  helm template karpenter-crd platform/dev/karpenter/crd \
    --namespace kube-system \
    --kube-version 1.36.0 \
    --include-crds \
    > "$output_dir/karpenter-crd-dev.yaml"
fi

if [[ -f platform/dev/karpenter/controller/Chart.yaml ]]; then
  "$helm_dependency_build" platform/dev/karpenter/controller >/dev/null
  helm template karpenter platform/dev/karpenter/controller \
    --namespace kube-system \
    --kube-version 1.36.0 \
    --skip-crds \
    > "$output_dir/karpenter-controller-dev.yaml"
fi

if [[ -f platform/prod/karpenter/crd/Chart.yaml ]]; then
  "$helm_dependency_build" platform/prod/karpenter/crd >/dev/null
  helm template karpenter-crd platform/prod/karpenter/crd \
    --namespace kube-system \
    --kube-version 1.36.0 \
    --include-crds \
    > "$output_dir/karpenter-crd-prod.yaml"
fi

if [[ -f platform/prod/karpenter/controller/Chart.yaml ]]; then
  "$helm_dependency_build" platform/prod/karpenter/controller >/dev/null
  helm template karpenter platform/prod/karpenter/controller \
    --namespace kube-system \
    --kube-version 1.36.0 \
    --skip-crds \
    > "$output_dir/karpenter-controller-prod.yaml"
fi

if [[ -f platform/dev/metrics-server/Chart.yaml ]]; then
  "$helm_dependency_build" platform/dev/metrics-server >/dev/null
  helm template metrics-server platform/dev/metrics-server \
    --namespace kube-system \
    --kube-version 1.36.0 \
    > "$output_dir/metrics-server-dev.yaml"
fi

if [[ -f platform/prod/metrics-server/Chart.yaml ]]; then
  "$helm_dependency_build" platform/prod/metrics-server >/dev/null
  helm template metrics-server platform/prod/metrics-server \
    --namespace kube-system \
    --kube-version 1.36.0 \
    > "$output_dir/metrics-server-prod.yaml"
fi

for component in driver provider-aws; do
  if [[ -f "platform/prod/secrets-store-csi/$component/Chart.yaml" ]]; then
    "$helm_dependency_build" "platform/prod/secrets-store-csi/$component" >/dev/null
    helm template "secrets-store-csi-$component" "platform/prod/secrets-store-csi/$component" \
      --namespace kube-system \
      --kube-version 1.36.0 \
      > "$output_dir/secrets-store-csi-$component-prod.yaml"
  fi
done

if [[ -f platform/dev/networking/aws-load-balancer-controller/Chart.yaml ]]; then
  "$helm_dependency_build" platform/dev/networking/aws-load-balancer-controller >/dev/null
  helm template aws-load-balancer-controller platform/dev/networking/aws-load-balancer-controller \
    --namespace kube-system \
    --kube-version 1.36.0 \
    > "$output_dir/aws-load-balancer-controller-dev.yaml"
fi

if [[ -f platform/prod/networking/aws-load-balancer-controller/Chart.yaml ]]; then
  "$helm_dependency_build" platform/prod/networking/aws-load-balancer-controller >/dev/null
  helm template aws-load-balancer-controller platform/prod/networking/aws-load-balancer-controller \
    --namespace kube-system \
    --kube-version 1.36.0 \
    > "$output_dir/aws-load-balancer-controller-prod.yaml"
fi

for chart in base istiod cni ztunnel; do
  if [[ -f "platform/dev/networking/istio/$chart/Chart.yaml" ]]; then
    "$helm_dependency_build" "platform/dev/networking/istio/$chart" >/dev/null
    helm template "istio-$chart" "platform/dev/networking/istio/$chart" \
      --namespace istio-system \
      --kube-version 1.36.0 \
      > "$output_dir/istio-$chart-dev.yaml"
  fi
done

for chart in base istiod cni ztunnel; do
  if [[ -f "platform/prod/networking/istio/$chart/Chart.yaml" ]]; then
    "$helm_dependency_build" "platform/prod/networking/istio/$chart" >/dev/null
    helm template "istio-$chart" "platform/prod/networking/istio/$chart" \
      --namespace istio-system \
      --kube-version 1.36.0 \
      > "$output_dir/istio-$chart-prod.yaml"
  fi
done

if [[ -f platform/dev/cert-manager/controller/Chart.yaml ]]; then
  "$helm_dependency_build" platform/dev/cert-manager/controller >/dev/null
  helm template cert-manager platform/dev/cert-manager/controller \
    --namespace kube-system \
    --kube-version 1.36.0 \
    > "$output_dir/cert-manager-dev.yaml"
fi

if [[ -f platform/prod/cert-manager/controller/Chart.yaml ]]; then
  "$helm_dependency_build" platform/prod/cert-manager/controller >/dev/null
  helm template cert-manager platform/prod/cert-manager/controller \
    --namespace kube-system \
    --kube-version 1.36.0 \
    > "$output_dir/cert-manager-prod.yaml"
fi

# 정적 NodePool 리소스도 Schema와 PR Manifest Diff 검증에 포함한다.
if [[ -f platform/dev/karpenter/nodepool/nodepool.yaml ]]; then
  cp platform/dev/karpenter/nodepool/ec2-nodeclass.yaml "$output_dir/karpenter-ec2nodeclass-dev.yaml"
  cp platform/dev/karpenter/nodepool/nodepool.yaml "$output_dir/karpenter-nodepool-dev.yaml"
fi


if [[ -f platform/prod/karpenter/nodepool/nodepool.yaml ]]; then
  cp platform/prod/karpenter/nodepool/ec2-nodeclass.yaml "$output_dir/karpenter-ec2nodeclass-prod.yaml"
  cp platform/prod/karpenter/nodepool/nodepool.yaml "$output_dir/karpenter-nodepool-prod.yaml"
fi

echo "Manifest 준비 완료: 공통 Fixture·Argo CD·Karpenter·Metrics Server·AWS LB Controller·Istio·cert-manager Chart 및 NodePool 선언"
