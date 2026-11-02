# Observability — prod

## 목적

Alloy Collector와 kube-state-metrics 등 prod Kubernetes 관측 구성요소를 GitOps로 관리하기 위한 디렉터리다.

## 확정된 방향

클러스터 Collector가 Kubernetes Metadata를 이용해 워크로드를 자동 발견하고 Metric·Log·Event를 기존 모니터링 스택으로 전송한다.

운영 Endpoint, 인증정보, Alert 규칙, 보존 기간과 Resource 설정은 아직 정의하지 않았다.
