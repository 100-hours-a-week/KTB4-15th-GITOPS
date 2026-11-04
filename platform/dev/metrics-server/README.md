# Metrics Server — dev

## 목적

EKS dev의 Node·Pod CPU와 Memory 현재 사용량을 Kubernetes Metrics API로 제공한다. `kubectl top nodes/pods`와 향후 CPU·Memory 기반 HPA가 이 API를 사용한다. 장기 보관·대시보드·알림은 Metrics Server가 아니라 별도 관측 시스템에서 담당한다.

## 관리 방식

- 공식 Helm Chart `3.14.0`, Metrics Server `0.9.0`을 Wrapper Chart로 고정한다.
- `lookddak-dev-metrics-server` Argo CD Application이 `main`의 이 디렉터리를 자동 동기화한다.
- Namespace는 클러스터 공통 구성요소가 위치하는 `kube-system`을 사용한다.
- AWS API를 호출하지 않으므로 IRSA를 구성하지 않는다.
- EKS에 직접 `kubectl apply`하거나 수동 `helm install/upgrade`하지 않는다.

## 배치·가용성 정책

| 항목 | 설정 | 이유 |
| --- | --- | --- |
| Replica | 2 | 한 System Node 장애 중에도 Metrics API를 유지한다. |
| NodeSelector | Linux·ARM64·`lookddak.io/node-pool=system` | Karpenter가 Application Node를 회수해도 수집기를 유지한다. |
| Pod Anti-Affinity | Hostname 기준 선호 분산 | 두 Replica를 가능한 한 서로 다른 System Node에 배치한다. |
| Toleration | `CriticalAddonsOnly=true:NoSchedule` | 향후 System Node 격리 Taint 적용 후에도 배치한다. |
| PDB | `minAvailable: 1` | 계획된 Node 중단 시 최소 한 개를 유지한다. |
| PriorityClass | `system-cluster-critical` | 일반 워크로드보다 클러스터 Metrics API를 우선 배치한다. |
| Resource request | CPU `100m`, Memory `200Mi` | 공식 Chart의 100개 Node 이하 기본값을 명시한다. |

Anti-Affinity는 `preferred` 정책이다. System Node 한 대가 실제로 사용할 수 없을 때 다른 한 대에 두 Replica가 함께 배치될 수 있도록 하여 Metrics API 전체 중단을 피한다.

## 네트워크 사전 확인

2026-11-04 조회 기준 별도의 AWS 네트워크 변경은 필요하지 않다.

- EKS API Server ENI, System Node ENI와 Cilium Pod ENI는 같은 Cluster Security Group `sg-04d109eb4f8eae342`를 사용한다.
- Cluster Security Group은 자기 자신을 Source로 하는 전체 통신을 허용한다.
- Node·Pod Private Subnet은 같은 기본 Network ACL을 사용하며 양방향 전체 통신을 허용한다.
- 기존 Argo CD Pod에서 두 System Node의 kubelet `10250` 포트까지 TCP 연결이 성공했다.
- 현재 `kube-system`을 제한하는 NetworkPolicy·CiliumNetworkPolicy는 없다.

필요한 통신은 다음 두 경로다.

```text
EKS API Server
→ metrics-server Service:443
→ Metrics Server Pod:10250

Metrics Server Pod
→ 각 Node InternalIP의 kubelet:10250
```

kubelet 인증서 검증을 유지하며 `--kubelet-insecure-tls`를 사용하지 않는다. Cilium NetworkPolicy를 추가할 때는 위 두 경로를 차단하지 않는지 네트워크 담당자와 함께 확인한다.

## 로컬 검증

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm dependency build platform/dev/metrics-server
helm lint platform/dev/metrics-server --namespace kube-system --kube-version 1.36.0

helm template metrics-server platform/dev/metrics-server \
  --namespace kube-system \
  --kube-version 1.36.0 \
  > /tmp/metrics-server-dev.yaml
```

렌더링 결과의 Deployment, PDB, APIService와 System Node 배치 설정은 PR Manifest Diff에서 검토한다. 공통 GitOps CI가 YAML·저장소 구조·Helm lint·Kubernetes Schema를 검사한다.

## Merge 후 Live 검증

```bash
kubectl -n argocd get application lookddak-dev-metrics-server
kubectl -n kube-system get deployment,pod,pdb -l app.kubernetes.io/name=metrics-server -o wide
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -A
```

다음을 확인한다.

1. Argo CD Application이 `Synced/Healthy`다.
2. Metrics Server Pod 2개가 `Running/Ready`이고 서로 다른 System Node에 배치된다.
3. `v1beta1.metrics.k8s.io` APIService가 `Available=True`다.
4. System Node와 이후 생성되는 Karpenter Node의 CPU·Memory가 조회된다.
5. Pod별 CPU·Memory가 조회되고 Metrics Server 로그에 `x509`, `Forbidden`, kubelet Timeout 오류가 없다.

Application Node가 없는 현재 상태에서는 System Node만 조회되는 것이 정상이다. 실제 HPA 확장과 Karpenter Node 생성·회수 연계 검증은 애플리케이션 워크로드 준비 후 별도 작업으로 수행한다.

## 업그레이드

1. Metrics Server의 Kubernetes 호환성 표와 Release Note를 확인한다.
2. `Chart.yaml`의 공식 Chart 버전을 변경하고 `helm dependency update`로 `Chart.lock`을 갱신한다.
3. 로컬 렌더링·정책·Schema 검사를 통과시킨다.
4. PR Manifest Diff에서 RBAC, APIService, Deployment와 PDB 변경을 검토한다.
5. Merge 후 Metrics API와 `kubectl top`을 다시 검증한다.
