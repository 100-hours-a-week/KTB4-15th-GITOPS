# 네트워크 정책 — dev

설계: `work/k8s-design/14-CNP.md` 요약.

## 구성

| 파일 | 리소스 | 내용 |
|---|---|---|
| `domain-baseline.yaml` | CCNP `lookddak-domain-baseline` | `lookddak.com/domain` Namespace Pod 기본 차단. 허용: Ambient probe `169.254.7.127/32`, Gateway → 15008, CoreDNS 53(DNS 관측) |
| `domain-same-namespace.yaml` | CCNP `lookddak-<domain>-same-namespace` ×5 | 같은 Namespace Pod 간 15008 |
| `domain-egress.yaml` | CCNP 8개 (opt-in) | 워크로드 `networkEgress` → Pod 라벨 `egress.lookddak.com/<대상>`. mysql·postgresql(RDS FQDN), aws-sts·s3(dev 이미지 버킷만)·sqs, runware, 29cm, modal |
| `web-waypoint.yaml` | CCNP 2개 | lookddak-web waypoint → istiod 15012·도메인 Pod 15008, 도메인 Pod ← waypoint 15008 |
| `hubble-relay.yaml` | CNP `kube-system/hubble-relay` | Relay 4245는 hubble-ui만 (Relay 서버 TLS 꺼짐) |

## Ambient와 함께 쓸 때
- Pod 간 트래픽은 HBONE 15008로 간다 → Cilium에서는 15008을 열고, 앱 포트·경로는 Istio `AuthorizationPolicy`로 통제한다.
- kubelet probe 출발지가 `169.254.7.127`이라 명시 허용이 필요하다 (없으면 Pod가 Ready가 안 된다).

## 추가 규칙 (앱 배포 시)
- 다른 도메인 Namespace 호출: 표준 `NetworkPolicy` (도메인 팀, 15008)
- DB·AWS API·외부 API: 워크로드 values `networkEgress`에 대상 이름 추가 (`domain-egress.yaml`에 있는 것만, CI 검사)
- 새 대상: `domain-egress.yaml`에 CCNP 추가 (인프라 팀). SSM은 Secrets Store CSI provider가 호출하므로 앱 Pod에 불필요
- 새 도메인 Namespace: `domain-same-namespace.yaml`에 추가 (CI가 Namespace 목록과 비교)

## 확인
- Hubble UI에서 `DROPPED` 흐름과 차단 원인 확인: `kubectl -n kube-system port-forward svc/hubble-ui 12000:80`
- CLI: `kubectl -n kube-system exec ds/cilium -- cilium-dbg policy get`
