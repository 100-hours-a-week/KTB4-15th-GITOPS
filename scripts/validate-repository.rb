#!/usr/bin/env ruby

require "yaml"

def load_yaml(file)
  YAML.safe_load(File.read(file), aliases: true)
end

domains = {
  "web" => ["web-bff"],
  "identity" => ["body-image-validator", "identity-api"],
  "commerce" => ["commerce-api", "price-crawler"],
  "chat" => ["chat-ai", "chat-api"],
  "fitting" => ["fitting-api", "fitting-worker", "vton-orchestrator"]
}.freeze

environments = %w[dev prod].freeze
application_names = []
gitops_repository = "https://github.com/100-hours-a-week/KTB4-15th-GITOPS.git"
in_cluster_server = "https://kubernetes.default.svc"
dev_namespaces = %w[
  lookddak-web
  lookddak-identity
  lookddak-commerce
  lookddak-chat
  lookddak-fitting
].freeze

argocd_files = %w[
  platform/dev/argocd/Chart.yaml
  platform/dev/argocd/Chart.lock
  platform/dev/argocd/values.yaml
  platform/dev/argocd/README.md
].freeze

argocd_files.each do |file|
  abort "필수 파일 누락: #{file}" unless File.file?(file)
end

environments.each do |environment|
  images_file = "environments/#{environment}/images.yaml"
  abort "필수 파일 누락: #{images_file}" unless File.file?(images_file)

  actual_domains = Dir["environments/#{environment}/domains/*"]
    .select { |path| File.directory?(path) }
    .map { |path| File.basename(path) }
    .sort

  unless actual_domains == domains.keys.sort
    abort "#{environment}: 도메인 구성이 설계와 다릅니다. 예상=#{domains.keys.sort}, 실제=#{actual_domains}"
  end

  domains.each do |domain, expected_workloads|
    domain_file = "environments/#{environment}/domains/#{domain}/domain.yaml"
    abort "필수 파일 누락: #{domain_file}" unless File.file?(domain_file)

    application_names << "#{environment}-#{domain}-domain"

    pattern = "environments/#{environment}/domains/#{domain}/workloads/*.yaml"
    workload_files = Dir[pattern].sort
    actual_workloads = workload_files.map { |file| File.basename(file, ".yaml") }

    unless actual_workloads == expected_workloads.sort
      abort "#{environment}/#{domain}: 워크로드 구성이 설계와 다릅니다. 예상=#{expected_workloads.sort}, 실제=#{actual_workloads}"
    end

    workload_files.each do |file|
      values = load_yaml(file)
      workload = values.fetch("workload")
      name = workload.fetch("name")
      type = workload.fetch("type")
      basename = File.basename(file, ".yaml")

      abort "#{file}: workload.name과 파일명이 다릅니다." unless name == basename
      abort "#{file}: 지원하지 않는 workload.type '#{type}'입니다." unless %w[deployment cronjob].include?(type)
      abort "#{file}: 지원하지 않는 imageGroup입니다." unless %w[fe be ai crawler].include?(values.fetch("imageGroup"))

      application_names << "#{environment}-#{name}"
    end
  end
end

duplicates = application_names.group_by(&:itself).select { |_, names| names.length > 1 }.keys
abort "중복 Application 이름: #{duplicates.join(', ')}" unless duplicates.empty?

expected_sets = {
  "argocd/dev/domain-applicationset.yaml" => "environments/dev/domains/*/domain.yaml",
  "argocd/dev/workload-applicationset.yaml" => "environments/dev/domains/*/workloads/*.yaml",
  "argocd/prod/domain-applicationset.yaml" => "environments/prod/domains/*/domain.yaml",
  "argocd/prod/workload-applicationset.yaml" => "environments/prod/domains/*/workloads/*.yaml"
}.freeze

expected_sets.each do |file, expected_path|
  abort "필수 파일 누락: #{file}" unless File.file?(file)
  manifest = load_yaml(file)
  actual_path = manifest.dig("spec", "generators", 0, "git", "files", 0, "path")
  abort "#{file}: Git generator 경로가 예상과 다릅니다." unless actual_path == expected_path
end

dev_project_file = "argocd/projects/lookddak-dev.yaml"
dev_project = load_yaml(dev_project_file)
abort "#{dev_project_file}: kind가 AppProject가 아닙니다." unless dev_project["kind"] == "AppProject"
abort "#{dev_project_file}: 허용 Repository가 예상과 다릅니다." unless dev_project.dig("spec", "sourceRepos") == [gitops_repository]

dev_destination = dev_project.dig("spec", "destinations", 0)
unless dev_destination == { "server" => in_cluster_server, "namespace" => "lookddak-*" }
  abort "#{dev_project_file}: dev 배포 대상 Cluster 또는 Namespace 범위가 예상과 다릅니다."
end

unless dev_project.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-2"
  abort "#{dev_project_file}: Root 동기화 전에 적용할 sync-wave -2가 필요합니다."
end

root_file = "argocd/dev/root-application.yaml"
abort "필수 파일 누락: #{root_file}" unless File.file?(root_file)
root = load_yaml(root_file)
abort "#{root_file}: kind가 Application이 아닙니다." unless root["kind"] == "Application"
abort "#{root_file}: Application 이름이 예상과 다릅니다." unless root.dig("metadata", "name") == "lookddak-dev-root"
abort "#{root_file}: Application은 argocd Namespace에 있어야 합니다." unless root.dig("metadata", "namespace") == "argocd"
abort "#{root_file}: Root Application은 default Project에서 부트스트랩해야 합니다." unless root.dig("spec", "project") == "default"

root_sources = root.dig("spec", "sources") || []
expected_root_sources = {
  "argocd/projects" => "lookddak-dev.yaml",
  "argocd/dev" => nil
}

actual_root_sources = root_sources.to_h do |source|
  abort "#{root_file}: Root source는 Public GitOps Repository만 사용할 수 있습니다." unless source["repoURL"] == gitops_repository
  abort "#{root_file}: Root source는 main 브랜치를 추적해야 합니다." unless source["targetRevision"] == "main"
  [source["path"], source.dig("directory", "include")]
end

abort "#{root_file}: Root 관리 경로가 예상과 다릅니다." unless actual_root_sources == expected_root_sources

unless root.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "argocd" }
  abort "#{root_file}: Root 배포 대상은 현재 Cluster의 argocd Namespace여야 합니다."
end

root_automation = root.dig("spec", "syncPolicy", "automated") || {}
expected_root_automation = {
  "enabled" => true,
  "prune" => true,
  "selfHeal" => true,
  "allowEmpty" => false
}
abort "#{root_file}: Root Auto Sync 안전 정책이 예상과 다릅니다." unless root_automation == expected_root_automation

dev_namespace_files = Dir["argocd/dev/namespace-*.yaml"].sort
actual_dev_namespaces = dev_namespace_files.map do |file|
  manifest = load_yaml(file)
  abort "#{file}: kind가 Namespace가 아닙니다." unless manifest["kind"] == "Namespace"
  abort "#{file}: Namespace 자동 삭제 방지를 위해 Prune=false가 필요합니다." unless manifest.dig("metadata", "annotations", "argocd.argoproj.io/sync-options") == "Prune=false"
  abort "#{file}: ApplicationSet보다 먼저 적용할 sync-wave -1이 필요합니다." unless manifest.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-1"
  manifest.dig("metadata", "name")
end.sort

unless actual_dev_namespaces == dev_namespaces.sort
  abort "dev Namespace 구성이 설계와 다릅니다. 예상=#{dev_namespaces.sort}, 실제=#{actual_dev_namespaces}"
end

dev_domain_set = load_yaml("argocd/dev/domain-applicationset.yaml")
dev_workload_set = load_yaml("argocd/dev/workload-applicationset.yaml")

[dev_domain_set, dev_workload_set].each do |application_set|
  unless application_set.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "0"
    abort "#{application_set.dig('metadata', 'name')}: Namespace 이후에 적용할 sync-wave 0이 필요합니다."
  end
end

unless dev_domain_set.dig("spec", "template", "spec", "project") == "lookddak-dev" &&
       dev_workload_set.dig("spec", "template", "spec", "project") == "lookddak-dev"
  abort "dev ApplicationSet은 lookddak-dev AppProject를 사용해야 합니다."
end

unless dev_workload_set.dig("spec", "template", "spec", "syncPolicy", "automated", "enabled") == false
  abort "실배포 값 확정 전에는 dev Workload Auto Sync가 비활성화되어야 합니다."
end

puts "저장소 구조 검사 완료: Argo CD 설치·Root 설정, dev Namespace 5개, 도메인 5개, 환경별 워크로드 10개, Application 이름 #{application_names.length}개"
