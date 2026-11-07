# GitOps CI 검증 자료

## 목적

`fixtures`는 공통 Helm Chart의 주요 조건 분기가 정상적으로 렌더링되는지 검사하기 위한 CI 전용 values다. 실제 dev 또는 prod 배포에는 사용하지 않는다.

## 검증 대상

- 외부 라우팅을 사용하는 Deployment
- HPA와 PDB를 사용하는 Deployment
- Service 없이 실행되는 Worker와 Secret Mount
- 정기 실행 CronJob
- ResourceQuota와 LimitRange 도메인 정책

Fixture의 이미지 주소, Digest, Port와 Resource 값은 렌더링 검증용이며 실제 서비스 설정을 의미하지 않는다.

현재 Kubernetes Schema 검사에서는 표준 Kubernetes 리소스를 엄격하게 검사한다. `HTTPRoute`, `SecretProviderClass` 등 CRD는 Cilium·Istio·Gateway API·Secrets Store CSI 버전이 확정된 후 해당 버전의 Schema를 고정하여 검사한다.

Karpenter의 NodePool·EC2NodeClass는 `karpenter-crd` 고정 버전의 렌더링 결과에서 v1 OpenAPI Schema를 추출해 별도로 검사한다. Schema 파일을 중복 관리하지 않고 Chart 버전과 함께 갱신한다. 두 정적 Manifest도 PR Diff에 포함한다. 로컬 Schema 검사는 API Server의 CEL·Admission 검증, AWS 리소스 발견과 실제 Ready 상태를 대신하지 않는다.

Metrics Server는 공식 Chart를 렌더링해 일반 Kubernetes Schema와 Manifest Diff 검사에 포함한다. Replica, System Node 배치, Toleration, Node 분산과 PDB 같은 운영 값은 PR Diff에서 검토하고, 실제 kubelet 연결과 Metrics API 가용성은 main Merge 후 Live 검증한다.

## Dev 이미지 Digest 전용 검증

`environments/dev/images.yaml`을 변경하는 PR은 일반 인프라 PR과 분리된 빠른 경로로 검사한다. 이 경로는 다음 조건을 모두 만족해야 한다.

- 변경 파일은 `environments/dev/images.yaml` 하나뿐이다.
- `fe`, `be`, `ai`, `crawler` 중 정확히 한 그룹의 `digest` 한 줄만 변경한다.
- Repository와 YAML 구조는 변경하지 않는다.
- Digest는 `sha256:` 뒤에 소문자 16진수 64자리가 오는 형식이다.

검증을 통과하면 해당 이미지 그룹을 사용하는 Dev 워크로드만 렌더링하고 Kubernetes Schema와 Manifest Diff를 검사한다. 다른 GitOps 변경은 기존 전체 Helm 의존성·Fixture·플랫폼 Schema 검사를 그대로 실행한다. 두 경로 모두 required check 이름은 `GitOps CI`다.

로컬에서 변경 규칙의 회귀 테스트를 실행하려면 다음 명령을 사용한다.

```bash
ruby scripts/test-validate-dev-image-change.rb
```

## Dev 이미지 PR 중앙 자동화

`.github/workflows/update-dev-image.yaml`은 애플리케이션 저장소가 확정한 이미지 Digest를 받아 GitOps 자동화 브랜치와 PR을 만든다. 실제 애플리케이션 저장소 연결 전에는 `workflow_dispatch`로 같은 입력을 수동 검증할 수 있다. 이후 애플리케이션 저장소는 `dev-image-published` 타입의 `repository_dispatch`만 전송한다.

워크플로는 기본 `GITHUB_TOKEN` 대신 GitHub App 설치 토큰을 사용한다. 기본 토큰으로 생성한 PR에서 후속 `pull_request` 워크플로 실행이 억제되는 것을 피하고, 생성된 PR도 일반 PR과 동일하게 `GitOps CI`를 통과하도록 하기 위해서다.

### GitHub App 사전 설정

GitHub App은 GitOps 저장소에 설치하고 다음 Repository Permission만 부여한다.

- Contents: Read and write
- Pull requests: Read and write
- Issues: Read and write — `automated-dev-image` 라벨 생성·부착용

GitOps 저장소 Actions 설정에 다음 값을 등록한다.

- Repository Variable `DEV_IMAGE_BOT_CLIENT_ID`: GitHub App Client ID
- Repository Secret `DEV_IMAGE_BOT_PRIVATE_KEY`: GitHub App Private Key 전체 PEM

Repository 설정에서 Auto Merge를 활성화하고, `main` Ruleset의 필수 검사로 기존 `GitOps CI`를 유지한다. 자동화 Bot에 `main` 직접 Push 또는 필수 검사 우회 권한을 부여하지 않는다.

### 입력과 멱등성

- `environment`: `dev`만 허용
- `image_key`: `fe`, `be`, `ai`, `crawler`
- `digest`: `sha256:`와 소문자 16진수 64자리
- `source_repository`: 이미지 그룹과 연결된 저장소만 허용
- `source_sha`: 40자리 소문자 Git Commit SHA
- `source_run_url`: 해당 저장소의 GitHub Actions Run URL

브랜치는 `automation/dev-<image_key>-<source_sha 앞 12자리>` 형식으로 결정한다. 동일 이벤트가 다시 전달되면 같은 브랜치를 안전하게 갱신하고 열린 PR을 재사용한다. 요청 Digest가 이미 `main`의 현재 값이면 브랜치와 PR을 만들지 않고 정상 종료한다.

로컬 입력·파일 갱신 회귀 테스트는 다음 명령으로 실행한다.

```bash
ruby scripts/test-update-dev-image.rb
```
