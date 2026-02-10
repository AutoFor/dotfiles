---
name: github-pr-create
description: 作業完了時に GitHub PR と Issue を作成し、紐付けを行う。ユーザーが「作業が完了した」「PRを作成したい」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - mcp__github__create_pull_request
  - mcp__github__issue_write
  - mcp__github__update_pull_request
  - mcp__github__get_me
---

# GitHub PR・Issue 作成スキル

このスキルは、作業完了時に PR と Issue を作成し、紐付けまでを行う標準手順を提供します。

## 前提条件の確認

以下を確認してから手順を開始する：

- ✅ 作業ブランチに必要なコミットがすべて含まれている
- ✅ リモートリポジトリに `git push` 済みである
- ✅ コードが正常に動作する

## 実行手順

**必ず以下の順序で実行する：**

### 1. プルリクエスト（PR）作成

GitHub の MCP ツールまたは `gh` コマンドで PR を作成する。

**MCPツール使用例:**
```
mcp__github__create_pull_request を使用
- owner: <リポジトリオーナー>
- repo: <リポジトリ名>
- title: [作業内容を簡潔に記載]
- body: [変更内容の詳細]
- head: [作業ブランチ名]
- base: master（または main）
```

**gh コマンド例:**
```bash
gh pr create --title "機能追加: 新機能の実装" --body "詳細な変更内容"
```

**PR作成時のポイント:**
- タイトルは簡潔で分かりやすく（50文字以内推奨）
- 本文には変更の背景、実装内容、テスト結果を記載
- スクリーンショットやコード例があれば追加

### 2. イシュー（Issue）作成

作業テーマに対するイシューを作成する。

**MCPツール使用例:**
```
mcp__github__issue_write を使用
- method: create
- owner: <リポジトリオーナー>
- repo: <リポジトリ名>
- title: [作業テーマを記載]
- body: [作業の目的や背景を記載]
```

**gh コマンド例:**
```bash
gh issue create --title "機能の改善" --body "背景と目的"
```

**Issue作成時のポイント:**
- タイトルは作業テーマを明確に
- 本文には目的、背景、期待される成果を記載

### 3. PR と Issue を紐づけ

PR の本文に `Closes #イシュー番号` を追加して、PR と Issue を関連付ける。

**MCPツール使用例:**
```
mcp__github__update_pull_request を使用
- owner: <リポジトリオーナー>
- repo: <リポジトリ名>
- pullNumber: [PR番号]
- body: "変更内容...\n\nCloses #[Issue番号]"
```

**gh コマンド例:**
```bash
gh pr edit <PR番号> --body "変更内容

Closes #<Issue番号>"
```

**紐付けのメリット:**
- PR がマージされると Issue が自動でクローズされる
- 変更履歴と課題が明確に関連付けられる

### 4. ユーザーに確認を依頼

**以下の確認文をユーザーに提示する:**

```
PR と Issue の作成が完了しました：

📋 プルリクエスト: #[PR番号]
🎯 イシュー: #[Issue番号]

以下の内容をご確認ください：
- PR のタイトルと本文は適切か？
- Issue の内容は正確か？
- PR と Issue の紐付けは正しいか？

問題なければ、このPRを承認しますか？
（「はい」で承認プロセスに進みます。修正が必要な場合は修正内容をお伝えください。）
```

**ユーザーの回答に応じて:**
- 「はい」→ `/github-pr-approve` スキルを実行
- 修正依頼 → 修正作業に戻る

## 実行例

```bash
# 1. PRを作成
gh pr create --title "機能追加: 新機能の実装" --body "詳細な変更内容"
# 出力例: https://github.com/owner/repo/pull/44

# 2. イシューを作成
gh issue create --title "機能の改善" --body "背景と目的"
# 出力例: https://github.com/owner/repo/issues/45

# 3. PRとイシューを紐づけ（PRの本文に追記）
gh pr edit 44 --body "変更内容

Closes #45"

# 4. ユーザーに確認
# → 「PRとイシューを確認してください。承認しますか？」
```

## 注意事項

- PR と Issue の内容は慎重に確認する
- ユーザーの承認を得るまで次のステップに進まない
- 修正依頼があった場合は、修正後に再度このスキルを実行する

## よくある質問

**Q: PR と Issue はどちらを先に作るべきか？**
A: PR を先に作成してから Issue を作成し、PR に `Closes #XX` で紐付けます。

**Q: ユーザーが「いいえ」と答えた場合は？**
A: 修正内容を確認し、必要な修正を行ってから再度このスキルを実行します。
