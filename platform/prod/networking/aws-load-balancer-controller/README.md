# AWS Load Balancer Controller — prod

Istio Gateway가 생성하는 `Service(type: LoadBalancer)`를 내부 NLB로 변환한다. Gateway API 자체는 Istio가 담당하며 Controller의 Gateway API 기능은 비활성화한다.

- Cluster: `lookddak-prod`
- VPC: `vpc-00846a80381ac4f45`
- IRSA: `lookddak-prod-aws-load-balancer-controller`
- Target type: Pod IP

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller -o wide
kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=100
```
