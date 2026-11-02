# Cilium — dev

## 목적

EKS dev의 Cilium 설정을 GitOps로 관리하기 위한 디렉터리다. Cilium은 ENI 기반 Pod 네트워크, L3/L4 정책, FQDN Egress 통제와 Hubble 네트워크 관측을 담당한다.

## 현재 상태

네트워크 담당자가 초기 클러스터 네트워크를 구축하고 있다. 아직 이 디렉터리에서 Helm values나 정책 Manifest를 관리하지 않는다.

## 설정 추가 전 확인사항

- Cilium 최초 설치를 Terraform·Bootstrap에서 계속 관리할지, 클러스터 준비 후 Argo CD로 이전할지 결정한다.
- Cilium 버전과 ENI Mode 설정을 확정한다.
- Istio Ambient와의 호환 설정을 확인한다.
- 기본 차단 정책 적용 전에 Ambient Health Probe 예외 정책을 정의한다.
- 동일한 Helm Release를 Terraform과 Argo CD에서 동시에 관리하지 않는다.
