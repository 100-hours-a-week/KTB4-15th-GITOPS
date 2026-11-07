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
| AMI | `al2023@v20261031` | SSM EKS 1.36 AL2023 ARM64 Standard recommended: `1.36.5-20261031`, `ami-0510e3a5d76be9b00` |
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
- Linux·ARM64·On-Demand·C/M/R·5세대 이상·2/4/8 vCPU. FE·BE·AI 이미지가 ARM64이므로 Application Node도 같은 아키텍처로 맞춘다.
- 허용 AZ: `ap-northeast-2a`, `ap-northeast-2c`. 실제 Pod의 AZ 분산은 각 Workload의 Topology Spread 설정이 담당한다.
- 영구 Taint는 적용하지 않는다. 일반 Pod를 Application Node로 보내려면 Workload에 위 Node Label을 선택하도록 설정해야 한다. 이 작업에서 Workload values를 변경하지 않는다.
- Cilium 준비 전 일반 Pod 실행을 막기 위해 `node.cilium.io/agent-not-ready=true:NoExecute`를 Startup Taint로 설정한다. Cilium이 준비 후 제거해야 하며 실제 신규 Node에서 해제 여부를 검증한다.
- C·M·R은 CPU 대비 메모리 비율이 다른 후보군이다. 특정 Workload를 특정 계열에 고정하지 않는다. T는 CPU Credit에 따른 성능·비용 변수가 부하 테스트를 방해할 수 있어 제외한다.

## ARM64와 System Node의 구분

`al2023@v20261031` alias 자체는 아키텍처가 고정된 AMI ID가 아니다. Karpenter는 NodePool의 `kubernetes.io/arch=arm64` 조건에 맞는 ARM64 AMI와 EC2를 선택한다. 따라서 alias 날짜는 유지한다. AWS 조회에서 `c7g.large`, `m7g.large`, `r7g.large`가 두 허용 AZ에 제공되는 것을 확인했다. 이는 후보 제공 여부이며 실제 시점의 EC2 가용 용량을 보장하지는 않는다.

System MNG는 현재 AMD64이고 Karpenter Controller·Argo CD·CoreDNS를 실행한다. Controller가 관리하는 Application Node와 같은 아키텍처일 필요는 없다. System MNG의 인스턴스 유형과 AMI는 CLOUD의 `infra/environments/dev/v3/system-node-group/main.tf`에서 관리하며 이번 변경에서는 대기한다.

ARM64 전용 애플리케이션을 배포할 때는 Workload의 `nodeSelector` 등에 `lookddak.io/node-pool=general-purpose`와 `kubernetes.io/arch=arm64`를 지정해야 한다. 현재 공통 Workload Chart의 배치 조건 지원·실배포 values는 후속 작업이며, NodePool의 조건만 바꾼 것으로 일반 Pod의 System Node 배치까지 차단되지는 않는다.

현재 Cluster의 Cilium·Cilium Envoy DaemonSet에는 AMD64 고정 NodeSelector가 없고, 사용 중인 두 이미지 Digest의 OCI Index에 `linux/arm64` Manifest가 포함된 것을 조회로 확인했다. 네트워크 설정 자체는 변경하지 않는다. 실제 ARM Node의 Cilium 초기화는 Node 공급 테스트에서 검증한다. Crawler와 향후 추가하는 Istio·수집기 등도 ARM64 또는 멀티아키텍처 이미지인지 배포 전에 확인한다. FE·BE·AI 이미지 아키텍처는 팀의 확인 내용을 기준으로 하며 이 저장소의 ECR Repository·Digest는 아직 미입력 상태다.

## Dev 초기 공급 상한

`limits.cpu=32`, `limits.memory=64Gi`는 Pool 전체 EC2 용량의 임시 상한이다. Node 한 대의 사양이나 항상 실행할 자원량이 아니다. 최종 처리량을 보장하는 값도 아니다.

현재 9개 Deployment를 Replica 2로 실행할 때 애플리케이션 requests는 약 9.5 vCPU·19Gi다. 초기 상한은 기능 검증용 여유를 둔 값이며 Istio·Cilium·로그 수집기 오버헤드와 실제 배치 효율은 추가 측정해야 한다. 부하 테스트로 Workload별 requests·maxReplicas를 확정하고 DaemonSet·시스템 예약 자원·Node 교체 여유를 더해 최종 상한을 갱신한다. 전체 672/874 RPS 테스트 전에 상한에 막히지 않는지 확인한다.

Karpenter의 상한 검사는 동시 공급 시 일시적으로 초과할 수 있어 엄격한 비용 한도는 아니다. EC2 개수는 인스턴스 조합에 따라 달라진다.

## 회수와 교체

- `WhenEmptyOrUnderutilized`: 빈 Node뿐 아니라 일반 Workload Pod를 다른 Node에 재배치할 수 있는 저사용률 Node도 통합 대상으로 검토한다. Karpenter는 Pod의 requests·NodeSelector·TopologySpreadConstraints와 Kubernetes Eviction API의 PDB 허용 여부를 만족할 때만 Pod를 이동한 뒤 Node를 회수한다.
- `consolidateAfter: 5m`: Pod 증감 직후 반복 회수를 줄이기 위한 Dev 초기 대기값이다.
- Disruption Budget `nodes: "1"`: Karpenter의 자발적 교체·회수를 한 번에 1대로 제한한다. 장애 등 모든 종류의 중단을 막는 값은 아니다.
- `expireAfter: Never`: 초기 검증 중 시간 만료로 Node가 교체되지 않게 한다. 정기 교체 주기는 SSE·Worker 종료 처리 검증 후 결정한다. AMI·SG 등 설정 변경에 따른 Drift 교체와 수동 삭제는 별개다.

Node를 먼저 강제 종료하는 정책이 아니다. 통합 가능한 경우 Karpenter가 대상 Node의 신규 Scheduling을 막고 Pod를 Eviction한 뒤, Deployment 등 Controller가 남은 Node에 대체 Pod를 배치하도록 한다. 다른 Node의 여유 자원이 부족하거나 AZ 분산·PDB 등 제약을 지킬 수 없으면 기존 Node를 유지한다.

2026-11-07 Dev 조회에서는 롤링 업데이트 중 생성된 `c6g.large` 1대에 `identity-api` Pod 하나가 남았고, 같은 AZ의 `web-bff` Node에 합산 requests가 들어갈 여유가 있었다. `WhenEmpty`는 이 Node를 비우지 않아 5대를 유지했으므로, 재배치 가능한 저사용률 Node까지 통합하도록 정책을 확장한다. SSE·Worker처럼 장기 연결이나 처리 중 작업이 있는 Workload는 종료 유예시간과 PDB를 먼저 검증한 뒤 Auto Sync를 활성화한다.

KEDA가 Pod를 0개로 줄여도 Gateway·Waypoint 등 일반 Pod가 계속 남고 다른 Node로 재배치할 수 없으면 Application Node 0대가 보장되지 않는다.

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
kubectl get nodes -l lookddak.io/node-pool=general-purpose -L kubernetes.io/arch,node.kubernetes.io/instance-type
kubectl get pods -A -o wide --field-selector spec.nodeName=<통합-대상-Node>
kubectl get events -A --field-selector involvedObject.kind=NodeClaim --sort-by=.lastTimestamp
```

완료 기준은 NodeClass와 NodePool의 `Ready=True`다. NodeClass에서는 AMI·Subnet·SG·Instance Profile 조회 조건도 확인한다. 두 리소스가 Ready여도 대상 Pending Pod가 없으면 EC2가 생성되지 않는 것이 정상이다. 실제 Node 생성·Cilium Taint 해제·Node Ready는 별도 공급 테스트에서 검증한다.

정책 반영 후에는 NodeClaim Event에서 `Unconsolidatable` 또는 통합 결정을 확인하고, Pod가 Ready 상태를 유지한 채 저사용률 Node가 줄어드는지 관찰한다. Node 수가 줄지 않아도 자원·Topology·PDB 제약으로 재배치할 수 없다면 정상이다. 수동 `kubectl delete node`, NodeClaim 삭제와 EC2 종료는 검증 절차에 포함하지 않는다.

Argo CD UI에서는 `lookddak-dev-karpenter-nodepool`의 Tree·리소스 상세·Events를 확인한다. NodePool을 Git에서 삭제해 Prune하면 해당 Pool의 Node도 종료될 수 있으므로 삭제 PR에는 전체 Pod 영향을 확인해야 한다.

## 참고

- [Karpenter NodePool](https://karpenter.sh/v1.15/concepts/nodepools/)
- [Karpenter EC2NodeClass](https://karpenter.sh/v1.15/concepts/nodeclasses/)
- [Karpenter 회수와 교체](https://karpenter.sh/v1.15/concepts/disruption/)
- [AWS Karpenter 권장사항](https://docs.aws.amazon.com/eks/latest/best-practices/karpenter.html)
- [Cilium Startup Taint](https://docs.cilium.io/en/stable/installation/taints/)
- [EKS ARM·x86 혼합 구성과 이미지 호환성](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html)
