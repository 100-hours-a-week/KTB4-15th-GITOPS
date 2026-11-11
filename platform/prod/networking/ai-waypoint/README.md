# AI 서킷 브레이커 waypoint — prod

계획: `work/k8s-setting/75-ai-circuit-breaker/plan.md`

```
identity-api ─▶ ztunnel ─HBONE─▶ waypoint(lookddak-identity) ─▶ body-image-validator ─▶ Modal
chat-ai ─(http://runware-llm.egress.internal, http://openai.egress.internal)─▶ ztunnel ─HBONE─▶ egress-waypoint(lookddak-chat)
  └ Host → api.runware.ai·api.openai.com, TLS 연결 ─▶ Runware·OpenAI
```

| 파일 | 내용 |
|---|---|
| `identity-waypoint.yaml` | Gateway `waypoint`(`istio-waypoint`), replicas 2 (AZ 분산, PDB minAvailable 1). Service `body-image-validator`가 `istio.io/use-waypoint: waypoint`로 사용 |
| `chat-egress-waypoint.yaml` | Gateway `egress-waypoint`, replicas 2 (AZ 분산, PDB minAvailable 1) |
| `chat-egress-services.yaml` | 내부 이름 `runware-llm.egress.internal`·`openai.egress.internal`: ServiceEntry(endpoint 실제 주소 443), DestinationRule(TLS 연결·서킷 브레이커), HTTPRoute(Host 재작성) |

판정·차단 (DestinationRule outlierDetection)

| 대상 | 판정 | 퇴출 |
|---|---|---|
| body-image-validator (`environments/dev/domains/identity/workloads/body-image-validator.yaml` `trafficPolicy`) | 502·503·504 연속 3, 연결 실패 연속 3 | 30s × 횟수, 최대 100% |
| runware-llm·openai | 5xx 연속 3, 연결 실패 연속 3 | 15s × 횟수, 최대 100% |

- 최대 100% + panic 꺼짐(`minHealthPercent` 기본 0): 모두 실패하면 모두 퇴출 → waypoint가 즉시 503(`UH`)
- 퇴출 시간이 지나면 다시 넣고 실제 요청으로 시험, 상한 300s
- 내부 이름을 쓰는 이유: ztunnel(DNS 캡처·VIP 라우팅)은 ServiceEntry `exportTo`와 무관하게 모든 Namespace에 적용된다. `api.runware.ai`를 ServiceEntry host로 두면 vton-orchestrator 등 다른 워크로드도 egress-waypoint로 향한다. 내부 이름은 chat-ai만 호출하므로 다른 워크로드는 실제 주소로 직접 나간다
- 네트워크 정책: `../policies/ai-waypoint.yaml` (waypoint → istiod, egress-waypoint → Runware·OpenAI 443)
- 인가: waypoint 신원(`cluster.local/ns/<ns>/sa/<waypoint>`)은 같은 Namespace라 `allow-same-namespace`로 허용
- 전제: ztunnel DNS 캡처(Istio 1.25+ Ambient 기본), ServiceEntry IP 자동 할당
