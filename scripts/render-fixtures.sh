#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "사용법: $0 <렌더링 결과 디렉터리>" >&2
  exit 1
fi

output_dir="$1"
mkdir -p "$output_dir"
helm_dependency_build="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helm-dependency-build.sh"

# CI Runner의 빈 Helm 설정에서도 Prod CSI Chart 의존성을 받을 수 있게 공식 저장소를 등록한다.
# 기존 GitHub Actions Workflow는 변경하지 않고 렌더링 스크립트가 필요한 저장소만 자체 준비한다.
if [[ -f platform/prod/secrets-store-csi/driver/Chart.yaml ]]; then
  helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts --force-update >/dev/null
  helm repo add secrets-store-csi-provider-aws https://aws.github.io/secrets-store-csi-driver-provider-aws --force-update >/dev/null
fi

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

# 실제 서비스와 분리된 Prod 실패 알림 리허설 Deployment도 Schema 검사에 포함한다.
cp tests/prod/notification-failure/deployment.yaml "$output_dir/notification-test-prod.yaml"

# Prod는 도메인별로 순차 활성화한다. 활성화 Application이 있는 버전만 실제 values로 렌더링한다.
# PR Manifest Diff가 활성화 전 기준 커밋의 미완성 values를 렌더링하지 않도록 Application을 기준으로 판별한다.
if [[ -f argocd/prod/workloads/web-bff-application.yaml ]]; then
  helm template web-bff charts/lookddak-workload \
    --namespace lookddak-web \
    --kube-version 1.36.0 \
    -f environments/prod/images.yaml \
    -f environments/prod/domains/web/workloads/web-bff.yaml \
    > "$output_dir/web-bff-prod.yaml"

  helm template web-domain charts/lookddak-domain \
    --namespace lookddak-web \
    --kube-version 1.36.0 \
    -f environments/prod/domains/web/domain.yaml \
    > "$output_dir/web-domain-prod.yaml"
fi

if [[ -f argocd/prod/workloads/identity-api-application.yaml ]]; then
  for workload in identity-api body-image-validator; do
    helm template "$workload" charts/lookddak-workload \
      --namespace lookddak-identity \
      --kube-version 1.36.0 \
      -f environments/prod/images.yaml \
      -f "environments/prod/domains/identity/workloads/$workload.yaml" \
      > "$output_dir/$workload-prod.yaml"
  done

  helm template identity-domain charts/lookddak-domain \
    --namespace lookddak-identity \
    --kube-version 1.36.0 \
    -f environments/prod/domains/identity/domain.yaml \
    > "$output_dir/identity-domain-prod.yaml"
fi

if [[ -f argocd/prod/workloads/commerce-api-application.yaml ]]; then
  for workload in commerce-api price-crawler; do
    helm template "$workload" charts/lookddak-workload \
      --namespace lookddak-commerce \
      --kube-version 1.36.0 \
      -f environments/prod/images.yaml \
      -f "environments/prod/domains/commerce/workloads/$workload.yaml" \
      > "$output_dir/$workload-prod.yaml"
  done

  helm template commerce-domain charts/lookddak-domain \
    --namespace lookddak-commerce \
    --kube-version 1.36.0 \
    -f environments/prod/domains/commerce/domain.yaml \
    > "$output_dir/commerce-domain-prod.yaml"
fi

if [[ -f argocd/prod/workloads/chat-api-application.yaml ]]; then
  for workload in chat-api chat-ai; do
    helm template "$workload" charts/lookddak-workload \
      --namespace lookddak-chat \
      --kube-version 1.36.0 \
      -f environments/prod/images.yaml \
      -f "environments/prod/domains/chat/workloads/$workload.yaml" \
      > "$output_dir/$workload-prod.yaml"
  done

  helm template chat-domain charts/lookddak-domain \
    --namespace lookddak-chat \
    --kube-version 1.36.0 \
    -f environments/prod/domains/chat/domain.yaml \
    > "$output_dir/chat-domain-prod.yaml"
fi

if [[ -f argocd/prod/workloads/fitting-api-application.yaml ]]; then
  for workload in fitting-api fitting-worker vton-orchestrator; do
    helm template "$workload" charts/lookddak-workload \
      --namespace lookddak-fitting \
      --kube-version 1.36.0 \
      -f environments/prod/images.yaml \
      -f "environments/prod/domains/fitting/workloads/$workload.yaml" \
      > "$output_dir/$workload-prod.yaml"
  done

  helm template fitting-domain charts/lookddak-domain \
    --namespace lookddak-fitting \
    --kube-version 1.36.0 \
    -f environments/prod/domains/fitting/domain.yaml \
    > "$output_dir/fitting-domain-prod.yaml"
fi

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
