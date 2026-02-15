---
name: gh-branch-finish
description: diff からブランチ作成・PR作成・承認・マージまで一気通貫で実行する。ユーザーが「ブランチ作成から全部やって」「diffから一気に完了させて」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Skill
---

# Git ブランチ作成〜マージ一気通貫スキル

このスキルは、`/gh-branch` → `/gh-pr-create` → `/gh-pr-approve` を順番に実行し、diff からブランチ作成・PR作成・承認・マージまでを一気に行います。

## 前提条件の確認

以下を確認してから手順を開始する：

- ✅ 作業中の変更（diff）または未プッシュコミットが存在する
- ✅ コードが正常に動作する
- ✅ **ユーザーの承認を得ている（確認なしで自動実行される）**

## 実行手順

このスキルは以下のスキルを順番に Skill ツールで呼び出す。

### 1. Skill ツールで `/gh-branch` を呼び出す

```
Skill ツール: skill = "gh-branch"
```

gh-branch が内部で以下を実行する：
1. `git remote -v` でリポジトリ情報を取得
2. `git status --short` / `git diff` / `git diff --cached` で変更内容を収集
3. 変更内容から日本語 Issue タイトルを自動生成
4. `mcp__github__issue_write` で GitHub Issue を作成
5. ブランチ名 `issue-<番号>-<スラッグ>` を生成
6. `git checkout -b <ブランチ名>` でブランチを作成（main に未プッシュコミットがある場合は移植処理も実行）
7. `/smart-commit` で未コミットの変更をコミット
8. `git push -u origin <ブランチ名>` でプッシュし、Draft PR を作成

gh-branch の完了を待ってからステップ 2 へ進む。

### 2. Skill ツールで `/gh-pr-create` を呼び出す

```
Skill ツール: skill = "gh-pr-create"
```

gh-pr-create が内部で以下を実行する：
1. `git branch --show-current` でブランチ名から Issue 番号を抽出
2. `mcp__github__issue_read` で Issue の存在を確認
3. `gh pr list --head <ブランチ名>` で既存 Draft PR を検索
4. Draft PR があれば Ready for Review に変更、なければ新規 PR を作成
5. PR と Issue を `Closes #<Issue番号>` で紐付け
6. 自動で `/gh-pr-approve` を呼び出して承認・マージまで進む

**注意:** gh-pr-create は内部で gh-pr-approve を自動呼び出しするため、このスキルからステップ 3 を別途実行する必要はない。gh-pr-create の完了を待てば全工程が終了する。

## 使い分け

- **段階的に進めたい場合**: `/gh-branch` → `/gh-pr-create` → `/gh-pr-approve`
- **PR 作成以降を一気にやりたい場合**: `/gh-finish`
- **diff から全部一気に完了させたい場合**: `/gh-branch-finish`（このスキル）

## 注意事項

- **このスキルは確認なしで自動的にブランチ作成から PR マージまで実行します**
- 慎重に確認したい場合は各スキルを個別に実行してください
- 変更内容は事前に確認しておくことを推奨します
