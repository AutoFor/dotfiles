---
name: gh-finish
description: 作業完了時に一気にマージまで実行する。ブランチ上なら PR 作成→マージ、main 上なら Issue・ブランチ作成から PR マージまで自動判定。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# GitHub 作業完了スキル（完全インライン版）

現在のブランチ状態を判定し、Issue 作成〜マージまでをすべてインラインで実行する。
Skill ツールによるサブスキル委譲は行わない。

## 絶対禁止事項

- `gh pr review --approve` は使用しないこと（自分の PR は GitHub の仕様上承認できない）
- Skill ツールでサブスキルを呼び出さないこと

---

## Step 0: ブランチ判定

```bash
git branch --show-current
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
```

- 現在ブランチ = デフォルトブランチ → **フロー A**（Step A-1 へ）
- 現在ブランチ ≠ デフォルトブランチ → **フロー B**（Step B-0 へ）

---

## フロー A: main/master 上にいる場合

### Step A-1: リポジトリ情報を取得

```bash
git remote -v
```

`owner` と `repo` を特定する。

→ Step A-2 へ

### Step A-2: 変更内容を収集

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
git status --short
git diff
git diff --cached
git log origin/<デフォルトブランチ>..HEAD --oneline
```

**変更が一切ない場合**（status・diff・未プッシュコミットすべて空）:
「変更がありません。」と表示して停止する。

→ Step A-3 へ

### Step A-3: Issue タイトルを自動生成

Step A-2 の diff・status・コミットログを分析し、日本語で簡潔な Issue タイトルを生成する。

例: `hooks設定を新フォーマットに修正` / `ダークモード対応を追加`

→ Step A-4 へ

### Step A-4: GitHub Issue を作成

```bash
gh issue create \
  --title "<自動生成タイトル>" \
  --body "<diff に基づいた作業概要>"
```

出力 URL から Issue 番号を記録する。

→ Step A-5 へ

### Step A-5: ブランチを作成

1. Issue タイトルを英語スラッグに変換（小文字・ハイフン・3〜5語）
2. ブランチ名: `issue-<Issue番号>-<英語スラッグ>`

**未プッシュコミットがある場合:**
```bash
git checkout -b <ブランチ名>
git branch -f <デフォルトブランチ> origin/<デフォルトブランチ>
```

**未プッシュコミットがない場合:**
```bash
git checkout -b <ブランチ名>
```

→ Step A-6 へ

### Step A-6: 変更をコミット（スマートコミット）

未コミットの変更がない場合はスキップして Step A-7 へ。

変更ファイルをテーマ（機能追加・修正・設定変更・ドキュメントなど）でグループ化し、グループごとにコミットする:

```bash
git add <ファイル1> <ファイル2> ...
git commit -m "<type>: <日本語説明>"
```

コミットメッセージは Conventional Commits 形式（`feat`/`fix`/`chore`/`docs`/`refactor`/`test`/`style`）。

→ Step A-7 へ

### Step A-7: プッシュして Draft PR を作成

```bash
git push -u origin <ブランチ名>
```

```bash
gh pr create \
  --draft \
  --title "WIP: <Issueタイトル>" \
  --body "Closes #<Issue番号>

作業中..." \
  --head "<ブランチ名>" \
  --base "<デフォルトブランチ>"
```

→ **Step 1（共通）** へ

---

## フロー B: feature ブランチ上にいる場合

### Step B-0: 変更状態を確認

```bash
git status --short
git log @{u}..HEAD --oneline 2>/dev/null
```

- 未コミットの変更あり → Step B-1 へ
- 未プッシュのコミットあり → `git push` して **Step 1（共通）** へ
- すべて完了済み → **Step 1（共通）** へ

### Step B-1: 変更をコミット（スマートコミット）

```bash
git diff
git diff --cached
```

変更ファイルをテーマでグループ化し、グループごとにコミットする:

```bash
git add <ファイル1> <ファイル2> ...
git commit -m "<type>: <日本語説明>"
```

```bash
git push -u origin $(git branch --show-current)
```

→ **Step 1（共通）** へ

---

## Step 1（共通）: メインリポジトリパスを記録

```bash
git worktree list
```

**MAIN_REPO の決定ルール（Step 5 で使用）:**

- `git rev-parse --show-toplevel` の出力を MAIN_REPO とする
- ただし bare worktree 構造（`.bare` ディレクトリがある場合）は、`git worktree list` でデフォルトブランチ（master/main）のワークツリーパスを MAIN_REPO とする
  - bare リポジトリのパス（`.bare`）は絶対に MAIN_REPO に使わないこと（bare repo では `git checkout` が実行できない）
- Worktree なし（1行のみ）の場合、現在の作業ディレクトリを MAIN_REPO、Worktree パスは `none` として扱う

→ Step 2 へ

---

## Step 2（共通）: Wiki ドキュメント更新（オプション）

> 失敗してもマージ処理は続行する。

### Step 2-1: ブランチの変更差分を取得

```bash
git fetch origin <デフォルトブランチ>
git log origin/<デフォルトブランチ>..HEAD --oneline
git diff origin/<デフォルトブランチ>...HEAD --name-only
git diff origin/<デフォルトブランチ>...HEAD
```

→ Step 2-2 へ

### Step 2-2: docs/wiki/ の存在確認

存在しない場合はステップ 2 全体をスキップして Step 3 へ。
存在する場合は既存の Markdown ファイルを Read で読み込む。

→ Step 2-3 へ

### Step 2-3: Wiki ページを更新

変更内容を分析し、影響を受けるページを Write/Edit で更新する。
ユーザー向け仕様の変化がない場合は最終更新日のみ更新する。

→ Step 2-4 へ

### Step 2-4: コミット・プッシュ

```bash
git status --short docs/wiki/
```

変更がある場合:

```bash
git add docs/wiki/
git commit -m "docs: Wiki を更新"
git push
```

変更がない場合はスキップ。

→ Step 3 へ

---

## Step 3（共通）: PR を Ready for Review に変更

### Step 3-1: ブランチ名から Issue 番号を抽出

```bash
git branch --show-current
```

`issue-(\d+)` パターンで抽出する。
見つからない場合は警告を表示して停止する。

→ Step 3-2 へ

### Step 3-2: 未コミット変更の確認

```bash
git status --short
```

変更がある場合は Step A-6 と同様にコミット・プッシュしてから次へ進む。

→ Step 3-3 へ

### Step 3-3: 既存 Draft PR を検索

```bash
gh pr list --head $(git branch --show-current) --state open --json number,isDraft,title
```

- Draft PR あり → Step 3-4A へ
- Draft PR なし → Step 3-4B へ

### Step 3-4A: 既存 Draft PR を更新・Ready for Review に変更

```bash
gh api repos/<owner>/<repo>/pulls/<PR番号> -X PATCH \
  -f title="<WIP プレフィックスを除いたタイトル>" \
  -f body="Closes #<Issue番号>

<変更内容の詳細>"
```

```bash
gh pr ready <PR番号>
```

→ Step 4 へ

### Step 3-4B: 新規 PR を作成

```bash
gh pr create \
  --title "<タイトル>" \
  --body "Closes #<Issue番号>

<変更内容の詳細>"
```

→ Step 4 へ

---

## Step 4（共通）: PR 承認・マージ

### Step 4-1: GitHub App Bot で PR 承認

```bash
bash ~/.claude/skills/gh-pr-approve/approve-pr.sh <owner> <repo> <PR番号>
```

**403 エラーの場合:** ブランチ保護が無効の可能性があるため、承認なしで Step 4-2 へ進む。

→ Step 4-2 へ

### Step 4-2: PR をマージ

```bash
gh pr merge <PR番号> --squash --repo <owner>/<repo>
```

マージ完了を確認:

```bash
gh pr view <PR番号> --repo <owner>/<repo> --json state,mergedAt
```

→ Step 4-3 へ

### Step 4-3: Issue クローズ確認

```bash
gh issue view <Issue番号> --repo <owner>/<repo> --json state
```

`CLOSED` でない場合:

```bash
gh issue close <Issue番号> --repo <owner>/<repo>
```

→ Step 5 へ

---

## Step 5（共通）: 後処理

```bash
bash ~/.claude/skills/gh-pr-approve/cleanup-after-merge.sh \
  <メインリポジトリパス> \
  <Worktreeパスまたはnone（小文字）> \
  <デフォルトブランチ> \
  <ブランチ名>
```

→ Step 6 へ

---

## Step 6: 完了メッセージ

以下の形式で表示する:

```
✅ PR のマージと後処理が完了しました。

完了した作業：
- Issue #<N> を作成（フロー A の場合のみ）
- ブランチ <ブランチ名> を作成・コミット
- PR #<N> を作成・マージ
- Issue #<N> をクローズ
- <デフォルトブランチ> ブランチに切り替え・最新を取得
- ローカル・リモートブランチを削除
```
