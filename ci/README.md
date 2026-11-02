# GitOps CI 검증 자료

## 목적

`fixtures`는 공통 Helm Chart의 주요 조건 분기가 정상적으로 렌더링되는지 검사하기 위한 CI 전용 values다. 실제 dev 또는 prod 배포에는 사용하지 않는다.

## 검증 대상

- 외부 라우팅을 사용하는 Deployment
- HPA와 PDB를 사용하는 Deployment
- Service 없이 실행되는 Worker와 Secret Mount
- 정기 실행 CronJob
- ResourceQuota와 LimitRange 도메인 정책

Fixture의 이미지 주소, Digest, Port와 Resource 값은 렌더링 검증용이며 실제 서비스 설정을 의미하지 않는다.

현재 Kubernetes Schema 검사에서는 표준 Kubernetes 리소스를 엄격하게 검사한다. `HTTPRoute`, `SecretProviderClass` 등 CRD는 Cilium·Istio·Gateway API·Secrets Store CSI 버전이 확정된 후 해당 버전의 Schema를 고정하여 검사한다.
