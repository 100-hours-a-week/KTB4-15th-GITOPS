#!/usr/bin/env ruby

require "yaml"

class DevImageUpdater
  FILE = "environments/dev/images.yaml"
  ENVIRONMENT = "dev"
  DIGEST_PATTERN = /\Asha256:[0-9a-f]{64}\z/
  SHA_PATTERN = /\A[0-9a-f]{40}\z/
  SOURCE_REPOSITORIES = {
    "fe" => "100-hours-a-week/KTB4-15th-FE",
    "be" => "100-hours-a-week/KTB4-15th-BE",
    "ai" => "100-hours-a-week/KTB4-15th-AI",
    "crawler" => "100-hours-a-week/KTB4-15th-Crawler"
  }.freeze

  Result = Struct.new(
    :changed,
    :content,
    :image_key,
    :old_digest,
    :new_digest,
    :branch,
    :title,
    :body,
    keyword_init: true
  )

  class ValidationError < StandardError; end

  def self.update(content:, environment:, image_key:, digest:, source_repository:, source_sha:, source_run_url:)
    validate_inputs(
      environment: environment,
      image_key: image_key,
      digest: digest,
      source_repository: source_repository,
      source_sha: source_sha,
      source_run_url: source_run_url
    )

    document = YAML.safe_load(content, aliases: false)
    images = document.is_a?(Hash) ? document["images"] : nil
    unless images.is_a?(Hash) && images.keys == SOURCE_REPOSITORIES.keys
      raise ValidationError, "#{FILE} 이미지 그룹이 허용 목록과 다릅니다."
    end

    image = images[image_key]
    unless image.is_a?(Hash) && image.keys.sort == %w[digest repository]
      raise ValidationError, "images.#{image_key}에는 repository와 digest만 있어야 합니다."
    end

    old_digest = image["digest"]
    unless old_digest.is_a?(String) && DIGEST_PATTERN.match?(old_digest)
      raise ValidationError, "현재 images.#{image_key}.digest가 올바른 sha256 형식이 아닙니다."
    end

    branch = "automation/dev-#{image_key}-#{source_sha[0, 12]}"
    title = "chore(dev): #{image_key.upcase} 이미지 digest 갱신"
    body = pull_request_body(
      image_key: image_key,
      old_digest: old_digest,
      new_digest: digest,
      source_repository: source_repository,
      source_sha: source_sha,
      source_run_url: source_run_url
    )

    if old_digest == digest
      return Result.new(
        changed: false,
        content: content,
        image_key: image_key,
        old_digest: old_digest,
        new_digest: digest,
        branch: branch,
        title: title,
        body: body
      )
    end

    lines = content.lines
    group_line = "  #{image_key}:\n"
    group_index = lines.index(group_line)
    raise ValidationError, "#{FILE}에서 images.#{image_key} 위치를 찾을 수 없습니다." unless group_index

    next_group_index = ((group_index + 1)...lines.length).find { |index| lines[index].match?(/\A  [a-z][a-z0-9_-]*:\s*\z/) } || lines.length
    digest_indexes = ((group_index + 1)...next_group_index).select { |index| lines[index].match?(/\A    digest:\s+/) }
    unless digest_indexes.length == 1
      raise ValidationError, "images.#{image_key}에서 Digest 줄을 정확히 하나 찾을 수 있어야 합니다."
    end

    digest_index = digest_indexes.first
    expected_line = "    digest: #{old_digest}\n"
    unless lines[digest_index] == expected_line
      raise ValidationError, "images.#{image_key}.digest 줄 형식이 예상과 다릅니다."
    end

    lines[digest_index] = "    digest: #{digest}\n"
    updated_content = lines.join

    changed_lines = content.lines.zip(updated_content.lines).count { |before, after| before != after }
    raise ValidationError, "Digest 외의 줄이 함께 변경되었습니다." unless changed_lines == 1

    Result.new(
      changed: true,
      content: updated_content,
      image_key: image_key,
      old_digest: old_digest,
      new_digest: digest,
      branch: branch,
      title: title,
      body: body
    )
  rescue Psych::SyntaxError => error
    raise ValidationError, "#{FILE} YAML 파싱 실패: #{error.message}"
  end

  def self.validate_inputs(environment:, image_key:, digest:, source_repository:, source_sha:, source_run_url:)
    raise ValidationError, "environment는 dev만 허용합니다." unless environment == ENVIRONMENT

    expected_repository = SOURCE_REPOSITORIES[image_key]
    raise ValidationError, "허용되지 않은 image_key입니다: #{image_key}" unless expected_repository
    unless source_repository == expected_repository
      raise ValidationError, "#{image_key}는 #{expected_repository} 저장소만 갱신할 수 있습니다."
    end

    raise ValidationError, "digest가 sha256 형식이 아닙니다." unless DIGEST_PATTERN.match?(digest)
    raise ValidationError, "source_sha는 40자리 소문자 Git SHA여야 합니다." unless SHA_PATTERN.match?(source_sha)

    run_url_pattern = %r{\Ahttps://github\.com/#{Regexp.escape(source_repository)}/actions/runs/[0-9]+\z}
    unless run_url_pattern.match?(source_run_url)
      raise ValidationError, "source_run_url이 해당 저장소의 GitHub Actions 실행 URL이 아닙니다."
    end
  end

  def self.pull_request_body(image_key:, old_digest:, new_digest:, source_repository:, source_sha:, source_run_url:)
    workloads = {
      "fe" => %w[web-bff],
      "be" => %w[identity-api commerce-api chat-api fitting-api fitting-worker],
      "ai" => %w[body-image-validator chat-ai vton-orchestrator],
      "crawler" => %w[price-crawler-apply price-crawler-deliver]
    }.fetch(image_key)

    <<~MARKDOWN
      ## Dev 이미지 자동 갱신

      - 이미지 그룹: `#{image_key}`
      - 원본 저장소: [`#{source_repository}`](https://github.com/#{source_repository})
      - 원본 Commit: [`#{source_sha}`](https://github.com/#{source_repository}/commit/#{source_sha})
      - 원본 Actions: [실행 결과](#{source_run_url})
      - 기존 Digest: `#{old_digest}`
      - 신규 Digest: `#{new_digest}`

      ## 영향 워크로드

      #{workloads.map { |workload| "- `#{workload}`" }.join("\n")}

      ## 자동화 정책

      이 PR은 Dev 이미지 배포 자동화가 생성했습니다. `GitOps CI`가 Digest 한 줄 변경과 영향 워크로드 Manifest를 검증하며, 필수 검사가 성공하면 Squash Auto Merge됩니다.
    MARKDOWN
  end
end

if $PROGRAM_NAME == __FILE__
  required = %w[ENVIRONMENT IMAGE_KEY DIGEST SOURCE_REPOSITORY SOURCE_SHA SOURCE_RUN_URL]
  missing = required.select { |name| ENV[name].nil? || ENV[name].empty? }
  abort "필수 환경변수 누락: #{missing.join(', ')}" unless missing.empty?

  begin
    result = DevImageUpdater.update(
      content: File.read(DevImageUpdater::FILE),
      environment: ENV.fetch("ENVIRONMENT"),
      image_key: ENV.fetch("IMAGE_KEY"),
      digest: ENV.fetch("DIGEST"),
      source_repository: ENV.fetch("SOURCE_REPOSITORY"),
      source_sha: ENV.fetch("SOURCE_SHA"),
      source_run_url: ENV.fetch("SOURCE_RUN_URL")
    )

    output_file = ENV["GITHUB_OUTPUT"]
    body_file = ENV.fetch("PR_BODY_FILE", "dev-image-pr-body.md")

    if result.changed
      File.write(DevImageUpdater::FILE, result.content)
      File.write(body_file, result.body)
    end

    outputs = {
      "changed" => result.changed,
      "image_key" => result.image_key,
      "old_digest" => result.old_digest,
      "new_digest" => result.new_digest,
      "branch" => result.branch,
      "title" => result.title,
      "body_file" => body_file
    }

    if output_file
      File.open(output_file, "a") { |file| outputs.each { |key, value| file.puts "#{key}=#{value}" } }
    end

    if result.changed
      puts "Dev 이미지 갱신 준비 완료: #{result.image_key} #{result.old_digest} -> #{result.new_digest}"
    else
      puts "현재 Digest와 동일하여 변경하지 않습니다: #{result.image_key} #{result.new_digest}"
    end
  rescue DevImageUpdater::ValidationError => error
    abort "Dev 이미지 갱신 입력 검증 실패: #{error.message}"
  end
end
