# Observability — dev

## 목적

V3 dev 클러스터 안 모니터링 구성(Prometheus·Loki·Tempo)을 관리한다. 설계: `k8s-design/18-Monitoring.md`

## 구성

| 구성 | Chart | 저장 | 비고 |
|---|---|---|---|
| Prometheus | `prometheus` 29.45.1 | gp3 30Gi, 보존 7일 | remote write 수신. 기본 수집 비활성 (수집은 Alloy) |
| Loki | `loki` 7.5.0 (SingleBinary) | S3 `lookddak-dev-v3-loki-*`, gp3 10Gi | 보존 7일, IRSA `lookddak-dev-v3-loki` |
| Tempo | `tempo` 3.2.1 (grafana-community) | S3 `lookddak-dev-v3-tempo-*`, gp3 10Gi | 보존 7일, OTLP 수신, service-graphs → Prometheus, IRSA `lookddak-dev-v3-tempo` |

- 배치: Monitoring Node(`lookddak.io/node-pool: monitoring`, Taint `dedicated=monitoring:NoSchedule`)
- Namespace `monitoring`: Ambient 미등록
- S3 버킷·IRSA: CLOUD `infra/environments/dev/v3/monitoring`

## 주소

| 구성 | Service |
|---|---|
| Prometheus | `http://prometheus-server.monitoring.svc.cluster.local` (remote write `/api/v1/write`) |
| Loki | `http://loki.monitoring.svc.cluster.local:3100` (push `/loki/api/v1/push`) |
| Tempo | `http://tempo.monitoring.svc.cluster.local:3200`, OTLP `:4317`·`:4318` |
