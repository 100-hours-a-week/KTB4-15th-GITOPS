# Argo CD — dev

## 목적

EKS dev에 설치된 Argo CD가 GitOps 저장소의 dev 목표 상태를 읽어 도메인 정책과 워크로드를 배포하도록 정의하는 디렉터리다. 이 디렉터리는 Argo CD 자체를 설치하지 않는다.

## 현재 작성된 범위

- `root-application.yaml`은 Public GitOps 저장소의 dev AppProject와 ApplicationSet, Namespace 선언을 관리하는 최초 진입점이다.
- `namespace-*.yaml`은 dev의 5개 도메인 Namespace를 생성한다. Namespace 자체는 실수로 자동 삭제되지 않도록 `Prune=false`를 사용한다.
- `domain-applicationset.yaml`은 dev의 5개 `domain.yaml`을 `lookddak-domain` Chart와 조합한다.
- `workload-applicationset.yaml`은 dev의 10개 워크로드 values를 `lookddak-workload` Chart 및 `images.yaml`과 조합한다.
- Root Application과 Domain ApplicationSet은 Git 변경을 자동 동기화한다.
- `argocd-application.yaml`은 기존 Argo CD 설치 Chart를 `argocd` Application으로 자동 관리한다. 전용 Project는 `lookddak-dev-argocd`이며 대상 Namespace는 `argocd`다.
- `metrics-server-application.yaml`은 Metrics Server를 `kube-system`의 ARM64 System Node에 자동 배포한다.
- Workload ApplicationSet은 각 workload values의 `gitops.autoSync`가 `true`인 Application에만 Auto Sync 정책을 추가한다.
- 배포 대상은 각 도메인의 `lookddak-*` Namespace이며, Argo CD가 실행되는 클러스터 내부 주소를 사용한다.

## 적용 순서

Root Application은 Sync Wave를 사용해 다음 순서로 리소스를 준비한다.

1. `lookddak-dev`, `lookddak-dev-platform`, `lookddak-dev-argocd` AppProject (`-2`)
2. dev 도메인 Namespace 5개 및 Karpenter CRD Application (`-1`)
3. Domain·Workload ApplicationSet, Karpenter Controller와 Metrics Server Application (`0`)
4. Karpenter NodePool Application과 Argo CD 자기 관리 Application (`1`)

NodePool Application은 `platform/dev/karpenter/nodepool`의 EC2NodeClass와 NodePool만 자동 반영한다. Root의 Sync Wave는 Child Application 선언 순서이며, 별도 Application의 배포 완료까지 보장하지 않는다. 기존 CRD·Controller가 정상인지 확인한 후 NodePool 구성을 Merge한다.

Root Application은 `default` Project를 사용해 위 부트스트랩 리소스만 관리한다. 실제 도메인과 워크로드 Application은 권한이 제한된 `lookddak-dev` AppProject를 사용한다.

## Workload Auto Sync 활성화 전에 준비할 항목

- ECR Repository와 Image Digest
- 워크로드별 Port, Resource, Probe, HPA, PDB, IRSA와 Secret Mount 값
- Gateway와 HTTPRoute의 `parentRefs`, Hostname 및 경로 규칙
- HPA·KEDA가 관리하는 Replica 필드의 `ignoreDifferences` 적용 범위
- Argo CD Notifications의 수신 채널과 알림 조건

위 항목이 준비되고 Helm 렌더링 검사가 통과한 워크로드만 `gitops.autoSync: true`로 전환한다. 준비되지 않은 워크로드는 `false`를 유지한다.

## 최초 등록 순서

1. Argo CD와 ApplicationSet Controller가 정상 동작하는지 확인한다.
2. Public GitOps 저장소가 `argocd-repo-server`에서 조회되는지 확인한다.
3. `root-application.yaml`을 최초 한 번 `kubectl apply`한다.
4. Root가 AppProject, Namespace와 ApplicationSet을 순서대로 생성하는지 확인한다.
5. `gitops.autoSync: false`인 Workload Application이 생성되지만 자동 Sync되지 않는지 확인한다.
6. 실배포 values를 완성하고 검증한 워크로드만 별도 PR에서 `gitops.autoSync: true`로 전환한다.
