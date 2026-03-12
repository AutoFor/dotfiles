---
name: gh-init-worktree
description: 既存の git リポジトリを worktree ベースのフォルダ構造に変換する。「worktree構造にしたい」「initして」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
---

# Git Worktree 初期化スキル

従来のフラットな git リポジトリ構造を worktree ベースの構造に変換する。

## 変換イメージ

**ビフォー（フラット構造）:**
```
~/projects/my-project/
  .git/
  readme.md
  src/
```

**アフター（worktree ベース構造）:**
```
~/projects/my-project/
  .bare/              ← bare git repository
  master/             ← worktree（デフォルトブランチ）
    readme.md
    src/
```

## 引数の処理

- **引数なし** (`/gh-init-worktree`): 現在のディレクトリを対象にする
- **引数あり** (`/gh-init-worktree ~/projects/my-project`): 指定パスを対象にする

## 実行手順

### ステップ 1: init-worktree.sh を実行

```bash
bash ~/.claude/skills/gh-init-worktree/init-worktree.sh [対象パス]
```

- 引数なしの場合はパス引数を省略（カレントディレクトリが対象）
- 引数ありの場合はパスを渡す

### ステップ 2: 結果を確認

スクリプトの出力を確認し、ユーザーに結果を表示する。

### ステップ 3: 完了メッセージ

```
worktree 構造への変換が完了しました。

bare リポジトリ: <パス>/.bare/
デフォルトブランチ worktree: <パス>/<ブランチ名>/

今後 `/gh-worktree-branch` や `/gh-worktree-from-issue` で作成される worktree は
<パス>/<ブランチ名>/ のようにサブディレクトリとして作成されます。
```
