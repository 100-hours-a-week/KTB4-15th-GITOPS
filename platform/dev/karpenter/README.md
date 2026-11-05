# Karpenter — dev

## 목적

EKS dev에서 Application Node를 자동 공급할 Karpenter의 CRD·Controller·NodePool을 GitOps로 관리한다.

## 관리 구조

- `crd`: `NodePool`, `NodeClaim`, `EC2NodeClass` API를 제공하는 CRD를 설치한다.
- `controller`: Pending Pod를 감시하고 AWS에 Application Node 생성을 요청하는 Controller를 설치한다.
- `nodepool`: Application Node의 AWS 생성 설정(EC2NodeClass)과 허용 인스턴스·공급 상한·회수 정책(NodePool)을 정의한다. 세부 설정과 검증 명령은 [NodePool README](nodepool/README.md)를 참고한다.
- CRD와 Controller는 `1.15.1`로 함께 고정하고 같은 PR에서 함께 업그레이드한다.

## Controller 실행 정책

- Namespace: `kube-system`
- ServiceAccount: `karpenter`
- AWS 권한: Terraform에서 생성한 `lookddak-dev-karpenter-controller` IAM Role을 IRSA로 연결
- 배치 위치: `lookddak.io/node-pool=system` Label이 있는 Managed Node Group
- Replica: 2개
- 가용성: 공식 Chart의 서로 다른 Node 배치, AZ 분산과 PDB 정책 유지
- Resource: requests CPU `100m`·Memory `256Mi`, limits Memory `512Mi` (CPU limit 없음). 2026-11-05 실사용 리더 9m/152Mi 기준, System Node CPU requests 98%로 Gateway 롤링이 막혀 낮춤
- 로그: `info`

## Argo CD 동기화

1. `lookddak-dev-platform` AppProject가 `kube-system`과 필요한 Cluster 범위 리소스만 허용한다.
2. `lookddak-dev-karpenter-crd` Application이 CRD를 먼저 설치한다.
3. `lookddak-dev-karpenter-controller` Application이 Controller를 설치한다.
4. `lookddak-dev-karpenter-nodepool` Application이 EC2NodeClass와 NodePool을 관리한다.
5. 세 Application 모두 Auto Sync, Prune, Self Heal을 사용한다.

Controller Chart에 함께 포함된 CRD는 `skipCrds: true`로 제외한다. CRD는 독립 `karpenter-crd` Chart만 소유하므로 업그레이드 시 소유권이 겹치지 않는다.

## 후속 설정

- Spot Capacity와 Interruption Queue
- 부하 테스트 기반 최종 CPU·Memory 공급 상한 (현재 Dev 초기값 CPU 32·Memory 64Gi)
- SSE·Worker 종료 검증 후 정기 Node 교체 주기 (현재 시간 만료 비활성화)
- Prometheus ServiceMonitor

NodePool이 Ready여도 Pending Pod가 없으면 Node가 생성되지 않는다. 실제 공급 테스트는 별도로 수행한다.
