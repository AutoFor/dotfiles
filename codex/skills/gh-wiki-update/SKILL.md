---
name: gh-wiki-update
description: コード変更を分析して docs/wiki/ 配下の Wiki ドキュメント（Markdown）を自動更新する。ユーザーが「Wiki を更新して」「ドキュメントを同期して」「gh-wiki-update」と言ったときに使用する。gh-finish からも自動で呼び出される。
---

# Wiki ドキュメント更新スキル

コード変更を分析し、`docs/wiki/` 配下の Markdown ファイルを自動更新する。

## 絶対禁止事項

- Wiki リポジトリ（`.wiki.git`）に直接 push しない（GitHub Actions が同期する）
- `docs/wiki/` 以外のファイルを変更しない

## 実行手順

### ステップ 1: リポジトリ情報取得

```bash
git remote -v
```

### ステップ 2: 変更内容の分析

デフォルトブランチを取得し、ブランチ全体の差分を確認する:

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
git fetch origin <default-branch>
git log origin/<default-branch>..HEAD --oneline
git diff origin/<default-branch>...HEAD --name-only
git diff origin/<default-branch>...HEAD
```

> `git diff` が空の場合は `git diff origin/<default-branch>..HEAD`（ドット2つ）も試すこと。

### ステップ 3: `docs/wiki/` の現状確認

- **存在しない場合**: `gh-init-wiki` スキルの手順を実行してセットアップ後、続行する
- **存在する場合**: 既存ページを読み込む

```bash
cat docs/wiki/*.md
```

### ステップ 4: ソースコード分析

変更されたファイルの内容とプロジェクト全体の構造を把握する。

### ステップ 5〜6: Wiki ページ更新

変更に影響するページを特定して更新する:
- `_Sidebar.md` を自動再生成（全ページへのリンク一覧）
- 各ページ末尾に最終更新日を記載

### ステップ 6.5: ダイアグラム更新

```bash
ls docs/wiki/images/*.drawio 2>/dev/null
```

既存ダイアグラムの確認後、変更内容に基づいて:
- **既存を編集**: XML の `<mxCell>` を更新
- **新規作成**: `.drawio` を作成し SVG エクスポート
- **不要**: スキップ

SVG エクスポート:

```bash
xvfb-run drawio --export --format svg --embed-svg-fonts true \
  --output docs/wiki/images/<name>.svg docs/wiki/images/<name>.drawio
```

### ステップ 7: 変更をコミット

```bash
git status --short docs/wiki/
git add docs/wiki/
git commit -m "docs: Wiki を更新"
git push
```

変更がない場合はスキップする。

### ステップ 8: 完了メッセージ

更新したページの一覧を表示する。
