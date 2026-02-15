---
name: gh-worktree-branch
description: 新しい作業を開始するときに GitHub Issue を作成し、Git Worktree とブランチを作成する。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - mcp__github__issue_write
  - mcp__github__create_pull_request
  - mcp__github__get_me
---

# Git Worktree ブランチ作成スキル（Issue-first）

## 引数の処理

- **引数なし** (`/gh-worktree-branch`): 「作業内容を伝えてください」と表示して **停止する。それ以上何もしない。**
- **引数あり** (`/gh-worktree-branch ダークモード対応`): 引数を Issue タイトルとして使用し、以下のフローを実行する。

## 実行フロー（引数ありの場合）

### 1. リポジトリ情報を取得

```bash
git remote -v
```

出力から `owner` と `repo` を特定する。

### 2. GitHub Issue を作成

`mcp__github__issue_write` を使用：
- method: `create`
- owner: （リポジトリオーナー）
- repo: （リポジトリ名）
- title: ユーザーの引数をそのまま使用
- body: 作業の概要を簡潔に記載

### 3. ブランチ名を生成

1. ユーザーの引数を英語スラッグに変換する
   - 小文字、ハイフン区切り、英数字のみ
   - 3〜5単語程度に簡潔にまとめる
   - 例: `ダークモード追加` → `add-dark-mode`
2. ブランチ名: `issue-<Issue番号>-<英語スラッグ>`
   - 例: `issue-17-add-dark-mode`

### 4. Worktree を作成

```bash
bash ~/.claude/skills/gh-worktree-branch/create-worktree.sh <ブランチ名>
```

### 5. Worktree ディレクトリに移動

スクリプト出力のディレクトリに `cd` する。

### 5a. 空コミットを作成して push

Worktree 作成直後は差分がないため、空コミットでブランチをリモートに push する：

```bash
git commit --allow-empty -m "chore: start work on #<Issue番号>"
git push -u origin <ブランチ名>
```

### 5b. Draft PR を作成

`mcp__github__create_pull_request` で Draft PR を作成する（`draft: true` を指定）：
- title: `WIP: <Issueタイトル>`
- body: `Closes #<Issue番号>\n\n作業中...`
- head: `<ブランチ名>`
- base: main（または master）
- draft: true

**フォールバック:** `mcp__github__create_pull_request` が `draft` パラメータをサポートしない場合：

```bash
gh pr create --draft --title "WIP: <Issueタイトル>" --body "Closes #<Issue番号>

作業中..."
```

### 6. クリップボードにコピー

Worktree のパスをクリップボードにコピーする：

```bash
bash ~/.claude/skills/_shared/copy-to-clipboard.sh "cd <Worktreeの絶対パス> && claude"
```

- コマンドが **成功** した場合 → 完了メッセージに「📋 クリップボードにコピー済み」と表示
- コマンドが **失敗** した場合 → 完了メッセージに「⚠ 手動でコピーしてください」と表示

### 7. 完了メッセージ

以下の形式で出力する：

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>
Draft PR: #<PR番号>

📋 クリップボードにコピー済み: cd <Worktreeの絶対パス> && claude
新しいターミナルで貼り付けて作業を開始してください。
```

**これ以上何も出力しない。コード編集・次のステップの提案は一切しない。**
