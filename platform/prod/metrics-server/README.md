# Metrics Server — prod

Kubernetes API에서 Pod·Node CPU와 메모리 사용량을 제공한다. System Node에 2개 Replica를 배치하고 서로 다른 Node를 선호한다.

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=metrics-server -o wide
kubectl top nodes
kubectl top pods -A
```
