#!/usr/bin/env bash
set -euo pipefail

# 前回セッションで遅延されたWorktree削除を実行する
PENDING_FILE="$HOME/.codex/pending-worktree-cleanup.txt"

[ -f "$PENDING_FILE" ] || exit 0

while IFS='|' read -r REPO WT BRANCH; do
  # Worktree削除（"none" または "None" はスキップ）
  if [ -n "$WT" ] && [ "${WT,,}" != "none" ]; then
    git -C "$REPO" worktree remove "$WT" 2>/dev/null || git -C "$REPO" worktree prune 2>/dev/null || true
  fi
  echo "Cleaned up worktree: $WT"

  # ローカルブランチ削除
  if [ -n "$BRANCH" ]; then
    git -C "$REPO" branch -d "$BRANCH" 2>/dev/null || true
    echo "Cleaned up branch: $BRANCH"
  fi
done < "$PENDING_FILE"

rm -f "$PENDING_FILE"
