#!/usr/bin/env ruby

require "minitest/autorun"
require_relative "update-dev-image"
require_relative "validate-dev-image-change"

class DevImageUpdaterTest < Minitest::Test
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
    {
      content: BASE,
      environment: "dev",
      image_key: "fe",
      digest: DIGEST,
      source_repository: "100-hours-a-week/KTB4-15th-FE",
      source_sha: SHA,
      source_run_url: "https://github.com/100-hours-a-week/KTB4-15th-FE/actions/runs/123456"
    }.merge(overrides)
  end

  def assert_validation_error(pattern, **overrides)
    error = assert_raises(DevImageUpdater::ValidationError) do
      DevImageUpdater.update(**valid_input(overrides))
    end
    assert_match pattern, error.message
  end

  def test_updates_exactly_one_digest_and_builds_traceable_metadata
    result = DevImageUpdater.update(**valid_input)

    assert result.changed
    assert_equal "fe", DevImageChangeValidator.validate(BASE, result.content)
    assert_equal "automation/dev-fe-aaaaaaaaaaaa", result.branch
    assert_equal "chore(dev): FE 이미지 digest 갱신", result.title
    assert_includes result.body, "KTB4-15th-FE/actions/runs/123456"
    assert_includes result.body, "web-bff"
  end

  def test_same_digest_is_idempotent_noop
    result = DevImageUpdater.update(**valid_input(digest: "sha256:#{"1" * 64}"))

    refute result.changed
    assert_equal BASE, result.content
  end

  def test_rejects_non_dev_environment
    assert_validation_error(/dev만 허용/, environment: "prod")
  end

  def test_rejects_unknown_image_key
    assert_validation_error(/허용되지 않은 image_key/, image_key: "unknown")
  end

  def test_rejects_repository_image_key_mismatch
    assert_validation_error(/저장소만 갱신/, source_repository: "100-hours-a-week/KTB4-15th-BE")
  end

  def test_rejects_invalid_digest
    assert_validation_error(/sha256 형식/, digest: "latest")
  end

  def test_rejects_short_source_sha
    assert_validation_error(/40자리/, source_sha: "abcdef0")
  end

  def test_rejects_run_url_for_other_repository
    assert_validation_error(
      /Actions 실행 URL/,
      source_run_url: "https://github.com/100-hours-a-week/KTB4-15th-BE/actions/runs/123456"
    )
  end

  def test_supports_all_repository_image_pairs
    DevImageUpdater::SOURCE_REPOSITORIES.each_with_index do |(image_key, repository), index|
      result = DevImageUpdater.update(
        **valid_input(
          image_key: image_key,
          source_repository: repository,
          source_run_url: "https://github.com/#{repository}/actions/runs/#{index + 1}",
          digest: "sha256:#{(index + 10).to_s(16) * 64}"
        )
      )
      assert result.changed
      assert_equal image_key, DevImageChangeValidator.validate(BASE, result.content)
    end
  end
end
