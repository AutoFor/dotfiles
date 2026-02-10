#!/bin/bash
set -euo pipefail

# プロジェクト名を取得（リポジトリのディレクトリ名）
PROJ=$(basename "$(git rev-parse --show-toplevel)")

# タイムスタンプでブランチ名を生成
BRANCH=$(date +%Y%m%d-%H%M%S)

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
