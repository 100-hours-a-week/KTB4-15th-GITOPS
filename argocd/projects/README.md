# Argo CD AppProject

## 목적

Argo CD Application이 사용할 수 있는 Git 저장소와 배포 대상 범위를 환경별로 제한한다.

## 현재 작성된 범위

- dev와 prod가 읽을 수 있는 저장소를 `KTB4-15th-GITOPS`로 제한한다.
- 각 환경은 자신이 실행되는 클러스터의 `lookddak-*` Namespace에만 배포할 수 있다.
- 현재 애플리케이션 Chart에는 Cluster 범위 리소스가 없으므로 Cluster 범위 리소스 생성을 허용하지 않는다.
- Argo CD가 관리하지 않는 리소스가 대상 Namespace에 남으면 경고하도록 설정한다.

플랫폼 구성요소와 Cluster 범위 리소스의 Argo CD 관리 범위는 아직 확정하지 않았으므로 현재 AppProject에 포함하지 않는다.
