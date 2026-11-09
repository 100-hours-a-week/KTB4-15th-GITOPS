# Secrets Store CSI — prod

모든 Linux Node에 CSI Driver와 AWS Provider(ASCP)를 DaemonSet으로 배치한다. 이후 워크로드는 IRSA로 SSM Parameter Store·Secrets Manager 값을 Pod 파일로 마운트한다.

- Kubernetes Secret 복제는 사용하지 않는다.
- 마운트 파일은 1시간마다 갱신한다.
- System Node Taint와 향후 Application Node Taint를 모두 허용한다.

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=secrets-store-csi-driver -o wide
kubectl -n kube-system get pods -l app.kubernetes.io/name=secrets-store-csi-driver-provider-aws -o wide
kubectl get csidriver secrets-store.csi.k8s.io
```

## 목적

EKS prod에서 사용할 Secrets Store CSI Driver와 AWS Secrets and Configuration Provider를 GitOps로 관리하기 위한 디렉터리다.

## 확정된 방향

- AWS Secrets Manager를 Secret 값의 단일 원본으로 사용한다.
- 각 워크로드는 IRSA를 통해 필요한 Secret에만 접근한다.
- Secret 원문을 Git에 저장하지 않고 Pod에 Mount한다.

운영 Driver 버전, Rotation 설정, IAM Role ARN, Secret 식별자와 Mount 경로는 아직 정의하지 않았다.
