---
name: gh-pr-approve
description: PR の承認・マージと後処理（Issue クローズ、ブランチ切り替え、Worktree 削除）を行う。ユーザーが「PRを承認する」「マージして」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - mcp__github__merge_pull_request
  - mcp__github__get_me
---

# GitHub PR 承認・マージスキル

このスキルは、GitHub App Bot による PR 承認、マージ、その後の後処理を行う標準手順を提供します。

## 絶対禁止事項

**`gh pr review --approve` は絶対に使用しないこと。** 自分の PR は GitHub の仕様上承認できないため、必ず失敗する。PR の承認には必ず `approve-pr.sh`（GitHub App Bot）を使用すること。

## 前提条件の確認

以下を確認してから手順を開始する：

- ✅ PR が作成済みである
- ✅ PR の内容をユーザーが確認済みである
- ✅ ユーザーから承認を得ている
- ✅ GitHub App のセットアップが完了している（初回のみ）

## 初回セットアップ

GitHub App Bot を使用するには、以下のセットアップが必要です（1回だけ）：

1. GitHub App を作成（Pull requests: Read & Write 権限）
2. 対象リポジトリにインストール
3. `~/.claude/github-app-config.env` に Client ID と Installation ID を設定
4. 秘密鍵を `~/.claude/github-app-key.pem` に配置

## 実行手順

**必ず以下の順序で実行する：**

### 0. CWD をメインリポジトリに移動（Worktree 使用時）

Worktree 内で実行している場合、後続の cleanup で Worktree が削除されると Bash ツールの CWD が無効になり、`cd` を含む**全コマンドが失敗する**。これを防ぐため、最初に CWD をメインリポジトリに移動する。

```bash
git worktree list
```

出力の1行目がメインリポジトリのパス。**`cd` を単独の Bash コマンドとして実行する:**

```bash
cd <メインリポジトリの絶対パス>
```

> ⚠️ **`cd <path> && other-command` は不可。** CWD が無効な場合、Bash ツールはコマンド実行前に CWD を検証し、コマンド全体を拒否する。`cd` は必ず単独で実行すること。

Worktree 未使用の場合はスキップ。

### 1a. GitHub App Bot で PR 承認

GitHub App Bot を使って PR を承認する。これにより、PR 作成者とは別のエンティティが承認するため、ブランチ保護ルール（承認必須）を満たせる。

```bash
bash ~/.claude/skills/gh-pr-approve/approve-pr.sh <owner> <repo> <PR番号>
```

**例:**
```bash
bash ~/.claude/skills/gh-pr-approve/approve-pr.sh <owner> my-repo 44
```

**エラーが出た場合:**
- `Config file not found` → `~/.claude/github-app-config.env` を確認
- `Private key not found` → `~/.claude/github-app-key.pem` を確認
- `Failed to get installation access token` → Client ID, Installation ID, 秘密鍵が正しいか確認
- `Failed to approve PR` → GitHub App がリポジトリにインストールされているか確認

### 1b. PR マージ

承認が成功したら、PR をマージする。

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

### 3. 後処理（master切替 + pull + Worktree/ブランチ削除）

Step 0 で CWD はメインリポジトリに移動済み。`git worktree list` の結果を参照してパスを指定する。

**Worktree 使用中（出力が2行以上）の場合:**
```bash
bash ~/.claude/skills/gh-pr-approve/cleanup-after-merge.sh <メインリポジトリの絶対パス> <Worktreeの絶対パス> master <ブランチ名>
```

**通常ブランチの場合:**
```bash
bash ~/.claude/skills/gh-pr-approve/cleanup-after-merge.sh <リポジトリの絶対パス> none master <ブランチ名>
```

### 4. 完了メッセージをユーザーに表示

以下のメッセージをユーザーに表示する：

```
✅ PR のマージと後処理が完了しました。

完了した作業：
- PR #[PR番号] を GitHub App Bot で承認
- PR #[PR番号] をマージ
- Issue #[Issue番号] をクローズ
- master ブランチに切り替え
- リモートの最新状態を取得
- Worktree を削除 / ローカルブランチを削除
- リモートブランチを削除

新しい作業を開始する場合は、`/gh-worktree-branch` または `/gh-branch` スキルをご利用ください。
```

## 実行例

```bash
# 1a. GitHub App Bot で PR を承認
bash ~/.claude/skills/gh-pr-approve/approve-pr.sh <owner> my-repo 44

# 1b. PR マージ
gh pr merge 44 --squash

# 2. Issueクローズ（通常は自動だが念のため）
gh issue close 45

# 3. 後処理（master切替 + pull + Worktree/ブランチ削除）— Step 0 で CWD 移動済み
bash ~/.claude/skills/gh-pr-approve/cleanup-after-merge.sh /home/user/projects/claude-config /home/user/projects/claude-config-feature master
```

## 注意事項

- **`gh pr review --approve` は絶対に使用禁止** — 必ず `approve-pr.sh` を使うこと
- **必ずユーザーの承認を得てから実行する**
- **初回セットアップが必要** — GitHub App 作成・インストール・設定ファイル配置が完了していること
- Worktree を削除する前にコミット・プッシュが完了しているか確認
- `git fetch --prune` でリモートで削除されたブランチをローカルからも削除
- master ブランチに戻った後は、新しい作業を開始する前に必ず新しいブランチを作成する
- approve-pr.sh は `bash`, `openssl`, `curl` に依存する

## よくある質問

**Q: マージ方法は何を選ぶべきか？**
A: 基本的には `--squash` を使用して、コミット履歴を整理します。

**Q: Worktree を削除し忘れたらどうなるか？**
A: `git worktree list` で確認し、`git worktree remove` で削除できます。

**Q: Issue が自動でクローズされない場合は？**
A: PR 本文に `Closes #XX` が含まれているか確認し、手動で `gh issue close` を実行します。

**Q: GitHub App Bot の承認が失敗する場合は？**
A: 以下を確認してください：
1. `~/.claude/github-app-config.env` の Client ID と Installation ID が正しいか
2. `~/.claude/github-app-key.pem` が存在し、正しい秘密鍵か
3. GitHub App が対象リポジトリにインストールされているか
4. GitHub App に Pull requests の Read & Write 権限があるか
