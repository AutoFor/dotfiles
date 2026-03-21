#!/usr/bin/env bash
set -euo pipefail

# Usage: cleanup-after-merge.sh <main-repo-path> <worktree-path|none> <default-branch> [branch-to-delete]
# Worktree削除後にcwdが無効になる問題を回避するため、全操作を git -C で実行する

MAIN_REPO="$1"       # メインリポジトリの絶対パス
WORKTREE_PATH="$2"   # Worktreeの絶対パス（Worktree未使用時は "none"）
DEFAULT_BRANCH="$3"  # デフォルトブランチ名（master or main）
BRANCH_TO_DELETE="${4:-}"  # 削除するブランチ名（通常ブランチの場合）

# "none"/"None" を正規化（大文字小文字どちらでも動作するよう）
if [ "${WORKTREE_PATH,,}" = "none" ]; then
  WORKTREE_PATH="none"
fi

# bare リポジトリ検出: .bare ディレクトリが MAIN_REPO として渡された場合は拒否
if git -C "$MAIN_REPO" rev-parse --is-bare-repository 2>/dev/null | grep -q "true"; then
  echo "ERROR: MAIN_REPO '$MAIN_REPO' is a bare repository. Pass the default-branch worktree path (e.g. .../master) instead." >&2
  exit 1
fi

# ガード: Worktree内から実行するとcwd消失でBashツールが壊れるため防止
if [ "$WORKTREE_PATH" != "none" ]; then
  CURRENT_DIR="$(pwd -P 2>/dev/null || echo "")"
  RESOLVED_WORKTREE="$(realpath "$WORKTREE_PATH" 2>/dev/null || echo "$WORKTREE_PATH")"
  if [[ "$CURRENT_DIR" == "$RESOLVED_WORKTREE" || "$CURRENT_DIR" == "$RESOLVED_WORKTREE/"* ]]; then
    echo "WARNING: Worktree内（またはそのサブディレクトリ）から実行されています。CWDをメインリポジトリに移動します。" >&2
    cd "$MAIN_REPO"
  fi
fi

# master切替
git -C "$MAIN_REPO" checkout "$DEFAULT_BRANCH"

# ローカル変更がある場合はstashしてpull
if ! git -C "$MAIN_REPO" diff --quiet 2>/dev/null; then
  git -C "$MAIN_REPO" stash
  git -C "$MAIN_REPO" pull origin "$DEFAULT_BRANCH"
  git -C "$MAIN_REPO" stash pop || git -C "$MAIN_REPO" checkout --theirs . && git -C "$MAIN_REPO" stash drop 2>/dev/null || true
else
  git -C "$MAIN_REPO" pull origin "$DEFAULT_BRANCH"
fi

# prune
git -C "$MAIN_REPO" fetch --prune

# Worktree/ブランチ削除
if [ "$WORKTREE_PATH" != "none" ]; then
  # Worktreeからブランチ名を検出（$4が未指定の場合）
  if [ -z "$BRANCH_TO_DELETE" ]; then
    BRANCH_TO_DELETE=$(git -C "$MAIN_REPO" worktree list --porcelain \
      | awk -v wt="$WORKTREE_PATH" '$1=="worktree" && $2==wt {found=1} found && $1=="branch" {print $2; exit}' \
      | sed 's|refs/heads/||')
  fi

  # Worktree削除を遅延（CWDが削除済みディレクトリになりStop hookがENOENTで失敗するため）
  echo "$MAIN_REPO|$WORKTREE_PATH|$BRANCH_TO_DELETE" >> ~/.claude/pending-worktree-cleanup.txt
  echo "Worktree cleanup deferred: $WORKTREE_PATH (will be cleaned up on next worktree creation)"
else
  # Worktree未使用時はローカルブランチを即座に削除
  if [ -n "$BRANCH_TO_DELETE" ]; then
    git -C "$MAIN_REPO" branch -d "$BRANCH_TO_DELETE" 2>/dev/null || true
    echo "Local branch deleted: $BRANCH_TO_DELETE"
  fi
fi

# リモートブランチ削除
if [ -n "$BRANCH_TO_DELETE" ]; then
  git -C "$MAIN_REPO" push origin --delete "$BRANCH_TO_DELETE" 2>/dev/null || true
  echo "Remote branch deleted: $BRANCH_TO_DELETE"
fi

echo "Cleanup completed successfully."
