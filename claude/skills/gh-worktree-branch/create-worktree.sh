#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <branch-name> [r|d]" >&2
  exit 1
fi

BRANCH="$1"
SPLIT_DIR="${2:-d}"

# モード1: .bare ディレクトリがある場合はコンテナ内にサブディレクトリとして作成
GIT_COMMON=$(git rev-parse --git-common-dir)
if [ "$(basename "$GIT_COMMON")" = ".bare" ]; then
  CONTAINER_DIR="$(dirname "$GIT_COMMON")"
  WORKTREE_DIR="${CONTAINER_DIR}/${BRANCH}"
  echo "origin から最新を取得中..."
  git fetch origin
  git worktree add -b "$BRANCH" "$WORKTREE_DIR"
else
  # モード2: remote URL から ~/.git-worktrees/... の .bare が存在するか確認
  # なければ init-worktree.sh で自動作成してから worktree を追加
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  WORKTREE_DIR=""

  # ソース（現在のgitリポジトリ）で削除済みの追跡ファイルを記録
  DELETED_FILES=$(git status --porcelain 2>/dev/null | awk '/^[ D]D /{print $NF}' || true)

  if [ -n "$REMOTE_URL" ]; then
    REPO_PATH=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
    CANDIDATE="${HOME}/.git-worktrees/github.com/${REPO_PATH}"
    if [ ! -d "${CANDIDATE}/.bare" ]; then
      echo ".bare が見つかりません。init-worktree で bare clone を作成します..."
      SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
      bash "${SCRIPT_DIR}/../gh-init-worktree/init-worktree.sh" "$(git rev-parse --show-toplevel)"
    fi
    echo "origin から最新を取得中..."
    GIT_DIR="${CANDIDATE}/.bare" git fetch origin
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

# ソースの削除済みファイルを新規 worktree にも伝播
if [ -n "${DELETED_FILES:-}" ]; then
  while IFS= read -r f; do
    rm -f "${WORKTREE_ABSPATH}/${f}"
  done <<< "$DELETED_FILES"
fi
# 未追跡ファイルを削除
git -C "$WORKTREE_ABSPATH" clean -fd 2>/dev/null || true

# WezTerm で新しいペインを開いて Claude を起動
# SSH経由の場合はWezTermが使えないのでスキップ
_wezterm_cmd=""
if [ -z "${SSH_CONNECTION:-}" ]; then
  if command -v wezterm &>/dev/null && [ -n "${WEZTERM_PANE:-}" ]; then
    _wezterm_cmd="wezterm"
  elif command -v wezterm.exe &>/dev/null; then
    _wezterm_cmd="wezterm.exe"
  elif [ -x "/mnt/c/Program Files/WezTerm/wezterm.exe" ]; then
    _wezterm_cmd="/mnt/c/Program Files/WezTerm/wezterm.exe"
  fi
fi

if [ "$SPLIT_DIR" != "none" ] && [ -n "$_wezterm_cmd" ]; then
  if [ "$SPLIT_DIR" = "r" ]; then
    "$_wezterm_cmd" cli split-pane --right --cwd "$WORKTREE_ABSPATH" -- zsh -l -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; ~/.local/bin/claude; exit 0"
  elif [ "$SPLIT_DIR" = "t" ]; then
    "$_wezterm_cmd" cli spawn --cwd "$WORKTREE_ABSPATH"
  else
    "$_wezterm_cmd" cli split-pane --cwd "$WORKTREE_ABSPATH" -- zsh -l -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; ~/.local/bin/claude; exit 0"
  fi
  echo "WezTerm: 新しいペインで Claude を起動しました。"
fi
