---
name: gh-branch
description: 作業中の変更内容（diff）から自動で GitHub Issue を作成し、ブランチを作成する（Worktree なし）。main 上の未プッシュコミットがある場合は自動でブランチに移植する。ユーザーが「ブランチを作って」「Issue を作ってブランチ切って」「gh-branch」と言ったときに使用する。
---

# Git ブランチ作成スキル（diff ベース自動命名、Worktree なし）

引数は無視する。常に現在の変更内容から Issue タイトルを自動生成する。

## サンドボックス制約時の再実行ルール

- `gh issue create` / `gh pr create` で `error connecting to api.github.com` が出た場合は、
  失敗したコマンドをそのまま**権限昇格付きで再実行**する。
- 権限昇格時の理由は短く具体的にする（例: `GitHub API に接続して Issue/PR を作成するため`）。
- 先に別コマンドへ進まず、まず失敗した API コマンドを完了させる。

## 実行フロー

### 1. リポジトリ情報を取得

```bash
git remote -v
```

### 2. 変更内容を分析

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
git status --short
git diff
git diff --cached
git log origin/<デフォルトブランチ>..HEAD --oneline
```

変更が何もない場合は停止する。

### 3. Issue タイトルを自動生成

diff・status・コミットログを分析し、日本語で簡潔なタイトルを生成する（例: `ダークモード対応を追加`）。

### 4. GitHub Issue を作成

```bash
gh issue create --title "<自動生成タイトル>" --body "<作業概要>"
```

### 5. ブランチ名を生成

ブランチ名: `issue-<番号>-<英語スラッグ>`（例: `issue-17-add-dark-mode`）

### 6. ブランチを作成

**ケース A: main にいて未プッシュコミットがある場合**

```bash
git checkout -b <ブランチ名>
git branch -f <デフォルトブランチ> origin/<デフォルトブランチ>
```

**ケース B: それ以外**

```bash
git checkout -b <ブランチ名>
```

### 7. 変更をコミット（未コミット変更がある場合）

変更をテーマでグループ化してコミット（Conventional Commits 形式）。

### 7a. push して Draft PR を作成

```bash
git push -u origin <ブランチ名>
gh pr create --draft --title "WIP: <Issueタイトル>" --body "Closes #<Issue番号>

作業中..."
```

### 8. 完了メッセージ

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>
Draft PR: #<PR番号>
```

**これ以上何も出力しない。**
