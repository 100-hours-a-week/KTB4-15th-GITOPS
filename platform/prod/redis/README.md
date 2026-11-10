# Redis Cluster — prod

설계: `work/k8s-design/11-Redis.md` §4-5·4-6, `18-Redis-Operator.md`

| 항목 | 값 |
|---|---|
| 구성 | Redis Cluster `redis-cache` 마스터 3 · 레플리카 3, Redis v7.2.17 (BSD) |
| 영속화·PV | 없음 (`appendonly no`, `save ""`, emptyDir). 복구는 레플리카 승격 + Operator 재합류 |
| 메모리 | Pod requests = limit 450Mi, `maxmemory 350mb`, `volatile-lru` |
| 인증 | 비밀번호 없음 (prod). Cilium + mTLS STRICT + Istio 인가로 통제 |
| 노드 | Redis 전용 NodePool `lookddak.io/node-pool=redis`, taint `lookddak.io/dedicated=redis:NoSchedule` (NodePool은 Karpenter 작업에서 추가) |
| 클라이언트 | `lookddak-chat/chat-api`만 6379 허용 |
| Operator | OT-CONTAINER-KIT `redis-operator` 0.27.0, 감시 범위 `lookddak-redis`, RBAC Namespace 범위 |
| 노드 주소 알림 | headless FQDN (`redis-cache-leader-0.redis-cache-leader-headless.lookddak-redis.svc.cluster.local`). Operator feature gate `GenerateConfigInInitContainer` |

## 디렉터리와 Application

| 경로 | Application | wave | 비고 |
|---|---|---|---|
| `crds/crds.yaml` | `lookddak-prod-redis-crds` | -1 | 차트 `crds/` 그대로. **prune 끔**, ServerSideApply |
| `operator/` | `lookddak-prod-redis-operator` | 0 | Helm, `skipCrds: true` |
| `cluster/` | `lookddak-prod-redis-cluster` | 1 | RedisCluster, 추가 설정 ConfigMap, Istio 인가. **prune 끔** |
| `../networking/policies/redis-network-policy.yaml` | `lookddak-prod-network-policies` | 3 | Cilium 기본 차단·허용 |

- CRD와 RedisCluster는 prune을 끈다: Git에서 파일이 빠지거나 Application이 바뀌어도 Redis가 삭제되지 않는다. 삭제는 PR + 수동 확인으로만 한다
- Operator 차트를 올릴 때는 `crds/crds.yaml`도 같은 버전으로 교체한다 (`helm pull ot-helm/redis-operator --version <버전> --untar` → `crds/crds.yaml` 복사)

## 네트워크·인가

| 구간 | Cilium | Istio 인가 |
|---|---|---|
| Redis 노드 간 (복제·cluster bus) | 같은 NS 15008 | 같은 NS → 6379, 16379 |
| Operator → Redis | 같은 NS 15008 | 같은 NS → 6379 |
| Operator → Kubernetes API | `kube-apiserver` 443 | — (메시 밖 목적지) |
| chat-api → Redis | chat-api egress + Redis ingress 15008 | `lookddak-chat/sa/chat-api` → 6379 |
| kubelet probe | `169.254.7.127/32` | — (ztunnel 우회) |

## chat-api 연결

`chat-api`는 다음 환경변수로 Redis Cluster에 연결한다.

```yaml
SPRING_PROFILES_ACTIVE: prod,chat-api
REDIS_CLUSTER_NODES: redis-cache-master.lookddak-redis.svc.cluster.local:6379
CHAT_REDIS_ENABLED: "true"
```

- Redis Cluster 설정(`spring.data.redis.cluster.nodes: ${REDIS_CLUSTER_NODES}`, Lettuce refresh)은 BE `application-chat-api.yaml`에만 있다. `chat-api` profile을 켠 workload만 Cluster 모드로 접속한다
- 같은 BE 이미지를 쓰는 commerce-api·fitting-api·fitting-worker·identity-api는 `prod`만 사용하고 Redis env를 받지 않는다. CI가 검사한다

- prod Redis는 비밀번호 인증을 사용하지 않으므로 `REDIS_PASSWORD`를 주입하지 않는다
- `redis-cache-master`는 3개 leader로 연결되는 seed Service다. BE `application-chat-api.yaml`의 `spring.data.redis.cluster.nodes`가 이 값을 읽어 Cluster 모드로 접속하고, Lettuce가 `MOVED`·토폴로지 갱신(adaptive)을 처리한다
- 단일 주소 env(`REDIS_HOST`·`REDIS_PORT`)는 쓰지 않는다 (Standalone 접속 → `MOVED` 실패). CI가 금지한다
- Redis는 채팅 Snapshot/Pub/Sub의 복구 계층이며 장애 시 local/DB fallback을 사용하므로 `MANAGEMENT_HEALTH_REDIS_ENABLED=false`를 유지한다
- BE `develop`에 `application-chat-api.yaml`이 병합되기 전에는 없는 profile로 무시되어 기존 동작과 같다

## 노드 주소 알림 (hostname)

- Redis 7 Cluster는 `CLUSTER NODES`에 노드 IP와 함께 `cluster-announce-hostname`을 알리고, Lettuce는 hostname이 있으면 그 이름으로 접속한다
- 이미지 기본 `entrypoint.sh`는 짧은 Pod 이름(`redis-cache-leader-0`)을 넣는다. 이 이름은 DNS 레코드가 없어(`<pod>.<headless>.<ns>.svc.cluster.local`만 존재) chat-api에서 `Failed to resolve`로 접속 실패했다 (2026-11-09)
- entrypoint는 ConfigMap `include` 뒤에 hostname을 써서 ConfigMap으로 덮어쓸 수 없다 → Operator feature gate `GenerateConfigInInitContainer: true`로 init container가 FQDN을 넣게 한다
- 확인: 아래 명령 결과 6줄 모두 `...lookddak-redis.svc.cluster.local`로 끝나야 한다

```bash
kubectl -n lookddak-redis exec redis-cache-leader-0 -- redis-cli cluster nodes | awk '{print $2}'
```

## 확인 (Merge 후)

```bash
kubectl -n argocd get applications lookddak-prod-redis-crds lookddak-prod-redis-operator lookddak-prod-redis-cluster
kubectl get crd | grep opstreelabs
kubectl -n lookddak-redis get pod,rediscluster -o wide
```

- Redis 전용 NodePool이 없으면 Redis Pod는 Pending이 정상이다
- 검증 시나리오: `work/k8s-design/18-Redis-Operator.md` §4
