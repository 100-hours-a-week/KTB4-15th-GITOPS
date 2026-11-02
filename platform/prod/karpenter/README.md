# Karpenter — prod

## 목적

prod의 Karpenter 설치 values와 NodePool·EC2NodeClass 같은 Kubernetes 리소스를 GitOps로 관리하기 위한 디렉터리다.

## 확정된 방향

- 필수 Controller는 소규모 Managed Node Group에서 실행한다.
- Pending Pod가 발생하면 Karpenter가 Application Node를 공급한다.
- On-Demand 용량을 사용하고 워크로드를 여러 가용 영역에 분산한다.

## 관리 경계 결정 필요

IAM Role, Instance Profile, Interruption Queue 같은 AWS 리소스는 Terraform이 관리한다. Karpenter Controller의 설치 주체를 합의한 후 NodePool과 EC2NodeClass는 GitOps로 관리할 수 있다. 같은 리소스를 두 시스템에서 동시에 관리하지 않는다.

dev 부하 테스트 후 운영 용량 상한과 Disruption 설정을 승격한다.
