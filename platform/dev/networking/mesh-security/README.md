# 메시 보안 — dev

설계: `work/k8s-design/16-Istio-Security.md` 요약.

| 리소스 | 위치 | 내용 |
|---|---|---|
| `PeerAuthentication istio-system/default` | 이 디렉터리 | 메시 전체 mTLS `STRICT` |
| `AuthorizationPolicy allow-same-namespace`, `allow-gateway` | `charts/lookddak-domain` (`authorizationPolicy.enabled`) | 도메인 NS마다 같은 NS + 공용 Gateway(`istio-ingress/lookddak-gateway-istio` SA)만 허용 |

- Cilium 정책(`../policies`)은 위치(Namespace·IP·FQDN), Istio는 신원(SPIFFE)으로 두 겹 방어
- ztunnel은 L4만 판단한다. 경로·메서드 조건은 waypoint 없이 쓰면 거부된다
- 다른 NS 호출·포트 제한은 서비스별 AuthorizationPolicy 추가
