# LookDDak V3 GitOps

LookDDak V3의 Kubernetes Desired State를 관리하는 저장소입니다. 공통 Helm Chart, dev/prod 환경별 설정, 클러스터 공통 플랫폼 구성과 Argo CD Application을 한곳에서 관리합니다.

이 저장소의 `main` 브랜치는 EKS-dev와 EKS-prod의 최종 Desired State입니다. 애플리케이션 코드는 각 Application Repository에서 관리하고, 이 저장소에는 Kubernetes 배포 상태만 저장합니다.

## 핵심 운영 원칙

> [!IMPORTANT]
> - EKS 리소스는 이 저장소의 PR을 통해서만 변경합니다.
> - Argo CD가 관리하는 리소스에 `kubectl apply/edit/delete/scale`, `helm install/upgrade/uninstall`을 직접 실행하지 않습니다.
> - GitHub Actions는 EKS를 직접 변경하지 않으며, Argo CD만 `main`의 상태를 EKS에 반영합니다.
> - 장애 복구도 Cluster를 직접 수정하지 않고 Git Revert PR로 수행합니다.
> - Secret 원문과 `latest` 같은 가변 이미지 태그를 Git에 저장하지 않습니다.
> - `main` 직접 Push와 Force Push를 금지하고, 단기 작업 브랜치와 PR을 사용합니다.

GitOps는 선언형 상태를 Git에 버전으로 기록하고, Argo CD가 Git의 Desired State를 가져와 실제 Cluster와 지속적으로 일치시키는 방식으로 운영합니다.

```text
Git main (Desired State)
        │
        │ Pull·Compare
        ▼
     Argo CD
        │
        │ Reconcile
        ▼
EKS dev / EKS prod (Live State)
```

## 저장소별 관리 범위

| 저장소 | 관리 대상 | 주요 책임 |
| --- | --- | --- |
| FE·BE·AI·Crawler Repository | 애플리케이션 | 코드, 테스트, Docker 이미지 Build, ECR Push |
| Cloud/Terraform Repository | AWS 기반 인프라 | VPC, EKS, IAM, ECR 등 AWS 리소스 생성과 변경 |
| 이 GitOps Repository | Kubernetes Desired State | Helm Chart, 환경별 values, 플랫폼 구성, Argo CD Application |
| Argo CD | 배포 실행 | Git의 Desired State와 EKS Live State 비교·동기화 |

변경 위치는 다음 기준으로 판단합니다.

```text
AWS 리소스를 생성·변경한다
→ Cloud/Terraform Repository

Kubernetes 내부 리소스와 배포 설정을 변경한다
→ GitOps Repository

애플리케이션 코드와 Docker 이미지를 변경한다
→ Application Repository
```

## 배포 흐름

### Dev 배포

```text
Application Repository의 develop Merge
→ GitHub Actions Test·Build
→ ECR Push 및 Image Digest 확정
→ environments/dev/images.yaml 변경 PR
→ GitOps CI
→ main Merge
→ Argo CD Auto Sync
→ EKS-dev 반영
```

### Prod 승격

```text
EKS-dev에서 기능 검증
→ 검증된 동일 Image Digest를 prod로 승격
→ environments/prod/images.yaml 변경 PR
→ GitOps CI
→ main Merge
→ Argo CD Auto Sync
→ EKS-prod 반영
```

Prod 승격 시 이미지를 다시 Build하지 않습니다. Dev에서 검증한 동일 Digest를 재사용하여 환경마다 서로 다른 이미지가 배포되는 것을 방지합니다.

## 디렉터리 구조

```text
KTB4-15th-GITOPS/
├─ .github/
│  ├─ workflows/                 # GitOps PR 검증 Workflow
│  └─ scripts/                   # PR Bot 댓글 작성 로직
├─ charts/
│  ├─ lookddak-workload/         # Deployment·CronJob 등 공통 Workload Chart
│  └─ lookddak-domain/           # ResourceQuota·LimitRange 등 Domain 정책 Chart
├─ environments/
│  ├─ dev/                       # EKS-dev Desired State
│  │  ├─ images.yaml             # Dev 이미지 Repository와 Digest
│  │  └─ domains/                # 5개 Domain과 Workload values
│  └─ prod/                      # EKS-prod Desired State
│     ├─ images.yaml             # Prod로 승격한 이미지 Digest
│     └─ domains/
├─ platform/
│  ├─ dev/                       # Dev 클러스터 공통 구성과 Argo CD 설치 설정
│  └─ prod/                      # Prod 클러스터 공통 구성
├─ argocd/
│  ├─ projects/                  # 환경별 AppProject
│  ├─ dev/                       # Dev Root Application·Namespace·ApplicationSet
│  └─ prod/                      # Prod ApplicationSet
├─ ci/
│  └─ fixtures/                  # 공통 Chart를 검증하는 대표 values
└─ scripts/                      # YAML·구조·정책·Manifest 검증 스크립트
```

### 주요 영역

| 경로 | 역할 |
| --- | --- |
| `charts/lookddak-workload` | API, AI, Worker, CronJob이 공통으로 사용하는 Helm Chart |
| `charts/lookddak-domain` | Namespace 단위 자원·네트워크 정책을 생성하는 Helm Chart |
| `environments/<env>/images.yaml` | FE·BE·AI·Crawler 이미지 Repository와 불변 Digest |
| `environments/<env>/domains` | Domain과 Workload별 환경 설정 |
| `platform/<env>` | Cilium, Istio, Gateway, Karpenter, KEDA, Secret, 관측 구성 |
| `platform/dev/argocd` | EKS dev에 설치할 Argo CD 자체의 Chart 버전과 Helm 설정 |
| `platform/dev/karpenter/nodepool` | Dev Application Node의 EC2NodeClass·NodePool과 공급·회수 정책 |
| `argocd/projects` | Argo CD의 Repository·Cluster·Namespace 접근 범위 |
| `argocd/<env>` | Root Application, Namespace와 Domain·Workload ApplicationSet |
| `ci/fixtures` | 실제 환경 설정이 완성되기 전 공통 Chart 분기를 검증하는 입력값 |
| `scripts` | CI가 실행하는 저장소 검증과 Manifest Diff 도구 |

## 환경·Domain·Workload

dev와 prod는 별도 EKS Cluster로 구성하지만 동일한 Directory 구조와 공통 Helm Chart를 사용합니다.

| Domain | Namespace | Workload |
| --- | --- | --- |
| Web | `lookddak-web` | `web-bff` |
| Identity | `lookddak-identity` | `identity-api`, `body-image-validator` |
| Commerce | `lookddak-commerce` | `commerce-api`, `price-crawler` |
| Chat | `lookddak-chat` | `chat-api`, `chat-ai` |
| Fitting | `lookddak-fitting` | `fitting-api`, `fitting-worker`, `vton-orchestrator` |

실제 애플리케이션 Repository를 마이크로서비스로 분리하지 않습니다. 동일한 BE·AI 이미지에서 `LOOKDDAK_RUNTIME_ROLE`에 따라 역할별 Controller와 Worker를 활성화하고, Kubernetes에서는 각 역할을 독립 Workload로 배포합니다.

### 이미지 그룹

| 이미지 그룹 | 사용하는 Workload |
| --- | --- |
| `fe` | `web-bff` |
| `be` | `identity-api`, `commerce-api`, `chat-api`, `fitting-api`, `fitting-worker` |
| `ai` | `body-image-validator`, `chat-ai`, `vton-orchestrator` |
| `crawler` | `price-crawler` |

하나의 이미지 그룹 Digest가 변경되면 해당 이미지를 공유하는 Workload가 함께 갱신됩니다.

## 변경 절차

### 1. Issue 생성

작업을 시작하기 전에 GitHub Issue를 생성합니다. Issue에는 작업 목적, 변경 범위, 영향을 받는 환경·Domain·Workload와 완료 조건을 작성합니다.

```text
제목: [영역] 작업 내용

- 작업 목적
- 변경 대상 환경·Domain·Workload
- 예상 영향
- 완료 조건
```

Issue는 작업이 진행되는 동안 Open 상태로 유지합니다. 작업을 취소하는 경우에는 취소 이유를 댓글로 남기고 Issue를 닫습니다.

### 2. 작업 브랜치 생성

장기 `develop` 브랜치를 두지 않고 `main + 단기 작업 브랜치`를 사용합니다.

```bash
git switch main
git pull --ff-only origin main
git switch -c feat/<작업명>
```

### 3. 변경 유형에 맞는 파일 수정

| 변경 목적 | 수정 위치 |
| --- | --- |
| 이미지 배포·승격 | `environments/<env>/images.yaml` |
| Workload 설정 | `environments/<env>/domains/<domain>/workloads/<workload>.yaml` |
| Domain 공통 정책 | `environments/<env>/domains/<domain>/domain.yaml` |
| 공통 Kubernetes Template | `charts/lookddak-workload` 또는 `charts/lookddak-domain` |
| Cilium·Istio·Gateway 등 플랫폼 | `platform/<env>` |
| Argo CD 배포 범위 | `argocd` |

### 4. 로컬 검증

```bash
ruby scripts/validate-yaml.rb
ruby scripts/validate-repository.rb

helm lint charts/lookddak-workload
helm lint charts/lookddak-domain
helm dependency build platform/dev/argocd
helm lint platform/dev/argocd --namespace argocd --kube-version 1.36.0

scripts/render-fixtures.sh /tmp/lookddak-rendered
ruby scripts/validate-policy.rb
```

`main`과 현재 브랜치가 생성하는 Fixture Manifest를 비교할 수 있습니다.

```bash
scripts/diff-rendered-manifests.sh origin/main /tmp/lookddak-manifest-diff
```

### 5. PR 생성·검토 및 Issue 종료

1. PR 본문에 관련 Issue 번호와 변경 이유, 영향을 받는 환경·Domain·Workload를 작성합니다.
2. PR 본문에 `Closes #<Issue 번호>`를 작성해 Merge 시 Issue가 자동으로 종료되도록 연결합니다.
3. GitOps CI 결과를 확인합니다.
4. PR Bot이 출력한 Helm Manifest 변경점을 확인합니다.
5. 리소스 삭제, Route·권한·Secret·prod 변경은 반드시 추가로 검토합니다.
6. 필수 검사가 성공하고 리뷰가 완료된 후 `main`에 Merge합니다.
7. Merge 후 관련 Issue가 종료되었는지 확인합니다.

## 브랜치·PR 규칙

- 기본 브랜치는 `main` 하나만 사용합니다.
- 작업을 시작하기 전에 Issue를 생성하고, PR에 해당 Issue를 연결합니다.
- 작업은 `feat/*`, `fix/*`, `ci/*`, `docs/*` 등 목적이 드러나는 단기 브랜치에서 진행합니다.
- `main` 직접 Push와 Force Push를 금지합니다.
- 모든 변경은 PR과 필수 상태 검사 `GitOps CI`를 통과해야 합니다.
- 한 PR에는 하나의 논리적 변경만 포함합니다.
- dev와 prod를 동시에 변경해야 한다면 변경 이유와 승격 근거를 PR에 명시합니다.
- 생성된 Manifest와 실제 의도가 일치하는지 확인한 뒤 Merge합니다.
- 작업 완료 후 관련 Issue가 종료되었는지 확인합니다.

## GitOps CI

`main` 대상 PR에는 다음 검사가 순차적으로 실행됩니다.

| 순서 | 검사 | 내용 |
| --- | --- | --- |
| 1 | YAML 문법 | 파싱 오류와 중복 키 검사 |
| 2 | 저장소 구조 | 5개 Domain, 환경별 10개 Workload, 필수 파일과 ApplicationSet 경로 검사 |
| 3 | Helm dependency·lint | 공통 Chart·Argo CD·Karpenter Chart 의존성·구조·Template 문법 검사 |
| 4 | Manifest 준비 | 대표 Fixture·Argo CD·Karpenter Chart 렌더링과 정적 Argo CD·NodePool YAML 수집 |
| 5 | Manifest Diff | `main`과 PR의 Helm·정적 리소스를 비교해 추가·변경·삭제 요약을 Summary와 PR Bot 댓글로 출력 |
| 6 | Kubernetes Schema | 표준·Argo CD 리소스와 고정 Karpenter CRD에서 추출한 NodePool·EC2NodeClass Schema 검사 |
| 7 | GitOps 정책 | Secret 원문, `kind: Secret`, 이미지 Repository·Digest 짝과 Digest 형식 검사 |

Manifest에 변경이 있다는 이유만으로 CI가 실패하지 않습니다. Diff는 변경 결과를 사람이 검토하기 위한 정보이며, 문법·구조·Schema·정책 위반이 있을 때 CI가 실패합니다.

환경별 values와 Argo CD·EKS 연동이 완료되면 PR의 Desired Manifest와 EKS Live State를 비교하는 Argo CD Live Diff를 추가합니다. EKS 변경 권한은 계속 Argo CD에만 유지합니다.

자세한 Fixture 설명은 [ci/README.md](ci/README.md)를 확인합니다.

## 보안 규칙

- `kind: Secret` 리소스와 비밀번호·Token·API Key 원문을 Commit하지 않습니다.
- Secret은 AWS Secrets Manager를 단일 원본으로 사용합니다.
- Git에는 SecretProviderClass와 Secret 참조 정보만 저장합니다.
- Pod의 AWS 권한은 Workload별 ServiceAccount와 IRSA로 분리합니다.
- 이미지에는 `latest`, `dev` 같은 가변 태그 대신 `sha256` Digest를 사용합니다.
- GitHub Actions에는 EKS 변경 권한을 부여하지 않습니다.
- Repository, Account ID, 권한 범위를 새로 추가할 때 최소 권한 원칙을 적용합니다.

## Argo CD 동기화 정책

Root Application과 최종 활성화된 ApplicationSet은 `main`을 감시하며 다음 정책으로 동기화합니다.

| 설정 | 동작 |
| --- | --- |
| `automated.enabled: true` | `main` 변경을 자동으로 Sync |
| `selfHeal: true` | Live State가 Git과 달라지면 Git 상태로 복구 |
| `prune: true` | Git에서 제거된 관리 리소스를 Cluster에서도 제거 |
| `allowEmpty: false` | 렌더링 결과가 비어 있을 때 전체 삭제 방지 |
| `PruneLast=true` | 새 상태가 반영된 후 삭제 대상 정리 |

따라서 Cluster를 수동으로 변경하더라도 Self Heal에 의해 Git 상태로 되돌아갈 수 있습니다. 운영 변경은 반드시 Git에서 시작해야 합니다.

EKS dev 최초 연결 단계에서는 이미지·Replica 등 실배포 값이 아직 확정되지 않았으므로 Workload ApplicationSet의 `automated.enabled`를 `false`로 유지합니다. Root Application은 AppProject, Namespace와 ApplicationSet을 자동 관리하지만, 실제 Workload Auto Sync는 필수 values와 전체 Helm 렌더링 검증이 완료된 후 별도 PR로 활성화합니다.

## 롤백·장애 대응

배포 문제는 정상 Commit을 기준으로 Git Revert PR을 만들어 복구합니다.

```bash
git switch main
git pull --ff-only origin main
git switch -c fix/revert-<작업명>
git revert <문제가-된-commit-sha>
git push -u origin fix/revert-<작업명>
```

복구 절차는 다음과 같습니다.

1. 실패한 Commit과 영향을 받은 환경·Workload를 확인합니다.
2. Revert Commit을 만든 뒤 PR을 생성합니다.
3. GitOps CI와 Manifest Diff를 확인합니다.
4. 긴급 리뷰 후 `main`에 Merge합니다.
5. Argo CD가 이전 Desired State를 EKS에 반영하는지 확인합니다.
6. Argo CD Sync·Health 상태와 Workload Readiness를 확인합니다.

`git reset --hard`, Force Push, Cluster 수동 수정으로 이력을 우회하지 않습니다.

## 담당 영역

| 영역 | 주 담당 |
| --- | --- |
| 애플리케이션 코드·Dockerfile·테스트 | 각 Application 담당 팀 |
| 공통 Helm Chart·환경 values·Argo CD | Cloud/Infrastructure 팀 |
| Cilium·Istio·Gateway·Karpenter·KEDA | Cloud/Infrastructure 팀 |
| 이미지 Build·ECR Push Workflow | Application 팀과 Cloud 팀 공동 관리 |
| GitOps CI·배포 정책·권한 | Cloud/Infrastructure 팀 |
| Domain별 기능 검증 | 해당 Domain 담당 팀 |

GitOps 설정 변경이 필요한 경우 이 저장소에 Issue 또는 PR을 생성하고, 변경 대상 환경·Domain·Workload와 예상 영향을 함께 작성합니다.

## 관련 문서

- [GitOps CI Fixture](ci/README.md)
- [Argo CD Project](argocd/projects/README.md)
- [Argo CD Dev](argocd/dev/README.md)
- [Argo CD Prod](argocd/prod/README.md)
- [Cilium ENI 모드 설계](https://github.com/100-hours-a-week/KTB4-15th-wiki/wiki/Cilium-ENI-%EB%AA%A8%EB%93%9C)
- [LookDDak V3 Kubernetes 설계](https://github.com/100-hours-a-week/KTB4-15th-wiki/wiki/%5BV3%5D-CL-5%EB%8B%A8%EA%B3%84:-%EC%BF%A0%EB%B2%84%EB%84%A4%ED%8B%B0%EC%8A%A4-%EC%84%A4%EA%B3%84)
- [OpenGitOps 원칙](https://opengitops.dev/)
- [Argo CD 문서](https://argo-cd.readthedocs.io/)
- [Kubernetes 선언형 관리](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)
