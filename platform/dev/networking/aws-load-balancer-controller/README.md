# AWS Load Balancer Controller — dev

## 목적

EKS dev(`lookddak-dev`)에서 Istio Gateway의 Service(`type: LoadBalancer`)를 보고 **내부 NLB(target-type `ip`)**를 만드는 Controller다. 공식 `aws-load-balancer-controller` Chart를 Wrapper Chart로 고정해 Argo CD가 관리한다.

```text
CloudFront + WAF → 내부 NLB (LBC가 생성) → Istio Gateway Pod IP → HTTPRoute → Service
```

- LBC는 NLB를 **만들고 Target(Pod IP)을 갱신**만 한다. 사용자 트래픽은 LBC를 지나가지 않는다
- L7 라우팅·Gateway API는 Istio가 담당한다. LBC의 ALB Ingress·Gateway API 기능은 쓰지 않는다

## 현재 설정

| 항목 | 값 | 이유 |
| --- | --- | --- |
| Chart | `aws-load-balancer-controller` `3.6.2` (`https://aws.github.io/eks-charts`) | 2026-11-03 기준 최신 |
| IRSA | `kube-system/aws-load-balancer-controller` → `lookddak-dev-aws-load-balancer-controller` | KTB4-15th-CLOUD `dev/v3/iam` (LBC v3.6.2 공식 IAM 정책) |
| Replica | 2, 차트 기본 podAntiAffinity, PDB `maxUnavailable: 1` | Controller 1개 장애 시에도 Target 갱신 유지 |
| 배치 | `lookddak.io/node-pool=system`, `arm64`, `CriticalAddonsOnly` Toleration | System Node 격리 정책 |
| `createIngressClassResource` | `false` | ALB Ingress 미사용 |
| `enableServiceMutatorWebhook` | `true` | 새 `type: LoadBalancer` Service에 LBC `loadBalancerClass`를 기본 주입 (EKS 기본 CCM의 CLB 생성 방지) |
| `defaultTargetType` | `ip` | Pod가 VPC IP(Cilium ENI)를 받으므로 NodePort 경유 없이 Pod로 직접 전달 |
| Feature Gate | `NLBGatewayAPI=false`, `ALBGatewayAPI=false` | Gateway API는 Istio 담당 |

## Webhook 인증서와 Argo CD

Chart는 Webhook TLS 인증서를 렌더링할 때마다 새로 만든다(`genCA`). Helm CLI는 `lookup`으로 기존 Secret을 재사용할 수 있지만 Argo CD는 클러스터 조회(`lookup`)를 하지 않아 매번 다른 인증서가 렌더링된다. 그대로 두면 OutOfSync가 반복되고, 인증서와 `caBundle` 짝이 어긋나 Service 생성이 거부될 수 있다.

따라서 Application에서 다음 필드를 비교·적용에서 제외한다 (`RespectIgnoreDifferences=true`).

| 리소스 | 제외 필드 |
| --- | --- |
| `MutatingWebhookConfiguration/aws-load-balancer-webhook` | `.webhooks[].clientConfig.caBundle` |
| `ValidatingWebhookConfiguration/aws-load-balancer-webhook` | `.webhooks[].clientConfig.caBundle` |
| `Secret/aws-load-balancer-tls` | `/data` |

최초 Sync에서 만든 인증서 짝(유효기간 10년)이 계속 유지된다. 인증서를 교체해야 하면 위 Secret과 두 Webhook을 함께 삭제한 뒤 Sync한다. 인증서가 필요한 구성요소가 늘면 cert-manager 도입 후 `enableCertManager: true`로 전환을 검토한다.

## 서브넷·보안그룹

- 내부 NLB 서브넷: `kubernetes.io/role/internal-elb=1`, `kubernetes.io/cluster/lookddak-dev=shared` 태그가 있는 node 서브넷 2a/2c (KTB4-15th-CLOUD `dev/v3/network`)
- Target(Pod ENI)은 EKS Cluster SG를 쓴다. LBC가 NLB SG → Target SG 인바운드 규칙을 관리한다

## 로컬 검증

```bash
helm dependency build platform/dev/networking/aws-load-balancer-controller
helm lint platform/dev/networking/aws-load-balancer-controller --namespace kube-system --kube-version 1.36.0
helm template aws-load-balancer-controller platform/dev/networking/aws-load-balancer-controller --namespace kube-system --kube-version 1.36.0
```

`charts/`는 Git에 저장하지 않고 `Chart.lock`만 저장한다.

## 반영 후 확인

```bash
kubectl -n argocd get application lookddak-dev-aws-load-balancer-controller
kubectl -n kube-system get deploy aws-load-balancer-controller -o wide
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller -o wide
kubectl -n kube-system logs deploy/aws-load-balancer-controller | tail -20
```

- Application `Synced/Healthy`, Pod 2개가 System Node 2대에 1개씩 Running
- 로그에 AWS 권한 오류(`AccessDenied`, `WebIdentityErr`)가 없어야 한다
- 실제 NLB 생성은 Istio Gateway 작업에서 검증한다

## 참고

- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [eks-charts aws-load-balancer-controller](https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller)
- [Argo CD Diffing Customization](https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/)
