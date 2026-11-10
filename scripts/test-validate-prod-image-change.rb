#!/usr/bin/env ruby

require "minitest/autorun"
require_relative "validate-prod-image-change"

class ProdImageChangeValidatorTest < Minitest::Test
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
    group_index = lines.index("  #{group}:\n")
    digest_index = (group_index...lines.length).find { |index| lines[index].start_with?("    digest:") }
    lines[digest_index] = "    digest: #{value}\n"
    lines.join
  end

  def assert_validation_error(pattern, &block)
    error = assert_raises(ProdImageChangeValidator::ValidationError, &block)
    assert_match pattern, error.message
  end

  def test_accepts_exactly_one_digest_change
    assert_equal "be", ProdImageChangeValidator.validate(BASE, replace_digest("be", "sha256:#{"a" * 64}"))
  end

  def test_rejects_repository_two_digest_invalid_and_line_addition
    assert_validation_error(/Digest 줄의 값만/) { ProdImageChangeValidator.validate(BASE, BASE.sub("example.com/fe", "example.com/other")) }
    two = replace_digest("fe", "sha256:#{"a" * 64}")
    two = replace_digest("ai", "sha256:#{"b" * 64}", two)
    assert_validation_error(/정확히 하나/) { ProdImageChangeValidator.validate(BASE, two) }
    assert_validation_error(/Digest 줄의 값만/) { ProdImageChangeValidator.validate(BASE, replace_digest("crawler", "latest")) }
    assert_validation_error(/Digest 한 줄/) { ProdImageChangeValidator.validate(BASE, BASE.sub("images:\n", "images:\n  # unexpected\n")) }
  end

  def test_classifies_prod_image_only_and_rejects_mixed_change
    assert ProdImageChangeValidator.classify_files([ProdImageChangeValidator::FILE])[:image_only]
    refute ProdImageChangeValidator.classify_files(["README.md"])[:image_only]
    assert_validation_error(/다른 파일과 함께/) do
      ProdImageChangeValidator.classify_files([ProdImageChangeValidator::FILE, "README.md"])
    end
  end
end
