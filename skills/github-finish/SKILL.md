---
name: github-finish
description: 作業完了時に PR・Issue 作成から承認・マージまで一気に実行する。ユーザーが「全部やって」「一気に完了させて」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Skill
  - Bash
---

# GitHub 作業完了フロースキル（自動実行版）

このスキルは、未コミットの変更があれば `/smart-commit` でコミットし、`/github-pr-create` と `/github-pr-approve` を **Skill ツールで順番に呼び出して** 実行し、作業完了から PR マージまでを一気に行います。

## 絶対禁止事項

- **`gh pr review --approve` は絶対に使用しないこと。** 自分の PR は GitHub の仕様上承認できないため、必ず失敗する。
- **Bash ツールで直接 PR 承認やマージを行わないこと。** 必ず `/github-pr-approve` スキルを Skill ツールで呼び出すこと。
- **サブスキルの処理を自分で再実装しないこと。** 必ず Skill ツールで委譲すること。
- **直接 `git add && git commit` を実行しないこと。** 未コミットの変更がある場合は必ず `/smart-commit` スキルを Skill ツールで呼び出すこと。

## 実行手順

**重要: 以下の各ステップは必ず Skill ツールを使って対応するスキルを呼び出すこと。直接 Bash コマンドで実行してはならない。**

### 0. 未コミット・未プッシュの変更を確認

```bash
git status --short
git log @{u}..HEAD --oneline 2>/dev/null
```

- **未コミットの変更がある場合** → Skill ツールで `/smart-commit` を呼び出してコミットする
- **未プッシュのコミットがある場合** → `git push` を実行する
- **すべてコミット・プッシュ済みの場合** → ステップ1へ進む

### 1. Skill ツールで `/github-pr-create` を呼び出す

PR と Issue の作成、紐付けを行います。

**実行内容:**
- ブランチ名から Issue を検出
- プルリクエスト作成
- PR と Issue を紐づけ

### 2. Skill ツールで `/github-pr-approve` を呼び出す

PR の承認・マージと後処理を行います。このスキルは内部で `approve-pr.sh`（GitHub App Bot）を使用して PR を承認する。

**実行内容:**
- GitHub App Bot による PR 承認（`approve-pr.sh` を使用）
- PR マージ
- Issue クローズ
- master ブランチに戻る
- リモートの最新状態を取得
- Worktree 削除（使用時のみ）

## 使い分け

- **段階的に進めたい場合**: `/github-pr-create` → 確認 → `/github-pr-approve`
- **一気に完了させたい場合**: `/github-finish`（このスキル）

## 注意事項

- **このスキルは確認なしで自動的に PR をマージします**
- 慎重に確認したい場合は `/github-pr-create` と `/github-pr-approve` を個別に実行してください
- PR と Issue の内容は事前に確認しておくことを推奨します
