# Observability — dev

## 목적

V3 dev 클러스터 안 모니터링 구성(Prometheus·Loki·Tempo, 수집기 Alloy·kube-state-metrics)을 관리한다. 설계: `k8s-design/18-Monitoring.md`

## 구성

| 구성 | Chart | 저장 | 비고 |
|---|---|---|---|
| Prometheus | `prometheus` 29.45.1 | gp3 30Gi, 보존 7일 | remote write 수신. 기본 수집 비활성 (수집은 Alloy) |
| Loki | `loki` 7.5.0 (SingleBinary) | S3 `lookddak-dev-v3-loki-*`, gp3 10Gi | 보존 7일, IRSA `lookddak-dev-v3-loki` |
| Alloy Node | `alloy` 1.15.0 (DaemonSet, 모든 노드, hostNetwork, 메시 밖) | — | 자기 노드 Pod 로그(CRI·multiline)·kubelet/containerd journal → Loki, 노드(unix)·kubelet·cAdvisor·KSM → Prometheus |
| Alloy Cluster | `alloy` 1.15.0 (Deployment 1, Monitoring Node, **Pod 단위 Ambient 등록**) | — | 앱(8080 `/actuator/prometheus`, 8000 `/metrics`)·istiod·ztunnel·Gateway·waypoint·플랫폼(kube-system·argocd `metrics` 포트)·kube-apiserver → Prometheus, Events → Loki, OTLP 4317·4318 → 20% 샘플링 → Tempo |
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
| 노드 로그 | `cluster`, `source=journal`, `node`, `unit`, `level` |
| 메트릭 | `cluster` (Alloy external_labels), 노드 지표 `node`·`node_pool` |
