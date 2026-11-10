# Observability — dev

## 목적

V3 dev 클러스터 안 모니터링 구성(Prometheus·Loki·Tempo, 수집기 Alloy·kube-state-metrics)을 관리한다. 설계: `k8s-design/18-Monitoring.md`

## 구성

| 구성 | Chart | 저장 | 비고 |
|---|---|---|---|
| Prometheus | `prometheus` 29.45.1 | gp3 30Gi, 보존 7일 | remote write 수신. 기본 수집 비활성 (수집은 Alloy) |
| Loki | `loki` 7.5.0 (SingleBinary) | S3 `lookddak-dev-v3-loki-*`, gp3 10Gi | 보존 7일, IRSA `lookddak-dev-v3-loki` |
| Alloy Node | `alloy` 1.15.0 (DaemonSet, 모든 노드, hostNetwork, 메시 밖) | — | 자기 노드 Pod 로그(CRI·multiline)·kubelet/containerd journal → Loki, 노드(unix)·kubelet·cAdvisor·KSM·Cilium agent·operator·Hubble → Prometheus |
| Alloy Cluster | `alloy` 1.15.0 (Deployment 1, Monitoring Node, **Pod 단위 Ambient 등록**) | — | 앱(8080 `/actuator/prometheus`, 8000 `/metrics`)·istiod·ztunnel·Gateway·waypoint·플랫폼(kube-system·argocd `metrics` 포트)·kube-apiserver·Redis 6노드(`prometheus.exporter.redis`)·RDS MySQL/PostgreSQL(내장 exporter, 비밀번호는 Secrets Store CSI)·RDS CloudWatch(9개 지표) → Prometheus, Events → Loki, OTLP 4317·4318 → probe·메트릭 수집 구간 제외 → 전량(100%) → Tempo |
| Grafana | `grafana` 14.4.0 (grafana-community) | gp3 5Gi | 데이터소스 Prometheus·Loki·Tempo(uid 고정, 로그↔트레이스 연결), `LookDDak` 폴더 대시보드 5개(`files/dashboards`, 생성 스크립트 `work/k8s-setting/55-grafana/generate-dashboards.py`). 관리자 계정·로그인 폼 없음, 임시로 익명 Viewer + port-forward (Gateway 인증 후 `auth.proxy`) |
| db-log-tailer | 평문 매니페스트, ECR `lookddak-dev-v3-db-log-tailer` digest 고정 (Deployment 1, Ambient 등록, Monitoring Node) | gp3 1Gi (읽은 위치) | RDS API(`DescribeDBLogFiles`·`DownloadDBLogFilePortion`, IRSA)로 dev MySQL 감사·error·slowquery, PostgreSQL 로그 → Alloy Cluster `:3500` → Loki. 소스: CLOUD `scripts/monitoring/db-log-tailer` |
| kube-state-metrics | `kube-state-metrics` 9.0.0 | — | 노드 라벨(NodePool·인스턴스 타입·Zone) 포함. Monitoring Node의 Alloy Node가 수집 |
| Tempo | `tempo` 3.2.1 (grafana-community) | S3 `lookddak-dev-v3-tempo-*`, gp3 10Gi | 보존 7일, OTLP 수신, service-graphs → Prometheus, IRSA `lookddak-dev-v3-tempo` |

- 저장소(Prometheus·Loki·Tempo) PriorityClass `lookddak-monitoring-storage` (`platform/dev/scheduling`)
- 배치(Alloy Node 제외): Monitoring Node(`lookddak.io/node-pool: monitoring`, Taint `dedicated=monitoring:NoSchedule`)
- Namespace `monitoring`: Ambient 미등록
- S3 버킷·IRSA: CLOUD `infra/environments/dev/v3/monitoring`

## 주소

| 구성 | Service |
|---|---|
| Prometheus | `http://prometheus-server.monitoring.svc.cluster.local` (remote write `/api/v1/write`) |
| Loki | `http://loki.monitoring.svc.cluster.local:3100` (push `/loki/api/v1/push`) |
| Tempo | `http://tempo.monitoring.svc.cluster.local:3200`, OTLP `:4317`·`:4318` |

## 라벨

| 신호 | 라벨 |
|---|---|
| Pod 로그 | `cluster`, `namespace`, `workload`(`app.kubernetes.io/name`, 없으면 controller 이름), `container`, `source=pod` / structured metadata `pod` |
| Events | `cluster`, `source=event` |
| RDS 로그 | `cluster`, 쿼리 `source=db-query`, 오류·슬로우 `source=rds`·`log_group=/aws/rds/instance/<id>/...` (V2와 같은 라벨) |
| 노드 로그 | `cluster`, `source=journal`, `node`, `unit`, `level` |
| 메트릭 | `cluster` (Alloy external_labels), 노드 지표 `node`·`node_pool` |

## DB 지표 (Alloy Cluster)

| 대상 | 방식 | 계정·권한 |
|---|---|---|
| Redis `redis-cache` 6노드 | `prometheus.exporter.redis` × 6 (headless FQDN 고정) | 비밀번호 없음. Cilium `redis-network-policy.yaml` 15008, Istio `allow-alloy-cluster-metrics` 6379 |
| MySQL `lookddak-dev-v2-mysql` | `prometheus.exporter.mysql`, `tls=true`(RDS CA, `SSL_CERT_DIR`) | `lookddak_v3_exporter`@`100.65.%` (CLOUD Runbook `lookddak-dev-v3-mysql-exporter-bootstrap`, 비밀번호 SSM `/lookddak/dev/v3/monitoring/mysql-exporter/password`) |
| PostgreSQL `lookddak-dev-postgresql` | `prometheus.exporter.postgres`, `sslmode=verify-full` | V2와 같은 `exporter`(`pg_monitor`), SSM `/lookddak/dev/monitoring/postgres-exporter/password` |
| RDS·SQS CloudWatch | `prometheus.exporter.cloudwatch`: RDS 2대 9개 지표(static), SQS `Environment=dev` 태그 검색(V2·V3 큐·DLQ, 이름으로 구분). CloudWatch 조회는 5분마다(`decoupled_scraping`), scrape는 1분마다 캐시 | IRSA `lookddak-dev-v3-alloy-cluster` (`cloudwatch:GetMetricData`·`ListMetrics`, `tag:GetResources`, 위 SSM 2개 읽기) |
- 비밀번호는 `SecretProviderClass alloy-cluster-db-exporters` → `/etc/db-exporters` 파일 (K8s Secret 미생성)
- RDS CA: `files/ap-northeast-2-bundle.pem` → ConfigMap `alloy-cluster-rds-ca` → `/etc/rds-ca`

## 접속

- `https://grafana.v3-dev.lookddak.com` → CloudFront → Istio Gateway → oauth2-proxy(ext_authz) → Cognito 로그인(V2 Grafana 사용자 풀) → Grafana `auth.proxy`(`X-Auth-Request-Email`)
- 처음 로그인한 사용자는 Editor로 자동 생성. 관리자 계정·로그인 폼·익명 접속 없음
- 사용자 추가는 Cognito 사용자 풀(`lookddak-dev-grafana`)에서 관리자가 만든다 (셀프 가입 없음)
- 로그아웃: Grafana → `/oauth2/sign_out` → Cognito logout → 첫 화면
- 클러스터 안 확인용: `kubectl -n monitoring port-forward svc/grafana 3000:80`는 헤더가 없어 로그인되지 않는다 (port-forward는 Gateway를 거치지 않음)

## job 이름

| job | 수집기 |
|---|---|
| `node`, `kubelet`, `cadvisor`, `kube-state-metrics`, `cilium-agent`, `hubble`, `cilium-operator` | Alloy Node |
| `app`, `istiod`, `mesh-proxy`, `platform`, `apiserver`, `redis`, `mysql`, `postgres`, `cloudwatch`, `db-log-tailer` | Alloy Cluster |

## 트레이스 (앱 자동 계측)

- `charts/lookddak-workload` `tracing`: `otel-init` initContainer가 OpenTelemetry Operator 자동 계측 이미지(arm64 digest 고정, V2와 같은 버전)에서 에이전트를 emptyDir `/otel`로 복사
- `runtime`별 적재: `java` `JDK_JAVA_OPTIONS=-javaagent:/otel/javaagent.jar`(OTLP gRPC 4317), `nodejs` `NODE_OPTIONS=--require /otel/autoinstrumentation.js`(OTLP HTTP 4318), `python` `PYTHONPATH`(sitecustomize, OTLP HTTP 4318)
- `OTEL_SERVICE_NAME` = 워크로드 이름, 리소스 속성 `k8s.namespace.name`·`k8s.pod.name`·`k8s.node.name`
- 대상: Spring 5개(java), FastAPI 3개(python), web-bff(nodejs). price-crawler(CronJob)는 제외
- 네트워크: `platform/dev/networking/policies/domain-otlp-export.yaml` 도메인 Pod → alloy-cluster HBONE 15008

