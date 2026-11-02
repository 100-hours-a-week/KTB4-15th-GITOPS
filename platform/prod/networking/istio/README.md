# Istio Ambient — prod

## 목적

prod의 Istio Control Plane, ztunnel, Ambient Mesh 등록과 Mesh 공통 정책을 GitOps로 관리하기 위한 디렉터리다.

## 확정된 방향

- Cilium과 Istio Ambient Mesh를 함께 사용한다.
- istiod를 Control Plane으로 사용하고 ztunnel로 Node 단위 mTLS를 제공한다.
- L7 정책이 필요한 대상에만 Waypoint Proxy를 추가한다.

## 미결정 항목

- 운영 Istio 버전과 Helm values
- Namespace의 Ambient 등록 순서
- Waypoint 적용 대상
- AuthorizationPolicy, Timeout, Circuit Breaker 세부 설정

dev에서 검증한 설정만 prod로 승격한다.
