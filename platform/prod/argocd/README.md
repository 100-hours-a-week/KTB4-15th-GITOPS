# Argo CD — prod Bootstrap

## 목적

Prod EKS에 Argo CD를 최초 설치하고, 설치 직후부터 GitOps `main`의 Prod Wrapper Chart를 자기 관리하도록 전환한다. 이 단계에서는 플랫폼 Controller와 애플리케이션 워크로드를 배포하지 않는다.

## 배포 범위

- 공식 `argo-cd` Chart `10.11.6`을 고정한다.
- 모든 Argo CD Pod를 `lookddak.io/node-pool=system` Node에 배치한다.
- Controller, ApplicationSet, Repo Server, Server와 Redis는 Bootstrap 단계에서 각각 단일 Replica로 실행한다.
- Ingress와 외부 HTTPRoute를 만들지 않는다. 2-3의 Istio Gateway·LB Controller 설치 전에는 `kubectl port-forward`로만 접근한다.
- 기본 관리자 로그인을 활성화하고 Dex와 Notifications를 비활성화한다. OAuth·운영 알림은 별도 작업으로 구성한다.
- CRD와 `argocd-secret`은 Prune·삭제로부터 보호한다. Secret 원문은 Git에 저장하지 않는다.

## 최초 Bootstrap

아래 명령은 반드시 승인되어 `main`에 반영된 코드에서 실행한다. Prod EKS Private API SSM Tunnel과 임시 kubeconfig 설정이 준비되어 있어야 한다.

```bash
cd /Users/juyeongjin/VsProjects/GitOps/KTB4-15th-GITOPS
git fetch origin main && git switch main && git merge --ff-only origin/main

helm dependency build platform/prod/argocd
helm upgrade --install argocd platform/prod/argocd \
  --namespace argocd \
  --create-namespace \
  --wait \
  --timeout 15m

kubectl apply -f argocd/prod/root-application.yaml
```

Root Application은 다음만 관리한다.

- `lookddak-prod`, `lookddak-prod-argocd` AppProject
- Argo CD 자기 관리 Application
- Prod 도메인과 다음 플랫폼 작업에 필요한 빈 Namespace

기존 `domain-applicationset.yaml`과 `workload-applicationset.yaml`은 Root 경로에서 제외한다. 따라서 이 단계만으로 Prod 애플리케이션 Pod가 생성되지 않는다.

## 검증

```bash
kubectl get nodes -L lookddak.io/node-pool
kubectl get namespace
kubectl -n argocd get pods -o wide
kubectl -n argocd get applications,appprojects
kubectl -n argocd get application lookddak-prod-root argocd
```

완료 기준은 Argo CD Pod가 System Node에서 Ready이고 `lookddak-prod-root`와 `argocd` Application이 `Synced/Healthy`인 상태다. `lookddak-*` Namespace에는 아직 워크로드 Pod가 없어야 한다.

로컬 UI가 필요하면 별도 터미널에서 다음을 실행한다.

```bash
kubectl -n argocd port-forward service/argocd-server 8080:80
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode; echo
```

브라우저에서는 `http://127.0.0.1:8080`으로 접속한다. 외부 URL·GitHub Webhook은 2-3에서 Gateway 경로를 만든 뒤 설정한다.

## 자기 관리 전환 후 주의사항

Root가 `argocd` Application을 생성한 뒤에는 Argo CD 변경을 Git PR로 수행한다. 기존 Helm Release Secret은 남아 있어도 정상이며 `helm upgrade`, `rollback`, `uninstall`을 임의로 실행하지 않는다.
