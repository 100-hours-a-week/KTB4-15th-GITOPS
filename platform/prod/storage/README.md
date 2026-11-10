# Storage — prod

## 목적

EBS CSI Driver(EKS 애드온)로 만드는 블록 볼륨의 StorageClass를 관리한다.

## 구성

| 이름 | 설정 |
|---|---|
| `gp3` (기본) | `ebs.csi.aws.com`, gp3, 암호화(aws/ebs), ext4, `WaitForFirstConsumer`, `Delete`, 확장 허용 |

- `WaitForFirstConsumer`: Pod가 배치된 노드의 AZ에 볼륨을 만든다
- `Delete`: PVC를 지우면 볼륨도 지운다
