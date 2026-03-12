---
name: gh-pr-create
description: 作業完了時に GitHub PR を作成し、ブランチ名から Issue を検出して紐付けを行う。ユーザーが「作業が完了した」「PRを作成したい」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
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
git diff
git diff --cached
```

**変更がある場合:**

変更ファイルをテーマ（機能追加・バグ修正・設定変更・ドキュメント）でグループ化し、グループごとにコミットを作成する：

```bash
git add <file1> <file2> ...
git commit -m "<type>: <日本語で簡潔な説明>"
```

Conventional Commits プレフィックス: `feat` / `fix` / `chore` / `docs` / `refactor` / `test` / `style`

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

```bash
gh issue view <Issue番号> --json number,title,state
```

Issue の存在とタイトルを確認する。

### 2a. 既存 Draft PR を検索

現在のブランチに対する Draft PR が既に存在するか確認する：

```bash
gh pr list --head <ブランチ名> --state open --json number,isDraft,title
```

- **Draft PR あり** → ステップ 3A へ
- **Draft PR なし** → ステップ 3B へ

### 3A. Draft PR を Ready for Review に変更

既存の Draft PR がある場合、以下の手順で Ready for Review に変更する：

1. `gh api` でタイトル・本文を最終版に更新する（`gh pr edit` は Projects classic 廃止の影響でエラーになるため使用しない）
   - タイトル: `WIP:` プレフィックスを除去し、作業内容を簡潔に記載
   - 本文: 変更内容の詳細を記載（`Closes #<Issue番号>` は維持）

```bash
gh api repos/<owner>/<repo>/pulls/<PR番号> -X PATCH \
  -f title="<タイトル>" \
  -f body="<本文>"
```

2. `gh pr ready <PR番号>` で Draft を解除する

### 3B. 新規 PR 作成（Draft PR がない場合）

```bash
gh pr create \
  --title "<作業内容を簡潔に記載>" \
  --body "$(cat <<'EOF'
<変更の背景と実装内容>

Closes #<Issue番号>
EOF
)"
```

**PR作成時のポイント:**
- タイトルは簡潔で分かりやすく（50文字以内推奨）
- 本文には変更の背景、実装内容を記載
- `Closes #<Issue番号>` を必ず含める

### 4. PR と Issue の紐付け確認

PR 作成時に `Closes #<Issue番号>` を含めているため、通常は追加作業不要。

漏れた場合のみ `gh api repos/<owner>/<repo>/pulls/<PR番号> -X PATCH -f body="..."` で PR 本文を更新する。

### 5. 自動で承認プロセスに進む

PR 作成完了後、確認を挟まずに以下のステップをインラインで実行する。

**5a. CWD をメインリポジトリに移動（Worktree 使用時は必須）**

```bash
git worktree list
```

出力1行目のパスに `cd` する（単独 Bash コマンドとして実行）。

**5b. GitHub App Bot で PR 承認**

```bash
bash ~/.claude/skills/gh-pr-approve/approve-pr.sh <owner> <repo> <PR番号>
```

**5c. PR マージ**

```bash
gh pr merge <PR番号> --squash
```

**5d. Issue クローズ確認**

PR 本文に `Closes #XX` があれば自動でクローズされるが、念のため確認する。手動クローズが必要な場合：

```bash
gh issue close <Issue番号>
```

**5e. 後処理（ブランチ切り替え・Worktree 削除）**

```bash
bash ~/.claude/skills/gh-pr-approve/cleanup-after-merge.sh <メインリポジトリの絶対パス> <Worktreeパス or none> <デフォルトブランチ> <ブランチ名>
```

## 実行例

**Draft PR がある場合:**

```bash
# 1. ブランチ名から Issue 番号を抽出
git branch --show-current
# → issue-17-add-dark-mode
# Issue #17 を検出

# 2. Issue 確認
gh issue view 17 --json number,title,state

# 2a. Draft PR を検索
gh pr list --head issue-17-add-dark-mode --state open --json number,isDraft,title
# → [{"isDraft":true,"number":18,"title":"WIP: ダークモード追加"}]

# 3A. Draft PR を Ready for Review に変更
# gh api repos/owner/repo/pulls/18 -X PATCH -f title="..." -f body="..."
# gh pr ready 18 で Draft 解除

# 5. 承認・マージ・後処理をインライン実行
```

**Draft PR がない場合:**

```bash
# 1〜2a. 同上（Draft PR なし）

# 3B. 新規 PR 作成
gh pr create --title "ダークモード追加" --body "..."
# → PR #18 作成

# 5. 承認・マージ・後処理をインライン実行
```

## 注意事項

- PR と Issue の内容は慎重に確認する
- PR 作成後は自動で承認・マージまで進む
