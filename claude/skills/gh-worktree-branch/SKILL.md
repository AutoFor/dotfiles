---
name: gh-worktree-branch
description: 新しい作業を開始するときに GitHub Issue を作成し、Git Worktree とブランチを作成する。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
---

# Git Worktree ブランチ作成スキル（Issue-first）

引数を Issue タイトルとして使用し、以下のフローを実行する。

## 実行フロー

### 0. コンテキスト取得

```bash
eval "$(bash ~/.claude/skills/_shared/detect-context.sh)"
```

### 1. GitHub Issue を作成

```bash
gh issue create --title "<ユーザーの引数をそのまま使用>" --body ""
```

出力 URL から Issue 番号を抽出する（例: `https://github.com/owner/repo/issues/17` → `17`）。

ブランチ名: `issue-<Issue番号>`（例: `issue-17`）

### 2. Worktree を作成

```bash
bash ~/.claude/skills/gh-worktree-branch/create-worktree.sh issue-<Issue番号>
```

### 3. Worktree ディレクトリに移動

スクリプト出力のディレクトリに `cd` する。

### 3a. 空コミットを作成して push

Worktree 作成直後は差分がないため、空コミットでブランチをリモートに push する：

```bash
git commit --allow-empty -m "chore: start work on #<Issue番号>"
git push -u origin issue-<Issue番号>
```

### 3b. Draft PR を作成

```bash
gh pr create --draft --title "WIP: <ユーザーの引数>" --body "Closes #<Issue番号>

作業中..."
```

### 4. 新しい pane で Claude Code を起動

```bash
if [ -n "$TMUX" ]; then
  tmux split-window -v -c "<Worktreeの絶対パス>" "claude"
else
  wezterm cli split-pane --cwd "<Worktreeの絶対パス>" -- claude
fi
```

### 5. 完了メッセージ

以下の形式で出力する：

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>
Draft PR: #<PR番号>

新しい pane で Claude Code を起動しました。
```

**これ以上何も出力しない。コード編集・次のステップの提案は一切しない。**
