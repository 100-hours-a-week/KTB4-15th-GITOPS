#!/usr/bin/env ruby

require "open3"
require "yaml"

class ProdImageChangeValidator
  FILE = "environments/prod/images.yaml"
  GROUPS = %w[fe be ai crawler].freeze
  DIGEST_PATTERN = /\Asha256:[0-9a-f]{64}\z/
  DIGEST_LINE_PATTERN = /\A(\s+)digest:\s+(sha256:[0-9a-f]{64})\s*\z/
  class ValidationError < StandardError; end

  def self.classify_files(changed_files)
    files = changed_files.reject(&:empty?).uniq.sort
    return { image_only: false } unless files.include?(FILE)
    raise ValidationError, "#{FILE} 변경은 다른 파일과 함께 제출할 수 없습니다: #{files.join(', ')}" unless files == [FILE]

    { image_only: true }
  end

  def self.validate(base_content, head_content)
    base_lines = base_content.lines(chomp: true)
    head_lines = head_content.lines(chomp: true)
    raise ValidationError, "#{FILE}에서는 Digest 한 줄 교체만 허용합니다." unless base_lines.length == head_lines.length

    indexes = base_lines.each_index.select { |index| base_lines[index] != head_lines[index] }
    raise ValidationError, "#{FILE}에서는 정확히 하나의 Digest만 변경해야 합니다." unless indexes.length == 1

    base_match = DIGEST_LINE_PATTERN.match(base_lines[indexes.first])
    head_match = DIGEST_LINE_PATTERN.match(head_lines[indexes.first])
    unless base_match && head_match && base_match[1] == head_match[1]
      raise ValidationError, "#{FILE}에서는 기존 Digest 줄의 값만 변경할 수 있습니다."
    end

    base_images = load_images(base_content, "기준")
    head_images = load_images(head_content, "변경")
    GROUPS.each do |group|
      raise ValidationError, "images.#{group}.repository는 변경할 수 없습니다." if base_images[group]["repository"] != head_images[group]["repository"]
    end
    changed_groups = GROUPS.select { |group| base_images[group]["digest"] != head_images[group]["digest"] }
    raise ValidationError, "정확히 하나의 이미지 Digest만 변경해야 합니다." unless changed_groups.length == 1

    group = changed_groups.first
    unless base_match[2] == base_images[group]["digest"] && head_match[2] == head_images[group]["digest"]
      raise ValidationError, "변경된 YAML 값과 Digest 줄이 일치하지 않습니다."
    end
    group
  end

  def self.load_images(content, label)
    document = YAML.safe_load(content, aliases: false)
    unless document.is_a?(Hash) && document.keys == ["images"] && document["images"].is_a?(Hash)
      raise ValidationError, "#{label} #{FILE}의 최상위 구조는 images 하나여야 합니다."
    end
    images = document["images"]
    raise ValidationError, "#{label} #{FILE}의 이미지 키가 허용 목록과 다릅니다." unless images.keys == GROUPS
    GROUPS.each do |group|
      image = images[group]
      unless image.is_a?(Hash) && image.keys.sort == %w[digest repository]
        raise ValidationError, "images.#{group}에는 repository와 digest만 허용합니다."
      end
      raise ValidationError, "images.#{group}.repository가 비어 있습니다." unless image["repository"].is_a?(String) && !image["repository"].empty?
      raise ValidationError, "images.#{group}.digest가 sha256 형식이 아닙니다." unless DIGEST_PATTERN.match?(image["digest"])
    end
    images
  rescue Psych::SyntaxError => error
    raise ValidationError, "#{label} #{FILE} YAML 파싱 실패: #{error.message}"
  end
end

if $PROGRAM_NAME == __FILE__
  abort "사용법: #{$PROGRAM_NAME} <기준 Commit SHA>" unless ARGV.length == 1
  base_sha = ARGV.first
  changed_files, error, status = Open3.capture3("git", "diff", "--name-only", "#{base_sha}...HEAD")
  abort "변경 파일 조회 실패: #{error}" unless status.success?

  begin
    classification = ProdImageChangeValidator.classify_files(changed_files.lines(chomp: true))
    output_file = ENV["GITHUB_OUTPUT"]
    unless classification[:image_only]
      File.open(output_file, "a") { |file| file.puts "image_only=false" } if output_file
      puts "일반 GitOps PR: 전체 검증을 실행합니다."
      exit 0
    end
    base_content, show_error, show_status = Open3.capture3("git", "show", "#{base_sha}:#{ProdImageChangeValidator::FILE}")
    abort "기준 images.yaml 조회 실패: #{show_error}" unless show_status.success?
    image_group = ProdImageChangeValidator.validate(base_content, File.read(ProdImageChangeValidator::FILE))
    if output_file
      File.open(output_file, "a") do |file|
        file.puts "image_only=true"
        file.puts "image_environment=prod"
        file.puts "image_group=#{image_group}"
      end
    end
    puts "Prod 이미지 전용 PR 검증 완료: images.#{image_group}.digest 한 줄 변경"
  rescue ProdImageChangeValidator::ValidationError => error
    abort "Prod 이미지 승격 PR 검증 실패: #{error.message}"
  end
end
