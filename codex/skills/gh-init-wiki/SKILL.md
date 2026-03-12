---
name: gh-init-wiki
description: プロジェクトに docs/wiki/ ディレクトリと GitHub Actions ワークフローを作成し、Wiki 自動同期の土台をセットアップする。ユーザーが「Wiki を初期化して」「Wiki 作って」「gh-init-wiki」と言ったときに使用する。
---

# Wiki 初期化スキル

`docs/wiki/` ディレクトリと GitHub Actions ワークフローを作成し、Wiki 自動同期の土台をセットアップする。

## 絶対禁止事項

- Wiki リポジトリ（`.wiki.git`）に直接 push しない（GitHub Actions が同期する）

## 実行手順

### ステップ 1: 既存チェック

`docs/wiki/` が既に存在する場合は「既にセットアップ済みです」と表示して終了する。

### ステップ 2: プロジェクト分析

以下を読み取りプロジェクトの概要を把握する:
- `README.md`
- `package.json`, `Cargo.toml`, `go.mod` 等の主要設定ファイル
- ソースコードのディレクトリ構造

### ステップ 3: `docs/wiki/` 作成

```bash
mkdir -p docs/wiki/images
```

生成するページ:
- `Home.md`: プロジェクト概要（非エンジニア向け、平易な日本語）
- `Specification.md`: 仕様書（機能一覧、全体像）
- `_Sidebar.md`: ナビゲーション（全ページへのリンク）

ダイアグラム生成:
1. `docs/wiki/images/<name>.drawio` を XML 形式で作成する
2. SVG にエクスポート:

```bash
xvfb-run drawio --export --format svg --embed-svg-fonts true \
  --output docs/wiki/images/<name>.svg docs/wiki/images/<name>.drawio
```

3. Wiki ページ内で参照: `![説明](./images/<name>.svg)`

`.drawio`（ソース）と `.svg`（出力）の両方をコミットする。

### ステップ 4: `.github/workflows/wiki-sync.yml` 作成

```yaml
name: Sync Wiki

on:
  push:
    branches: [main]
    paths:
      - 'docs/wiki/**'

permissions:
  contents: write

jobs:
  sync-wiki:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: Andrew-Chen-Wang/github-wiki-action@v4
        with:
          path: 'docs/wiki/'
          strategy: clone
```

### ステップ 5: コミット

変更ファイルをグループ化してコミット:

```bash
git add docs/wiki/ .github/workflows/wiki-sync.yml
git commit -m "feat: Wiki 初期セットアップ"
git push
```

### ステップ 6: 完了メッセージ

生成したファイルの一覧と、初回は GitHub リポジトリの Wiki タブで手動初期ページ作成が必要な旨を表示する。
