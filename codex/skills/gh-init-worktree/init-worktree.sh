#!/bin/bash
set -euo pipefail

# 対象ディレクトリを決定（引数なし→カレント、引数あり→指定パス）
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

cd "$TARGET_DIR"

# git リポジトリかチェック
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "エラー: $TARGET_DIR は git リポジトリではありません" >&2
  exit 1
fi

# remote URL を取得
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
if [ -z "$REMOTE_URL" ]; then
  echo "エラー: origin リモートが設定されていません" >&2
  exit 1
fi

# URL から github.com/owner/repo を抽出
REPO_PATH=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
if [ -z "$REPO_PATH" ]; then
  echo "エラー: GitHub リポジトリの URL を解析できませんでした: $REMOTE_URL" >&2
  exit 1
fi

CONTAINER_DIR="$HOME/.git-worktrees/github.com/${REPO_PATH}"
BARE_DIR="${CONTAINER_DIR}/.bare"

# 二重実行防止
if [ -d "$BARE_DIR" ]; then
  echo "エラー: $BARE_DIR が既に存在します。既に worktree 構造に変換済みです" >&2
  exit 1
fi

# デフォルトブランチ名を取得
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git branch --show-current)
fi
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH="main"
fi

echo "=== ~/.git-worktrees/ への bare clone を開始 ==="
echo "ソース: $TARGET_DIR"
echo "コンテナ: $CONTAINER_DIR"
echo "デフォルトブランチ: $DEFAULT_BRANCH"
echo ""

# コンテナディレクトリを作成
mkdir -p "$CONTAINER_DIR"

# bare clone
echo "bare clone 中..."
git clone --bare "$REMOTE_URL" "$BARE_DIR"

# remote.origin.fetch を設定（bare リポジトリでも全ブランチを取得できるように）
git -C "$BARE_DIR" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# fetch して最新状態に
git -C "$BARE_DIR" fetch origin

# デフォルトブランチの worktree を作成
WORKTREE_DIR="${CONTAINER_DIR}/${DEFAULT_BRANCH}"
echo "worktree を作成中: $WORKTREE_DIR"
GIT_DIR="$BARE_DIR" git worktree add "$WORKTREE_DIR" "$DEFAULT_BRANCH"

echo ""
echo "=== 変換完了 ==="
echo "bare リポジトリ: $BARE_DIR"
echo "デフォルトブランチ worktree: $WORKTREE_DIR"
echo ""
echo "ghq クローン ($TARGET_DIR) は変更していません。"
