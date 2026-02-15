---
name: gh-finish
description: 作業完了時に PR・Issue 作成から承認・マージまで一気に実行する。ユーザーが「全部やって」「一気に完了させて」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Skill
  - Bash
---

# GitHub 作業完了フロースキル（自動実行版）

このスキルは、未コミットの変更があれば `/smart-commit` でコミットし、`/gh-pr-create` と `/gh-pr-approve` を **Skill ツールで順番に呼び出して** 実行し、作業完了から PR マージまでを一気に行います。

## 絶対禁止事項

- **`gh pr review --approve` は絶対に使用しないこと。** 自分の PR は GitHub の仕様上承認できないため、必ず失敗する。
- **Bash ツールで直接 PR 承認やマージを行わないこと。** 必ず `/gh-pr-approve` スキルを Skill ツールで呼び出すこと。
- **サブスキルの処理を自分で再実装しないこと。** 必ず Skill ツールで委譲すること。
- **直接 `git add && git commit` を実行しないこと。** 未コミットの変更がある場合は必ず `/smart-commit` スキルを Skill ツールで呼び出すこと。

## 実行手順

**重要: 以下の各ステップは必ず Skill ツールを使って対応するスキルを呼び出すこと。直接 Bash コマンドで実行してはならない。**

### 0. 未コミット・未プッシュの変更を確認

```bash
git status --short
git log @{u}..HEAD --oneline 2>/dev/null
```

- **未コミットの変更がある場合** → ステップ 1 へ進む
- **未プッシュのコミットがある場合** → `git push` を実行してからステップ 2 へ進む
- **すべてコミット・プッシュ済みの場合** → ステップ 2 へ進む

### 1. Skill ツールで `/smart-commit` を呼び出す

未コミットの変更がある場合のみ実行する。

```
Skill ツール: skill = "smart-commit"
```

smart-commit が完了したら、リモートにプッシュする：

```bash
git push -u origin $(git branch --show-current)
```

### 2. Skill ツールで `/gh-pr-create` を呼び出す

```
Skill ツール: skill = "gh-pr-create"
```

gh-pr-create が内部で以下を実行する：
1. ブランチ名から Issue 番号を抽出
2. Issue の存在を確認
3. 既存 Draft PR があれば Ready for Review に変更、なければ新規 PR 作成
4. PR と Issue を `Closes #<Issue番号>` で紐付け
5. 自動で `/gh-pr-approve` を呼び出して承認・マージまで進む

**注意:** gh-pr-create は内部で gh-pr-approve を自動呼び出しするため、このスキルからステップ 3 を別途実行する必要はない。gh-pr-create の完了を待てば全工程が終了する。

## 使い分け

- **段階的に進めたい場合**: `/gh-pr-create` → 確認 → `/gh-pr-approve`
- **一気に完了させたい場合**: `/gh-finish`（このスキル）

## 注意事項

- **このスキルは確認なしで自動的に PR をマージします**
- 慎重に確認したい場合は `/gh-pr-create` と `/gh-pr-approve` を個別に実行してください
- PR と Issue の内容は事前に確認しておくことを推奨します
