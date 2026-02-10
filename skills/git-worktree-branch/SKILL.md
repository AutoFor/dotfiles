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

## 実行

```bash
bash ~/.claude/skills/git-worktree-branch/create-worktree.sh
```

スクリプト実行後、出力されたディレクトリに `cd` する。
