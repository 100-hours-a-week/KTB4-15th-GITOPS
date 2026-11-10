# Argo CD — prod

## 목적

EKS prod에 설치된 Argo CD가 GitOps 저장소의 prod 목표 상태를 읽어 도메인 정책과 워크로드를 배포하도록 정의하는 디렉터리다. 이 디렉터리는 Argo CD 자체를 설치하지 않는다.

## 현재 작성된 범위

- `domain-applicationset.yaml`은 prod의 5개 `domain.yaml`을 `lookddak-domain` Chart와 조합한다.
- `workload-applicationset.yaml`은 prod의 10개 워크로드 values를 `lookddak-workload` Chart 및 `images.yaml`과 조합한다.
- 두 ApplicationSet은 Git 변경을 자동 동기화하고 `Self Heal`, `Prune`, `allowEmpty: false`, `PruneLast=true` 정책을 사용한다.
- 배포 대상은 각 도메인의 `lookddak-*` Namespace이며, Argo CD가 실행되는 클러스터 내부 주소를 사용한다.

## Bootstrap 완료 후 단계적으로 준비할 항목

- 외부 Gateway·DNS를 통한 Argo CD 접근과 GitHub Webhook
- 운영 Namespace 생성 주체
- dev에서 검증하여 승격할 ECR Image Digest
- 워크로드별 Port, Resource, Probe, HPA, PDB, IRSA와 Secret Mount 값
- Gateway와 HTTPRoute의 `parentRefs`, Hostname 및 경로 규칙
- HPA·KEDA가 관리하는 Replica 필드의 `ignoreDifferences` 적용 범위
- Argo CD Notifications의 수신 채널과 알림 조건
- 운영 배포 실패 판단과 Git Revert를 실행할 주체 및 절차

현재 Root Application은 `argocd/prod/bootstrap`과 `argocd/prod/platform`을 포함한다. Bootstrap의 `lookddak-prod-workloads` Application이 단계적으로 승인된 `argocd/prod/workloads`를 관리하며, 현재는 Web·Identity Domain과 `web-bff`·`identity-api`·`body-image-validator`를 활성화한다. 전체 Domain·Workload ApplicationSet은 아직 적용하지 않는다.

## 네트워크 정책과 Route 준비 범위

- Root가 관리하는 `network-policies`, `mesh-security`, `internal-api` Application이 기본 차단·mTLS·내부 waypoint를 먼저 구성한다.
- 검증 단계의 외부 HTTPRoute는 `v3-prod.lookddak.com`과 기존 `lookddak-gateway`의 `https-v3-prod` Listener만 사용한다.
- `lookddak.com`, `www.lookddak.com` Listener는 향후 운영 전환용으로 보존하지만 현재 Prod V3 워크로드 Route는 연결하지 않는다.
- Chat과 Fitting 알림 SSE 경로는 `request: 0s`로 Gateway 요청 시간 제한을 비활성화한다.
- Redis·모니터링 전용 정책은 해당 구성 배포 시 별도로 추가한다.
- 승인한 도메인의 Application만 `argocd/prod/workloads`에 추가해 순차 배포한다. 현재는 Web·Identity HTTPRoute와 Pod만 생성되며, 운영 V2 주 도메인 트래픽은 바뀌지 않는다.

## 플랫폼 Controller 단계

`argocd/prod/platform`은 다음 순서로 기반 구성요소를 등록한다.

1. Gateway API·Karpenter CRD, Istio base, Secrets Store CSI Driver
2. Karpenter·LB Controller·Metrics Server·ASCP·cert-manager·istiod
3. Karpenter NodePool·ClusterIssuer·Istio CNI
4. ztunnel
5. 공용 Istio Gateway

Gateway Pod 2개는 `general-purpose` NodePool을 요구하므로 Karpenter가 2a·2c에 Application Node를 생성한다. 이 PR은 Prod 애플리케이션을 배포하지 않는다.

## 최초 등록 순서

1. `platform/prod/argocd` Wrapper Chart로 Argo CD를 최초 설치한다.
2. `root-application.yaml`을 적용해 Project·Namespace·자기관리 Application을 등록한다.
3. Root와 `argocd` Application의 Sync 및 Health 상태를 확인한다.
4. 플랫폼 Controller 전체가 `Synced/Healthy`이고 Application Node가 Ready인지 확인한다.
5. 별도 PR에서 Domain·Workload ApplicationSet을 Root에 연결한다.

## 플랫폼 검증

```bash
kubectl -n argocd get applications | grep lookddak-prod
kubectl -n kube-system get pods -o wide
kubectl -n istio-system get pods -o wide
kubectl -n istio-ingress get gateway,certificate,pods,service -o wide
kubectl get ec2nodeclass,nodepool,nodeclaim
kubectl get nodes -L lookddak.io/node-pool,topology.kubernetes.io/zone
kubectl top nodes
```

완료 기준은 플랫폼 Application 전체 `Synced/Healthy`, Controller Pod Ready, CNI·ztunnel DaemonSet이 모든 Node에서 Ready, Gateway Pod 2개가 서로 다른 AZ의 Application Node에서 Running인 상태다.
