#!/usr/bin/env bash

set -euo pipefail
[[ $# -eq 3 ]] || { echo "사용법: $0 <기준 Commit SHA> <fe|be|ai|crawler> <작업 디렉터리>" >&2; exit 1; }

base_sha="$1"
image_group="$2"
work_dir="$3"
base_checkout="$work_dir/base"
base_output="$work_dir/base-rendered"
head_output="$work_dir/head-rendered"
diff_file="$work_dir/manifest.diff"
summary_file="$work_dir/manifest-summary.md"
mkdir -p "$work_dir"
cleanup() { git worktree remove --force "$base_checkout" >/dev/null 2>&1 || true; }
trap cleanup EXIT

git worktree add --detach "$base_checkout" "$base_sha" >/dev/null
scripts/render-prod-image-workloads.sh "$image_group" "$base_output" "$base_checkout"
scripts/render-prod-image-workloads.sh "$image_group" "$head_output" .
set +e
diff -ruN "$base_output" "$head_output" > "$diff_file"
diff_status=$?
set -e
[[ $diff_status -le 1 ]] || { echo "Prod 이미지 Manifest 비교 중 오류가 발생했습니다." >&2; exit "$diff_status"; }
ruby scripts/summarize-rendered-manifests.rb "$base_output" "$head_output" "$summary_file"
[[ $diff_status -eq 0 ]] && echo "Prod 이미지 Manifest 변경 없음" || { echo "Prod 이미지 Manifest 변경점"; cat "$diff_file"; }
[[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || cat "$summary_file" >> "$GITHUB_STEP_SUMMARY"
