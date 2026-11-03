# Argo CD — dev 설치 설정

## 목적

EKS dev에 설치할 Argo CD 자체의 버전과 Helm 설정을 관리한다. 이 디렉터리의 Wrapper Chart는 공식 `argo-cd` Chart를 고정된 버전으로 가져오고 LookDDak dev 환경 설정을 적용한다.

`argocd/dev`가 설치된 Argo CD가 배포할 ApplicationSet을 정의한다면, 이 디렉터리는 Argo CD 프로그램 자체를 설치하는 설정이다.

## 현재 설정

- 공식 `argo-cd` Chart 버전을 `Chart.yaml`과 `Chart.lock`으로 고정한다.
- 모든 Argo CD Pod를 `lookddak.io/node-pool=system` Node에 배치한다.
- dev 환경에서는 Application Controller, ApplicationSet Controller, Repo Server, Server와 Redis를 각각 단일 Replica로 실행한다.
- Argo CD Server는 `ClusterIP`로 유지하고 Ingress를 생성하지 않는다.
- Argo CD 외부 기준 URL은 `https://argocd-dev.lookddak.com`으로 선언한다.
- 최초 구축 단계에서는 Argo CD 기본 로컬 관리자 로그인을 명시적으로 활성화하고 Dex를 비활성화한다. GitHub OAuth는 후속 작업에서 별도로 구성한다.
- Discord 장애 알림은 후속 작업에서 구성하므로 Notifications Controller를 비활성화한다.
- Cilium 정책은 별도 플랫폼 설정에서 관리하므로 Chart의 NetworkPolicy 생성을 비활성화한다.
- CPU·메모리 request와 limit은 관측 기준이 없으므로 이 단계에서 임의로 지정하지 않는다.

## 외부 접속 경계

이 Chart는 Argo CD가 외부 링크와 로그인 Redirect의 기준으로 사용할 URL만 선언한다. 실제 외부 네트워크 경로는 이 작업에서 생성하지 않는다.

```text
argocd-dev.lookddak.com
→ 기존 외부 진입 경로
→ Istio Gateway·Gateway API HTTPRoute
→ argocd-server ClusterIP Service
```

Istio Gateway, HTTPRoute, DNS, 인증서와 앞단 Load Balancer 설정은 네트워크 담당 작업에서 구성한다. 따라서 Argo CD Chart 자체의 Ingress는 계속 비활성화한다.

## 로컬 검증

```bash
helm dependency build platform/dev/argocd
helm lint platform/dev/argocd --namespace argocd --kube-version 1.36.0
helm template argocd platform/dev/argocd \
  --namespace argocd \
  --kube-version 1.36.0 \
  --include-crds
```

`helm dependency build`가 내려받은 `platform/dev/argocd/charts` 파일은 Git에 저장하지 않는다. 검증된 의존성 정보가 기록된 `Chart.lock`은 Git에 저장한다.

## 후속 단계

이 단계에서는 실제 EKS 리소스를 변경하지 않는다. 다음 작업에서 Bastion을 통해 이 Chart를 최초 설치하고, 이후 Private GitOps Repository 인증과 Root Application을 연결한다.

다음 기능은 최초 부트스트랩 이후 별도 Issue로 구성한다.

- GitHub OAuth 기반 Dex 로그인과 RBAC
- Discord Webhook 기반 장애 알림
- `argocd-dev.lookddak.com`용 Gateway API HTTPRoute와 TLS 연결

다음 값은 Git에 원문으로 저장하지 않는다.

- GitHub App Private Key
- Deploy Key
- Personal Access Token
- Argo CD 관리자 비밀번호
- Webhook Secret

