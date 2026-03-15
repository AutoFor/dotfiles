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

**ビフォー（ghq クローン）:**
```
~/ghq/github.com/owner/my-project/
  .git/
  readme.md
  src/
```

**アフター（ghq クローンはそのまま維持 + ~/.git-worktrees/ に bare 構造を作成）:**
```
~/.git-worktrees/
  github.com/owner/my-project/    ← コンテナ（ghq 管理外）
    .bare/                        ← bare git repository
    main/                         ← worktree（デフォルトブランチ）
      readme.md
      src/
    feature/issue-123-xxx/        ← フィーチャー worktree

~/ghq/github.com/owner/my-project/  ← そのまま維持（触らない）
  .git/
  readme.md
  src/
```

ghq クローンは一切変更せず、`ghq list` / `ghq look` は引き続き正常に動作します。

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

bare リポジトリ: ~/.git-worktrees/github.com/<owner>/<repo>/.bare/
デフォルトブランチ worktree: ~/.git-worktrees/github.com/<owner>/<repo>/<ブランチ名>/

ghq クローン（~/ghq/.../）は変更していません。ghq list / ghq look は引き続き正常に動作します。

今後 `/gh-worktree-branch` や `/gh-worktree-from-issue` で作成される worktree は
~/.git-worktrees/github.com/<owner>/<repo>/<ブランチ名>/ に作成されます。
```
