---
name: gh-pr-create
description: 作業完了時に GitHub PR を作成し、ブランチ名から Issue を検出して紐付けを行う。ユーザーが「作業が完了した」「PRを作成したい」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Skill
  - mcp__github__create_pull_request
  - mcp__github__update_pull_request
  - mcp__github__issue_read
  - mcp__github__get_me
---

# GitHub PR 作成スキル

このスキルは、作業完了時にブランチ名から Issue 番号を検出し、PR を作成して紐付けを行います。

**Issue は `/gh-worktree-branch`、`/gh-worktree-from-issue`、または `/gh-branch` で事前に作成済みであることが前提です。**

## 前提条件の確認

以下を確認してから手順を開始する：

- コードが正常に動作する
- 未コミットの変更がある場合はステップ0で自動コミットする

## 実行手順

### 0. コミットとプッシュ

未コミットの変更があるか確認する：

```bash
git status --short
```

**変更がある場合:**
`/smart-commit` スキルを実行してコミットを作成する。

**コミット完了後（または変更がない場合）:**
リモートにプッシュする：

```bash
git push -u origin <ブランチ名>
```

### 1. ブランチ名から Issue 番号を抽出

```bash
git branch --show-current
```

以下のパターンで `issue-(\d+)` を抽出する：
- `issue-17-add-dark-mode` → Issue #17
- `feature/issue-17-add-dark-mode` → Issue #17
- `fix/issue-17-fix-login-bug` → Issue #17

**Issue 番号が見つからない場合:**

以下を表示して **停止する**：

```
ブランチ名から Issue 番号を検出できませんでした。
`/gh-worktree-branch` で Issue を作成してから作業してください。
```

### 2. Issue 確認

`mcp__github__issue_read` で Issue の存在とタイトルを確認する。

### 2a. 既存 Draft PR を検索

現在のブランチに対する Draft PR が既に存在するか確認する：

```bash
gh pr list --head <ブランチ名> --state open --json number,isDraft,title
```

- **Draft PR あり** → ステップ 3A へ
- **Draft PR なし** → ステップ 3B へ

### 3A. Draft PR を Ready for Review に変更

既存の Draft PR がある場合、以下の手順で Ready for Review に変更する：

1. `mcp__github__update_pull_request` でタイトル・本文を最終版に更新する
   - タイトル: `WIP:` プレフィックスを除去し、作業内容を簡潔に記載
   - 本文: 変更内容の詳細を記載（`Closes #<Issue番号>` は維持）
2. `gh pr ready <PR番号>` で Draft を解除する

### 3B. 新規 PR 作成（Draft PR がない場合）

`mcp__github__create_pull_request` を使用：
- owner: （リポジトリオーナー）
- repo: （リポジトリ名）
- title: 作業内容を簡潔に記載
- body: 変更内容の詳細 + `Closes #<Issue番号>`
- head: 現在のブランチ名
- base: main（または master）

**PR作成時のポイント:**
- タイトルは簡潔で分かりやすく（50文字以内推奨）
- 本文には変更の背景、実装内容を記載
- `Closes #<Issue番号>` を必ず含める

### 4. PR と Issue の紐付け確認

PR 作成時に `Closes #<Issue番号>` を含めているため、通常は追加作業不要。

漏れた場合のみ `mcp__github__update_pull_request` で PR 本文を更新する。

### 5. 自動で承認プロセスに進む

PR 作成完了後、確認を挟まずに `/gh-pr-approve` スキルを Skill ツールで呼び出して承認・マージまで自動で進める。

## 実行例

**Draft PR がある場合:**

```bash
# 1. ブランチ名から Issue 番号を抽出
git branch --show-current
# → issue-17-add-dark-mode
# Issue #17 を検出

# 2. Issue 確認
# mcp__github__issue_read で Issue #17 の詳細を取得

# 2a. Draft PR を検索
gh pr list --head issue-17-add-dark-mode --state open --json number,isDraft,title
# → [{"isDraft":true,"number":18,"title":"WIP: ダークモード追加"}]

# 3A. Draft PR を Ready for Review に変更
# mcp__github__update_pull_request でタイトル・本文を更新
# gh pr ready 18 で Draft 解除

# 5. ユーザーに確認
```

**Draft PR がない場合（後方互換）:**

```bash
# 1〜2a. 同上（Draft PR なし）

# 3B. 新規 PR 作成
# mcp__github__create_pull_request で PR を作成
# → PR #18 作成

# 5. ユーザーに確認
```

## 注意事項

- PR と Issue の内容は慎重に確認する
- PR 作成後は自動で承認・マージまで進む
