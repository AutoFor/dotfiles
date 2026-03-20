---
name: gh-worktree-branch
description: 新しい作業を開始するときに GitHub Issue を作成し、Git Worktree とブランチを作成する。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
---

# Git Worktree ブランチ作成スキル

引数不要。仮タイトルでIssueを作り、worktreeを用意するだけ。

## 実行フロー

### 1. GitHub Issue を作成（仮タイトル固定）

```bash
gh issue create --title "WIP" --body ""
```

出力 URL から Issue 番号を抽出する（例: `https://github.com/owner/repo/issues/17` → `17`）。

### 2. Worktree を作成

```bash
bash ~/.claude/skills/gh-worktree-branch/create-worktree.sh issue-<Issue番号>
```

### 3. 完了メッセージ

```
Issue #<Issue番号> / 作業ディレクトリ: <Worktreeの絶対パス>
```

**これ以上何も出力しない。**
