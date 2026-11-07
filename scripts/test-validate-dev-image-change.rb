#!/usr/bin/env ruby

require "minitest/autorun"
require_relative "validate-dev-image-change"

class DevImageChangeValidatorTest < Minitest::Test
  BASE = <<~YAML
    images:
      fe:
        repository: example.com/fe
        digest: sha256:#{"1" * 64}
      be:
        repository: example.com/be
        digest: sha256:#{"2" * 64}
      ai:
        repository: example.com/ai
        digest: sha256:#{"3" * 64}
      crawler:
        repository: example.com/crawler
        digest: sha256:#{"4" * 64}
  YAML

  def replace_digest(group, value, content = BASE)
    lines = content.lines
    group_index = lines.index { |line| line == "  #{group}:\n" }
    digest_index = (group_index...lines.length).find { |index| lines[index].start_with?("    digest:") }
    lines[digest_index] = "    digest: #{value}\n"
    lines.join
  end

  def assert_validation_error(pattern = nil, &block)
    error = assert_raises(DevImageChangeValidator::ValidationError, &block)
    assert_match(pattern, error.message) if pattern
  end

  def test_accepts_exactly_one_digest_change
    head = replace_digest("be", "sha256:#{"a" * 64}")
    assert_equal "be", DevImageChangeValidator.validate(BASE, head)
  end

  def test_rejects_repository_change
    head = BASE.sub("example.com/fe", "example.com/other")
    assert_validation_error(/Digest 줄의 값만/) { DevImageChangeValidator.validate(BASE, head) }
  end

  def test_rejects_two_digest_changes
    head = replace_digest("fe", "sha256:#{"a" * 64}")
    head = replace_digest("ai", "sha256:#{"b" * 64}", head)
    assert_validation_error(/정확히 하나의 Digest/) { DevImageChangeValidator.validate(BASE, head) }
  end

  def test_rejects_invalid_digest
    head = replace_digest("crawler", "latest")
    assert_validation_error(/Digest 줄의 값만/) { DevImageChangeValidator.validate(BASE, head) }
  end

  def test_rejects_unknown_image_group
    head = BASE.sub("  crawler:\n", "  unknown:\n")
    assert_validation_error(/Digest 줄의 값만/) { DevImageChangeValidator.validate(BASE, head) }
  end

  def test_rejects_line_addition
    head = BASE.sub("images:\n", "images:\n  # unexpected\n")
    assert_validation_error(/줄 추가·삭제/) { DevImageChangeValidator.validate(BASE, head) }
  end

  def test_classifies_unrelated_change_as_full_validation
    result = DevImageChangeValidator.classify_files(["charts/lookddak-workload/values.yaml"])
    refute result[:image_only]
  end

  def test_classifies_images_only_change
    result = DevImageChangeValidator.classify_files([DevImageChangeValidator::FILE])
    assert result[:image_only]
  end

  def test_rejects_images_change_with_other_file
    files = [DevImageChangeValidator::FILE, "README.md"]
    assert_validation_error(/다른 파일과 함께/) { DevImageChangeValidator.classify_files(files) }
  end
end
