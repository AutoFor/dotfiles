---
name: github-pr-approve
description: PR の承認・マージと後処理（Issue クローズ、ブランチ切り替え、Worktree 削除）を行う。ユーザーが「PRを承認する」「マージして」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - mcp__github__merge_pull_request
  - mcp__github__get_me
---

# GitHub PR 承認・マージスキル

このスキルは、PR の承認・マージと、その後の後処理を行う標準手順を提供します。

## 前提条件の確認

以下を確認してから手順を開始する：

- ✅ PR が作成済みである
- ✅ PR の内容をユーザーが確認済みである
- ✅ ユーザーから承認を得ている

## 実行手順

**必ず以下の順序で実行する：**

### 1. PR 承認とマージ

ユーザーの承認を得てから、PR をマージする。

**MCPツール使用例:**
```
mcp__github__merge_pull_request を使用
- owner: <リポジトリオーナー>
- repo: <リポジトリ名>
- pullNumber: [PR番号]
- merge_method: squash  # または merge, rebase
```

**gh コマンド例:**
```bash
gh pr merge <PR番号> --squash  # または --merge, --rebase
```

**マージ方法の選択:**
- `--squash`: 複数コミットを1つにまとめる（推奨）
- `--merge`: マージコミットを作成
- `--rebase`: コミット履歴を線形に保つ

### 2. Issue クローズ確認

PR に `Closes #XX` が含まれていれば自動でクローズされるが、念のため確認する。

**手動クローズが必要な場合:**
```bash
gh issue close <Issue番号>
```

### 3. master ブランチに戻る

作業ブランチから master ブランチに戻る。

```bash
cd ../<メインディレクトリ>  # メインリポジトリに戻る（Worktree使用時）
git checkout master
```

### 4. リモートの最新状態を取得と不要ブランチ削除

master ブランチを最新に更新し、不要なリモートブランチ情報を削除する。

```bash
git pull
git fetch --prune
```

### 5. Worktree の削除（Worktree使用時のみ）

Git Worktree を使用していた場合、作業ディレクトリを削除する。

```bash
git worktree remove ../<プロジェクト名>-<ブランチ種別>
```

**例:**
```bash
git worktree remove ../myproject-feature
```

### 6. 完了メッセージをユーザーに表示

以下のメッセージをユーザーに表示する：

```
✅ PR のマージと後処理が完了しました。

完了した作業：
- PR #[PR番号] をマージ
- Issue #[Issue番号] をクローズ
- master ブランチに切り替え
- リモートの最新状態を取得
- Worktree を削除（使用時のみ）

新しい作業を開始する場合は、`/git-worktree-branch` スキルをご利用ください。
```

## 実行例

```bash
# 1. PR承認とマージ
gh pr merge 44 --squash

# 2. Issueクローズ（通常は自動だが念のため）
gh issue close 45

# 3. masterブランチに戻る
cd ../claude-config
git checkout master

# 4. 最新状態を取得と不要ブランチ削除
git pull
git fetch --prune

# 5. Worktreeを削除（使用時のみ）
git worktree remove ../claude-config-feature
```

## 注意事項

- **必ずユーザーの承認を得てから実行する**
- Worktree を削除する前にコミット・プッシュが完了しているか確認
- `git fetch --prune` でリモートで削除されたブランチをローカルからも削除
- master ブランチに戻った後は、新しい作業を開始する前に必ず新しいブランチを作成する

## よくある質問

**Q: マージ方法は何を選ぶべきか？**
A: 基本的には `--squash` を使用して、コミット履歴を整理します。

**Q: Worktree を削除し忘れたらどうなるか？**
A: `git worktree list` で確認し、`git worktree remove` で削除できます。

**Q: Issue が自動でクローズされない場合は？**
A: PR 本文に `Closes #XX` が含まれているか確認し、手動で `gh issue close` を実行します。
