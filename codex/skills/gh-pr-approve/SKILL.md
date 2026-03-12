---
name: gh-pr-approve
description: PR の承認・マージと後処理（Issue クローズ、ブランチ切り替え、Worktree 削除）を行う。ユーザーが「PR を承認する」「マージして」「gh-pr-approve」と言ったときに使用する。通常は gh-pr-create から自動で呼び出される。
---

# GitHub PR 承認・マージスキル

## 絶対禁止事項

**`gh pr review --approve` は使用禁止。** 自分の PR は承認できない。必ず `approve-pr.sh`（GitHub App Bot）を使用する。

## 前提条件

- PR が作成済みであること
- GitHub App のセットアップが完了していること（初回のみ）

## 初回セットアップ

1. GitHub App を作成（Pull requests: Read & Write 権限）
2. 対象リポジトリにインストール
3. `~/.codex/github-app-config.env` に Client ID と Installation ID を設定
4. 秘密鍵を `~/.codex/github-app-key.pem` に配置

## 実行手順

### 0. CWD をメインリポジトリに移動（必須）

```bash
git worktree list
```

- bare 構造の場合: デフォルトブランチの worktree パスに `cd`
- 通常の場合: 1行目のパスに `cd`
- **bare リポジトリパス（`.bare`）は絶対に使わないこと**

### 1. GitHub App Bot で PR 承認

```bash
bash ~/.codex/skills/gh-pr-approve/approve-pr.sh <owner> <repo> <PR番号>
```

エラー時:
- `Config file not found` → `~/.codex/github-app-config.env` を確認
- `Private key not found` → `~/.codex/github-app-key.pem` を確認
- 403 エラー → ブランチ保護が無効の可能性。承認なしで次へ進む

### 2. PR マージ

```bash
gh pr merge <PR番号> --squash
```

### 3. Issue クローズ確認

```bash
gh issue view <Issue番号> --json state
# CLOSED でない場合:
gh issue close <Issue番号>
```

### 4. 後処理

```bash
bash ~/.codex/skills/gh-pr-approve/cleanup-after-merge.sh \
  <メインリポジトリパス> \
  <Worktreeパス or none> \
  <デフォルトブランチ> \
  <ブランチ名>
```

### 5. 完了メッセージ

```
✅ PR のマージと後処理が完了しました。

完了した作業：
- PR #<N> を GitHub App Bot で承認
- PR #<N> をマージ
- Issue #<N> をクローズ
- <デフォルトブランチ> ブランチに切り替え・最新を取得
- Worktree 削除 / ローカル・リモートブランチを削除
```
