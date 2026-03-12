---
name: gh-pr-create
description: 作業完了時に GitHub PR を作成し、ブランチ名から Issue を検出して紐付けを行い、承認・マージまで自動実行する。ユーザーが「作業が完了した」「PR を作成したい」「マージして」「gh-pr-create」と言ったときに使用する。
---

# GitHub PR 作成スキル

作業完了時にブランチ名から Issue 番号を検出し、PR を作成・承認・マージまで実行する。

## サンドボックス制約時の再実行ルール

- `gh issue view` / `gh pr list` / `gh api` / `gh pr create` / `gh pr merge` / `gh issue close` などで
  `error connecting to api.github.com` が出たら、失敗コマンドを**権限昇格付きで再実行**する。
- 権限昇格時の理由は短く具体的にする（例: `GitHub API に接続して PR 操作を行うため`）。
- API 呼び出しは失敗を放置せず、その場で再実行してから次のステップへ進む。

## 前提条件

- コードが正常に動作すること
- Issue は `gh-worktree-branch`、`gh-worktree-from-issue`、または `gh-branch` で事前作成済み

## 実行手順

### 0. コミットとプッシュ

```bash
git status --short
git diff
git diff --cached
```

変更がある場合はテーマでグループ化してコミット:

```bash
git add <file1> <file2> ...
git commit -m "<type>: <日本語説明>"
```

Conventional Commits: `feat` / `fix` / `chore` / `docs` / `refactor` / `test` / `style`

プッシュ:

```bash
git push -u origin <ブランチ名>
```

### 1. ブランチ名から Issue 番号を抽出

```bash
git branch --show-current
```

`issue-(\d+)` パターンで抽出する。見つからない場合は停止する。

### 2. Issue 確認

```bash
gh issue view <Issue番号> --json number,title,state
```

### 2a. 既存 Draft PR を検索

```bash
gh pr list --head <ブランチ名> --state open --json number,isDraft,title
```

### 3A. Draft PR あり → Ready for Review に変更

```bash
gh api repos/<owner>/<repo>/pulls/<PR番号> -X PATCH \
  -f title="<WIPプレフィックスを除いたタイトル>" \
  -f body="<変更内容>

Closes #<Issue番号>"
gh pr ready <PR番号>
```

### 3B. Draft PR なし → 新規 PR 作成

```bash
gh pr create \
  --title "<作業内容を簡潔に記載>" \
  --body "$(cat <<'EOF'
<変更の背景と実装内容>

Closes #<Issue番号>
EOF
)"
```

### 4. 承認・マージ

**4a. CWD をメインリポジトリに移動（Worktree 使用時は必須）**

```bash
git worktree list
```

出力1行目のパス（bare 構造の場合はデフォルトブランチのパス）に `cd` する。

**4b. GitHub App Bot で PR 承認**

```bash
bash ~/.codex/skills/gh-pr-approve/approve-pr.sh <owner> <repo> <PR番号>
```

**4c. PR マージ**

```bash
gh pr merge <PR番号> --squash
```

**4d. Issue クローズ確認**

```bash
gh issue view <Issue番号> --json state
# CLOSED でない場合:
gh issue close <Issue番号>
```

**4e. 後処理**

```bash
bash ~/.codex/skills/gh-pr-approve/cleanup-after-merge.sh <メインリポジトリパス> <Worktreeパス or none> <デフォルトブランチ> <ブランチ名>
```
