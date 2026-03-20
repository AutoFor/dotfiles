---
name: gh-finish
description: 作業完了時に一気にマージまで実行する。ブランチ上なら PR 作成→マージ、main 上なら Issue・ブランチ作成から PR マージまで自動判定。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
---

# GitHub 作業完了スキル

以下を実行する:

```bash
bash ~/.claude/skills/gh-finish/gh-finish.sh
```

スクリプトが対話なしで完了まで実行する。
エラーが発生した場合はエラーメッセージを確認してユーザーに報告する。

## 注意事項

- `gh pr review --approve` は使用しないこと（自分の PR は GitHub の仕様上承認できない）
- Skill ツールでサブスキルを呼び出さないこと
