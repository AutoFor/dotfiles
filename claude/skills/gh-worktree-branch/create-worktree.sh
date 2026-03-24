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
  git worktree list --porcelain \
    | awk '/^worktree /{print $2}' | grep -v '\.bare$' \
    | while IFS= read -r wt; do [ -d "$wt" ] && git -C "$wt" restore . 2>/dev/null || true; done
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
    echo "origin から最新を取得中..."
    GIT_DIR="${CANDIDATE}/.bare" git fetch origin
    GIT_DIR="${CANDIDATE}/.bare" git worktree list --porcelain \
      | awk '/^worktree /{print $2}' | grep -v '\.bare$' \
      | while IFS= read -r wt; do [ -d "$wt" ] && git -C "$wt" restore . 2>/dev/null || true; done
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

# worktree を強制的にクリーンな状態にする（削除済み追跡ファイルの復元・未追跡ファイルの削除）
git -C "$WORKTREE_ABSPATH" restore . 2>/dev/null || true
git -C "$WORKTREE_ABSPATH" clean -fd 2>/dev/null || true

# WezTerm で新しいペインを開いて Claude を起動
# ネイティブ: wezterm + WEZTERM_PANE が必要
# WSL2: wezterm.exe で代替（WEZTERM_PANE 不要）
_wezterm_cmd=""
if command -v wezterm &>/dev/null && [ -n "${WEZTERM_PANE:-}" ]; then
  _wezterm_cmd="wezterm"
elif command -v wezterm.exe &>/dev/null; then
  _wezterm_cmd="wezterm.exe"
elif [ -x "/mnt/c/Program Files/WezTerm/wezterm.exe" ]; then
  _wezterm_cmd="/mnt/c/Program Files/WezTerm/wezterm.exe"
fi

if [ "$SPLIT_DIR" != "none" ] && [ -n "$_wezterm_cmd" ]; then
  if [ "$SPLIT_DIR" = "r" ]; then
    "$_wezterm_cmd" cli split-pane --right --cwd "$WORKTREE_ABSPATH" -- zsh -l -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; ~/.local/bin/claude; exit 0"
  else
    "$_wezterm_cmd" cli split-pane --cwd "$WORKTREE_ABSPATH" -- zsh -l -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; ~/.local/bin/claude; exit 0"
  fi
  echo "WezTerm: 新しいペインで Claude を起動しました。"
fi
