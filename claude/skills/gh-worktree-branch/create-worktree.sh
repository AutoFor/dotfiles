#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <branch-name>" >&2
  exit 1
fi

PROJ=$(basename "$(git rev-parse --show-toplevel)")
BRANCH="$1"
WORKTREE_DIR="../${PROJ}-${BRANCH}"

git worktree add -b "$BRANCH" "$WORKTREE_DIR"

WORKTREE_ABSPATH="$(cd "$WORKTREE_DIR" && pwd)"

echo ""
echo "=== Worktree 作成完了 ==="
echo "ブランチ: $BRANCH"
echo "ディレクトリ: $WORKTREE_ABSPATH"
