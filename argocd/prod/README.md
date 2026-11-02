# Argo CD — prod

## 목적

EKS prod에 설치된 Argo CD가 GitOps 저장소의 prod 목표 상태를 읽어 도메인 정책과 워크로드를 배포하도록 정의하는 디렉터리다. 이 디렉터리는 Argo CD 자체를 설치하지 않는다.

## 현재 작성된 범위

- `domain-applicationset.yaml`은 prod의 5개 `domain.yaml`을 `lookddak-domain` Chart와 조합한다.
- `workload-applicationset.yaml`은 prod의 10개 워크로드 values를 `lookddak-workload` Chart 및 `images.yaml`과 조합한다.
- 두 ApplicationSet은 Git 변경을 자동 동기화하고 `Self Heal`, `Prune`, `allowEmpty: false`, `PruneLast=true` 정책을 사용한다.
- 배포 대상은 각 도메인의 `lookddak-*` Namespace이며, Argo CD가 실행되는 클러스터 내부 주소를 사용한다.

## 적용 전에 결정하거나 준비할 항목

- Argo CD 설치 방법, 버전과 설치 Namespace
- Private GitHub 저장소를 읽기 위한 Repository Credential 전달 방식
- 운영 Namespace 생성 주체
- dev에서 검증하여 승격할 ECR Image Digest
- 워크로드별 Port, Resource, Probe, HPA, PDB, IRSA와 Secret Mount 값
- Gateway와 HTTPRoute의 `parentRefs`, Hostname 및 경로 규칙
- HPA·KEDA가 관리하는 Replica 필드의 `ignoreDifferences` 적용 범위
- Argo CD Notifications의 수신 채널과 알림 조건
- 운영 배포 실패 판단과 Git Revert를 실행할 주체 및 절차

위 항목이 준비되고 dev에서 동일 구성이 검증되기 전에는 이 디렉터리의 AppProject와 ApplicationSet을 prod 클러스터에 적용하지 않는다.

## 최초 등록 순서

1. Argo CD와 ApplicationSet Controller가 정상 동작하는지 확인한다.
2. Private GitOps 저장소 Credential을 등록한다.
3. `lookddak-prod` AppProject를 등록한다.
4. 대상 Namespace와 승인된 prod values가 준비되었는지 확인한다.
5. prod의 Domain ApplicationSet과 Workload ApplicationSet을 등록한다.
6. 생성된 Application의 Sync 및 Health 상태를 확인한다.
