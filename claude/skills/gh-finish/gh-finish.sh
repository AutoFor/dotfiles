#!/usr/bin/env bash
# gh-finish.sh - GitHub 作業完了スクリプト
# claude -p を 3 箇所のみで使用:
#   1. Issue タイトル + 英語スラッグ生成 (flow_a のみ)
#   2. スマートコミット JSON 生成 (flow_a / flow_b 共通)
#   3. PR body 生成 (ready_for_review)

set -euo pipefail

# ─── グローバル変数 ───────────────────────────────────────────────────
OWNER=""
REPO=""
DEFAULT_BRANCH=""
CURRENT_BRANCH=""
MAIN_REPO=""
WORKTREE_PATH="none"
FEATURE_BRANCH=""

# ─── 依存ツール確認 ───────────────────────────────────────────────────
check_deps() {
  local missing=()
  for cmd in git gh claude; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: Missing required tools: ${missing[*]}" >&2
    exit 1
  fi
  # jq は optional（なければ python3 で代替）
  if ! command -v jq &>/dev/null && ! command -v python3 &>/dev/null; then
    echo "Error: Either jq or python3 is required for JSON parsing." >&2
    exit 1
  fi
}

# ─── JSON ヘルパー（jq or python3）────────────────────────────────────
# json_is_array: stdin が JSON 配列なら 0、そうでなければ 1
json_is_array() {
  if command -v jq &>/dev/null; then
    jq -e '. | type == "array"' &>/dev/null
  else
    python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if isinstance(d,list) else 1)"
  fi
}

# json_each_compact: 配列の各要素を1行の JSON として出力
json_each_compact() {
  if command -v jq &>/dev/null; then
    jq -c '.[]'
  else
    python3 -c "import sys,json; [print(json.dumps(x)) for x in json.load(sys.stdin)]"
  fi
}

# json_get_string KEY: stdin の JSON オブジェクトから文字列フィールドを取得
json_get_string() {
  local key="$1"
  if command -v jq &>/dev/null; then
    jq -r ".$key"
  else
    python3 -c "import sys,json; print(json.load(sys.stdin)['$key'])"
  fi
}

# json_get_array_lines KEY: stdin の JSON オブジェクトから配列を1行ずつ出力
json_get_array_lines() {
  local key="$1"
  if command -v jq &>/dev/null; then
    jq -r ".${key}[]"
  else
    python3 -c "import sys,json; [print(x) for x in json.load(sys.stdin)['$key']]"
  fi
}

# json_first_number KEY: stdin の JSON 配列から .[0].KEY を取得（なければ空文字）
json_first_number() {
  local key="$1"
  if command -v jq &>/dev/null; then
    jq -r ".[0].${key} // empty"
  else
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['$key'] if d and '$key' in d[0] else '')"
  fi
}

# ─── コンテキスト検出 ─────────────────────────────────────────────────
detect_context() {
  CURRENT_BRANCH=$(git branch --show-current)

  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
    | sed 's@^refs/remotes/origin/@@' || echo "main")

  # OWNER/REPO
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+?)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
  else
    echo "Error: Cannot detect owner/repo from: $remote_url" >&2
    exit 1
  fi

  # MAIN_REPO / WORKTREE_PATH
  local worktree_list worktree_count toplevel
  worktree_list=$(git worktree list)
  worktree_count=$(echo "$worktree_list" | wc -l)
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

  if [ "$worktree_count" -le 1 ]; then
    MAIN_REPO="$toplevel"
    WORKTREE_PATH="none"
  elif [ -d "$toplevel/../.bare" ]; then
    # .bare ディレクトリがある worktree 構造
    MAIN_REPO=$(echo "$worktree_list" | grep "\[$DEFAULT_BRANCH\]" | awk '{print $1}' | head -1)
    MAIN_REPO="${MAIN_REPO:-$toplevel}"
    if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
      WORKTREE_PATH="$toplevel"
    else
      WORKTREE_PATH="none"
    fi
  else
    MAIN_REPO="$toplevel"
    WORKTREE_PATH="none"
  fi
}

# ─── スマートコミット [claude -p #2] ──────────────────────────────────
smart_commit() {
  local untracked staged unstaged
  untracked=$(git ls-files --others --exclude-standard)
  staged=$(git diff --cached --name-only)
  unstaged=$(git diff --name-only)

  if [ -z "$untracked" ] && [ -z "$staged" ] && [ -z "$unstaged" ]; then
    return 0
  fi

  echo "コミット計画を生成中..."
  local files diff commit_plan json

  files=$(git status --short)
  diff=$(git diff; git diff --cached)

  commit_plan=$(printf "files:\n%s\n\ndiff:\n%s" "$files" "$diff" | claude -p \
    "ファイルをテーマ別にグループ化し、コミット計画をJSON配列のみ出力（説明不要）。形式: [{\"files\":[\"path\"],\"message\":\"feat: 日本語説明\"}]")

  # JSON 配列部分を抽出（余分なテキストを除去）
  if echo "$commit_plan" | json_is_array; then
    json="$commit_plan"
  else
    # [ から始まる行を抽出
    json=$(echo "$commit_plan" | awk '/^\[/{p=1} p{print} /^\]/{p=0}')
    if ! echo "$json" | json_is_array 2>/dev/null; then
      # フォールバック: 全変更を1コミット
      echo "Warning: JSON parse failed. Falling back to single commit." >&2
      git add -A
      git commit -m "chore: update files"
      return 0
    fi
  fi

  echo "$json" | json_each_compact | while IFS= read -r group; do
    local msg
    msg=$(echo "$group" | json_get_string message)
    mapfile -t files_arr < <(echo "$group" | json_get_array_lines files)
    git add "${files_arr[@]}"
    git commit -m "$msg"
    echo "Committed: $msg"
  done
}

# ─── フロー A: main/master 上にいる場合 ──────────────────────────────
flow_a() {
  echo "=== Flow A: main ブランチから Issue・ブランチ・PR を作成 ==="

  local status diff_all log
  status=$(git status --short)
  diff_all=$(git diff; git diff --cached)
  log=$(git log "origin/$DEFAULT_BRANCH..HEAD" --format="%s" 2>/dev/null || echo "")

  if [ -z "$status" ] && [ -z "$diff_all" ] && [ -z "$log" ]; then
    echo "変更がありません。終了します。"
    exit 0
  fi

  # [claude -p #1] Issue タイトル + 英語スラッグ（1回のみ）
  echo "Issue タイトルを生成中..."
  local claude_out issue_title slug
  claude_out=$(printf '%s\n%s\n%s' "$diff_all" "$log" "$status" | claude -p \
    "この変更内容から以下を生成して2行で出力。1行目: GitHub Issue タイトル（日本語20文字以内）。2行目: ブランチ名用英語スラッグ（小文字・ハイフン区切り・3〜5語）。余計な説明は一切不要。")
  issue_title=$(echo "$claude_out" | head -1 | tr -d '\r\n')
  slug=$(echo "$claude_out" | sed -n '2p' | tr -d '\r\n' | tr -cd 'a-z0-9-' | cut -c1-40)
  echo "  タイトル: $issue_title"
  echo "  スラッグ: $slug"

  # Issue 作成
  echo "Issue を作成中..."
  local issue_url issue_num
  issue_url=$(gh issue create \
    --title "$issue_title" \
    --body "$(printf '## 変更内容\n\n```\n%s\n```' "$diff_all")" \
    --repo "$OWNER/$REPO")
  issue_num=$(echo "$issue_url" | grep -oE '[0-9]+$')
  echo "  Issue #$issue_num: $issue_url"

  # ブランチ作成
  local branch_name="issue-${issue_num}-${slug}"
  echo "ブランチを作成中: $branch_name"

  local unpushed
  unpushed=$(git log "origin/$DEFAULT_BRANCH..HEAD" --oneline 2>/dev/null || echo "")

  git checkout -b "$branch_name"

  if [ -n "$unpushed" ]; then
    # 未プッシュコミットを新ブランチに残し、デフォルトブランチをリセット
    git branch -f "$DEFAULT_BRANCH" "origin/$DEFAULT_BRANCH"
  fi

  FEATURE_BRANCH="$branch_name"

  # 未コミット変更をコミット
  smart_commit

  # プッシュ
  git push -u origin "$branch_name"

  # Draft PR 作成
  local pr_url
  pr_url=$(gh pr create \
    --draft \
    --title "WIP: $issue_title" \
    --body "$(printf 'Closes #%s\n\n作業中...' "$issue_num")" \
    --head "$branch_name" \
    --base "$DEFAULT_BRANCH" \
    --repo "$OWNER/$REPO")
  echo "  Draft PR: $pr_url"

  ready_for_review "$issue_num"
}

# ─── フロー B: feature ブランチ上にいる場合 ──────────────────────────
flow_b() {
  echo "=== Flow B: feature ブランチの作業を完了 ==="

  FEATURE_BRANCH="$CURRENT_BRANCH"

  # Issue 番号を抽出（先に確認して早期終了）
  local issue_num
  issue_num=$(echo "$CURRENT_BRANCH" | grep -oP 'issue-\K\d+' || echo "")
  if [ -z "$issue_num" ]; then
    echo "Error: ブランチ名から Issue 番号を抽出できません: $CURRENT_BRANCH" >&2
    exit 1
  fi

  local status
  status=$(git status --short)

  if [ -n "$status" ]; then
    smart_commit
  fi

  # コミット後も含めた未プッシュ確認
  local unpushed
  unpushed=$(git log "@{u}..HEAD" --oneline 2>/dev/null || \
             git log "origin/$DEFAULT_BRANCH..HEAD" --oneline 2>/dev/null || echo "")
  if [ -n "$unpushed" ]; then
    git push -u origin "$CURRENT_BRANCH"
  fi

  ready_for_review "$issue_num"
}

# ─── PR を Ready for Review に変更 [claude -p #3] ────────────────────
ready_for_review() {
  local issue_num="$1"
  local branch
  branch=$(git branch --show-current)

  echo "=== PR を Ready for Review に変更 (Issue #$issue_num) ==="

  # 未コミット確認
  if [ -n "$(git status --short 2>/dev/null)" ]; then
    smart_commit
  fi

  # 未プッシュ確認
  local unpushed
  unpushed=$(git log "@{u}..HEAD" --oneline 2>/dev/null || echo "")
  if [ -n "$unpushed" ]; then
    git push -u origin "$branch"
  fi

  # [claude -p #3] PR タイトル + 本文を diff から生成（Issue タイトルに依存しない）
  echo "PR タイトル・説明文を生成中..."
  local log diff claude_out pr_title pr_body
  log=$(git log "origin/$DEFAULT_BRANCH..HEAD" --oneline 2>/dev/null || echo "")
  diff=$(git diff "origin/$DEFAULT_BRANCH...HEAD" 2>/dev/null || echo "")
  claude_out=$(printf "commits:\n%s\n\ndiff:\n%s" "$log" "$diff" | claude -p \
    "このブランチの変更から以下を生成。1行目: PR タイトル（日本語20文字以内）。2行目以降: PR 説明文（Markdown、## 変更内容 と ## テスト方法 セクション含む）。余計な前置き不要。")
  pr_title=$(echo "$claude_out" | head -1 | tr -d '\r\n')
  pr_body=$(echo "$claude_out" | tail -n +2)

  # 既存 Draft PR を検索
  local draft_pr_json pr_num
  draft_pr_json=$(gh pr list --head "$branch" --state open \
    --json number,isDraft,title --repo "$OWNER/$REPO" 2>/dev/null || echo "[]")
  pr_num=$(echo "$draft_pr_json" | json_first_number number)

  if [ -n "$pr_num" ]; then
    echo "既存 PR #$pr_num を更新中..."
    gh api "repos/$OWNER/$REPO/pulls/$pr_num" -X PATCH \
      -f title="$pr_title" \
      -f body="$(printf 'Closes #%s\n\n%s' "$issue_num" "$pr_body")"
    gh pr ready "$pr_num" --repo "$OWNER/$REPO"
    echo "  PR #$pr_num を Ready for Review に変更しました。"
  else
    echo "新規 PR を作成中..."
    local pr_url
    pr_url=$(gh pr create \
      --title "$pr_title" \
      --body "$(printf 'Closes #%s\n\n%s' "$issue_num" "$pr_body")" \
      --head "$branch" \
      --base "$DEFAULT_BRANCH" \
      --repo "$OWNER/$REPO")
    pr_num=$(echo "$pr_url" | grep -oE '[0-9]+$')
    echo "  PR #$pr_num: $pr_url"
  fi

  approve_and_merge "$pr_num" "$issue_num"
}

# ─── 承認・マージ ─────────────────────────────────────────────────────
approve_and_merge() {
  local pr_num="$1"
  local issue_num="$2"

  echo "=== PR #$pr_num を承認・マージ ==="

  local approve_script="$HOME/.claude/skills/gh-pr-approve/approve-pr.sh"
  if [ -f "$approve_script" ]; then
    bash "$approve_script" "$OWNER" "$REPO" "$pr_num" || {
      echo "Warning: PR 承認失敗（403 or 設定なし）。マージを続行します。" >&2
    }
  else
    echo "Warning: approve-pr.sh が見つかりません。承認をスキップ。" >&2
  fi

  gh pr merge "$pr_num" --squash --repo "$OWNER/$REPO"
  echo "  PR #$pr_num マージ完了。"

  local issue_state
  issue_state=$(gh issue view "$issue_num" --repo "$OWNER/$REPO" --json state -q '.state' \
    2>/dev/null || echo "OPEN")
  if [ "$issue_state" != "CLOSED" ]; then
    gh issue close "$issue_num" --repo "$OWNER/$REPO"
    echo "  Issue #$issue_num クローズ。"
  fi

  cleanup "$pr_num" "$issue_num"
}

# ─── 後処理 ───────────────────────────────────────────────────────────
cleanup() {
  local pr_num="$1"
  local issue_num="$2"
  local branch="$FEATURE_BRANCH"

  echo "=== 後処理 ==="

  local cleanup_script="$HOME/.claude/skills/gh-pr-approve/cleanup-after-merge.sh"
  if [ -f "$cleanup_script" ]; then
    bash "$cleanup_script" "$MAIN_REPO" "$WORKTREE_PATH" "$DEFAULT_BRANCH" "$branch"
  else
    echo "Warning: cleanup-after-merge.sh が見つかりません。" >&2
    git -C "$MAIN_REPO" checkout "$DEFAULT_BRANCH" 2>/dev/null || true
    git -C "$MAIN_REPO" pull 2>/dev/null || true
  fi

  echo ""
  echo "PR のマージと後処理が完了しました。"
  echo ""
  echo "完了した作業:"
  if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
    echo "  - Issue #$issue_num を作成"
    echo "  - ブランチ $branch を作成・コミット"
  fi
  echo "  - PR #$pr_num をマージ"
  echo "  - Issue #$issue_num をクローズ"
  echo "  - $DEFAULT_BRANCH ブランチに切り替え・最新を取得"
  echo "  - ブランチ $branch を削除"
}

# ─── エントリーポイント ───────────────────────────────────────────────
main() {
  check_deps
  detect_context

  echo "Branch : $CURRENT_BRANCH"
  echo "Default: $DEFAULT_BRANCH"
  echo "Repo   : $OWNER/$REPO"
  echo "Root   : $MAIN_REPO"
  echo ""

  if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
    flow_a
  else
    flow_b
  fi
}

main "$@"
