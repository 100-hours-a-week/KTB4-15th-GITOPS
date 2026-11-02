# KEDA — dev

## 목적

dev의 KEDA Controller와 클러스터 공통 KEDA 설정을 GitOps로 관리하기 위한 디렉터리다.

## 확정된 방향

KEDA를 Event 기반 확장과 dev 비용 최적화에 활용한다.

## 미결정 항목

- KEDA 버전과 설치 values
- Scale-to-Zero 적용 워크로드
- 일정, Time Zone, Trigger와 최소 Replica
- 워크로드별 ScaledObject 관리 위치

위 조건이 합의되기 전에는 ScaledObject를 생성하지 않는다.
