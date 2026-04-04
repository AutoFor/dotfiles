---
name: gh-worktree-from-issue
description: 既存の GitHub Issue から Git Worktree を使った作業ブランチを作成する。ユーザーが「Issue #123 から作業を開始したい」「既存のIssueで作業する」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
---

# Git Worktree from Issue スキル

このスキルは、既存の GitHub Issue から Git Worktree を使って作業ブランチを作成する標準手順を提供します。

## ⚠️ 重要な禁止事項

- **master（またはmain）ブランチで直接コード修正を行わない**
- **master ブランチで `git commit` や `git push` を提案しない**
- 既存Issueから作業を開始する際は、必ずこのスキルを使用する

## 実行手順

### 0. 古い Worktree の自動掃除

前回のセッションで削除が遅延された Worktree がある場合、自動的に削除する:

```bash
bash ~/.codex/skills/gh-pr-approve/cleanup-stale-worktrees.sh
```

出力がない場合は掃除不要。

### 1. 引数の確認とIssue取得

**引数がある場合（例: `/gh-worktree-from-issue 123`）:**
- 指定されたIssue番号の詳細を取得

```bash
gh issue view <Issue番号> --json number,title,labels,state
```

**引数がない場合:**
- リポジトリのOpen状態のIssue一覧を取得してユーザーに選択肢を提示

```bash
gh issue list --state open --json number,title,labels --limit 50
```

**Issue一覧の表示例:**
```
以下のOpen Issueが見つかりました:

1. #123 - プレビュー機能の追加 (feature)
2. #124 - パースエラーの修正 (bug)
3. #125 - ドキュメント更新 (documentation)

どのIssueで作業を開始しますか？番号を入力してください:
```

### 2. Issueタイトルからブランチ名を自動生成

Issue情報から適切なブランチ名を生成する。

**生成ルール:**
1. Issueのラベルまたはタイトルから `feature` or `fix` を判定
   - ラベルに `bug`, `fix`, `hotfix` が含まれる → `fix/`
   - それ以外 → `feature/`
2. Issue番号を必ず含める: `issue-<番号>`
3. タイトルから主要なキーワードを抽出（英数字、ハイフン区切り）

**生成例:**
```
Issue #123: "プレビュー機能の追加" (ラベル: enhancement)
  → feature/issue-123-preview-feature

Issue #456: "Fix: パースエラーの修正" (ラベル: bug)
  → fix/issue-456-parse-error

Issue #789: "ドキュメント更新" (ラベル: documentation)
  → feature/issue-789-document-update
```

**日本語タイトルの英語変換例（簡易的）:**
- "追加" → "add"
- "修正" → "fix"
- "更新" → "update"
- "改善" → "improve"
- "削除" → "remove"

### 3. Git リポジトリ情報の取得

現在のリポジトリ名を取得する:
```bash
git remote -v
```

プロジェクト名を抽出（例: `codex-config`）

### 4. Git Worktree コマンドの実行

`create-worktree.sh` に委譲する（モード自動検出）:

```bash
bash ~/.codex/skills/gh-worktree-branch/create-worktree.sh <ブランチ名>
```

スクリプトが以下の優先順位でモードを自動検出する:
1. **モード1**: `.bare` worktree 内 → コンテナ内にサブディレクトリとして作成
2. **モード2**: `~/.git-worktrees/github.com/<owner>/<repo>/.bare` が存在 → そちらに作成
3. **モード3**: 従来通り隣接ディレクトリ（`../<proj>-<branch>`）に作成

出力の `ディレクトリ: ` 行から `WORKTREE_DIR` を取得する:

```bash
OUTPUT=$(bash ~/.codex/skills/gh-worktree-branch/create-worktree.sh <ブランチ名>)
echo "$OUTPUT"
WORKTREE_DIR=$(echo "$OUTPUT" | grep "^ディレクトリ: " | sed 's/^ディレクトリ: //')
```

### 5. 作業ディレクトリへの移動

ステップ 4 で取得した `WORKTREE_DIR` に移動する:

```bash
cd "$WORKTREE_DIR"
```

### 5a. 空コミットを作成して push

Worktree 作成直後は差分がないため、空コミットでブランチをリモートに push する：

```bash
git commit --allow-empty -m "chore: start work on #<Issue番号>"
git push -u origin <ブランチ名>
```

### 5b. Draft PR を作成

```bash
gh pr create --draft --title "WIP: <Issueタイトル>" --body "Closes #<Issue番号>

作業中..."
```

### 5c. クリップボードにコピー

Worktree の絶対パスを取得し、クリップボードにコピーする：

```bash
WORKTREE_ABSPATH="$(cd "$WORKTREE_DIR" && pwd)"
bash ~/.codex/skills/_shared/copy-to-clipboard.sh "cd ${WORKTREE_ABSPATH} && codex"
```

- コマンドが **成功** した場合 → 完了メッセージに「📋 クリップボードにコピー済み」と表示
- コマンドが **失敗** した場合 → 完了メッセージに「⚠ 手動でコピーしてください」と表示し、コピー用テキストをそのまま表示

### 6. 作業開始の確認メッセージ

ユーザーに以下のメッセージを表示:

```
Issue #<番号> から作業を開始しました。

Issue: <タイトル>
ブランチ: <ブランチ名>
作業ディレクトリ: ../<プロジェクト名>-<ブランチ種別>
Draft PR: #<PR番号>

📋 クリップボードにコピー済み: cd <Worktreeの絶対パス> && codex
新しいターミナルで貼り付けて作業を開始してください。

作業完了後は `/gh-pr-create` で Draft PR を Ready for Review に変更してください。
```

## 実行例

```bash
# ユーザー入力: /gh-worktree-from-issue 123

# 1. Issue #123 の情報を取得
# タイトル: "プレビュー機能の追加"
# ラベル: enhancement

# 2. ブランチ名を生成
# → feature/issue-123-preview-feature

# 3. Worktree を作成（create-worktree.sh に委譲）
OUTPUT=$(bash ~/.codex/skills/gh-worktree-branch/create-worktree.sh feature/issue-123-preview-feature)
WORKTREE_DIR=$(echo "$OUTPUT" | grep "^ディレクトリ: " | sed 's/^ディレクトリ: //')
# ~/.git-worktrees/... または ../codex-config-feature に作成される

# 4. ディレクトリに移動
cd "$WORKTREE_DIR"

# 5a. 空コミット + push
git commit --allow-empty -m "chore: start work on #123"
git push -u origin feature/issue-123-preview-feature

# 5b. Draft PR を作成
gh pr create --draft --title "WIP: プレビュー機能の追加" --body "Closes #123

作業中..."
# → Draft PR #124 作成

# 6. 確認メッセージを表示
# "Issue #123 から作業を開始しました..."
```

## Worktree のメリット

- ✅ ブランチ切り替え時のファイル変更が不要
- ✅ ビルドや node_modules 再構築が不要
- ✅ 緊急対応が入っても作業中のコードを退避する必要がない
- ✅ 複数の作業を並行して進められる

## 注意事項

- **Issue番号は必ずブランチ名に含める**（後でPR作成時に紐付けるため）
- Worktreeを削除する前にコミット・プッシュを忘れずに行う
- `.git` フォルダは元のリポジトリで共有される
- PRマージ後は忘れずにWorktreeを削除する

## 次のステップ

作業完了後は、以下のスキルを使用して Draft PR を Ready for Review に変更:
- `/gh-pr-create` - 既存 Draft PR を検出して Ready for Review に変更（Draft PR がない場合は新規作成）

## Worktree 一覧の確認

必要に応じて、以下のコマンドで現在のWorktree一覧を確認できる:

```bash
git worktree list
```