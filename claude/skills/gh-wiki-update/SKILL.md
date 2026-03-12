---
name: gh-wiki-update
description: コード変更を分析して /docs/wiki/ 配下の Wiki ドキュメント（Markdown）を自動更新する。gh-finish から自動で呼ばれるほか、単独でも使用可能。
disable-model-invocation: true
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Skill
---

# Wiki ドキュメント更新スキル

コード変更を分析し、`/docs/wiki/` 配下の Markdown ファイルを自動更新する。

## 絶対禁止事項

- Wiki リポジトリ（`.wiki.git`）に直接 push しないこと（GitHub Actions が同期する）
- `/docs/wiki/` 以外のファイルを変更しないこと
- サブスキル（`/smart-commit`）の処理を自分で再実装しないこと

## 実行手順

### ステップ 1: リポジトリ情報取得

```bash
git remote -v
```

owner/repo を特定する。

### ステップ 2: 変更内容の分析

> **重要**: このステップでは**ブランチ全体の変更**を検出する。`git diff`（作業ツリーの未コミット変更）とは異なり、`git diff origin/main...HEAD` はコミット済みの変更も含むブランチ上の全差分を表示する。gh-finish 等で既にコミット・プッシュ済みでも、ブランチ差分は存在する。**必ず以下のコマンドを実際に実行すること（前のステップの出力を流用しない）。**

デフォルトブランチを取得:

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
```

リモートの最新情報を取得（ブランチ差分を正確に検出するため）:

```bash
git fetch origin <default-branch>
```

ブランチ上のコミット一覧を確認:

```bash
git log origin/<default-branch>..HEAD --oneline
```

デフォルトブランチとの diff を取得:

```bash
git diff origin/<default-branch>...HEAD --name-only
```

```bash
git diff origin/<default-branch>...HEAD
```

変更されたファイルの一覧と内容を把握する。

> `git log` でコミットが表示されるのに `git diff` が空の場合は、リベースやマージの影響の可能性がある。その場合は `git diff origin/<default-branch>..HEAD` （ドット2つ）も試すこと。

### ステップ 3: `/docs/wiki/` の現状確認

`/docs/wiki/` が存在するか確認する。

- **存在しない場合**: Skill ツールで `/gh-init-wiki` を呼び出して初期セットアップを実行。完了後、ステップ 4 へ続行する
- **存在する場合**: 既存ページを Read で読み込む

### ステップ 4: ソースコード分析

- 変更されたファイルの内容を読み込む
- プロジェクト全体の構造を把握（README.md、主要設定ファイル等）

### ステップ 5: 更新が必要なページを判定

- 変更ファイルに基づいて、影響を受ける Wiki ページを特定
- 新しいコンポーネント/モジュールが追加された場合 → 詳細設計ページの新規作成を検討

### ステップ 6: Wiki ページ生成・更新

Write ツールで `/docs/wiki/` 内の Markdown ファイルを更新する。

- `_Sidebar.md` を自動再生成（全ページへのリンク一覧）
- 各ページ末尾に最終更新日を記載

### ステップ 6.5: ダイアグラム生成・更新

変更内容に基づいて、`docs/wiki/images/` 配下のダイアグラムを作成・更新する。

#### 6.5.1 既存ダイアグラムの確認

`docs/wiki/images/` 内の既存 `.drawio` ファイルを一覧する:

```bash
ls docs/wiki/images/*.drawio 2>/dev/null
```

既存ファイルがある場合は Read ツールで内容を読み込み、現在のダイアグラム構成を把握する。

#### 6.5.2 ダイアグラムの要否判定

ステップ 2 の変更内容と 6.5.1 の既存ダイアグラムを照合し、以下を判定する:

| 判定 | 条件 | アクション |
|------|------|-----------|
| **既存を編集** | 変更がダイアグラム内のノード・エッジに影響する（モジュール名変更、フロー変更、接続先変更等） | 6.5.3 へ |
| **新規作成** | 新しいコンポーネント/モジュール/フローが追加され、既存ダイアグラムでカバーされない | 6.5.4 へ |
| **不要** | 変更がダイアグラムに影響しない | ステップ 7 へスキップ |

#### 6.5.3 既存 `.drawio` ファイルの編集

Read ツールで対象の `.drawio` ファイルを読み込み、変更内容に合わせて Edit ツールまたは Write ツールで XML を更新する。

編集の例:
- **ノード追加**: `<mxCell>` 要素を `<root>` 内に追加
- **ノード名変更**: 対象 `<mxCell>` の `value` 属性を更新
- **ノード削除**: 対象 `<mxCell>` とそれに接続するエッジを削除
- **エッジの接続先変更**: `<mxCell>` の `source` / `target` 属性を更新
- **スタイル変更**: `style` 属性を更新

> 既存ノードの `id` と座標（`<mxGeometry>`）は変更が必要な箇所のみ修正し、他は維持する。

→ 6.5.5 へ進む。

#### 6.5.4 新規 `.drawio` ファイル作成

`docs/wiki/images/` ディレクトリが存在しない場合は作成する:

```bash
mkdir -p docs/wiki/images
```

Write ツールで `.drawio` XML ファイルを作成する。ダイアグラムの種類はプロジェクトに応じて自動判定する:

| ダイアグラム例 | ファイル名 | 用途 |
|-------------|----------|------|
| アーキテクチャ図 | `architecture.drawio` | システム全体構成 |
| フロー図 | `flow-*.drawio` | 処理フロー |
| モジュール構成図 | `modules.drawio` | モジュール間の関係 |

`.drawio` ファイルは draw.io XML 形式で記述する。テンプレート:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxfile>
  <diagram name="ページ名">
    <mxGraphModel dx="1422" dy="762" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <!-- ここにノードとエッジを配置 -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

→ 6.5.5 へ進む。

#### 6.5.5 SVG エクスポート

作成・更新した各 `.drawio` ファイルを SVG にエクスポートする:

```bash
xvfb-run drawio --export --format svg --embed-svg-fonts true --output docs/wiki/images/<name>.svg docs/wiki/images/<name>.drawio
```

> `.drawio`（ソース）と `.svg`（出力）の両方を `docs/wiki/images/` に保持する。

#### 6.5.6 Wiki ページへの埋め込み

新規ダイアグラムの場合、対応する Wiki ページに SVG 画像の参照を追加する:

```markdown
![ダイアグラムの説明](./images/<name>.svg)
```

> 既存ダイアグラムの編集の場合、SVG ファイル名が変わらなければ Markdown の参照は更新不要。

### ステップ 7: 変更をコミット

```bash
git status --short docs/wiki/
```

- **変更がある場合** → Skill ツールで `/smart-commit` を呼び出してコミット
- **変更がない場合** → スキップ

### ステップ 8: 完了メッセージ表示

更新したページの一覧を表示する。

---

## Wiki ページ構成（自動判定）

プロジェクトを分析して最適なページ構成を自動判定する。基本構成:

| ページ | 対象読者 | 内容 | 生成ソース |
|--------|---------|------|-----------|
| `Home.md` | 全員（非エンジニア含む） | 概要、目的、導入手順のサマリ | README.md, 設定ファイル |
| `Specification.md` | 全員 | 仕様書: 機能一覧、全体像 | ソースコード全体 |
| 詳細設計ページ（動的） | エンジニア | 各コンポーネントの実装詳細 | 主要モジュールのソース |
| `_Sidebar.md` | 全員 | ナビゲーション | 自動生成（全ページのリンク） |

## 各ページの書き方ルール

- **Home.md**: 平易な日本語、専門用語は避けるか注釈付き、非エンジニアが読んで理解できる
- **Specification.md**: 仕様ベース、「何ができるか」を中心に記述、フローチャートやテーブルを活用
- **詳細設計ページ**: 実装詳細、コード例、呼び出しフロー図、引数・戻り値の仕様
