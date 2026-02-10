---
name: github-finish
description: 作業完了時に PR・Issue 作成から承認・マージまで一気に実行する。ユーザーが「全部やって」「一気に完了させて」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Skill
---

# GitHub 作業完了フロースキル（自動実行版）

このスキルは、`/github-pr-create` と `/github-pr-approve` を順番に実行し、作業完了から PR マージまでを一気に行います。

## 前提条件の確認

以下を確認してから手順を開始する：

- ✅ 作業ブランチに必要なコミットがすべて含まれている
- ✅ リモートリポジトリに `git push` 済みである
- ✅ コードが正常に動作する
- ✅ **ユーザーの承認を得ている（確認なしで自動実行される）**

## 実行手順

このスキルは以下の2つのスキルを順番に呼び出します：

### 1. `/github-pr-create` スキルを実行

PR と Issue の作成、紐付けを行います。

**実行内容:**
- プルリクエスト作成
- イシュー作成
- PR と Issue を紐づけ

### 2. `/github-pr-approve` スキルを実行

PR の承認・マージと後処理を行います。

**実行内容:**
- PR 承認とマージ
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
