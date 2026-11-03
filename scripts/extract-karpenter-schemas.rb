#!/usr/bin/env ruby

require "fileutils"
require "json"
require "yaml"

abort "사용법: #{$PROGRAM_NAME} <렌더링된 Karpenter CRD YAML> <Schema 출력 디렉터리>" unless ARGV.length == 2

# 고정한 공식 CRD Chart에서 추출하므로 설치 버전과 검증 Schema가 일치한다.
# Kubernetes의 CEL·Admission 검증과 AWS 참조 검증은 API Server·Controller가 담당한다.
def strict_objects(value)
  case value
  when Hash
    if value["properties"] && !value.key?("additionalProperties") && !value["x-kubernetes-preserve-unknown-fields"]
      value["additionalProperties"] = false
    end
    value.each_value { |child| strict_objects(child) }
  when Array
    value.each { |child| strict_objects(child) }
  end
end

expected = { "NodePool" => "karpenter.sh", "EC2NodeClass" => "karpenter.k8s.aws" }
found = []
YAML.load_stream(File.read(ARGV[0])).compact.each do |crd|
  next unless crd["kind"] == "CustomResourceDefinition"
  kind = crd.dig("spec", "names", "kind")
  next unless expected.key?(kind) && crd.dig("spec", "group") == expected[kind]
  version = crd.dig("spec", "versions").find { |item| item["name"] == "v1" && item["served"] }
  abort "#{kind}: served v1 Schema가 없습니다." unless version
  schema = version.fetch("schema").fetch("openAPIV3Schema")
  strict_objects(schema)
  schema["$schema"] = "http://json-schema.org/draft-07/schema#"
  directory = File.join(ARGV[1], expected.fetch(kind))
  FileUtils.mkdir_p(directory)
  File.write(File.join(directory, "#{kind.downcase}_v1.json"), JSON.pretty_generate(schema))
  found << kind
end
abort "NodePool·EC2NodeClass Schema가 모두 필요합니다." unless found.sort == expected.keys.sort
puts "고정 Karpenter CRD에서 NodePool·EC2NodeClass v1 Schema 추출 완료"
