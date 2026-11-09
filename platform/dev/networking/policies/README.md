# 네트워크 정책 — dev

설계: `work/k8s-design/14-CNP.md` 요약.

## 구성

| 파일 | 리소스 | 내용 |
|---|---|---|
| `domain-baseline.yaml` | CCNP `lookddak-domain-baseline` | `lookddak.com/domain` Namespace Pod 기본 차단. 허용: Ambient probe `169.254.7.127/32`, Gateway → 15008, CoreDNS 53(DNS 관측) |
| `domain-same-namespace.yaml` | CCNP `lookddak-<domain>-same-namespace` ×5 | 같은 Namespace Pod 간 15008 |
| `<워크로드>-egress.yaml` | CCNP (워크로드마다 1개) | 해당 워크로드 Pod(`app.kubernetes.io/name`)만 DB·AWS API·외부 API FQDN 허용. S3는 dev 이미지 버킷 호스트만 |
| `web-waypoint.yaml` | CCNP 2개 | lookddak-web waypoint → istiod 15012·도메인 Pod 15008, 도메인 Pod ← waypoint 15008 |
| `hubble-relay.yaml` | CNP `kube-system/hubble-relay` | Relay 4245는 hubble-ui만 (Relay 서버 TLS 꺼짐) |
| `monitoring-grafana.yaml` | CNP 2개 (`monitoring`) | Grafana 3000·oauth2-proxy 4180 ← 공용 Gateway만 (Grafana `auth.proxy` 헤더 위조 방지) |
| `alloy-cluster-scrape.yaml` | CCNP | 도메인 Pod ← `monitoring/alloy-cluster` 15008(앱 메트릭, HBONE)·15020(waypoint 메트릭). 포트 8080·8000 제한은 domain Chart `allow-metrics-scrape` |

## Ambient와 함께 쓸 때
- Pod 간 트래픽은 HBONE 15008로 간다 → Cilium에서는 15008을 열고, 앱 포트·경로는 Istio `AuthorizationPolicy`로 통제한다.
- kubelet probe 출발지가 `169.254.7.127`이라 명시 허용이 필요하다 (없으면 Pod가 Ready가 안 된다).

## 추가 규칙 (앱 배포 시)
- 다른 도메인 Namespace 호출: 표준 `NetworkPolicy` (도메인 팀, 15008)
- DB·AWS API·외부 API: `<워크로드>-egress.yaml`에 FQDN 추가 (CI: 이름·선택 대상·FQDN만 검사). SSM은 Secrets Store CSI provider가 호출하므로 앱 Pod에 불필요
- 새 도메인 Namespace: `domain-same-namespace.yaml`에 추가 (CI가 Namespace 목록과 비교)

## 확인
- Hubble UI에서 `DROPPED` 흐름과 차단 원인 확인: `kubectl -n kube-system port-forward svc/hubble-ui 12000:80`
- CLI: `kubectl -n kube-system exec ds/cilium -- cilium-dbg policy get`
