# Istio Gateway — dev

## 목적

dev의 공용 Istio Gateway(Gateway API)를 GitOps로 관리한다. 각 도메인의 HTTPRoute는 이 Gateway를 parentRef로 참조한다.

## 요청 흐름

`Client → CloudFront + WAF (인증서 A: ACM us-east-1) → VPC Origin → 내부 NLB (TCP 443 통과) → Istio Gateway (인증서 B: Let's Encrypt, TLS 종료) → HTTPRoute → Service (ztunnel mTLS)`

- CloudFront는 viewer Host(`dev.lookddak.com`)를 origin으로 전달한다 (Origin Request Policy에 Host 포함). Gateway 인증서 이름이 이 Host와 같아야 CloudFront의 origin 인증서 검증을 통과한다.
- NLB는 TLS를 풀지 않는다 (`ssl-cert` 어노테이션 없음). L7 처리는 Istio가 한다.

## 확정 값

| 항목 | 값 |
|---|---|
| GatewayClass | `istio` (istiod가 제공) |
| Gateway | `istio-ingress/lookddak-gateway` |
| Listener | 443 HTTPS, `tls.mode: Terminate`, 인증서 1개 공유<br>`https`: `dev.lookddak.com` → `lookddak.com/domain` 라벨 Namespace<br>`https-argocd`: `argocd.dev.lookddak.com` → `argocd` Namespace<br>`https-grafana`: `grafana.dev.lookddak.com` → `monitoring` Namespace |
| 인증서 | Certificate `dev-lookddak-com` → Secret `dev-lookddak-com-tls`, SAN 3개(dev·argocd·grafana), cert-manager Route53 DNS-01, ECDSA P-256 |
| NLB | `internal`, target-type `ip`, TCP, cross-zone 활성 |
| NLB Health Check | HTTP `15021` `/healthz/ready` |
| Deregistration delay | 300초 (SSE 연결 종료 대기) |
| Gateway Pod | replicas 2, System Node(`lookddak.io/node-pool: system`) + `CriticalAddonsOnly` Toleration, Zone 분산, PDB minAvailable 1 |
| 종료 대기 | `terminationGracePeriodSeconds: 330` (deregistration 300초 + 여유) |
| istio-proxy 리소스 | requests 200m/256Mi, limits 1 CPU/512Mi |

## 파일

- `gateway.yaml` — Gateway. `spec.infrastructure.annotations`가 istiod가 만드는 Service에 붙고, AWS LB Controller가 이를 보고 NLB를 만든다.
- `gateway-options.yaml` — istiod가 만드는 Deployment·PDB 덮어쓰기 값 (`parametersRef`).
- `certificate.yaml` — Gateway TLS 인증서.
- Namespace `istio-ingress`는 `argocd/dev/namespace-istio-ingress.yaml`. `elbv2.k8s.aws/pod-readiness-gate-inject: enabled`로 NLB Target 등록 후 Pod Ready (무중단 롤링).

## 운영 메모

### 인증서 staging → prod

1. 처음에는 `letsencrypt-staging`으로 DNS-01 발급 절차를 확인한다.
2. `kubectl -n istio-ingress get certificate dev-lookddak-com`이 `READY True`이면 `issuerRef.name`을 `letsencrypt-prod`로 바꾼다.
3. CloudFront 연결 전에 반드시 prod여야 한다 (staging CA는 CloudFront가 신뢰하지 않아 502).
4. 2026-11-05 staging 발급(SAN 3개) 확인 후 `letsencrypt-prod`로 전환했다. 이후 발급 테스트는 staging Certificate를 따로 만들어 한다 (prod 주간 발급 한도).

### Gateway 확장 (System Node → Application Node)

트래픽이 늘어 System Node 자원이 부족해지면 `nodeSelector`를 지우고 다음으로 바꾼다.

- `requiredDuringScheduling`: `lookddak.io/node-pool In [system]` 또는 Karpenter `general-purpose` NodePool
- `preferredDuringScheduling`: `lookddak.io/node-pool In [system]`
- HPA를 추가해 늘어난 Pod는 general-purpose Node로 가게 한다.

### 운영 도구 (Argo CD, Grafana)

- HTTPRoute는 각 도구 담당이 해당 Namespace에 만든다 (`parentRefs: istio-ingress/lookddak-gateway`, `sectionName: https-argocd`/`https-grafana`).
- Argo CD: TLS를 Gateway가 끝내므로 `server.insecure: true`가 필요하다. CLI는 `--grpc-web`으로 접속한다.
- 외부에 노출되므로 CloudFront WAF IP 제한 또는 SSO를 함께 건다.

### SSE

- NLB TCP idle timeout은 350초다. SSE heartbeat는 350초보다 짧아야 한다 (BE와 확인 필요).
