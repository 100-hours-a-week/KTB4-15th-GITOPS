# AI 서킷 브레이커 waypoint — dev

계획: `work/k8s-setting/75-ai-circuit-breaker/plan.md`

```
identity-api ─▶ ztunnel ─HBONE─▶ waypoint(lookddak-identity) ─▶ body-image-validator ─▶ Modal
chat-ai ─(http://api.runware.ai, http://api.openai.com)─▶ ztunnel ─HBONE─▶ egress-waypoint(lookddak-chat) ─TLS─▶ Runware·OpenAI
```

| 파일 | 내용 |
|---|---|
| `identity-waypoint.yaml` | Gateway `waypoint`(`istio-waypoint`), replicas 1. Service `body-image-validator`가 `istio.io/use-waypoint: waypoint`로 사용 |
| `chat-egress-waypoint.yaml` | Gateway `egress-waypoint`, replicas 1 |
| `chat-egress-services.yaml` | ServiceEntry·DestinationRule `api.runware.ai`, `api.openai.com` (lookddak-chat 전용 `exportTo: .`). 80 → waypoint에서 TLS 연결(443), 443은 통과 |

판정·차단 (DestinationRule outlierDetection)

| 대상 | 판정 | 퇴출 |
|---|---|---|
| body-image-validator (`environments/dev/domains/identity/workloads/body-image-validator.yaml` `trafficPolicy`) | 502·503·504 연속 3, 연결 실패 연속 3 | 30s × 횟수, 최대 100% |
| api.runware.ai, api.openai.com | 5xx 연속 3, 연결 실패 연속 3 | 15s × 횟수, 최대 100% |

- 최대 100% + panic 꺼짐(`minHealthPercent` 기본 0): 모두 실패하면 모두 퇴출 → waypoint가 즉시 503(`UH`)
- 퇴출 시간이 지나면 다시 넣고 실제 요청으로 시험, 상한 300s
- 네트워크 정책: `../policies/ai-waypoint.yaml`
- 인가: waypoint 신원(`cluster.local/ns/<ns>/sa/<waypoint>`)은 같은 Namespace라 `allow-same-namespace`로 허용
- 전제: ztunnel DNS 캡처(Istio 1.25+ Ambient 기본), ServiceEntry IP 자동 할당
- 주의: ServiceEntry `exportTo: .`는 istiod(Envoy 설정)에만 적용되고 ztunnel(DNS 캡처·VIP 라우팅)은 Namespace 구분 없이 적용한다 → 다른 Namespace에서 `api.runware.ai`·`api.openai.com`을 호출해도 egress-waypoint를 거친다. 새 워크로드가 이 주소를 쓰면 `../policies/ai-waypoint.yaml`에 워크로드 → egress-waypoint 15008 허용을 추가한다 (현재 vton-orchestrator)
