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
