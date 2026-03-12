#!/bin/bash
set -euo pipefail

# 対象ディレクトリを決定（引数なし→カレント、引数あり→指定パス）
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

cd "$TARGET_DIR"

# 二重実行防止（.bare が既に存在する場合 — git チェックより先に行う）
if [ -d "$TARGET_DIR/.bare" ]; then
  echo "エラー: $TARGET_DIR/.bare が既に存在します。既に worktree 構造に変換済みです" >&2
  exit 1
fi

# git リポジトリかチェック
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "エラー: $TARGET_DIR は git リポジトリではありません" >&2
  exit 1
fi

# .git がディレクトリであることを確認（worktree 内ではない）
if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "エラー: $TARGET_DIR/.git がディレクトリではありません。worktree 内から実行していませんか？" >&2
  exit 1
fi

# デフォルトブランチ名を取得
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git branch --show-current)
fi
if [ -z "$DEFAULT_BRANCH" ]; then
  echo "エラー: デフォルトブランチを特定できません" >&2
  exit 1
fi

echo "=== worktree 構造への変換を開始 ==="
echo "対象: $TARGET_DIR"
echo "デフォルトブランチ: $DEFAULT_BRANCH"
echo ""

# 未コミット変更を stash（untracked 含む）
STASHED=false
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "未コミットの変更を stash します..."
  git stash push -u -m "gh-init-worktree: temporary stash"
  STASHED=true
fi

# 一時ディレクトリに退避
TMPDIR=$(mktemp -d "${TARGET_DIR}/.git-worktree-init-XXXXXX")
echo "一時ディレクトリに退避中: $TMPDIR"

# .git/ を一時ディレクトリに移動
mv "$TARGET_DIR/.git" "$TMPDIR/git-backup"

# 作業ファイルを一時ディレクトリに移動（.で始まるファイルも含む、一時ディレクトリ自体は除く）
mkdir -p "$TMPDIR/files-backup"
TMPDIR_NAME=$(basename "$TMPDIR")
for item in "$TARGET_DIR"/* "$TARGET_DIR"/.[!.]* "$TARGET_DIR"/..?*; do
  [ -e "$item" ] || continue
  item_name=$(basename "$item")
  [ "$item_name" = "$TMPDIR_NAME" ] && continue
  # 移動失敗時はコピー＋削除を試み、それでも駄目ならスキップ（bin/obj 等のロックされたビルド成果物）
  mv "$item" "$TMPDIR/files-backup/" 2>/dev/null || \
    (cp -r "$item" "$TMPDIR/files-backup/" && rm -rf "$item") 2>/dev/null || \
    echo "警告: $item_name の移動をスキップしました（ロックされている可能性があります）"
done

# .git/ → .bare/ に変換
mv "$TMPDIR/git-backup" "$TARGET_DIR/.bare"

# bare リポジトリとして設定
git -C "$TARGET_DIR/.bare" config core.bare true

# remote.origin.fetch を設定（bare リポジトリでも全ブランチを取得できるように）
git -C "$TARGET_DIR/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# デフォルトブランチの worktree を作成
echo "worktree を作成中: $TARGET_DIR/$DEFAULT_BRANCH"
GIT_DIR="$TARGET_DIR/.bare" git worktree add "$TARGET_DIR/$DEFAULT_BRANCH" "$DEFAULT_BRANCH"

# 退避した作業ファイルを worktree に復元
if [ -d "$TMPDIR/files-backup" ]; then
  for item in "$TMPDIR/files-backup"/* "$TMPDIR/files-backup"/.[!.]* "$TMPDIR/files-backup"/..?*; do
    [ -e "$item" ] || continue
    item_name=$(basename "$item")
    # worktree が既に持っているファイルは上書きしない
    if [ ! -e "$TARGET_DIR/$DEFAULT_BRANCH/$item_name" ]; then
      mv "$item" "$TARGET_DIR/$DEFAULT_BRANCH/"
    fi
  done
fi

# stash を復元
if [ "$STASHED" = true ]; then
  echo "stash を復元中..."
  cd "$TARGET_DIR/$DEFAULT_BRANCH"
  git stash pop || echo "警告: stash の復元に失敗しました。git stash list で確認してください"
fi

# 一時ディレクトリを削除
rm -rf "$TMPDIR"

echo ""
echo "=== 変換完了 ==="
echo "bare リポジトリ: $TARGET_DIR/.bare/"
echo "デフォルトブランチ worktree: $TARGET_DIR/$DEFAULT_BRANCH/"
