---
name: gh-init-worktree
description: 既存の git リポジトリを worktree ベースのフォルダ構造（bare + worktrees）に変換する。ユーザーが「worktree 構造にしたい」「init して」「gh-init-worktree」と言ったときに使用する。
---

# Git Worktree 初期化スキル

従来のフラットな git リポジトリを worktree ベースの構造に変換する。

## 変換イメージ

**ビフォー:**
```
~/projects/my-project/
  .git/
  src/
```

**アフター:**
```
~/projects/my-project/
  .bare/        ← bare git repository
  master/       ← worktree（デフォルトブランチ）
    src/
```

## 引数の処理

- **引数なし**: 現在のディレクトリを対象にする
- **引数あり**: 指定パスを対象にする

## 実行手順

### ステップ 1: init-worktree.sh を実行

```bash
bash ~/.codex/skills/gh-init-worktree/init-worktree.sh [対象パス]
```

### ステップ 2: 完了メッセージ

```
worktree 構造への変換が完了しました。

bare リポジトリ: <パス>/.bare/
デフォルトブランチ worktree: <パス>/<ブランチ名>/
```
