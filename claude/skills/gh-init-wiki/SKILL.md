---
name: gh-init-wiki
description: プロジェクトに docs/wiki/ と GitHub Actions ワークフローを作成し、Wiki 自動同期の土台をセットアップする。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Skill
---

# Wiki 初期化スキル

プロジェクトに `docs/wiki/` ディレクトリと GitHub Actions ワークフローを作成し、Wiki 自動同期の土台をセットアップする。

## 絶対禁止事項

- Wiki リポジトリ（`.wiki.git`）に直接 push しないこと（GitHub Actions が同期する）
- サブスキル（`/smart-commit`）の処理を自分で再実装しないこと

## 実行手順

### ステップ 1: 既存チェック

`docs/wiki/` が既に存在するか確認する。

- **存在する場合**: 「既にセットアップ済みです。`/gh-wiki-update` で更新できます。」と表示して **終了**
- **存在しない場合**: ステップ 2 へ進む

### ステップ 2: プロジェクト分析

以下のファイルを読み取り、プロジェクトの概要を把握する:

- `README.md`（プロジェクト説明）
- `package.json`、`Cargo.toml`、`go.mod` 等の主要設定ファイル
- ソースコードのディレクトリ構造（Glob で把握）
- 主要なソースファイル（エントリポイント、設定ファイル等）

### ステップ 3: `docs/wiki/` 作成

ディレクトリを作成し、プロジェクト分析に基づいて初期ページとダイアグラムを生成する。

```bash
mkdir -p docs/wiki/images
```

#### 生成するページ

| ページ | 対象読者 | 内容 |
|--------|---------|------|
| `Home.md` | 全員（非エンジニア含む） | プロジェクト概要、目的、できること |
| `Specification.md` | 全員 | 仕様書: 機能一覧、全体像 |
| `_Sidebar.md` | 全員 | ナビゲーション（全ページへのリンク） |

#### 各ページの書き方ルール

- **Home.md**: 平易な日本語、専門用語は避けるか注釈付き、非エンジニアが読んで理解できる
- **Specification.md**: 仕様ベース、「何ができるか」を中心に記述、フローチャートやテーブルを活用
- **_Sidebar.md**: 全ページへのリンク一覧

#### ダイアグラム生成

プロジェクト分析に基づいて、`docs/wiki/images/` にアーキテクチャ図等の初期ダイアグラムを作成する。

1. Write ツールで `.drawio` XML ファイルを作成する（例: `docs/wiki/images/architecture.drawio`）
2. draw.io CLI で SVG にエクスポートする:

```bash
xvfb-run drawio --export --format svg --embed-svg-fonts true --output docs/wiki/images/<name>.svg docs/wiki/images/<name>.drawio
```

3. Wiki ページ内で SVG を参照する:

```markdown
![アーキテクチャ図](./images/architecture.svg)
```

`.drawio`（ソース）と `.svg`（出力）の両方をリポジトリにコミットする。

### ステップ 4: `.github/workflows/wiki-sync.yml` 作成

既に存在する場合はスキップする。存在しない場合は以下の内容で作成:

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

Skill ツールで `/smart-commit` を呼び出してコミットする。

### ステップ 6: 完了メッセージ

以下の情報を表示する:

1. 生成したファイルの一覧
2. **注意**: 初回は GitHub リポジトリの Settings → Pages セクション横の Wiki タブで、Wiki を有効化し初期ページを手動作成する必要がある（GitHub Actions による同期はその後から機能する）
