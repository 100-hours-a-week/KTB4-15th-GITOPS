#!/usr/bin/env ruby

require "open3"
require "yaml"

class DevImageChangeValidator
  FILE = "environments/dev/images.yaml"
  GROUPS = %w[fe be ai crawler].freeze
  DIGEST_PATTERN = /\Asha256:[0-9a-f]{64}\z/
  DIGEST_LINE_PATTERN = /\A(\s+)digest:\s+(sha256:[0-9a-f]{64})\s*\z/

  class ValidationError < StandardError; end

  def self.classify_files(changed_files)
    files = changed_files.reject(&:empty?).uniq.sort
    return { image_only: false } unless files.include?(FILE)

    unless files == [FILE]
      raise ValidationError, "#{FILE} 변경은 다른 파일과 함께 제출할 수 없습니다: #{files.join(', ')}"
    end

    { image_only: true }
  end

  def self.validate(base_content, head_content)
    base_lines = base_content.lines(chomp: true)
    head_lines = head_content.lines(chomp: true)

    unless base_lines.length == head_lines.length
      raise ValidationError, "#{FILE}에서는 Digest 한 줄 교체만 허용합니다. 줄 추가·삭제는 허용하지 않습니다."
    end

    changed_line_indexes = base_lines.each_index.select { |index| base_lines[index] != head_lines[index] }
    unless changed_line_indexes.length == 1
      raise ValidationError, "#{FILE}에서는 정확히 하나의 Digest만 변경해야 합니다. 변경된 줄=#{changed_line_indexes.length}"
    end

    line_index = changed_line_indexes.first
    base_line_match = DIGEST_LINE_PATTERN.match(base_lines[line_index])
    head_line_match = DIGEST_LINE_PATTERN.match(head_lines[line_index])
    unless base_line_match && head_line_match && base_line_match[1] == head_line_match[1]
      raise ValidationError, "#{FILE}에서는 기존 Digest 줄의 값만 변경할 수 있습니다."
    end

    base_images = load_images(base_content, "기준")
    head_images = load_images(head_content, "변경")

    GROUPS.each do |group|
      if base_images.fetch(group).fetch("repository") != head_images.fetch(group).fetch("repository")
        raise ValidationError, "images.#{group}.repository는 변경할 수 없습니다."
      end
    end

    changed_groups = GROUPS.select do |group|
      base_images.fetch(group).fetch("digest") != head_images.fetch(group).fetch("digest")
    end
    unless changed_groups.length == 1
      raise ValidationError, "정확히 하나의 이미지 Digest만 변경해야 합니다. 변경된 그룹=#{changed_groups.join(', ')}"
    end

    group = changed_groups.first
    old_digest = base_images.fetch(group).fetch("digest")
    new_digest = head_images.fetch(group).fetch("digest")
    unless base_line_match[2] == old_digest && head_line_match[2] == new_digest
      raise ValidationError, "변경된 YAML 값과 Digest 줄이 일치하지 않습니다."
    end

    group
  end

  def self.load_images(content, label)
    document = YAML.safe_load(content, aliases: false)
    unless document.is_a?(Hash) && document.keys == ["images"] && document["images"].is_a?(Hash)
      raise ValidationError, "#{label} #{FILE}의 최상위 구조는 images 하나여야 합니다."
    end

    images = document.fetch("images")
    unless images.keys == GROUPS
      raise ValidationError, "#{label} #{FILE}의 이미지 키가 허용 목록과 다릅니다. 예상=#{GROUPS.join(', ')}, 실제=#{images.keys.join(', ')}"
    end

    GROUPS.each do |group|
      image = images[group]
      unless image.is_a?(Hash) && image.keys.sort == %w[digest repository]
        raise ValidationError, "images.#{group}에는 repository와 digest만 허용합니다."
      end

      repository = image["repository"]
      digest = image["digest"]
      raise ValidationError, "images.#{group}.repository가 비어 있습니다." unless repository.is_a?(String) && !repository.empty?
      unless digest.is_a?(String) && DIGEST_PATTERN.match?(digest)
        raise ValidationError, "images.#{group}.digest가 sha256 형식이 아닙니다."
      end
    end

    images
  rescue Psych::SyntaxError => error
    raise ValidationError, "#{label} #{FILE} YAML 파싱 실패: #{error.message}"
  end
end

if $PROGRAM_NAME == __FILE__
  abort "사용법: #{$PROGRAM_NAME} <기준 Commit SHA>" unless ARGV.length == 1

  base_sha = ARGV.first
  diff_range = "#{base_sha}...HEAD"
  changed_files_output, error_output, status = Open3.capture3("git", "diff", "--name-only", diff_range)
  abort "변경 파일 조회 실패: #{error_output}" unless status.success?

  begin
    classification = DevImageChangeValidator.classify_files(changed_files_output.lines(chomp: true))
    output_file = ENV["GITHUB_OUTPUT"]

    unless classification[:image_only]
      File.open(output_file, "a") { |file| file.puts "image_only=false" } if output_file
      puts "일반 GitOps PR: 전체 검증을 실행합니다."
      exit 0
    end

    base_content, show_error, show_status = Open3.capture3("git", "show", "#{base_sha}:#{DevImageChangeValidator::FILE}")
    abort "기준 images.yaml 조회 실패: #{show_error}" unless show_status.success?

    image_group = DevImageChangeValidator.validate(base_content, File.read(DevImageChangeValidator::FILE))
    if output_file
      File.open(output_file, "a") do |file|
        file.puts "image_only=true"
        file.puts "image_environment=dev"
        file.puts "image_group=#{image_group}"
      end
    end
    puts "Dev 이미지 전용 PR 검증 완료: images.#{image_group}.digest 한 줄 변경"
  rescue DevImageChangeValidator::ValidationError => error
    abort "Dev 이미지 갱신 PR 검증 실패: #{error.message}"
  end
end
