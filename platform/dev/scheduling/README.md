# Scheduling — dev

## 목적

클러스터 범위 PriorityClass를 관리한다.

## 구성

| 이름 | 값 | 선점 | 대상 |
|---|---|---|---|
| `lookddak-monitoring-storage` | 100000 | Never | Prometheus·Loki·Tempo (Monitoring Node 메모리 압박 시 수집기보다 늦게 축출) |
