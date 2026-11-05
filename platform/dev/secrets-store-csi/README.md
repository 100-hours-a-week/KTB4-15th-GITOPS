# Secrets Store CSI — dev

## 목적

EKS dev의 모든 Linux Node에서 AWS Secrets Manager와 SSM Parameter Store의 값을 Pod 파일로 마운트할 수 있도록 공통 기반을 설치한다.

이번 구성은 Secret 전달 통로만 만든다. 실제 Secret 값, Secret 식별자, 워크로드별 IAM Role, `SecretProviderClass`와 시작 스크립트는 후속 PR에서 추가한다.

## 구성

```text
AWS Secrets Manager 또는 SSM Parameter Store
                  │
                  │ 워크로드 ServiceAccount의 IRSA
                  ▼
AWS Secrets and Configuration Provider
                  │
                  ▼
Secrets Store CSI Driver
                  │
                  ▼
Pod의 읽기 전용 임시 파일
```

| 구성요소 | 버전 | 역할 | 배치 방식 |
| --- | --- | --- | --- |
| Secrets Store CSI Driver | `1.6.2` | Kubernetes Volume 요청을 받아 외부 Secret을 Pod 파일로 마운트 | 모든 Linux Node에 DaemonSet 1개 |
| AWS Provider(ASCP) | `3.1.4` | AWS API를 호출해 Secrets Manager·Parameter Store 값을 조회 | 모든 Linux Node에 DaemonSet 1개 |

두 구성요소는 System Node에만 고정하지 않는다. Secret을 사용하는 애플리케이션 Pod가 Karpenter Application Node에 배치될 수 있으므로 해당 Node에도 Driver와 Provider가 필요하다.

`operator: Exists` Toleration을 사용해 System Node의 `CriticalAddonsOnly` Taint와 앞으로 추가될 수 있는 Application Node Taint를 허용한다. `kubernetes.io/os: linux`만 선택하고 아키텍처를 고정하지 않아 ARM64와 AMD64 Node에서 모두 동작하게 한다.

## 디렉터리

```text
platform/dev/secrets-store-csi/
├─ driver/
│  ├─ Chart.yaml
│  ├─ Chart.lock
│  ├─ values.yaml
│  ├─ charts/
│  └─ templates/.gitkeep
├─ provider-aws/
│  ├─ Chart.yaml
│  ├─ Chart.lock
│  ├─ values.yaml
│  ├─ charts/
│  └─ templates/.gitkeep
└─ README.md
```

공식 Chart를 Wrapper Chart의 의존성으로 사용하며, Driver와 Provider의 버전과 패키지 Digest를 `Chart.lock`으로 고정한다.

## 보안 설정

- Secret 원문은 Git에 저장하지 않는다.
- `syncSecret.enabled: false`를 유지해 외부 Secret 값을 Kubernetes Secret과 etcd에 복제하지 않는다.
- `driverWritesSecrets: false`는 ASCP가 마운트 대상 파일을 직접 작성하는 기본 동작을 명시한다. 이 값은 Kubernetes Secret 동기화 여부와는 관계가 없다.
- AWS Provider 컨테이너는 Privileged 권한과 권한 상승을 사용하지 않는다.
- Driver는 `sts.amazonaws.com`과 `pods.eks.amazonaws.com` Audience의 ServiceAccount Token을 요청할 수 있다.
- 실제 AWS 조회 권한은 후속 작업에서 워크로드별 ServiceAccount와 IRSA Role에 최소 권한으로 부여한다.
- Secret 이름과 ARN은 값이 아닌 식별 정보지만, 워크로드 연결 PR에서 필요한 범위만 선언한다.

## Rotation

Driver는 1시간마다 외부 저장소의 변경 여부를 확인해 마운트된 파일을 갱신한다. 이 설정은 Secrets Manager API 호출 비용과 Dev 환경의 갱신 속도를 함께 고려한 초기값이다.

파일이 바뀌어도 이미 실행 중인 프로세스의 환경변수는 자동으로 바뀌지 않는다. 이후 적용할 `CSI 파일 → 공통 시작 스크립트 → 환경변수 기반 애플리케이션` 구조에서는 Secret 회전 후 Pod를 재시작해야 새 값을 환경변수로 읽는다.

## Argo CD 적용 순서

1. `lookddak-dev-secrets-store-csi-driver` Application이 Driver와 CRD·RBAC를 설치한다.
2. `lookddak-dev-secrets-store-csi-provider-aws` Application이 ASCP를 설치한다.
3. 두 Application 모두 `kube-system`에 자동 동기화하며 Drift는 Self Heal한다.

Root Application의 Sync Wave는 Application 선언 순서만 제어하며 앞선 Application의 배포 완료까지 기다리지는 않는다. Provider는 Driver 준비 전 생성되더라도 DaemonSet으로 대기하고, 최종적으로 두 DaemonSet이 모든 Linux Node에서 `Ready`인지 확인한다.

## 배포 후 확인

```bash
kubectl -n kube-system get daemonset \
  secrets-store-csi-driver \
  secrets-store-csi-driver-provider-aws

kubectl -n kube-system get pod -o wide \
  -l app.kubernetes.io/name=secrets-store-csi-driver

kubectl -n kube-system get pod -o wide \
  -l app.kubernetes.io/name=secrets-store-csi-driver-provider-aws

kubectl get csidriver secrets-store.csi.k8s.io
```

완료 기준은 다음과 같다.

- 두 DaemonSet의 `DESIRED`, `CURRENT`, `READY` 수가 각 Linux Node 수와 같다.
- System Node와 Karpenter Application Node마다 Driver Pod와 Provider Pod가 각각 한 개씩 실행된다.
- `CSIDriver/secrets-store.csi.k8s.io`가 존재한다.
- 애플리케이션 Secret 값이 Kubernetes Secret으로 생성되지 않는다.

## 후속 작업

- Parameter Store 값을 Secrets Manager로 이전할 범위와 이름 규칙 확정
- 워크로드별 최소 권한 IAM Role과 IRSA 구성
- 워크로드별 `SecretProviderClass`, 마운트 경로와 파일 이름 정의
- CSI 파일을 기존 환경변수로 변환하는 공통 시작 스크립트 추가
- 테스트 Pod로 Parameter Store와 Secrets Manager 파일 마운트 검증
