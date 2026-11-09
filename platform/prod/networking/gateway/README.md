# Istio Gateway — prod

CloudFront VPC Origin과 내부 NLB를 통해 Istio Gateway에 진입한다. TLS는 Gateway에서 종료하고 NLB는 TCP 443을 Pod IP로 전달한다.

- Gateway Pod 2개는 `general-purpose` Application Node에 서로 다른 AZ로 배치한다.
- NLB 접근은 Cloud Terraform이 만든 전용 Security Group(`sg-0993a57cec9f3b5f5`)으로 제한한다.
- 전용 Security Group은 AWS 관리 CloudFront Origin Prefix List의 TCP 443만 허용한다.
- NLB에서 Gateway Pod로 가는 Backend Security Group Rule은 AWS Load Balancer Controller가 관리한다.
- DNS·CloudFront VPC Origin·WAF는 Cloud 저장소가, Gateway·HTTPRoute는 GitOps 저장소가 관리한다.

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

## 소유권 경계

- Cloud: Route 53, ACM Viewer 인증서, CloudFront, WAF, VPC Origin, NLB 전용 Security Group
- GitOps: Gateway Listener, NLB Annotation, Kubernetes TLS 인증서, HTTPRoute, Service
- AWS Load Balancer Controller: Internal NLB, Target Group, Backend Security Group Rule
