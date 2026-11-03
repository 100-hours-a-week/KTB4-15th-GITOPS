## 7. System Node 격리 정책 적용

핵심 구성요소용 Node에 일반 애플리케이션 Pod가 새로 들어오지 못하도록 제한한다.

System Node에 `CriticalAddonsOnly=true:NoSchedule` Taint를 설정하면, 이 Taint를 허용하는 Toleration이 없는 Pod는 해당 Node에 새로 배치되지 않는다. 애플리케이션이 Karpenter·CoreDNS·Argo CD의 CPU와 메모리를 사용하는 것을 제한하기 위한 배치 정책이다. 방화벽이나 Pod 통신 정책은 아니다.

| 설정 | 적용 대상 | 역할 |
| --- | --- | --- |
| Taint | System Node | Toleration 없는 Pod의 신규 배치를 제한 |
| Toleration | 핵심 구성요소 Pod | System Node의 Taint를 허용 |
| nodeSelector 또는 필수 Node Affinity | 핵심 구성요소 Pod | System Node에 배치 위치를 고정 |

`NoSchedule`은 기존 Pod를 퇴거시키지 않는다. 다만 Toleration 없는 Pod가 재시작되면 System Node에 다시 배치되지 못하므로, 필요한 구성요소를 먼저 준비하고 Taint를 나중에 적용한다.

### 7-1. 이번 PR의 작업 범위

| 대상 | 변경 내용 | 이유 |
| --- | --- | --- |
| Argo CD Helm values | global Toleration에 `CriticalAddonsOnly=true:NoSchedule` 허용 | System Taint 적용 후에도 Argo CD Pod와 Hook이 실행되어야 함 |
| Argo CD 자기 관리 | 전용 AppProject와 `argocd` Application 추가 | 이후 설치 values 변경도 main Merge로 자동 반영 |
| CRD·런타임 Secret | 삭제 방지와 Secret 데이터 보존 설정 | 자기 관리 전환 중 API 정의·관리자 비밀번호 등을 유지 |
| GitOps CI | 렌더링된 실행 구성요소·Hook의 System 배치와 보호 설정 검사 | global 설정이 실제 Pod 설정에 반영되는지 지속 검증 |
| Karpenter·CoreDNS | 변경 없음 | 기존 System NodeSelector와 필요한 Toleration이 이미 적용됨 |

현재 System NodeSelector로 위치를 고정하고 있으므로 동일 목적의 필수 Node Affinity는 중복 추가하지 않는다. Toleration만으로는 위치를 고정할 수 없다.

### 7-2. 네트워크 담당자에게 인계할 작업

Cilium·Istio·Gateway 설정과 System MNG Taint는 이번 PR에서 변경하지 않는다. 2026-11-03 조회 시 Cilium Operator에는 `CriticalAddonsOnly` Toleration이 없었으므로, 현재 상태에서 System Taint를 적용하면 Operator 재생성 시 배치가 제한될 수 있다.

| 후속 순서 | 담당 영역 | 확인할 내용 |
| --- | --- | --- |
| 1 | 네트워크 | Cilium Operator의 System 배치·Toleration 확인 및 필요한 보완 |
| 2 | 플랫폼 | Argo CD 자기 관리 Application Synced/Healthy, 실행 Pod 5개의 실제 Toleration 확인 |
| 3 | 플랫폼 | 별도 General-purpose Node 공급·회수 검증 수행 |
| 4 | CLOUD | Terraform으로 System MNG에 `CriticalAddonsOnly=true:NoSchedule` Taint 작성·Plan·PR 검토 후 반영 |
| 5 | 공동 검증 | 핵심 Pod 정상 배치 및 일반 애플리케이션 Pod의 System Node 신규 배치 차단 확인 |

Cilium Agent·Cilium Envoy 같은 Node용 DaemonSet은 System·Application Node 모두에서 실행되어야 한다. 일반 애플리케이션에는 System Taint Toleration을 부여하지 않는다.

7번 전체의 완료 기준인 “일반 Pod는 System Node에 배치되지 않음”은 위 후속 작업까지 끝나야 충족한다. 이번 PR은 Taint를 적용하기 전 Argo CD의 배치 준비와 GitOps 반영 경로를 완성하는 범위다.

### 7-3. 확인 명령

연결된 dev kubeconfig에서 다음 명령은 조회만 수행한다.

```bash
kubectl get application -n argocd argocd
kubectl get pods -n argocd -o wide
kubectl get deployments,statefulsets -n argocd -o yaml
kubectl get nodes -l lookddak.io/node-pool=system -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

Argo CD Pod Template에 System NodeSelector와 Toleration이 있는지 확인한다. System Taint는 후속 Terraform 반영 전까지 비어 있는 것이 정상이다.

### 근거

- [Kubernetes Taint·Toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Kubernetes Node 배치 조건](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Argo CD Helm 관리 방식](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
- [Argo CD Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
