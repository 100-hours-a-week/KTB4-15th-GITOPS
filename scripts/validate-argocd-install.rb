#!/usr/bin/env ruby

require "yaml"

abort "사용법: #{$PROGRAM_NAME} <렌더링된 Argo CD Manifest>" unless ARGV.length == 1
resources = YAML.load_stream(File.read(ARGV[0])).compact
expected_toleration = { "key" => "CriticalAddonsOnly", "operator" => "Equal", "value" => "true", "effect" => "NoSchedule" }
expected_pods = %w[
  argocd-application-controller
  argocd-applicationset-controller
  argocd-redis
  argocd-repo-server
  argocd-server
  argocd-redis-secret-init
]
pod_resources = resources.select { |item| %w[Deployment StatefulSet DaemonSet Job].include?(item["kind"]) }
unless pod_resources.map { |item| item.dig("metadata", "name") }.sort == expected_pods.sort
  abort "Argo CD 전환 중 활성 구성요소·Hook 구성이 변경되었습니다."
end
pod_resources.each do |item|
  name = item.dig("metadata", "name")
  pod = item.dig("spec", "template", "spec")
  unless pod.dig("nodeSelector", "lookddak.io/node-pool") == "system" && (pod["tolerations"] || []).include?(expected_toleration)
    abort "#{name}: System Node 고정과 CriticalAddonsOnly Toleration이 필요합니다."
  end
end

crds = resources.select { |item| item["kind"] == "CustomResourceDefinition" }
expected_crds = %w[applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io]
abort "Argo CD CRD 3개가 필요합니다." unless crds.map { |item| item.dig("metadata", "name") }.sort == expected_crds.sort
crds.each do |item|
  options = item.dig("metadata", "annotations", "argocd.argoproj.io/sync-options").to_s.split(",")
  unless %w[ServerSideApply=true Prune=false Delete=false].all? { |option| options.include?(option) } && item.dig("metadata", "annotations", "helm.sh/resource-policy") == "keep"
    abort "Argo CD CRD에는 Server Side Apply·삭제 방지 설정이 필요합니다."
  end
end
secrets = resources.select { |item| item["kind"] == "Secret" }
unless secrets.length == 1 && secrets.first.dig("metadata", "name") == "argocd-secret"
  abort "기존 argocd-secret 외의 Secret 생성은 이번 전환 범위가 아닙니다."
end
secret = secrets.first
unless (secret["data"] || {}).empty? && (secret["stringData"] || {}).empty?
  abort "Argo CD 런타임 Secret 데이터를 Manifest에 지정하면 안 됩니다."
end
unless secret.dig("metadata", "annotations", "argocd.argoproj.io/sync-options") == "Prune=false,Delete=false"
  abort "Argo CD 런타임 Secret 삭제 방지 설정이 필요합니다."
end
abort "Argo CD 외부 진입·NetworkPolicy는 이번 작업에서 생성하지 않습니다." if resources.any? { |item| %w[Ingress HTTPRoute Gateway NetworkPolicy].include?(item["kind"]) }
puts "Argo CD 설치 검증 완료: 실행 구성요소 5개·Hook 1개 System 배치, CRD 3개·런타임 Secret 보호"
