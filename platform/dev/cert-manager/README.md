# cert-manager — dev

## 목적

EKS dev(`lookddak-dev`)에서 **Istio Gateway가 TLS를 종료할 공인 인증서**를 Let's Encrypt로 발급·갱신한다.

```text
Client ─TLS─▶ CloudFront ─TLS─▶ 내부 NLB(TCP 통과) ─TLS─▶ Istio Gateway [종료] ─mTLS─▶ 앱
                  │ origin 인증서 검증                         └─ cert-manager가 만든 Secret
```

- CloudFront는 origin 인증서를 검증하므로 공인 CA 인증서가 필요하다. 일반 ACM 인증서는 개인키를 꺼낼 수 없어 Gateway에 넣을 수 없다
- 설계 근거: `lookddak_infra/work/k8s-design/09-Gateway-API-Controller.md` 5장

## 구성

| 디렉터리 | Application | sync-wave | 내용 |
| --- | --- | --- | --- |
| `controller` | `lookddak-dev-cert-manager` | 0 | 공식 `cert-manager` Chart `v1.21.3` (`https://charts.jetstack.io`), CRD 포함 |
| `issuers` | `lookddak-dev-cert-manager-issuers` | 1 | `ClusterIssuer` `letsencrypt-staging`, `letsencrypt-prod` |

## 주요 설정

| 항목 | 값 | 이유 |
| --- | --- | --- |
| Namespace | `kube-system` | 플랫폼 AppProject 대상. leader election 기본 위치와 같다 |
| IRSA | `kube-system/cert-manager` → `lookddak-dev-cert-manager` | KTB4-15th-CLOUD `dev/v3/iam`. lookddak.com Zone의 `_acme-challenge.*` TXT만 변경 |
| `securityContext.fsGroup` | `1001` | non-root 컨테이너가 IRSA 토큰 파일을 읽게 한다 |
| 배치 | controller·webhook·cainjector 모두 System Node, `CriticalAddonsOnly` Toleration | System Node 격리 정책 |
| CRD | `crds.enabled: true`, `crds.keep: true` | CRD 삭제 시 모든 Certificate가 함께 삭제되므로 유지 |
| `startupapicheck` | `false` | Helm post-install Hook Job. Argo CD에서 Hook 처리가 달라 끈다 |
| caBundle | Webhook·CRD conversion `ignoreDifferences` + `RespectIgnoreDifferences=true` | cainjector가 실행 중 채운다 |
| 적용 | `ServerSideApply=true` | 큰 CRD의 client-side apply 어노테이션 한도 회피 |

## ClusterIssuer

| 이름 | ACME 서버 | 용도 |
| --- | --- | --- |
| `letsencrypt-staging` | staging | 발급 절차 검증. 신뢰되지 않는 인증서, 발급 한도 넉넉 |
| `letsencrypt-prod` | production | 실제 사용 (주간 발급 한도 있음). staging 성공 후 사용 |

- Solver: Route53 DNS-01, `hostedZoneID: Z06877251U6DKTWG3X2JG`, `dnsZones: [lookddak.com]`
- 자격 증명은 IRSA만 쓴다. accessKey·secretAccessKey Secret을 쓰지 않는다
- email은 지정하지 않는다 (ACME 계정에 필수 아님)
- ClusterIssuer는 Cluster 범위 리소스이며 ACME 계정 키 Secret은 `kube-system`에 생긴다

## 반영 후 확인

```bash
kubectl -n argocd get applications lookddak-dev-cert-manager lookddak-dev-cert-manager-issuers
kubectl -n kube-system get pods -l app.kubernetes.io/instance=cert-manager -o wide
kubectl get clusterissuers
```

- 두 Application `Synced/Healthy`, Pod 3개(controller, webhook, cainjector) Running
- ClusterIssuer 2개 `READY=True` (ACME 계정 등록 성공)
- 실제 인증서 발급(Route53 DNS-01)은 Istio Gateway 작업의 Certificate로 검증한다

## 운영

- 인증서 만료 감시: `certmanager_certificate_expiration_timestamp_seconds` 지표로 만료 14일 전 알림 (관측 작업에서 추가)
- 갱신 실패 시 원인 확인: `kubectl describe certificate`, `kubectl get certificaterequests,orders,challenges -A`

## 참고

- [cert-manager Helm 설치](https://cert-manager.io/docs/installation/helm/)
- [ACME DNS-01 Route53](https://cert-manager.io/docs/configuration/acme/dns01/route53/)
- [Let's Encrypt 발급 한도](https://letsencrypt.org/docs/rate-limits/)
