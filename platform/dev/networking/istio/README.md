# Istio Ambient — dev

## 목적

EKS dev(`lookddak-dev`)의 Istio Ambient Mesh(Control Plane, CNI Node Agent, ztunnel)를 Argo CD로 관리한다. Gateway(외부 진입점)와 Mesh 정책은 별도 작업에서 추가한다.

## 구성

| 디렉터리 | 공식 Chart | Release | Namespace | 형태 | sync-wave |
| --- | --- | --- | --- | --- | --- |
| `base` | `base` 1.31.3 | `istio-base` | `istio-system` | Istio CRD·공통 리소스 | -1 |
| `istiod` | `istiod` 1.31.3 | `istiod` | `istio-system` | Control Plane (Deployment, HPA 1~3) | 0 |
| `cni` | `cni` 1.31.3 | `istio-cni` | `istio-system` | CNI Node Agent (DaemonSet) | 1 |
| `ztunnel` | `ztunnel` 1.31.3 | `ztunnel` | `istio-system` | L4 mTLS 프록시 (DaemonSet) | 1 |

- Chart Repository: `https://blob.istio.io/istio-release/charts`
- Gateway API CRD(`gateway.networking.k8s.io`)는 `../gateway-api/crds`에서 별도 관리한다
- Root Application의 sync-wave는 Application 생성 순서일 뿐 설치 완료를 보장하지 않는다. 앞 단계가 준비되기 전 실패하면 `retry`(최대 5회)로 다시 시도한다

## 주요 설정

| 항목 | 값 | 이유 |
| --- | --- | --- |
| profile | `ambient` (istiod, cni) | Sidecar 없이 ztunnel·waypoint 사용 |
| istiod 배치 | `lookddak.io/node-pool=system`, arm64, `CriticalAddonsOnly` Toleration | System Node 격리 정책 |
| istiod 자원 | requests 200m / 512Mi, HPA 1~3 | 차트 기본(500m / 2Gi)은 System Node(m7g.large 2대)에 과함. 관측 후 조정 |
| istio-cni·ztunnel | DaemonSet, 차트 기본 Toleration(모든 Taint 허용) | System·Application Node 모두에서 실행 |
| istio-cni·ztunnel requests | CPU 50m, 메모리 64Mi (차트 기본: ztunnel 200m/512Mi, cni 100m/100Mi) | 실측 ztunnel CPU 1m·메모리 4~6Mi(2026-11-08, 유휴). 노드당 예약 CPU 200m·메모리 484Mi 감소. limit 없음. 부하 테스트 중 최대값 재측정 |
| `base.validationFailurePolicy` | `Fail` (**base·istiod 둘 다**) | istiod가 실행 중 `Ignore`→`Fail`로 바꾸며 생기는 반복 diff 방지 (Istio Helm 문서: SSA·Argo CD 사용 시 필수). `Fail`은 istiod가 응답하지 못할 때 **Istio 설정 리소스(istio.io)** 생성·변경만 거부한다. Pod·Service·트래픽에는 영향 없음 |
| Webhook `caBundle` | base·istiod Application `ignoreDifferences` + `RespectIgnoreDifferences=true` | istiod가 실행 중 caBundle을 직접 채운다. Git 값으로 되돌리지 않는다 |
| base 적용 | `ServerSideApply=true` | 큰 CRD의 client-side apply 어노테이션 한도 회피 |

## Cilium 공존 (Cilium values, Bootstrap 관리)

| Cilium 설정 | 값 | 이유 |
| --- | --- | --- |
| `cni.exclusive` | `false` | istio-cni가 Cilium conflist에 체이닝 |
| `socketLB.hostNamespaceOnly` | `true` | kube-proxy 대체 시 Pod 안 socket LB가 ztunnel 리다이렉션을 우회하지 않게 |
| `bpf.masquerade` | 기본값(false) 유지 | `true`면 Ambient health probe 실패 (Istio 미지원) |
| 기본 차단 정책 전 | `169.254.7.127/32` ingress 허용 CCNP, HBONE 15008 허용 | 정책 작업에서 추가 |

## Mesh 등록

- 이 작업은 **설치만** 한다. 어떤 Namespace도 Ambient에 등록하지 않으므로 애플리케이션 트래픽은 바뀌지 않는다
- 등록은 Namespace label `istio.io/dataplane-mode=ambient`로 하며, 도메인 Namespace별로 통신 경로를 검증하면서 진행한다

## 반영 후 확인

```bash
kubectl -n argocd get applications | grep -E 'gateway-api|istio|ztunnel'
kubectl get crd | grep -E 'gateway.networking.k8s.io|istio.io' | wc -l
kubectl -n istio-system get pods -o wide
kubectl -n istio-system get ds
```

- Application 5개 `Synced/Healthy`
- istiod 1개 Running(System Node), istio-cni·ztunnel이 모든 Node에 1개씩 Running
- Cilium 상태 유지: `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status --brief` → `OK`

## 미결정 항목

- Namespace의 Ambient 등록 순서
- Waypoint 적용 대상
- AuthorizationPolicy, Timeout, Circuit Breaker 세부 설정

## 참고

- [Install ambient mode with Helm](https://istio.io/latest/docs/ambient/install/helm/)
- [Platform-specific prerequisites (Cilium)](https://istio.io/latest/docs/ambient/install/platform-prerequisites/)
