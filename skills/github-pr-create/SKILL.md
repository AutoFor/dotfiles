---
name: github-pr-create
description: 作業完了時に GitHub PR を作成し、ブランチ名から Issue を検出して紐付けを行う。ユーザーが「作業が完了した」「PRを作成したい」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - mcp__github__create_pull_request
  - mcp__github__update_pull_request
  - mcp__github__issue_read
  - mcp__github__get_me
---

# GitHub PR 作成スキル

このスキルは、作業完了時にブランチ名から Issue 番号を検出し、PR を作成して紐付けを行います。

**Issue は `/git-worktree-branch`、`/git-worktree-from-issue`、または `/git-branch` で事前に作成済みであることが前提です。**

## 前提条件の確認

以下を確認してから手順を開始する：

- 作業ブランチに必要なコミットがすべて含まれている
- リモートリポジトリに `git push` 済みである
- コードが正常に動作する

## 実行手順

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
`/git-worktree-branch` で Issue を作成してから作業してください。
```

### 2. Issue 確認

`mcp__github__issue_read` で Issue の存在とタイトルを確認する。

### 3. PR 作成

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

### 5. ユーザーに確認を依頼

以下の確認文を表示する：

```
PR の作成が完了しました：

プルリクエスト: #[PR番号]
紐付けた Issue: #[Issue番号] - [Issueタイトル]

以下の内容をご確認ください：
- PR のタイトルと本文は適切か？
- 紐付けた Issue は正しいか？
- PR と Issue の紐付け（Closes #XX）は正しいか？

問題なければ、この PR を承認しますか？
（「はい」で承認プロセスに進みます。修正が必要な場合は修正内容をお伝えください。）
```

**ユーザーの回答に応じて:**
- 「はい」→ `/github-pr-approve` スキルを実行
- 修正依頼 → 修正作業に戻る

## 実行例

```bash
# 1. ブランチ名から Issue 番号を抽出
git branch --show-current
# → issue-17-add-dark-mode
# Issue #17 を検出

# 2. Issue 確認
# mcp__github__issue_read で Issue #17 の詳細を取得
# → タイトル: "ダークモード追加"

# 3. PR 作成
# mcp__github__create_pull_request で PR を作成
# → PR #18 作成

# 4. 紐付け確認 → PR 作成時に含めたので追加作業なし

# 5. ユーザーに確認
```

## 注意事項

- PR と Issue の内容は慎重に確認する
- ユーザーの承認を得るまで次のステップに進まない
- 修正依頼があった場合は、修正後に再度このスキルを実行する
