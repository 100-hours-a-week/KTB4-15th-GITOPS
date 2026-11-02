# Secrets Store CSI — dev

## 목적

EKS dev에서 사용할 Secrets Store CSI Driver와 AWS Secrets and Configuration Provider를 GitOps로 관리하기 위한 디렉터리다.

## 확정된 방향

- AWS Secrets Manager를 Secret 값의 단일 원본으로 사용한다.
- 각 워크로드는 IRSA를 통해 필요한 Secret에만 접근한다.
- Secret 원문을 Git에 저장하지 않고 Pod에 Mount한다.

Driver 버전, Rotation 설정, IAM Role ARN, Secret 식별자와 Mount 경로는 아직 정의하지 않았다.
