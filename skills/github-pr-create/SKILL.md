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
  - mcp__github__issue_read
  - mcp__github__search_issues
  - mcp__github__get_me
---

# GitHub PR・Issue 作成スキル

このスキルは、作業完了時に PR と Issue を作成し、紐付けまでを行う標準手順を提供します。

**既存Issue自動検出機能:**
- ✅ 会話履歴やブランチ名から既存Issue番号を検出
- ✅ 既存Issueがある場合: 新規Issue作成をスキップして既存Issueに紐付け
- ✅ 既存Issueがない場合: 新規Issue作成（従来通り）

## 前提条件の確認

以下を確認してから手順を開始する：

- ✅ 作業ブランチに必要なコミットがすべて含まれている
- ✅ リモートリポジトリに `git push` 済みである
- ✅ コードが正常に動作する

## 実行手順

**必ず以下の順序で実行する：**

### 0. 既存Issue番号の検出（新規追加）

会話履歴とブランチ名から既存Issue番号を検出する。

**検出パターン:**
1. **会話履歴を確認:**
   - ユーザーが言及したIssue番号（例: 「Issue #123で作業した」）
   - `/git-worktree-from-issue` スキルで指定したIssue番号
   - 会話内の「#123」のようなIssue番号参照

2. **ブランチ名を確認:**
   ```bash
   git branch --show-current
   ```
   - パターン: `feature/issue-123-xxx` → Issue #123
   - パターン: `fix/issue-456-xxx` → Issue #456

**検出結果の処理:**

**ケース1: Issue番号が検出された場合**
```
🔍 既存Issue #<番号> を検出しました。
タイトル: <Issueタイトル>

このIssueに紐付けてPRを作成します。
新規Issueは作成しません。

→ ステップ1（PR作成）に進む
→ ステップ2（Issue作成）はスキップ
→ ステップ3（紐付け）で既存Issueと紐付け
```

**ケース2: Issue番号が見つからない場合**
```
ℹ️ 既存Issueが見つかりませんでした。
新規作業として、Issue を作成します。

→ ステップ1（PR作成）に進む
→ ステップ2（Issue作成）を実行
→ ステップ3（紐付け）で新規Issueと紐付け
```

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

### 2. イシュー（Issue）作成または既存Issue確認

**ステップ0で既存Issueが検出された場合:**
- ✅ このステップはスキップ
- ✅ 検出されたIssue番号を使用

**既存Issueが見つからなかった場合（新規作業）:**

作業テーマに対する新規イシューを作成する。

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

**既存Issueに紐付けた場合:**
```
✅ PR の作成が完了しました：

📋 プルリクエスト: #[PR番号]
🎯 紐付けた既存Issue: #[Issue番号] - [Issueタイトル]

以下の内容をご確認ください：
- PR のタイトルと本文は適切か？
- 紐付けたIssueは正しいか？
- PR と Issue の紐付け（Closes #XX）は正しいか？

問題なければ、このPRを承認しますか？
（「はい」で承認プロセスに進みます。修正が必要な場合は修正内容をお伝えください。）
```

**新規Issueを作成した場合（従来通り）:**
```
✅ PR と Issue の作成が完了しました：

📋 プルリクエスト: #[PR番号]
🎯 新規イシュー: #[Issue番号]

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

**ケース1: 既存Issueから作業を開始した場合**
```bash
# 0. 既存Issue番号を検出
git branch --show-current
# → feature/issue-123-preview-feature
# Issue #123 を検出

# MCPツールでIssue詳細を取得
# → タイトル: "プレビュー機能の追加"

# 1. PRを作成
gh pr create --title "プレビュー機能の追加" --body "詳細な変更内容

Closes #123"
# 出力例: https://github.com/owner/repo/pull/44

# 2. Issue作成はスキップ（既存Issue #123を使用）

# 3. PRとIssueは既に紐付け済み（ステップ1で実施）

# 4. ユーザーに確認
# → 「PRを確認してください。既存Issue #123に紐付けました。」
```

**ケース2: 新規作業から開始した場合（従来通り）**
```bash
# 0. 既存Issue番号を検出
git branch --show-current
# → feature/add-preview
# Issue番号なし → 新規作業

# 1. PRを作成
gh pr create --title "機能追加: 新機能の実装" --body "詳細な変更内容"
# 出力例: https://github.com/owner/repo/pull/44

# 2. 新規イシューを作成
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

**Q: 既存Issueの検出は自動で行われますか？**
A: はい。会話履歴とブランチ名から自動で検出します。`/git-worktree-from-issue` を使った場合は必ず検出されます。

**Q: 既存Issueがあるのに検出されなかった場合は？**
A: ブランチ名に `issue-123` の形式でIssue番号が含まれていない可能性があります。手動でPR本文に `Closes #123` を追記してください。

**Q: 新規Issueと既存Issueのどちらになるか確認したい場合は？**
A: スキル実行時に「ステップ0」で検出結果が表示されます。既存Issueが検出された場合は明示的に通知されます。

**Q: PR と Issue はどちらを先に作るべきか？**
A: 既存Issueの場合はPRのみ作成します。新規作業の場合はPRを先に作成してからIssueを作成し、`Closes #XX`で紐付けます。

**Q: ユーザーが「いいえ」と答えた場合は？**
A: 修正内容を確認し、必要な修正を行ってから再度このスキルを実行します。
