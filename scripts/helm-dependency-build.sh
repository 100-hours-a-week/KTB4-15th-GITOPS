#!/usr/bin/env bash
set -euo pipefail

for chart in "$@"; do
  for attempt in 1 2 3 4 5; do
    if helm dependency build "$chart"; then
      break
    fi
    if [[ "$attempt" == 5 ]]; then
      echo "Helm 의존성 준비 실패: $chart" >&2
      exit 1
    fi
    sleep $((attempt * 10))
  done
done
