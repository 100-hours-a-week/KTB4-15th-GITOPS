# Cilium — dev

## 목적

EKS dev(`lookddak-dev`)의 Cilium 설정을 관리하는 디렉터리다. Cilium은 ENI 기반 Pod 네트워크, kube-proxy 대체, L3/L4 정책, FQDN Egress 통제와 Hubble 네트워크 관측을 담당한다.

## 현재 상태

- 버전: Cilium `1.20.4` (차트 `cilium/cilium`, `https://helm.cilium.io`), Namespace `kube-system`
- 설치 주체: 네트워크 담당자가 bastion SSM 포트포워딩으로 `helm upgrade --install` (Bootstrap)
  - EKS API 엔드포인트가 private이므로 VPC 밖(GitHub Actions 등)에서는 설치하지 않는다
  - Terraform(`helm_release`)으로는 관리하지 않는다 (KTB4-15th-CLOUD에서 롤백됨)
- Argo CD 이전: Argo CD 설치 후 플랫폼용 AppProject(`kube-system`, Cluster 범위 리소스 허용)를 만들고 이 `values.yaml`을 그대로 쓰는 Application으로 이전한다
  - 이전 후에는 수동 `helm upgrade`를 하지 않는다 (동일 Release 이중 관리 금지)

## 주요 설정 (`values.yaml`)

| 항목 | 값 | 이유 |
| --- | --- | --- |
| IPAM | `ipam.mode=eni`, `routingMode=native` | Pod가 VPC IP를 직접 받는다. 캡슐화 없음 |
| Pod 서브넷 | `eni.subnetTagsFilter=Tier=private-pod` | 보조 CIDR `100.65.0.0/16`의 Pod 전용 서브넷 2a/2c |
| eth0 제외 | `eni.nodeSpec.firstInterfaceIndex=1` | 노드 서브넷 IP를 Pod에 쓰지 않는다 |
| Prefix Delegation | `eni.awsEnablePrefixDelegation=true` | `/28` 단위 할당으로 노드당 Pod 수 확보 (차트 기본값 false) |
| IP 반납 | `eni.awsReleaseExcessIPs=true` | 남는 IP·Prefix 반납 |
| Operator 권한 | `eni.iamRole` = `lookddak-dev-cilium-operator` | IRSA (`kube-system/cilium-operator`) |
| kube-proxy | `kubeProxyReplacement=true`, `k8sServiceHost` = EKS API 호스트 | 클러스터에 kube-proxy가 없다 |
| Istio Ambient 공존 | `cni.exclusive=false`, `socketLB.hostNamespaceOnly=true` | istio-cni 체이닝, ztunnel 리다이렉션 충돌 방지 |
| Hubble | 수집만, Relay·UI 끔 | 관측 단계에서 켠다 |

## 설치·변경 (Argo CD 이전 전)

터미널 1 (터널, 켜둔다) — KTB4-15th-CLOUD에서
```bash
aws ssm start-session --region ap-northeast-2 --target $(cd infra/environments && terraform output -raw dev_v2_db_access_instance_id) --document-name lookddak-dev-api-port-forward --parameters '{"localPortNumber":["8443"]}'
```

터미널 2 — kubeconfig 최초 1회
```bash
aws eks update-kubeconfig --region ap-northeast-2 --name lookddak-dev && kubectl config set-cluster arn:aws:eks:ap-northeast-2:686496667254:cluster/lookddak-dev --server=https://127.0.0.1:8443 --tls-server-name=<EKS API 호스트>
```

터미널 2 — 설치·변경 (이 저장소 루트에서)
```bash
helm repo add cilium https://helm.cilium.io && helm repo update cilium && helm upgrade --install cilium cilium/cilium --version 1.20.4 -n kube-system -f platform/dev/networking/cilium/values.yaml
```

## 확인

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/part-of=cilium -o wide
```

- 노드가 없으면 `cilium-operator`는 Pending이 정상이다 (system Node Group 생성 후 Running)
- 노드가 붙으면 `cilium` DaemonSet이 뜨고 노드의 `node.cilium.io/agent-not-ready` taint가 지워진다

## 남은 작업

- system Node Group 생성 후 동작 확인: 노드 Ready, Pod IP(100.65.x.x), Prefix 할당, `cilium connectivity test`
- 기본 차단 정책 적용 전에 Ambient Health Probe(`169.254.7.127/32`), HBONE(15008) 예외 정책 정의
- Hubble Relay·UI
- Argo CD 이전
