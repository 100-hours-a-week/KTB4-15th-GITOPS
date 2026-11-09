#!/usr/bin/env bash
set -euo pipefail

locked_charts_present() {
  ruby -ryaml -e '
    chart = ARGV[0]
    lock = YAML.safe_load(File.read(File.join(chart, "Chart.lock")))
    ok = (lock["dependencies"] || []).all? { |d| File.file?(File.join(chart, "charts", "#{d["name"]}-#{d["version"]}.tgz")) }
    exit(ok ? 0 : 1)
  ' "$1"
}

for chart in "$@"; do
  if [[ -f "$chart/Chart.lock" ]] && locked_charts_present "$chart"; then
    echo "Helm 의존성 캐시 사용: $chart"
    continue
  fi
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
