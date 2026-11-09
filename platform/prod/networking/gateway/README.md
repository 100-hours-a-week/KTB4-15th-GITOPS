# Istio Gateway — prod

CloudFront 전환 전에 내부 NLB와 Istio Gateway 기반을 먼저 검증한다. TLS는 Gateway에서 종료하고 NLB는 TCP 443을 Pod IP로 전달한다.

- Gateway Pod 2개는 `general-purpose` Application Node에 서로 다른 AZ로 배치한다.
- 초기 NLB 접근은 Prod VPC CIDR(`10.20.0.0/16`)로 제한한다.
- 최종 CloudFront 연결 PR에서 전용 Origin Security Group을 Terraform으로 만들고 이 제한을 SG 기반으로 교체한다.
- 이 단계에서는 DNS와 CloudFront Origin을 변경하지 않는다.

```bash
kubectl -n istio-ingress get gateway,certificate,pods,service -o wide
kubectl -n istio-ingress describe gateway lookddak-gateway
kubectl -n istio-ingress get certificate lookddak-com
kubectl get nodes -L lookddak.io/node-pool,topology.kubernetes.io/zone
```

## 목적

prod의 공용 Istio Gateway와 Gateway API 설정을 GitOps로 관리하기 위한 디렉터리다.

## 확정된 요청 흐름

`CloudFront + WAF → Internal NLB → Istio Gateway → HTTPRoute → Service`

## 미결정 항목

- Gateway와 GatewayClass 이름
- Gateway Namespace와 Listener 이름
- TLS 인증서와 TLS 종료 위치
- NLB Annotation과 Target 설정
- SSE Timeout 값

dev에서 전체 요청 경로를 검증한 후 Gateway 설정을 prod로 승격한다.
