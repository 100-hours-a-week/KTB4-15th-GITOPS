# Gateway API CRD — dev

## 목적

Kubernetes 표준 Gateway API CRD(`gateway.networking.k8s.io`)를 설치한다. Istio가 Gateway·HTTPRoute를 처리하고, 각 워크로드 Chart의 HTTPRoute가 이 CRD를 사용한다.

## 현재 설정

| 항목 | 값 |
| --- | --- |
| 버전 | `v1.6.3` Standard channel (`standard-install.yaml`, 공식 Release 원문) |
| 근거 | Istio 1.31 Ambient Helm 설치 문서가 v1.6 계열을 사용. Experimental 리소스는 쓰지 않는다 |
| 포함 리소스 | CRD 10개 (Gateway, GatewayClass, HTTPRoute, GRPCRoute, ReferenceGrant, BackendTLSPolicy, ListenerSet, TCPRoute, TLSRoute, UDPRoute) + 업그레이드 보호 `ValidatingAdmissionPolicy`·`Binding` |
| Application | `lookddak-dev-gateway-api-crds`, sync-wave -1, `ServerSideApply=true`, **자동 Prune 끔** |

- CRD를 삭제하면 모든 Gateway·HTTPRoute가 함께 지워지므로 자동 Prune을 끈다
- 파일이 1.1MB라 client-side apply 어노테이션 한도를 넘으므로 Server Side Apply로 적용한다
- AWS LB Controller의 `gateway.k8s.aws` CRD와는 다른 API 그룹이며 충돌하지 않는다

## 버전 갱신

```bash
curl -sSfL https://github.com/kubernetes-sigs/gateway-api/releases/download/<버전>/standard-install.yaml -o platform/dev/networking/gateway-api/crds/standard-install.yaml
```

Istio가 지원하는 버전인지 Istio 릴리스 노트로 확인한 뒤 PR로 갱신한다. 원문은 수정하지 않는다.
