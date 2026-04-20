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

1. 作業対象ディレクトリを決定する
   - 引数としてパスが渡された場合はそれを使用する
   - 引数がない場合は `$CLAUDE_PROJECT_DIR`（現在の Claude Code プロジェクトディレクトリ）を使用する

2. 以下を実行する（`<DIR>` は上記で決定したディレクトリ）:

```bash
bash ~/.claude/skills/gh-finish/gh-finish.sh "<DIR>"
```

スクリプトが対話なしで完了まで実行する。
エラーが発生した場合はエラーメッセージを確認してユーザーに報告する。

## 注意事項

- `gh pr review --approve` は使用しないこと（自分の PR は GitHub の仕様上承認できない）
- Skill ツールでサブスキルを呼び出さないこと
- スクリプト実行中に独自判断でコマンドを追加実行しないこと（`.gitignore` 追加・`git rm --cached` など、スクリプトが意図しない操作を行わないこと）
- スクリプト外での修正が必要な問題（例: `node_modules` が追跡されているなど）はユーザーに報告するだけにとどめること
