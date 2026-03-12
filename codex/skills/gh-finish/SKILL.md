---
name: gh-finish
description: 作業完了時に Issue 作成からマージまでを一気に実行する。ブランチ上にいれば PR 作成→マージ、main/master 上にいれば Issue・ブランチ作成から PR マージまで自動判定。ユーザーが「全部やって」「一気に完了させて」「gh-finish」と言ったときに使用する。
---

# GitHub 作業完了スキル（完全自動版）

現在のブランチ状態を判定し、Issue 作成〜マージまでをすべて実行する。

## 絶対禁止事項

- `gh pr review --approve` は使用しない（自分の PR は承認できない）

## サンドボックス制約時の再実行ルール

- `gh issue create` / `gh pr create` / `gh pr merge` / `gh issue view` など GitHub API 呼び出しで
  `error connecting to api.github.com` が出た場合は、同一コマンドを**権限昇格付きで即再実行**する。
- 権限昇格時の理由は短く具体的に書く（例: `GitHub API に接続して Issue/PR を操作するため`）。
- ユーザーへの質問は 1 回でまとめる。失敗した同一コマンド以外を先に進めない。

---

## Step 0: ブランチ判定

```bash
git branch --show-current
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
```

- 現在ブランチ = デフォルトブランチ → **フロー A**
- 現在ブランチ ≠ デフォルトブランチ → **フロー B**

---

## フロー A: main/master 上にいる場合

### A-1. リポジトリ情報取得

```bash
git remote -v
```

### A-2. 変更内容を収集

```bash
git status --short && git diff && git diff --cached
git log origin/<デフォルトブランチ>..HEAD --oneline
```

変更が一切ない場合は「変更がありません。」と表示して停止する。

### A-3. Issue タイトルを自動生成

diff・status・コミットログを分析し、日本語で簡潔な Issue タイトルを生成する。

### A-4. GitHub Issue を作成

```bash
gh issue create --title "<自動生成タイトル>" --body "<作業概要>"
```

### A-5. ブランチを作成

ブランチ名: `issue-<番号>-<英語スラッグ>`

未プッシュコミットがある場合:
```bash
git checkout -b <ブランチ名>
git branch -f <デフォルトブランチ> origin/<デフォルトブランチ>
```

ない場合:
```bash
git checkout -b <ブランチ名>
```

### A-6. 変更をコミット（未コミット変更がある場合）

変更をテーマでグループ化して Conventional Commits 形式でコミット。

### A-7. プッシュして Draft PR を作成

```bash
git push -u origin <ブランチ名>
gh pr create --draft --title "WIP: <Issueタイトル>" \
  --body "Closes #<Issue番号>

作業中..." \
  --head "<ブランチ名>" --base "<デフォルトブランチ>"
```

→ **Step 1（共通）** へ

---

## フロー B: feature ブランチ上にいる場合

### B-0. 変更状態を確認

```bash
git status --short
git log @{u}..HEAD --oneline 2>/dev/null
```

- 未コミットあり → B-1 へ
- 未プッシュコミットあり → `git push` して Step 1 へ
- 完了済み → Step 1 へ

### B-1. 変更をコミット

```bash
git diff && git diff --cached
# グループごとにコミット
git push -u origin $(git branch --show-current)
```

---

## Step 1: メインリポジトリパスを記録

```bash
git worktree list
```

MAIN_REPO の決定:
- bare 構造の場合: デフォルトブランチの worktree パス
- 通常の場合: 現在のリポジトリパス
- bare リポジトリパス（`.bare`）は絶対に使わない

## Step 2: Wiki ドキュメント更新（オプション）

`docs/wiki/` が存在する場合のみ実行。失敗してもマージ処理は続行する。

```bash
git fetch origin <デフォルトブランチ>
git diff origin/<デフォルトブランチ>...HEAD --name-only
git diff origin/<デフォルトブランチ>...HEAD
```

変更に影響する Wiki ページを更新し、変更があればコミット:

```bash
git add docs/wiki/
git commit -m "docs: Wiki を更新"
git push
```

## Step 3: PR を Ready for Review に変更

```bash
git branch --show-current
# issue-(\d+) パターンで Issue 番号を抽出
gh pr list --head $(git branch --show-current) --state open --json number,isDraft,title
```

- Draft PR あり → タイトル・本文を更新して `gh pr ready <PR番号>`
- Draft PR なし → `gh pr create --title ... --body "Closes #<Issue番号>..."`

## Step 4: PR 承認・マージ

```bash
# 4-1. GitHub App Bot で PR 承認
bash ~/.codex/skills/gh-pr-approve/approve-pr.sh <owner> <repo> <PR番号>

# 4-2. PR マージ
gh pr merge <PR番号> --squash --repo <owner>/<repo>

# 4-3. Issue クローズ確認
gh issue view <Issue番号> --repo <owner>/<repo> --json state
# CLOSED でない場合:
gh issue close <Issue番号> --repo <owner>/<repo>
```

## Step 5: 後処理

```bash
bash ~/.codex/skills/gh-pr-approve/cleanup-after-merge.sh \
  <メインリポジトリパス> \
  <Worktreeパス or none> \
  <デフォルトブランチ> \
  <ブランチ名>
```

## Step 6: 完了メッセージ

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
