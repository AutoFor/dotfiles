---
name: gh-life-close
description: 未コミットの変更を Issue 単位にグループ化してコミットし、その場で Issue までクローズする。ユーザーが「作業が溜まった」「まとめてクローズしたい」「gh-life-close」と言ったときに使用する。
---

# gh-life-close

## Overview

未コミットの変更をテーマごとにまとめ、Issue を作ってコミットし、各 Issue をその場でクローズする。

小さな作業をまとめて棚卸ししたいとき向け。

## サンドボックス制約時の再実行ルール

- `gh issue create` / `gh issue close` など GitHub API 呼び出しで `error connecting to api.github.com` が出たら、同じコマンドを権限昇格付きで即再実行する。
- 失敗を放置して次のステップへ進まない。

## Workflow

### 1. 変更状態を確認する

```bash
git status --short
git diff
git diff --cached
```

変更が一切なければ停止する。

### 2. 変更をグループ化する

変更ファイルと diff を分析し、テーマごとに 1 つ以上のグループに分ける。

各グループでは次を決める:

- テーマ名
- 対象ファイル
- Issue タイトル案
- 想定するコミット種別（`feat` / `fix` / `docs` / `chore` / `refactor` / `test` / `style`）

必ずユーザーへ確認する。形式は簡潔でよいが、少なくともグループ名・対象ファイル・Issue タイトル案を示す。

### 3. グループごとに Issue を作成する

承認後、各グループを順番に処理する。

```bash
gh issue create --title "<Issueタイトル>" --body "<作業内容の概要>"
```

出力 URL から Issue 番号を取得する。

### 4. グループごとにコミットする

```bash
git add <対象ファイル>
git commit -m "<type>: <説明> #<Issue番号>"
```

コミット後、短いハッシュを取得する:

```bash
git rev-parse --short HEAD
```

### 5. Issue をクローズする

各グループのコミット後に Issue を閉じる。

```bash
gh issue close <Issue番号> --comment "<短縮ハッシュ> でコミット済み"
```

### 6. まとめてプッシュする

```bash
git push
```

upstream が未設定なら `git push -u origin $(git branch --show-current)` を使う。

### 7. 完了メッセージ

次を簡潔に伝える:

- クローズした Issue 一覧
- 各 Issue に対応するコミットハッシュ

## Notes

- 他のグループのファイルを混ぜない。
- 既存の unrelated な差分は巻き込まない。
- グループ化の提案が曖昧な場合は、勝手に進めず短く確認する。
