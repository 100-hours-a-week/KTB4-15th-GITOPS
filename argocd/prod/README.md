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

현재 Root Application은 `argocd/prod/bootstrap`만 포함하며 이 디렉터리의 Domain·Workload ApplicationSet은 아직 적용하지 않는다.

## 최초 등록 순서

1. `platform/prod/argocd` Wrapper Chart로 Argo CD를 최초 설치한다.
2. `root-application.yaml`을 적용해 Project·Namespace·자기관리 Application을 등록한다.
3. Root와 `argocd` Application의 Sync 및 Health 상태를 확인한다.
4. 플랫폼 Controller 검증 후 별도 PR에서 Domain·Workload ApplicationSet을 Root에 연결한다.
