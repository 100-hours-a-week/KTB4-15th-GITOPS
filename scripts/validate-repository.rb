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

puts "저장소 구조 검사 완료: 도메인 5개, 환경별 워크로드 10개, Application 이름 #{application_names.length}개"
