#!/usr/bin/env ruby

require "digest"
require "fileutils"
require "yaml"

abort "사용법: #{$PROGRAM_NAME} <기준 Manifest 디렉터리> <변경 Manifest 디렉터리> <요약 파일>" unless ARGV.length == 3

base_dir, head_dir, output_file = ARGV

def load_manifests(directory)
  resources = {}
  files = {}

  Dir.glob(File.join(directory, "**", "*.{yaml,yml}")).sort.each do |file|
    relative_path = file.delete_prefix("#{directory}/")
    content = File.read(file)
    files[relative_path] = Digest::SHA256.hexdigest(content)

    YAML.load_stream(content).compact.each do |document|
      next unless document.is_a?(Hash)

      kind = document["kind"]
      name = document.dig("metadata", "name")
      next if kind.nil? || name.nil?

      api_version = document["apiVersion"] || "-"
      namespace = document.dig("metadata", "namespace") || "cluster"
      key = [api_version, kind, namespace, name]
      resources[key] = { document: document, file: relative_path }
    end
  end

  [resources, files]
end

def resource_label(key)
  api_version, kind, namespace, name = key
  "`#{kind}/#{name}` (`#{namespace}`, `#{api_version}`)"
end

def prioritized(keys)
  priorities = {
    "Namespace" => 0,
    "Deployment" => 1,
    "StatefulSet" => 2,
    "DaemonSet" => 3,
    "Service" => 4,
    "HTTPRoute" => 5,
    "Ingress" => 6,
    "CronJob" => 7,
    "HorizontalPodAutoscaler" => 8,
    "Application" => 9,
    "ApplicationSet" => 10,
    "AppProject" => 11,
    "ConfigMap" => 12
  }

  keys.sort_by { |key| [priorities.fetch(key[1], 100), key[1], key[2], key[3]] }
end

base_resources, base_files = load_manifests(base_dir)
head_resources, head_files = load_manifests(head_dir)

base_keys = base_resources.keys
head_keys = head_resources.keys
added = head_keys - base_keys
removed = base_keys - head_keys
changed = (base_keys & head_keys).select do |key|
  base_resources[key][:document] != head_resources[key][:document]
end

all_files = (base_files.keys | head_files.keys).sort
changed_files = all_files.select { |file| base_files[file] != head_files[file] }

status_sets = {
  "추가" => added,
  "변경" => changed,
  "삭제" => removed
}

kinds = status_sets.values.reduce([], :+).map { |key| key[1] }.uniq.sort

lines = []
lines << "### Manifest 변경 요약"
lines << ""
lines << "| 구분 | 개수 |"
lines << "| --- | ---: |"
lines << "| 추가 | #{added.length} |"
lines << "| 변경 | #{changed.length} |"
lines << "| 삭제 | #{removed.length} |"
lines << "| 영향받은 렌더링 파일 | #{changed_files.length} |"

unless kinds.empty?
  lines << ""
  lines << "### 리소스 종류별 변경"
  lines << ""
  lines << "| Kind | 추가 | 변경 | 삭제 |"
  lines << "| --- | ---: | ---: | ---: |"
  kinds.each do |kind|
    counts = status_sets.values.map { |keys| keys.count { |key| key[1] == kind } }
    lines << "| `#{kind}` | #{counts[0]} | #{counts[1]} | #{counts[2]} |"
  end
end

unless changed_files.empty?
  lines << ""
  lines << "### 영향받은 렌더링 파일"
  lines << ""
  changed_files.first(10).each { |file| lines << "- `#{file}`" }
  lines << "- 그 외 #{changed_files.length - 10}개" if changed_files.length > 10
end

status_sets.each do |status, keys|
  next if keys.empty?

  limit = 15
  ordered = prioritized(keys)
  lines << ""
  lines << "### #{status}된 주요 리소스"
  lines << ""
  ordered.first(limit).each { |key| lines << "- #{resource_label(key)}" }
  lines << "- 그 외 #{ordered.length - limit}개" if ordered.length > limit
end

if added.empty? && changed.empty? && removed.empty?
  lines << ""
  lines << "렌더링된 Kubernetes 리소스 변경이 없습니다."
end

FileUtils.mkdir_p(File.dirname(output_file))
File.write(output_file, "#{lines.join("\n")}\n")

