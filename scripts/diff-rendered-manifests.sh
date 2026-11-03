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
summary_file="$work_dir/manifest-summary.md"

mkdir -p "$work_dir"

cleanup() {
  git worktree remove --force "$base_checkout" >/dev/null 2>&1 || true
}
trap cleanup EXIT

copy_static_manifests() {
  local source_root="$1"
  local output_root="$2"
  local manifest
  local relative_path
  local target

  [[ -d "$source_root/argocd" ]] || return 0

  while IFS= read -r -d '' manifest; do
    relative_path="${manifest#"$source_root"/}"
    target="$output_root/gitops-static/$relative_path"
    mkdir -p "$(dirname "$target")"
    cp "$manifest" "$target"
  done < <(find "$source_root/argocd" -type f -name '*.yaml' -print0)
}

git worktree add --detach "$base_checkout" "$base_sha" >/dev/null

(
  cd "$base_checkout"
  scripts/render-fixtures.sh "$base_output"
)

scripts/render-fixtures.sh "$head_output"

copy_static_manifests "$base_checkout" "$base_output"
copy_static_manifests "." "$head_output"

set +e
diff -ruN "$base_output" "$head_output" > "$diff_file"
diff_status=$?
set -e

if [[ $diff_status -gt 1 ]]; then
  echo "Helm Manifest 비교 중 오류가 발생했습니다." >&2
  exit "$diff_status"
fi

ruby scripts/summarize-rendered-manifests.rb \
  "$base_output" \
  "$head_output" \
  "$summary_file"

if [[ $diff_status -eq 0 ]]; then
  echo "Helm Manifest 변경 없음"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "$summary_file" >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 0
fi

echo "Helm Manifest 변경점"
cat "$diff_file"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "$summary_file" >> "$GITHUB_STEP_SUMMARY"
fi

exit 0
