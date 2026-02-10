#!/bin/bash
set -euo pipefail

# プロジェクト名を取得（リポジトリのディレクトリ名）
PROJ=$(basename "$(git rev-parse --show-toplevel)")

# タイムスタンプを生成
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# テーマ引数があればブランチ名に付加（例: 20260210-143052-add-dark-mode）
if [ $# -ge 1 ]; then
  BRANCH="${TIMESTAMP}-$*"
else
  BRANCH="$TIMESTAMP"
fi

# Worktree ディレクトリのパス
WORKTREE_DIR="../${PROJ}-${BRANCH}"

# Worktree 作成
git worktree add -b "$BRANCH" "$WORKTREE_DIR"

# 結果を表示
echo ""
echo "=== Worktree 作成完了 ==="
echo "ブランチ: $BRANCH"
echo "ディレクトリ: $(cd "$WORKTREE_DIR" && pwd)"
echo ""
echo "作業完了後は /github-finish で PR 作成できます"
