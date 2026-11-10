# Prod 배포 실패 수동 복구 Runbook

## 목적

Prod Argo CD 배포 실패 알림을 받은 운영자가 Git을 기준 상태로 유지하면서 이전의 검증된 image digest 또는 Manifest로 안전하게 복구한다. Argo CD UI에서 리소스를 직접 수정하거나 `kubectl set image`로 우회하지 않는다.

## 알림을 받으면 먼저 확인할 것

1. Discord 알림의 `Application`, `Sync / Health`, `GitOps Revision`, 오류 메시지를 확인한다.
2. `Argo CD Application` 링크에서 실패 리소스와 이벤트를 확인한다.
3. `GitOps 변경` 링크에서 실패 직전에 반영된 커밋과 변경 파일을 확인한다.
4. `ImagePullBackOff`, `CrashLoopBackOff`, Probe 실패, 권한·Secret·Network 오류 중 어느 유형인지 구분한다.

기존 Pod가 Ready 상태로 남아 있으면 서비스 트래픽은 이전 Pod가 처리할 수 있다. 원인 확인 전 정상 Pod를 강제로 삭제하지 않는다.

## 복구 방법 A — 실패 커밋 전체 Revert

실패 커밋이 한 워크로드의 digest 또는 설정만 바꾼 독립 커밋일 때 사용한다.

```bash
cd /Users/juyeongjin/VsProjects/GitOps/KTB4-15th-GITOPS
git fetch origin main
git switch -c fix/prod-revert-<application>-<revision> origin/main
git revert <실패한-GitOps-커밋-SHA>
git push -u origin fix/prod-revert-<application>-<revision>
gh pr create --base main --title "revert(prod): <application> 배포 복구" --body "실패 revision <SHA>를 이전 상태로 복구합니다."
```

`GitOps CI`가 성공한 뒤 PR을 승인·병합한다. Argo CD Auto Sync가 Revert 커밋을 감지해 이전 Manifest를 다시 적용한다.

## 복구 방법 B — 영향 파일만 이전 digest로 복원

하나의 커밋에 여러 워크로드 변경이 섞여 전체 Revert가 위험할 때 사용한다.

```bash
cd /Users/juyeongjin/VsProjects/GitOps/KTB4-15th-GITOPS
git fetch origin main
git switch -c fix/prod-restore-<image-key>-digest origin/main
git show <실패한-GitOps-커밋-SHA>^:environments/prod/images.yaml > /tmp/images-before-failure.yaml
```

`/tmp/images-before-failure.yaml`에서 영향받은 `image_key`의 이전 digest만 확인해 현재 `environments/prod/images.yaml`에 반영한다. 다른 image key와 repository는 바꾸지 않는다. 이후 커밋·푸시하고 복구 PR을 만든다.

## 복구 완료 기준

- 복구 PR의 `GitOps CI` 성공
- 대상 Application `Synced / Healthy`
- 새 Pod Ready, 실패 Pod 제거
- 핵심 API 또는 화면 Smoke Test 성공
- Discord 성공 알림은 오지 않음
- 장애 원인과 복구 PR을 이슈 또는 장애 기록에 남김

## 금지 사항

- Argo CD UI에서 Live Manifest 직접 수정
- `kubectl set image`, `kubectl edit deployment`로 Git을 우회
- 정상인 이전 Pod 강제 삭제
- 원인 확인 없이 여러 image digest를 한 번에 변경
- 자동 Revert 사용
