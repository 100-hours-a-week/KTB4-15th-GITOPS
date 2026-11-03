#!/usr/bin/env ruby

require "yaml"

digest_pattern = /\Asha256:[0-9a-f]{64}\z/
sensitive_keys = /\A(password|passwd|token|api[_-]?key|secret[_-]?key|access[_-]?key)\z/i

def load_yaml(file)
  YAML.safe_load(File.read(file), aliases: true)
end

def walk(value, file, sensitive_keys)
  case value
  when Hash
    # ignoreDifferences·targetRef 등의 kind: Secret 참조는 실제 Secret 선언과 구분한다.
    if value["kind"] == "Secret" && (value.key?("apiVersion") || value.key?("metadata"))
      abort "#{file}: kind: Secret 리소스는 Git에 저장할 수 없습니다."
    end

    value.each do |key, child|
      if key.to_s.match?(sensitive_keys) && !child.nil? && child.to_s != ""
        abort "#{file}: Secret 원문으로 의심되는 '#{key}' 값이 있습니다. 외부 Secret 참조를 사용하세요."
      end
      walk(child, file, sensitive_keys)
    end
  when Array
    value.each { |child| walk(child, file, sensitive_keys) }
  end
end

source_files = Dir.glob("**/*.{yaml,yml}", File::FNM_DOTMATCH).reject do |file|
  file.start_with?(".git/") || file.match?(%r{\Acharts/[^/]+/templates/})
end.sort

source_files.each do |file|
  document = load_yaml(file)
  abort "#{file}: kind: Secret 리소스는 Git에 저장할 수 없습니다." if document.is_a?(Hash) && document["kind"] == "Secret"
  walk(document, file, sensitive_keys) unless document.nil?
end

%w[dev prod].each do |environment|
  file = "environments/#{environment}/images.yaml"
  images = load_yaml(file).fetch("images")

  %w[fe be ai crawler].each do |group|
    image = images.fetch(group)
    repository = image.fetch("repository")
    digest = image.fetch("digest")

    if repository.empty? && digest.empty?
      next
    end

    if repository.empty? || digest.empty?
      abort "#{file}: images.#{group}의 repository와 digest는 함께 입력해야 합니다."
    end

    abort "#{file}: images.#{group}.digest가 sha256 형식이 아닙니다." unless digest.match?(digest_pattern)
  end
end

puts "GitOps 정책 검사 완료: Secret 금지, 이미지 repository/digest 짝 및 Digest 형식"
