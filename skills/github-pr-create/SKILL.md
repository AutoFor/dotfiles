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

### 0. 既存Issue番号の検出

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
   - パターン: `issue-123-20260210-143052` → Issue #123
   - パターン: `issue-123-20260210-143052-add-dark-mode` → Issue #123

**検出結果の処理:**

**ケース1: Issue番号が検出された場合**
```
🔍 既存Issue #<番号> を検出しました。
タイトル: <Issueタイトル>

このIssueに紐付けてPRを作成します。
新規Issueは作成しません。

→ ステップ1（Issue確認）で既存Issueを使用
→ ステップ2（ブランチ名変更）を判定
→ ステップ3（PR作成）に進む
```

**ケース2: Issue番号が見つからない場合**
```
ℹ️ 既存Issueが見つかりませんでした。
新規作業として、Issue を作成します。

→ ステップ1（Issue作成）を実行
→ ステップ2（ブランチ名変更）を判定
→ ステップ3（PR作成）に進む
```

### 1. Issue番号の確定（Issue作成または既存Issue確認）

**ステップ0で既存Issueが検出された場合:**
- ✅ 新規Issue作成はスキップ
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

### 2. ブランチ名変更（タイムスタンプブランチの場合のみ）

**適用条件:** 現在のブランチ名が `^[0-9]{8}-[0-9]{6}` で始まる場合のみ実行する。
（例: `20260210-143052` や `20260210-143052-add-dark-mode` のようなタイムスタンプベースのブランチ名）

それ以外のブランチ名（`feature/xxx`、`fix/xxx` 等）の場合はこのステップをスキップする。

**新ブランチ名:** `issue-<Issue番号>-<元のブランチ名>`
（例: `issue-123-20260210-143052`、`issue-123-20260210-143052-add-dark-mode`）

**実行コマンド:**
```bash
# 1. ローカルブランチをリネーム
git branch -m <旧ブランチ名> <新ブランチ名>

# 2. 新しい名前でリモートにpush
git push -u origin <新ブランチ名>

# 3. 旧リモートブランチを削除
git push origin --delete <旧ブランチ名>
```

**例:**
```bash
# タイムスタンプのみの場合
git branch -m 20260210-143052 issue-123-20260210-143052
git push -u origin issue-123-20260210-143052
git push origin --delete 20260210-143052

# テーマ付きの場合
git branch -m 20260210-143052-add-dark-mode issue-123-20260210-143052-add-dark-mode
git push -u origin issue-123-20260210-143052-add-dark-mode
git push origin --delete 20260210-143052-add-dark-mode
```

**変更後の表示:**
```
🔄 ブランチ名を変更しました: <旧ブランチ名> → issue-<番号>-<旧ブランチ名>
```

### 3. プルリクエスト（PR）作成

GitHub の MCP ツールまたは `gh` コマンドで PR を作成する。
PR の body に `Closes #<Issue番号>` を含めて、Issue との紐付けも同時に行う。

**MCPツール使用例:**
```
mcp__github__create_pull_request を使用
- owner: <リポジトリオーナー>
- repo: <リポジトリ名>
- title: [作業内容を簡潔に記載]
- body: "[変更内容の詳細]\n\nCloses #[Issue番号]"
- head: [作業ブランチ名（ステップ2で変更した場合は新しい名前）]
- base: master（または main）
```

**gh コマンド例:**
```bash
gh pr create --title "機能追加: 新機能の実装" --body "詳細な変更内容

Closes #<Issue番号>"
```

**PR作成時のポイント:**
- タイトルは簡潔で分かりやすく（50文字以内推奨）
- 本文には変更の背景、実装内容、テスト結果を記載
- スクリーンショットやコード例があれば追加
- `Closes #<Issue番号>` を必ず含める

### 4. PRとIssueの紐付け確認

PR作成時に `Closes #<Issue番号>` を含めているため、通常は追加作業不要。

PR作成時に紐付けが漏れた場合のみ、PR本文を更新する：

**MCPツール使用例:**
```
mcp__github__update_pull_request を使用
- owner: <リポジトリオーナー>
- repo: <リポジトリ名>
- pullNumber: [PR番号]
- body: "変更内容...\n\nCloses #[Issue番号]"
```

**紐付けのメリット:**
- PR がマージされると Issue が自動でクローズされる
- 変更履歴と課題が明確に関連付けられる

### 5. ユーザーに確認を依頼

**以下の確認文をユーザーに提示する:**

**既存Issueに紐付けた場合（ブランチ名変更あり）:**
```
✅ PR の作成が完了しました：

📋 プルリクエスト: #[PR番号]
🎯 紐付けた既存Issue: #[Issue番号] - [Issueタイトル]
🔄 ブランチ名: [旧ブランチ名] → [新ブランチ名]

以下の内容をご確認ください：
- PR のタイトルと本文は適切か？
- 紐付けたIssueは正しいか？
- PR と Issue の紐付け（Closes #XX）は正しいか？

問題なければ、このPRを承認しますか？
（「はい」で承認プロセスに進みます。修正が必要な場合は修正内容をお伝えください。）
```

**既存Issueに紐付けた場合（ブランチ名変更なし）:**
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

**新規Issueを作成した場合（ブランチ名変更あり）:**
```
✅ PR と Issue の作成が完了しました：

📋 プルリクエスト: #[PR番号]
🎯 新規イシュー: #[Issue番号]
🔄 ブランチ名: [旧ブランチ名] → [新ブランチ名]

以下の内容をご確認ください：
- PR のタイトルと本文は適切か？
- Issue の内容は正確か？
- PR と Issue の紐付けは正しいか？

問題なければ、このPRを承認しますか？
（「はい」で承認プロセスに進みます。修正が必要な場合は修正内容をお伝えください。）
```

**新規Issueを作成した場合（ブランチ名変更なし）:**
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

**ケース1: 既存Issueから作業（意味のあるブランチ名）**
```bash
# 0. 既存Issue番号を検出
git branch --show-current
# → feature/issue-123-preview-feature
# Issue #123 を検出

# MCPツールでIssue詳細を取得
# → タイトル: "プレビュー機能の追加"

# 1. Issue番号の確定 → 既存Issue #123を使用（作成スキップ）

# 2. ブランチ名変更 → スキップ（タイムスタンプブランチではない）

# 3. PRを作成
gh pr create --title "プレビュー機能の追加" --body "詳細な変更内容

Closes #123"
# 出力例: https://github.com/owner/repo/pull/44

# 4. 紐付け確認 → PR作成時に含めたので追加作業なし

# 5. ユーザーに確認
# → 「PRを確認してください。既存Issue #123に紐付けました。」
```

**ケース2: タイムスタンプブランチで新規作業（テーマなし）**
```bash
# 0. 既存Issue番号を検出
git branch --show-current
# → 20260210-143052
# Issue番号なし → 新規作業

# 1. Issue番号の確定 → 新規Issue作成
gh issue create --title "機能の改善" --body "背景と目的"
# 出力例: https://github.com/owner/repo/issues/45

# 2. ブランチ名変更（タイムスタンプブランチなので実行）
git branch -m 20260210-143052 issue-45-20260210-143052
git push -u origin issue-45-20260210-143052
git push origin --delete 20260210-143052
# → 🔄 ブランチ名: 20260210-143052 → issue-45-20260210-143052

# 3. PRを作成（新しいブランチ名で）
gh pr create --title "機能追加: 新機能の実装" --body "詳細な変更内容

Closes #45"
# 出力例: https://github.com/owner/repo/pull/46

# 4. 紐付け確認 → PR作成時に含めたので追加作業なし

# 5. ユーザーに確認
# → 「PRとIssueを確認してください。ブランチ名も変更しました。」
```

**ケース2b: テーマ付きタイムスタンプブランチで新規作業**
```bash
# 0. 既存Issue番号を検出
git branch --show-current
# → 20260210-143052-add-dark-mode
# Issue番号なし → 新規作業

# 1. Issue番号の確定 → 新規Issue作成
gh issue create --title "ダークモード追加" --body "背景と目的"
# 出力例: https://github.com/owner/repo/issues/45

# 2. ブランチ名変更（タイムスタンプベースなので実行）
git branch -m 20260210-143052-add-dark-mode issue-45-20260210-143052-add-dark-mode
git push -u origin issue-45-20260210-143052-add-dark-mode
git push origin --delete 20260210-143052-add-dark-mode
# → 🔄 ブランチ名: 20260210-143052-add-dark-mode → issue-45-20260210-143052-add-dark-mode

# 3. PRを作成（新しいブランチ名で）
gh pr create --title "feat: ダークモード追加" --body "詳細な変更内容

Closes #45"

# 4. 紐付け確認 → PR作成時に含めたので追加作業なし

# 5. ユーザーに確認
```

**ケース3: 意味のあるブランチ名で新規作業（従来通り）**
```bash
# 0. 既存Issue番号を検出
git branch --show-current
# → feature/add-preview
# Issue番号なし → 新規作業

# 1. Issue番号の確定 → 新規Issue作成
gh issue create --title "機能の改善" --body "背景と目的"
# 出力例: https://github.com/owner/repo/issues/45

# 2. ブランチ名変更 → スキップ（タイムスタンプブランチではない）

# 3. PRを作成
gh pr create --title "機能追加: 新機能の実装" --body "詳細な変更内容

Closes #45"
# 出力例: https://github.com/owner/repo/pull/46

# 4. 紐付け確認 → PR作成時に含めたので追加作業なし

# 5. ユーザーに確認
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
A: Issue番号を先に確定してからPRを作成します。これにより、タイムスタンプブランチのリネームやPR本文への `Closes #XX` 記載がスムーズに行えます。

**Q: タイムスタンプブランチとは何ですか？**
A: `/git-worktree-branch` で即時作成されるブランチ名です。テーマなしの場合は `YYYYMMDD-HHMMSS`（例: `20260210-143052`）、テーマありの場合は `YYYYMMDD-HHMMSS-<テーマ>`（例: `20260210-143052-add-dark-mode`）の形式です。PR作成時にIssue番号が確定するため、そのタイミングで先頭に `issue-XX-` が付加されます。

**Q: ブランチ名の変更に失敗した場合は？**
A: ブランチ名の変更は必須ではありません。失敗した場合はエラーを表示し、元のブランチ名のままPR作成を続行します。

**Q: ユーザーが「いいえ」と答えた場合は？**
A: 修正内容を確認し、必要な修正を行ってから再度このスキルを実行します。
