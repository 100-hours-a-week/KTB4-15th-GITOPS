#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "사용법: $0 <기준 Commit SHA> <작업 디렉터리>" >&2
  exit 1
fi

base_sha="$1"
work_dir="$2"
base_checkout="$work_dir/base"
base_output="$work_dir/base-rendered"
head_output="$work_dir/head-rendered"
diff_file="$work_dir/manifest.diff"

mkdir -p "$work_dir"

cleanup() {
  git worktree remove --force "$base_checkout" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git worktree add --detach "$base_checkout" "$base_sha" >/dev/null

(
  cd "$base_checkout"
  scripts/render-fixtures.sh "$base_output"
)

scripts/render-fixtures.sh "$head_output"

set +e
diff -ruN "$base_output" "$head_output" > "$diff_file"
diff_status=$?
set -e

if [[ $diff_status -gt 1 ]]; then
  echo "Helm Manifest 비교 중 오류가 발생했습니다." >&2
  exit "$diff_status"
fi

if [[ $diff_status -eq 0 ]]; then
  echo "Helm Manifest 변경 없음"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Helm Manifest 변경점"
      echo
      echo "렌더링된 Manifest 변경이 없습니다."
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 0
fi

echo "Helm Manifest 변경점"
cat "$diff_file"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Helm Manifest 변경점"
    echo
    echo "기준 Commit: \`$base_sha\`"
    echo
    echo '```diff'
    head -c 60000 "$diff_file"
    echo
    echo '```'
    if [[ $(wc -c < "$diff_file") -gt 60000 ]]; then
      echo
      echo "> 변경 내용이 길어 앞부분 60KB만 표시했습니다. 전체 내용은 Workflow 로그에서 확인할 수 있습니다."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit 0
