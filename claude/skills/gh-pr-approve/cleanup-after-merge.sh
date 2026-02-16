#!/usr/bin/env bash
set -euo pipefail

# Usage: cleanup-after-merge.sh <main-repo-path> <worktree-path|none> <default-branch> [branch-to-delete]
# Worktree削除後にcwdが無効になる問題を回避するため、全操作を git -C で実行する

MAIN_REPO="$1"       # メインリポジトリの絶対パス
WORKTREE_PATH="$2"   # Worktreeの絶対パス（Worktree未使用時は "none"）
DEFAULT_BRANCH="$3"  # デフォルトブランチ名（master or main）
BRANCH_TO_DELETE="${4:-}"  # 削除するブランチ名（通常ブランチの場合）

# master切替
git -C "$MAIN_REPO" checkout "$DEFAULT_BRANCH"

# ローカル変更がある場合はstashしてpull
if ! git -C "$MAIN_REPO" diff --quiet 2>/dev/null; then
  git -C "$MAIN_REPO" stash
  git -C "$MAIN_REPO" pull
  git -C "$MAIN_REPO" stash pop || git -C "$MAIN_REPO" checkout --theirs . && git -C "$MAIN_REPO" stash drop 2>/dev/null || true
else
  git -C "$MAIN_REPO" pull
fi

# prune
git -C "$MAIN_REPO" fetch --prune

# Worktree/ブランチ削除
if [ "$WORKTREE_PATH" != "none" ]; then
  git -C "$MAIN_REPO" worktree remove "$WORKTREE_PATH" 2>/dev/null || \
    git -C "$MAIN_REPO" worktree prune
  echo "Worktree removed: $WORKTREE_PATH"
else
  if [ -n "$BRANCH_TO_DELETE" ]; then
    git -C "$MAIN_REPO" branch -d "$BRANCH_TO_DELETE" 2>/dev/null || true
    echo "Branch deleted: $BRANCH_TO_DELETE"
  fi
fi

echo "Cleanup completed successfully."
