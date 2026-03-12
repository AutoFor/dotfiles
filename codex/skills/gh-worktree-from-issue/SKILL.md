---
name: gh-worktree-from-issue
description: 既存の GitHub Issue から Git Worktree を使った作業ブランチを作成する。ユーザーが「Issue #123 から作業を開始したい」「既存の Issue で作業する」「gh-worktree-from-issue」と言ったときに使用する。
---

# Git Worktree from Issue スキル

既存の GitHub Issue から Git Worktree を使って作業ブランチを作成する。

## ⚠️ 禁止事項

- **master/main ブランチで直接コード修正を行わない**
- **master/main ブランチで `git commit` や `git push` を提案しない**

## 実行手順

### 0. 古い Worktree の自動掃除

```bash
bash ~/.codex/skills/gh-pr-approve/cleanup-stale-worktrees.sh
```

### 1. 引数の確認と Issue 取得

**引数がある場合（例: `gh-worktree-from-issue 123`）:**

```bash
gh issue view <Issue番号> --json number,title,labels,state
```

**引数がない場合:** Open Issue 一覧を表示してユーザーに選択させる。

```bash
gh issue list --state open --json number,title,labels --limit 50
```

### 2. Issue タイトルからブランチ名を自動生成

- ラベルに `bug`, `fix`, `hotfix` → `fix/issue-<番号>-<スラッグ>`
- それ以外 → `feature/issue-<番号>-<スラッグ>`

### 3. Git Worktree コマンドの実行

bare 構造かどうかを検出:

```bash
GIT_COMMON=$(git rev-parse --git-common-dir)
if [ "$(basename "$GIT_COMMON")" = ".bare" ]; then
  CONTAINER_DIR="$(dirname "$GIT_COMMON")"
  WORKTREE_DIR="${CONTAINER_DIR}/<ブランチ種別>"
else
  PROJ=$(basename "$(git rev-parse --show-toplevel)")
  WORKTREE_DIR="../${PROJ}-<ブランチ種別>"
fi
git worktree add "$WORKTREE_DIR" -b <ブランチ名>
```

### 4. 空コミット + push + Draft PR 作成

```bash
cd "$WORKTREE_DIR"
git commit --allow-empty -m "chore: start work on #<Issue番号>"
git push -u origin <ブランチ名>
gh pr create --draft --title "WIP: <Issueタイトル>" --body "Closes #<Issue番号>

作業中..."
```

### 5. クリップボードにコピー

```bash
WORKTREE_ABSPATH="$(cd "$WORKTREE_DIR" && pwd)"
bash ~/.codex/skills/_shared/copy-to-clipboard.sh "cd ${WORKTREE_ABSPATH} && codex"
```

### 6. 完了メッセージ

```
Issue #<番号> から作業を開始しました。

Issue: <タイトル>
ブランチ: <ブランチ名>
Draft PR: #<PR番号>

📋 クリップボードにコピー済み: cd <Worktreeの絶対パス> && codex
新しいターミナルで貼り付けて作業を開始してください。
```
