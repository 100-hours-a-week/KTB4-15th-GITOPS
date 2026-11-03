# Karpenter — dev

## 목적

EKS dev에서 Application Node를 자동 공급할 Karpenter의 CRD와 Controller를 GitOps로 관리한다.

## 관리 구조

- `crd`: `NodePool`, `NodeClaim`, `EC2NodeClass` API를 제공하는 CRD를 설치한다.
- `controller`: Pending Pod를 감시하고 AWS에 Application Node 생성을 요청하는 Controller를 설치한다.
- CRD와 Controller는 `1.15.1`로 함께 고정하고 같은 PR에서 함께 업그레이드한다.

## Controller 실행 정책

- Namespace: `kube-system`
- ServiceAccount: `karpenter`
- AWS 권한: Terraform에서 생성한 `lookddak-dev-karpenter-controller` IAM Role을 IRSA로 연결
- 배치 위치: `lookddak.io/node-pool=system` Label이 있는 Managed Node Group
- Replica: 2개
- 가용성: 공식 Chart의 서로 다른 Node 배치, AZ 분산과 PDB 정책 유지
- Resource: Pod당 CPU `1`, Memory `1Gi`를 request와 limit에 동일하게 설정
- 로그: `info`

## Argo CD 동기화

1. `lookddak-dev-platform` AppProject가 `kube-system`과 필요한 Cluster 범위 리소스만 허용한다.
2. `lookddak-dev-karpenter-crd` Application이 CRD를 먼저 설치한다.
3. `lookddak-dev-karpenter-controller` Application이 Controller를 설치한다.
4. 두 Application 모두 Auto Sync, Prune, Self Heal을 사용한다.

Controller Chart에 함께 포함된 CRD는 `skipCrds: true`로 제외한다. CRD는 독립 `karpenter-crd` Chart만 소유하므로 업그레이드 시 소유권이 겹치지 않는다.

## 이번 범위에서 제외한 설정

- `EC2NodeClass`, `NodePool` 및 Application Node 공급 정책
- Spot Capacity와 Interruption Queue
- Karpenter Node 총 CPU·Memory 공급 상한
- Consolidation, Disruption Budget 및 Node 만료 시간
- Prometheus ServiceMonitor

위 설정은 General-purpose NodePool 구성 작업에서 별도로 추가한다.
