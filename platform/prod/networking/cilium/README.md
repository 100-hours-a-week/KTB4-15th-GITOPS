# Cilium — prod

## 목적

EKS prod(`lookddak-prod`)의 Cilium Bootstrap 설정을 관리한다. Cilium은 ENI 기반 Pod 네트워크, kube-proxy 대체와 L3/L4 정책 기반을 담당한다.

## 관리 경계

- 버전: Cilium `1.20.4`, Namespace `kube-system`
- Cilium은 Argo CD보다 먼저 필요한 CNI이므로 **Argo CD Application으로 관리하지 않는다**.
- Terraform도 Cilium Helm Release를 소유하지 않는다.
- 변경은 PR 검증과 리뷰를 거쳐 `main`에 Merge한 뒤, 네트워크 담당자가 `main`의 values로 수동 `helm upgrade`한다.
- 운영 변경 실패 시 Helm Rollback으로 네트워크를 먼저 복구하고 같은 내용을 Git Revert PR로 남긴다.

## Prod 고정 값

- Cluster: `lookddak-prod`, EKS `1.36`
- Private API: `98FAA5345EEC969890293E6E0090CC4C.gr7.ap-northeast-2.eks.amazonaws.com`
- Pod CIDR: `100.64.0.0/16`
- Pod Subnet: `Tier=private-pod` 태그가 있는 2a·2c Subnet
- Operator IRSA: `arn:aws:iam::686496667254:role/lookddak-prod-cilium-operator`
- API Access Host: `lookddak-prod-monitoring` EC2, SSM Document `lookddak-prod-api-port-forward`
- Hubble: Agent Flow 수집만 활성화하며 Relay·UI는 CoreDNS 완료 후 관측 PR에서 활성화
- Metrics: Cilium Agent·Operator·Hubble Prometheus endpoint만 활성화하며 실제 수집은 Prod 관측 PR에서 연결

## 최초 Bootstrap

아래 명령은 이 저장소의 `main`을 최신화한 상태에서 실행한다. Terminal 1의 SSM Session은 검증이 끝날 때까지 유지한다.

### Terminal 1 — Private EKS API Tunnel

```bash
aws ssm start-session \
  --region ap-northeast-2 \
  --target i-05542e51bdea3fb64 \
  --document-name lookddak-prod-api-port-forward \
  --parameters '{"localPortNumber":["9443"]}'
```

### Terminal 2 — kubeconfig와 Cilium 설치

```bash
export AWS_REGION=ap-northeast-2
export PROD_CLUSTER_ARN="$(aws eks describe-cluster --region "$AWS_REGION" --name lookddak-prod --query 'cluster.arn' --output text)"
export PROD_API_HOST="$(aws eks describe-cluster --region "$AWS_REGION" --name lookddak-prod --query 'cluster.endpoint' --output text | sed 's#https://##')"

aws eks update-kubeconfig --region "$AWS_REGION" --name lookddak-prod
kubectl config set-cluster "$PROD_CLUSTER_ARN" \
  --server=https://127.0.0.1:9443 \
  --tls-server-name="$PROD_API_HOST"
kubectl config use-context "$PROD_CLUSTER_ARN"

git checkout main
git pull --ff-only origin main
helm repo add cilium https://helm.cilium.io --force-update
helm repo update cilium
helm upgrade --install cilium cilium/cilium \
  --version 1.20.4 \
  --namespace kube-system \
  --values platform/prod/networking/cilium/values.yaml \
  --wait \
  --timeout 15m
```

## 검증

```bash
helm status cilium -n kube-system
helm history cilium -n kube-system
kubectl get nodes -o wide
kubectl -n kube-system get pods -l app.kubernetes.io/part-of=cilium -o wide
kubectl -n kube-system get ds cilium
kubectl -n kube-system get deploy cilium-operator
```

확인 기준은 다음과 같다.

- System Node 2대가 `Ready`
- 각 Node에 `cilium` Pod 1개가 `Running`
- `cilium-operator` 2개가 `Running`
- `node.cilium.io/agent-not-ready` Taint 제거
- Pod IP가 `100.64.0.0/16` 범위

Cilium 확인 후 Cloud Terraform Apply를 다시 실행해 System Node Group State와 CoreDNS·EBS CSI Add-on 생성을 완료한다.

## 변경과 Rollback

변경 전 현재 Revision을 기록한다.

```bash
helm history cilium -n kube-system
```

문제가 발생하면 직전 정상 Revision으로 복구한다.

```bash
helm rollback cilium <정상_REVISION> -n kube-system --wait --timeout 15m
```

긴급 복구 후에는 실패한 변경을 Revert하는 PR을 생성하여 Git `main`과 실제 Cluster 설정을 다시 일치시킨다. Cilium Release를 `helm uninstall`하지 않는다.
