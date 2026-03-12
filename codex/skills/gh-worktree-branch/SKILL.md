---
name: gh-worktree-branch
description: 新しい作業を開始するときに GitHub Issue を作成し、Git Worktree とブランチを作成する。ユーザーが「新しい機能を追加したい」「作業を開始したい」「Issue を作って作業したい」「gh-worktree-branch」と言ったときに使用する。引数（作業内容）が必要。
---

# Git Worktree ブランチ作成スキル（Issue-first）

## 引数の処理

- **引数なし**: 「作業内容を伝えてください」と表示して停止する。
- **引数あり**: 引数を Issue タイトルとして使用し、以下のフローを実行する。

## 実行フロー（引数ありの場合）

### 0. 古い Worktree の自動掃除

```bash
bash ~/.codex/skills/gh-pr-approve/cleanup-stale-worktrees.sh
```

### 1. リポジトリ情報を取得

```bash
git remote -v
```

`owner` と `repo` を特定する。

### 2. GitHub Issue を作成

```bash
gh issue create --title "<ユーザーの引数>" --body "<作業の概要を簡潔に記載>"
```

出力 URL から Issue 番号を抽出する。

### 3. ブランチ名を生成

1. ユーザーの引数を英語スラッグに変換（小文字・ハイフン・3〜5語）
2. ブランチ名: `issue-<Issue番号>-<英語スラッグ>`（例: `issue-17-add-dark-mode`）

### 4. Worktree を作成

```bash
bash ~/.codex/skills/gh-worktree-branch/create-worktree.sh <ブランチ名>
```

### 5. Worktree ディレクトリに移動し、空コミット + push

```bash
git commit --allow-empty -m "chore: start work on #<Issue番号>"
git push -u origin <ブランチ名>
```

### 5b. Draft PR を作成

```bash
gh pr create --draft --title "WIP: <Issueタイトル>" --body "Closes #<Issue番号>

作業中..."
```

### 6. クリップボードにコピー

```bash
bash ~/.codex/skills/_shared/copy-to-clipboard.sh "cd <Worktreeの絶対パス> && codex"
```

### 7. 完了メッセージ

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>
Draft PR: #<PR番号>

📋 クリップボードにコピー済み: cd <Worktreeの絶対パス> && codex
新しいターミナルで貼り付けて作業を開始してください。
```

**これ以上何も出力しない。コード編集・次のステップの提案は一切しない。**
