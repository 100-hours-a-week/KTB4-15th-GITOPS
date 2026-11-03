# General-purpose NodePool — dev

## 역할과 관리 범위

`EC2NodeClass`는 EC2의 AMI·Subnet·SG·Instance Profile을 정의하고, `NodePool`은 허용할 인스턴스와 공급·회수 조건을 정의한다. 두 리소스는 Namespace가 없는 Cluster 범위 리소스다. Application의 Destination이 `kube-system`이어도 두 리소스에 Namespace가 생기지는 않는다.

| 파일 | 역할 |
| --- | --- |
| `ec2-nodeclass.yaml` | Application Node를 생성할 AWS 설정 |
| `nodepool.yaml` | 인스턴스 조건, Cilium Startup Taint와 공급·회수 정책 |
| `../../../../argocd/dev/karpenter-nodepool-application.yaml` | main의 두 YAML을 EKS dev에 자동 동기화 |

## AWS 연결값

2026-11-03 AWS 읽기 전용 조회로 다음 값을 확인했다.

| 항목 | 설정 | 확인 근거 |
| --- | --- | --- |
| Cluster | `lookddak-dev`, Kubernetes `1.36` | EKS DescribeCluster |
| AMI | `al2023@v20261031` | SSM EKS 1.36 AL2023 x86_64 Standard recommended: `1.36.5-20261031`, `ami-0ff26945ed10b79c1` |
| Instance Profile | `lookddak-dev-karpenter-node` | Terraform 생성, IAM GetInstanceProfile과 EKS EC2_LINUX Access Entry 확인 |
| Node Subnet | discovery=`lookddak-dev`, Tier=`private-node` | `subnet-0d66a74a831adfd95`(2a), `subnet-02919412338655f46`(2c) |
| SG | `sg-04d109eb4f8eae342` | EKS 기본 Cluster SG. System MNG도 사용하는 기존 SG |
| EBS | 암호화 gp3 `30Gi`, Node 종료 시 삭제 | 기존 System Node 디스크 정책과 초기 설계 기준 |
| IMDS | v2 필수, Hop Limit 1 | 일반 Pod의 Node 자격증명 접근을 제한. hostNetwork·특권 Pod까지 격리하는 정책은 아님 |

Cilium의 Pod ENI는 기존 `Tier=private-pod` Subnet 선택 설정을 따른다. 이 NodeClass는 EC2의 기본 ENI용 Node Subnet만 선택하며 Cilium values는 변경하지 않는다.

기존 SG에는 `karpenter.sh/discovery` 태그가 없으므로 임의로 Terraform 소유 리소스를 변경하지 않고 정확한 ID를 참조한다. EKS 재생성 또는 SG 교체 시 이 값도 PR로 갱신해야 한다. AMI는 `@latest` 대신 날짜 버전을 고정하며 업데이트는 Dev 검증 PR로 진행한다. 사용자 정의 UserData 없이 Karpenter의 AL2023 부트스트랩을 사용한다.

## NodePool 정책

- 동적 Pool 1개: `general-purpose`. `replicas`를 지정하지 않아 수요가 없으면 0대까지 줄일 수 있다.
- Node Label: `lookddak.io/node-pool=general-purpose`.
- Linux·AMD64·On-Demand·C/M/R·5세대 이상·2/4/8 vCPU.
- 허용 AZ: `ap-northeast-2a`, `ap-northeast-2c`. 실제 Pod의 AZ 분산은 각 Workload의 Topology Spread 설정이 담당한다.
- 영구 Taint는 적용하지 않는다. 일반 Pod를 Application Node로 보내려면 Workload에 위 Node Label을 선택하도록 설정해야 한다. 이 작업에서 Workload values를 변경하지 않는다.
- Cilium 준비 전 일반 Pod 실행을 막기 위해 `node.cilium.io/agent-not-ready=true:NoExecute`를 Startup Taint로 설정한다. Cilium이 준비 후 제거해야 하며 실제 신규 Node에서 해제 여부를 검증한다.
- C·M·R은 CPU 대비 메모리 비율이 다른 후보군이다. 특정 Workload를 특정 계열에 고정하지 않는다. T는 CPU Credit에 따른 성능·비용 변수가 부하 테스트를 방해할 수 있어 제외한다.

## Dev 초기 공급 상한

`limits.cpu=32`, `limits.memory=64Gi`는 Pool 전체 EC2 용량의 임시 상한이다. Node 한 대의 사양이나 항상 실행할 자원량이 아니다. 최종 처리량을 보장하는 값도 아니다.

현재 9개 Deployment를 Replica 2로 실행할 때 애플리케이션 requests는 약 9.5 vCPU·19Gi다. 초기 상한은 기능 검증용 여유를 둔 값이며 Istio·Cilium·로그 수집기 오버헤드와 실제 배치 효율은 추가 측정해야 한다. 부하 테스트로 Workload별 requests·maxReplicas를 확정하고 DaemonSet·시스템 예약 자원·Node 교체 여유를 더해 최종 상한을 갱신한다. 전체 672/874 RPS 테스트 전에 상한에 막히지 않는지 확인한다.

Karpenter의 상한 검사는 동시 공급 시 일시적으로 초과할 수 있어 엄격한 비용 한도는 아니다. EC2 개수는 인스턴스 조합에 따라 달라진다.

## 회수와 교체

- `WhenEmpty`: 일반 Workload Pod가 없는 Node만 비용 절감 대상으로 회수한다. DaemonSet만 남은 Node도 회수 대상이 될 수 있다.
- `consolidateAfter: 5m`: Pod 증감 직후 반복 회수를 줄이기 위한 Dev 초기 대기값이다.
- Disruption Budget `nodes: "1"`: Karpenter의 자발적 교체·회수를 한 번에 1대로 제한한다. 장애 등 모든 종류의 중단을 막는 값은 아니다.
- `expireAfter: Never`: 초기 검증 중 시간 만료로 Node가 교체되지 않게 한다. 정기 교체 주기는 SSE·Worker 종료 처리 검증 후 결정한다. AMI·SG 등 설정 변경에 따른 Drift 교체와 수동 삭제는 별개다.

SSE를 유지 중인 Node를 비용 절감 목적으로 이동시키지 않도록 초기에는 빈 Node 회수만 사용한다. KEDA가 Pod를 0개로 줄여도 Gateway·Waypoint 등 일반 Pod가 계속 남으면 Node는 빈 상태가 아니므로 0대가 보장되지 않는다.

## 반영과 확인

main Merge 후 기존 Root Application이 `lookddak-dev-karpenter-nodepool`을 등록하고 해당 Application이 두 리소스를 Auto Sync한다. Root의 Sync Wave는 Child Application 선언 순서이며 별도 Application의 전체 설치 완료를 보장하지 않으므로 기존 CRD·Controller 정상 상태를 먼저 확인한다.

연결된 kubeconfig에서 다음 명령은 조회만 수행한다.

```bash
kubectl get applications -n argocd lookddak-dev-karpenter-crd lookddak-dev-karpenter-controller lookddak-dev-karpenter-nodepool
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter -o wide
kubectl get ec2nodeclass general-purpose
kubectl get nodepool general-purpose
kubectl describe ec2nodeclass general-purpose
kubectl describe nodepool general-purpose
kubectl get nodeclaims
kubectl get nodes -l lookddak.io/node-pool=general-purpose -o wide
```

완료 기준은 NodeClass와 NodePool의 `Ready=True`다. NodeClass에서는 AMI·Subnet·SG·Instance Profile 조회 조건도 확인한다. 두 리소스가 Ready여도 대상 Pending Pod가 없으면 EC2가 생성되지 않는 것이 정상이다. 실제 Node 생성·Cilium Taint 해제·Node Ready는 별도 공급 테스트에서 검증한다.

Argo CD UI에서는 `lookddak-dev-karpenter-nodepool`의 Tree·리소스 상세·Events를 확인한다. NodePool을 Git에서 삭제해 Prune하면 해당 Pool의 Node도 종료될 수 있으므로 삭제 PR에는 전체 Pod 영향을 확인해야 한다.

## 참고

- [Karpenter NodePool](https://karpenter.sh/v1.15/concepts/nodepools/)
- [Karpenter EC2NodeClass](https://karpenter.sh/v1.15/concepts/nodeclasses/)
- [Karpenter 회수와 교체](https://karpenter.sh/v1.15/concepts/disruption/)
- [AWS Karpenter 권장사항](https://docs.aws.amazon.com/eks/latest/best-practices/karpenter.html)
- [Cilium Startup Taint](https://docs.cilium.io/en/stable/installation/taints/)
