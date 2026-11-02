# KEDA — prod

## 목적

향후 prod의 KEDA Controller와 클러스터 공통 설정을 관리하기 위한 디렉터리다.

## 현재 상태

운영 Scale-to-Zero와 Event 기반 확장 정책은 아직 승인되지 않았다. 별도의 가용성 검토 없이 dev 일정이나 ScaledObject를 prod에 복사하지 않는다.
