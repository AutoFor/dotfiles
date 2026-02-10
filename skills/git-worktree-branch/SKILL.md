---
name: git-worktree-branch
description: 新しい作業を開始するときに GitHub Issue を作成し、Git Worktree とブランチを作成する。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - mcp__github__issue_write
  - mcp__github__get_me
---

# Git Worktree ブランチ作成スキル（Issue-first）

## 引数の処理

- **引数なし** (`/git-worktree-branch`): 「作業内容を伝えてください」と表示して **停止する。それ以上何もしない。**
- **引数あり** (`/git-worktree-branch ダークモード対応`): 引数を Issue タイトルとして使用し、以下のフローを実行する。

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
bash ~/.claude/skills/git-worktree-branch/create-worktree.sh <ブランチ名>
```

### 5. Worktree ディレクトリに移動

スクリプト出力のディレクトリに `cd` する。

### 6. 完了メッセージ

以下の形式で出力する：

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>
```

**これ以上何も出力しない。コード編集・次のステップの提案は一切しない。**
