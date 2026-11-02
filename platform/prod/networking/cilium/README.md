# Cilium — prod

## 목적

EKS prod의 Cilium 설정을 GitOps로 관리하기 위한 디렉터리다. Cilium은 ENI 기반 Pod 네트워크, L3/L4 정책, FQDN Egress 통제와 Hubble 네트워크 관측을 담당한다.

## 현재 상태

운영 Cilium Helm values와 정책 Manifest는 아직 정의하지 않았다.

## 설정 추가 전 확인사항

- dev에서 검증한 Cilium 버전과 설정만 prod로 승격한다.
- Istio Ambient와의 호환 설정을 확인한다.
- 기본 차단 정책 적용 전에 Ambient Health Probe 예외 정책을 정의한다.
- CNI 변경의 Rollback 절차를 준비한다.
- 동일한 Helm Release를 Terraform과 Argo CD에서 동시에 관리하지 않는다.
