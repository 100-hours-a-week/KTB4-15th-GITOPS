# Cilium — dev

## 목적

EKS dev(`lookddak-dev`)의 Cilium 설정을 관리하는 디렉터리다. Cilium은 ENI 기반 Pod 네트워크, kube-proxy 대체, L3/L4 정책, FQDN Egress 통제와 Hubble 네트워크 관측을 담당한다.

## 현재 상태

- 버전: Cilium `1.20.4` (차트 `cilium/cilium`, `https://helm.cilium.io`), Namespace `kube-system`
- **관리 방식: Bootstrap 전용. Argo CD 관리 대상이 아니다**
  - 네트워크 담당자가 bastion SSM 포트포워딩으로 `helm upgrade --install` 한다
  - EKS API 엔드포인트가 private이므로 VPC 밖(GitHub Actions 등)에서는 설치하지 않는다
  - Terraform(`helm_release`)으로는 관리하지 않는다 (KTB4-15th-CLOUD에서 롤백됨)

## Argo CD로 관리하지 않는 이유

- Argo CD 자체가 CNI 위에서 동작한다. CNI는 Argo CD보다 먼저 있어야 하므로 최초 설치는 어차피 Argo CD 밖에서 한다
- Argo CD가 잘못된 values를 자동 동기화하면 Pod 네트워크가 끊기고 Argo CD도 함께 멈춘다. 이때 복구는 결국 수동 `helm`이다
- 따라서 CNI는 변경 시점을 사람이 통제하는 Bootstrap으로 유지한다
- 저장소 원칙("Argo CD가 관리하는 리소스에 `helm` 직접 실행 금지")은 Argo CD 관리 대상에만 해당한다. Cilium은 대상이 아니므로 예외가 아니다
- 동일 Release 이중 관리 금지: 이 디렉터리에 Argo CD Application을 만들지 않는다

## 변경 절차

1. `values.yaml` 변경 PR → GitOps CI → 리뷰 → `main` Merge
2. 네트워크 담당자가 `main` 기준으로 `helm upgrade` 실행 (아래 "설치·변경")
3. 확인 후 PR에 적용 결과(`helm history` REVISION, Pod 상태) 코멘트

- Git(`main`)과 클러스터가 어긋나지 않도록 **Merge되지 않은 values로 `helm upgrade`하지 않는다**
- 롤백: Revert PR Merge → `helm upgrade` 재실행 (긴급 시 `helm rollback cilium <REVISION>` 후 Revert PR)

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

## 설치·변경

터미널 1 (터널, 켜둔다)
```bash
aws ssm start-session --region ap-northeast-2 --target $(aws ec2 describe-instances --region ap-northeast-2 --filters Name=tag:Name,Values=lookddak-dev-db-access Name=instance-state-name,Values=running --query 'Reservations[0].Instances[0].InstanceId' --output text) --document-name lookddak-dev-api-port-forward --parameters '{"localPortNumber":["8443"]}'
```

터미널 2 — kubeconfig 최초 1회
```bash
aws eks update-kubeconfig --region ap-northeast-2 --name lookddak-dev && kubectl config set-cluster arn:aws:eks:ap-northeast-2:686496667254:cluster/lookddak-dev --server=https://127.0.0.1:8443 --tls-server-name=<EKS API 호스트>
```

터미널 2 — 설치·변경 (이 저장소 루트에서, `main` 기준)
```bash
git checkout main && git pull && helm repo add cilium https://helm.cilium.io && helm repo update cilium && helm upgrade --install cilium cilium/cilium --version 1.20.4 -n kube-system -f platform/dev/networking/cilium/values.yaml && helm history cilium -n kube-system
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
