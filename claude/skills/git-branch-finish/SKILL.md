---
name: git-branch-finish
description: diff からブランチ作成・PR作成・承認・マージまで一気通貫で実行する。ユーザーが「ブランチ作成から全部やって」「diffから一気に完了させて」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Skill
---

# Git ブランチ作成〜マージ一気通貫スキル

このスキルは、`/git-branch` → `/github-pr-create` → `/github-pr-approve` を順番に実行し、diff からブランチ作成・PR作成・承認・マージまでを一気に行います。

## 前提条件の確認

以下を確認してから手順を開始する：

- ✅ 作業中の変更（diff）または未プッシュコミットが存在する
- ✅ コードが正常に動作する
- ✅ **ユーザーの承認を得ている（確認なしで自動実行される）**

## 実行手順

このスキルは以下の3つのスキルを順番に呼び出します：

### 1. `/git-branch` スキルを実行

Issue 作成・ブランチ作成・smart-commit を行います。

**実行内容:**
- 変更内容を分析して Issue タイトルを自動生成
- GitHub Issue を作成
- ブランチを作成
- 未コミットの変更を smart-commit

### 2. `/github-pr-create` スキルを実行

PR の作成と Issue 紐付けを行います。

**実行内容:**
- ブランチ名から Issue を検出
- プルリクエスト作成
- PR と Issue を紐づけ

### 3. `/github-pr-approve` スキルを実行

PR の承認・マージと後処理を行います。

**実行内容:**
- PR 承認とマージ
- Issue クローズ
- デフォルトブランチに戻る
- リモートの最新状態を取得
- Worktree 削除（使用時のみ）

## 使い分け

- **段階的に進めたい場合**: `/git-branch` → `/github-pr-create` → `/github-pr-approve`
- **PR 作成以降を一気にやりたい場合**: `/github-finish`
- **diff から全部一気に完了させたい場合**: `/git-branch-finish`（このスキル）

## 注意事項

- **このスキルは確認なしで自動的にブランチ作成から PR マージまで実行します**
- 慎重に確認したい場合は各スキルを個別に実行してください
- 変更内容は事前に確認しておくことを推奨します
