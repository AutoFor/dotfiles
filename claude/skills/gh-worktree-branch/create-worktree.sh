#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <branch-name>" >&2
  exit 1
fi

BRANCH="$1"

# モード1: .bare ディレクトリがある場合はコンテナ内にサブディレクトリとして作成
GIT_COMMON=$(git rev-parse --git-common-dir)
if [ "$(basename "$GIT_COMMON")" = ".bare" ]; then
  CONTAINER_DIR="$(dirname "$GIT_COMMON")"
  WORKTREE_DIR="${CONTAINER_DIR}/${BRANCH}"
  git worktree add -b "$BRANCH" "$WORKTREE_DIR"
else
  # モード2: remote URL から ~/.git-worktrees/... の .bare が存在するか確認
  # なければ init-worktree.sh で自動作成してから worktree を追加
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  WORKTREE_DIR=""

  if [ -n "$REMOTE_URL" ]; then
    REPO_PATH=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
    CANDIDATE="${HOME}/.git-worktrees/github.com/${REPO_PATH}"
    if [ ! -d "${CANDIDATE}/.bare" ]; then
      echo ".bare が見つかりません。init-worktree で bare clone を作成します..."
      SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
      bash "${SCRIPT_DIR}/../gh-init-worktree/init-worktree.sh" "$(git rev-parse --show-toplevel)"
    fi
    WORKTREE_DIR="${CANDIDATE}/${BRANCH}"
    GIT_DIR="${CANDIDATE}/.bare" git worktree add -b "$BRANCH" "$WORKTREE_DIR"
  else
    echo "エラー: origin リモートが設定されていません" >&2
    exit 1
  fi
fi

WORKTREE_ABSPATH="$(cd "$WORKTREE_DIR" && pwd)"

echo ""
echo "=== Worktree 作成完了 ==="
echo "ブランチ: $BRANCH"
echo "ディレクトリ: $WORKTREE_ABSPATH"
