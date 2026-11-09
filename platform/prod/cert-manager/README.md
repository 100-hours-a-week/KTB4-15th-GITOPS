# cert-manager — prod

Route 53 DNS-01 방식으로 `lookddak.com` 인증서를 발급한다. AWS 키를 Secret에 저장하지 않고 `kube-system/cert-manager` ServiceAccount의 Prod IRSA를 사용한다.

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/instance=cert-manager -o wide
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```
