const fs = require("node:fs");

const COMMENT_MARKER = "<!-- lookddak-helm-manifest-diff -->";
const MAX_DIFF_LENGTH = 50_000;

function buildComment({ diff, summary, baseSha, ciStatus, runUrl }) {
  const validationResult = ciStatus === "success"
    ? "✅ GitOps CI 검증을 통과했습니다."
    : `❌ GitOps CI 검증에 실패했습니다. [실행 로그](${runUrl})를 확인해 주세요.`;

  let diffResult;

  if (summary?.trim()) {
    diffResult = summary.trim();
  } else if (diff === null) {
    diffResult = `Manifest 비교 결과를 생성하지 못했습니다. [실행 로그](${runUrl})를 확인해 주세요.`;
  } else if (diff.trim() === "") {
    diffResult = "렌더링된 Helm Manifest 변경이 없습니다.";
  } else {
    const truncated = diff.length > MAX_DIFF_LENGTH;
    const visibleDiff = diff.slice(0, MAX_DIFF_LENGTH);

    diffResult = [
      "```diff",
      visibleDiff,
      "```",
      truncated
        ? `> 변경 내용이 길어 앞부분만 표시했습니다. 전체 내용은 [실행 로그](${runUrl})에서 확인할 수 있습니다.`
        : "",
    ].filter(Boolean).join("\n\n");
  }

  return [
    COMMENT_MARKER,
    "## Helm Manifest 변경점",
    "",
    `기준 Commit: \`${baseSha}\``,
    "",
    validationResult,
    "",
    diffResult,
    "",
    `> 이 댓글은 GitOps CI가 자동으로 갱신합니다. [Actions 실행 보기](${runUrl})`,
  ].join("\n");
}

async function commentManifestDiff({ github, context, core }) {
  const pullNumber = context.issue.number;

  if (!pullNumber) {
    core.warning("PR 번호를 확인할 수 없어 Manifest 변경점 댓글을 작성하지 않습니다.");
    return;
  }

  const diffFile = process.env.DIFF_FILE;
  const diff = diffFile && fs.existsSync(diffFile)
    ? fs.readFileSync(diffFile, "utf8")
    : null;
  const summaryFile = process.env.SUMMARY_FILE;
  const summary = summaryFile && fs.existsSync(summaryFile)
    ? fs.readFileSync(summaryFile, "utf8")
    : null;

  const body = buildComment({
    diff,
    summary,
    baseSha: process.env.BASE_SHA,
    ciStatus: process.env.CI_STATUS,
    runUrl: process.env.RUN_URL,
  });

  const comments = await github.paginate(github.rest.issues.listComments, {
    ...context.repo,
    issue_number: pullNumber,
    per_page: 100,
  });

  const existingComment = comments.find((comment) =>
    comment.user?.type === "Bot" && comment.body?.includes(COMMENT_MARKER)
  );

  if (existingComment) {
    await github.rest.issues.updateComment({
      ...context.repo,
      comment_id: existingComment.id,
      body,
    });
    core.info(`기존 Manifest 변경점 댓글을 갱신했습니다: ${existingComment.id}`);
    return;
  }

  const created = await github.rest.issues.createComment({
    ...context.repo,
    issue_number: pullNumber,
    body,
  });
  core.info(`Manifest 변경점 댓글을 생성했습니다: ${created.data.id}`);
}

module.exports = commentManifestDiff;
module.exports.buildComment = buildComment;
