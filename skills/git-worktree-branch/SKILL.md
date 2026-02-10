---
name: git-worktree-branch
description: 新しい作業を開始するときに Git Worktree とブランチを即座に作成する。質問なしで即実行。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
---

# Git Worktree ブランチ即時作成スキル

呼び出されたら**質問せずに即座に以下を実行**する。

## 引数の処理

- **引数なし** (`/git-worktree-branch`): タイムスタンプのみのブランチを作成（従来通り）
- **引数あり** (`/git-worktree-branch ダークモード対応`): テーマを英語スラッグに変換してブランチ名に付加

**テーマの変換ルール:**
1. ユーザーの引数（日本語OK）を短い英語スラッグに変換する
2. 小文字、ハイフン区切り、英数字のみ（例: `add-dark-mode`, `fix-login-bug`）
3. 3〜5単語程度に簡潔にまとめる

**ブランチ名の例:**
- 引数なし → `20260210-143052`
- `ダークモード追加` → `20260210-143052-add-dark-mode`
- `ログインバグ修正` → `20260210-143052-fix-login-bug`

## 実行

```bash
# 引数なしの場合
bash ~/.claude/skills/git-worktree-branch/create-worktree.sh

# 引数ありの場合（英語スラッグに変換済みの値を渡す）
bash ~/.claude/skills/git-worktree-branch/create-worktree.sh <英語スラッグ>
```

スクリプト実行後、出力されたディレクトリに `cd` する。
