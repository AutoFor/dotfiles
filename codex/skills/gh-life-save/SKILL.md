---
name: gh-life-save
description: 作業途中の変更を Issue 単位にグループ化してコミットし、Issue はクローズせずに残す。ユーザーが「まだ終わってないけどイシューにしておきたい」「進捗を保存したい」「gh-life-save」と言ったときに使用する。
---

# gh-life-save

## Overview

未コミットの変更をテーマごとにまとめ、Issue を作ってコミットする。

このスキルは途中保存用。Issue は開いたままにし、続きは別の作業で進める前提にする。

## サンドボックス制約時の再実行ルール

- `gh issue create` など GitHub API 呼び出しで `error connecting to api.github.com` が出たら、同じコマンドを権限昇格付きで即再実行する。
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
gh issue create --title "<Issueタイトル>" --body "<作業内容の概要・現状・続きでやること>"
```

出力 URL から Issue 番号を取得する。

### 4. グループごとにコミットする

Issue を作ったら、そのグループの対象ファイルだけをコミットする。

```bash
git add <対象ファイル>
git commit -m "<type>: <説明> #<Issue番号>"
```

- コミットはグループ単位で分ける
- 他のグループのファイルを混ぜない
- 未コミット変更が残る場合はそのまま残してよい

### 5. まとめてプッシュする

```bash
git push
```

upstream が未設定なら `git push -u origin $(git branch --show-current)` を使う。

### 6. 完了メッセージ

次を簡潔に伝える:

- 作成した Issue 一覧
- 各 Issue に対応するコミット
- Issue は open のままであること

## Notes

- このスキルはマージやクローズを行わない。
- 既存の unrelated な差分は巻き込まない。
- グループ化の提案が曖昧な場合は、勝手に進めず短く確認する。
