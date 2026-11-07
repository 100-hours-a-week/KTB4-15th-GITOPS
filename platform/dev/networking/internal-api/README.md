# 내부 API 라우팅 (web-bff → BE) — dev

설계: `work/k8s-design/17-Internal-API-Waypoint.md`

```
web-bff ─(API_BASE_URL=http://api.lookddak-web.svc.cluster.local/api/v1/)─▶ ztunnel ─HBONE─▶ waypoint(lookddak-web)
  └ HTTPRoute api (parentRef = Service api) ─HBONE─▶ identity-api / chat-api / commerce-api / fitting-api
```

| 파일 | 내용 |
|---|---|
| `waypoint.yaml` | Gateway `waypoint`(`istio-waypoint`), replicas 1 |
| `api-service.yaml` | Pod 선택 없는 Service `api`, `istio.io/use-waypoint: waypoint` |
| `api-httproute.yaml` | 내부 경로 표 (외부 HTTPRoute와 같은 경로) |
| `reference-grants.yaml` | 대상 Namespace 4개: lookddak-web HTTPRoute → Service 허용 |
| `authorization-policy.yaml` | waypoint L7 인가: Service `api`는 web-bff 신원(`cluster.local/ns/lookddak-web/sa/web-bff`)만 허용, 나머지 403 |

- 네트워크 정책: `../policies/web-waypoint.yaml` (waypoint → istiod 15012, 도메인 Pod 15008)
- 인가 (두 단계)
  - 입구(waypoint): `authorization-policy.yaml` — 호출자가 web-bff인지 확인
  - 출구(대상 API): `charts/lookddak-domain` `gatewayPrincipals`에 `cluster.local/ns/lookddak-web/sa/waypoint` — 대상 API는 waypoint 신원만 본다
- 서비스 경로를 바꾸면 워크로드 `routing` 값(외부)과 `api-httproute.yaml`(내부)을 함께 바꾼다
- FE 코드 변경 없음: web-bff `API_BASE_URL`만 변경
