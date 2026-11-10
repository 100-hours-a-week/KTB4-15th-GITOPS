#!/usr/bin/env ruby

require "minitest/autorun"
require_relative "update-prod-image"
require_relative "validate-prod-image-change"

class ProdImageUpdaterTest < Minitest::Test
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
  SHA = "a" * 40
  DIGEST = "sha256:#{"b" * 64}"

  def valid_input(overrides = {})
    { content: BASE, environment: "prod", image_key: "fe", digest: DIGEST,
      source_repository: "100-hours-a-week/KTB4-15th-FE", source_sha: SHA,
      source_run_url: "https://github.com/100-hours-a-week/KTB4-15th-FE/actions/runs/123456" }.merge(overrides)
  end

  def assert_validation_error(pattern, **overrides)
    error = assert_raises(ProdImageUpdater::ValidationError) { ProdImageUpdater.update(**valid_input(overrides)) }
    assert_match pattern, error.message
  end

  def test_updates_one_digest_and_builds_traceable_metadata
    result = ProdImageUpdater.update(**valid_input)
    assert result.changed
    assert_equal "fe", ProdImageChangeValidator.validate(BASE, result.content)
    assert_equal "automation/prod-fe-aaaaaaaaaaaa", result.branch
    assert_equal "chore(prod): FE 이미지 digest 승격", result.title
    assert_includes result.body, "원본 `main` Commit"
    assert_includes result.body, "web-bff"
  end

  def test_same_digest_is_idempotent_noop
    result = ProdImageUpdater.update(**valid_input(digest: "sha256:#{"1" * 64}"))
    refute result.changed
    assert_equal BASE, result.content
  end

  def test_rejects_non_prod_environment
    assert_validation_error(/prod만 허용/, environment: "dev")
  end

  def test_rejects_repository_image_key_mismatch
    assert_validation_error(/저장소만 승격/, source_repository: "100-hours-a-week/KTB4-15th-BE")
  end

  def test_rejects_invalid_digest_sha_and_run_url
    assert_validation_error(/sha256 형식/, digest: "latest")
    assert_validation_error(/40자리/, source_sha: "abcdef")
    assert_validation_error(/Actions 실행 URL/, source_run_url: "https://github.com/100-hours-a-week/KTB4-15th-BE/actions/runs/1")
  end

  def test_supports_all_repository_image_pairs
    ProdImageUpdater::SOURCE_REPOSITORIES.each_with_index do |(image_key, repository), index|
      result = ProdImageUpdater.update(**valid_input(
        image_key: image_key, source_repository: repository,
        source_run_url: "https://github.com/#{repository}/actions/runs/#{index + 1}",
        digest: "sha256:#{(index + 10).to_s(16) * 64}"
      ))
      assert result.changed
      assert_equal image_key, ProdImageChangeValidator.validate(BASE, result.content)
    end
  end
end
