# Argo CD — dev 설치 설정

## 목적

EKS dev에 설치된 Argo CD 자체의 버전과 Helm 설정을 관리한다. 이 디렉터리의 Wrapper Chart는 공식 `argo-cd` Chart를 고정된 버전으로 가져오고 LookDDak dev 환경 설정을 적용한다. 최초 Helm 설치 이후에는 `argocd` Application이 이 경로를 자동 동기화한다.

`argocd/dev`가 설치된 Argo CD가 배포할 ApplicationSet을 정의한다면, 이 디렉터리는 Argo CD 프로그램 자체를 설치하는 설정이다.

## 현재 설정

- 공식 `argo-cd` Chart 버전을 `Chart.yaml`과 `Chart.lock`으로 고정한다.
- 모든 Argo CD Pod를 `lookddak.io/node-pool=system` Node에 배치한다.
- 실행 구성요소와 Redis 초기화 Hook에 `CriticalAddonsOnly=true:NoSchedule` Toleration을 적용한다. System Node Taint는 네트워크 담당자와 준비를 마친 후 CLOUD에서 별도로 반영한다.
- dev 환경에서는 Application Controller, ApplicationSet Controller, Repo Server, Server와 Redis를 각각 단일 Replica로 실행한다.
- Argo CD Server는 `ClusterIP`로 유지하고 Ingress를 생성하지 않는다. 외부 진입은 공용 Istio Gateway의 HTTPRoute로 한다.
- Argo CD 외부 기준 URL은 `https://argocd.dev.lookddak.com`으로 선언한다.
- TLS는 Istio Gateway에서 종료하므로 `server.insecure: true`로 argocd-server가 HTTP(80)로 받는다. CLI는 `argocd login argocd.dev.lookddak.com --grpc-web`으로 접속한다.
- 최초 구축 단계에서는 Argo CD 기본 로컬 관리자 로그인을 명시적으로 활성화하고 Dex를 비활성화한다. GitHub OAuth는 후속 작업에서 별도로 구성한다.
- Discord 장애 알림은 후속 작업에서 구성하므로 Notifications Controller를 비활성화한다.
- Cilium 정책은 별도 플랫폼 설정에서 관리하므로 Chart의 NetworkPolicy 생성을 비활성화한다.
- CPU·메모리 request와 limit은 관측 기준이 없으므로 이 단계에서 임의로 지정하지 않는다.

## 외부 접속 경계

이 Chart는 외부 기준 URL과 `templates/httproute.yaml`을 선언한다. Gateway·인증서·NLB는 `platform/dev/networking/gateway`, CloudFront는 KTB4-15th-CLOUD에서 관리한다.

```text
argocd.dev.lookddak.com
→ CloudFront (VPC Origin)
→ 내부 NLB (TCP 443)
→ Istio Gateway https-argocd Listener (TLS 종료)
→ HTTPRoute argocd/argocd-server
→ argocd-server ClusterIP Service :80
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

## Argo CD 자기 관리 전환

| 항목 | 설정 |
| --- | --- |
| Application | `argocd` (`argocd` Namespace) |
| AppProject | `lookddak-dev-argocd` |
| Source | 이 저장소 main의 `platform/dev/argocd` |
| Helm releaseName | 기존 최초 설치와 동일한 `argocd` |
| Chart | 기존 Wrapper 0.1.0 / 공식 argo-cd 10.11.6 유지 |
| 자동 반영 | Auto Sync·Prune·Self Heal·PruneLast |

기존 Root가 `lookddak-dev*.yaml` Project와 `argocd/dev`를 관리하므로, main Merge 후 새 Project와 자기 관리 Application이 자동 등록된다. 별도로 두 번째 Helm 설치를 하지 않는다. 기존 리소스 이름과 Deployment·StatefulSet·Service Selector를 유지하여 같은 리소스를 이어받는다.

Toleration이 Pod Template에 추가되므로 기존 Argo CD Pod는 업데이트된다. Dev 구성요소는 단일 Replica이므로 UI·조정 작업이 일시 중단될 수 있다. System Taint는 적용하지 않으므로 이번 전환에 Cilium 설정 변경은 필요하지 않다.

전환 이후 Helm은 Manifest 생성에 사용되고 배포 수명주기는 Argo CD가 관리한다. 기존 Helm Release 기록은 자동 삭제·갱신되지 않으므로 `helm list`에 최초 Revision이 남아도 오류가 아니다. 동일 Release에 `helm upgrade/rollback/uninstall`을 실행하면 GitOps와 충돌하거나 실행 중인 Argo CD를 제거할 수 있으므로 이후 변경·복구는 Git PR/Revert로 수행한다. 기존 Release Secret은 이번 작업에서 수정하거나 삭제하지 않는다.

## CRD·Secret 보호

- Argo CD CRD 3개는 Server Side Apply와 `Prune=false,Delete=false`를 사용하고 `helm.sh/resource-policy: keep`도 유지한다.
- 공식 Chart가 생성하는 `argocd-secret` 선언에는 Secret 값이 없다. Git에는 비밀번호·서버 키·인증서를 저장하지 않는다.
- Application은 기존 `argocd-secret`의 `/data`를 비교에서 제외하고 `RespectIgnoreDifferences=true`로 적용 시에도 기존 값을 유지한다. 해당 Secret은 Prune·삭제 대상에서도 제외한다.
- Redis 초기화 Hook은 기존 공식 Chart의 동작을 유지한다. 기존 Redis Secret이나 Helm Release Secret을 Git으로 복사하지 않는다.
- 자기 관리 Application에는 연쇄 삭제 Finalizer를 추가하지 않는다. Application을 제거하는 것과 Argo CD 프로그램 자체를 제거하는 작업을 구분한다.

CI는 Secret 참조와 실제 Secret Manifest를 구분한다. `ignoreDifferences`의 `kind: Secret`은 참조이므로 허용하되 실제 Secret 선언·원문 값은 계속 차단한다. 렌더링 결과에서도 `argocd-secret`에 데이터가 지정되지 않았는지 확인한다.

## Merge 후 확인

```bash
kubectl get applications -n argocd lookddak-dev-root argocd
kubectl get pods -n argocd -o wide
kubectl get deployments,statefulsets -n argocd
```

`argocd` Application이 `Synced/Healthy`이고 활성 Pod 5개가 준비되었는지 확인한다. Pod Template의 System NodeSelector·Toleration, 기존 관리자 로그인도 확인한다. 실제 정상 상태는 main Merge 후 검증하며 로컬 렌더링 통과만으로 배포 완료라고 판단하지 않는다.

System Node 격리 원칙과 네트워크 담당자 인계 내용은 [System Node 격리 정책](system-node-isolation.md)을 참고한다.

## 후속 단계

최초 설치와 Public Repository Root 연결은 완료되었다. 자기 관리 Application이 main에 반영된 이후에는 이 경로의 변경도 PR 검증과 Auto Sync로 배포한다.

다음 기능은 최초 부트스트랩 이후 별도 Issue로 구성한다.

- GitHub OAuth 기반 Dex 로그인과 RBAC
- Discord Webhook 기반 장애 알림

다음 값은 Git에 원문으로 저장하지 않는다.

- GitHub App Private Key
- Deploy Key
- Personal Access Token
- Argo CD 관리자 비밀번호
- Webhook Secret

