#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <branch-name>" >&2
  exit 1
fi

BRANCH="$1"

# init モード検出: .bare ディレクトリがある場合はコンテナ内にサブディレクトリとして作成
GIT_COMMON=$(git rev-parse --git-common-dir)
if [ "$(basename "$GIT_COMMON")" = ".bare" ]; then
  CONTAINER_DIR="$(dirname "$GIT_COMMON")"
  WORKTREE_DIR="${CONTAINER_DIR}/${BRANCH}"
else
  PROJ=$(basename "$(git rev-parse --show-toplevel)")
  WORKTREE_DIR="../${PROJ}-${BRANCH}"
fi

git worktree add -b "$BRANCH" "$WORKTREE_DIR"

WORKTREE_ABSPATH="$(cd "$WORKTREE_DIR" && pwd)"

echo ""
echo "=== Worktree 作成完了 ==="
echo "ブランチ: $BRANCH"
echo "ディレクトリ: $WORKTREE_ABSPATH"
