---
name: draw-io-to-wiki
description: 引数の説明から draw.io ダイアグラムを作成し、SVG エクスポートして Wiki に追加する。「図を描いて」「ダイアグラム作って」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# draw.io → Wiki ダイアグラム作成スキル

引数で指定された内容に基づいて draw.io ダイアグラムを作成し、SVG にエクスポートして Wiki に追加する。

## 使い方

```
/draw-io-to-wiki アーキテクチャの全体図
/draw-io-to-wiki ユーザー認証フロー
/draw-io-to-wiki モジュール間の依存関係
```

## 絶対禁止事項

- `/docs/wiki/` 以外のファイルを変更しないこと
- サブスキル（`/smart-commit`）の処理を自分で再実装しないこと

## 実行手順

### ステップ 1: 引数の解析

引数からダイアグラムの内容を把握する。引数が空の場合はユーザーに何を描くか確認する。

### ステップ 2: プロジェクト分析

ダイアグラムの内容に関連するソースコードを読み込み、正確な図を描くための情報を収集する。

- プロジェクト構造（Glob で把握）
- 関連するソースファイル（Read で読み込む）
- README.md、設定ファイル等

### ステップ 3: ファイル名の決定

ダイアグラムの内容からファイル名を決定する（英語のケバブケース）。

例:
- アーキテクチャ図 → `architecture`
- ユーザー認証フロー → `auth-flow`
- モジュール依存関係 → `module-dependencies`

既存ファイルとの重複を確認する:

```bash
ls docs/wiki/images/*.drawio 2>/dev/null
```

同名ファイルが存在する場合は Read で読み込み、上書き更新とする。

### ステップ 4: `.drawio` ファイル作成

`docs/wiki/images/` ディレクトリが存在しない場合は作成する:

```bash
mkdir -p docs/wiki/images
```

Write ツールで `docs/wiki/images/<name>.drawio` を作成する。

draw.io XML 形式で記述する。テンプレート:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxfile>
  <diagram name="ダイアグラム名">
    <mxGraphModel dx="1422" dy="762" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <!-- ノードとエッジをここに配置 -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

ダイアグラム作成のガイドライン:

- ノードには分かりやすい日本語ラベルを付ける
- 色分けでカテゴリを区別する（例: コンポーネント=青系、データ=緑系、外部=灰色系）
- 矢印にはラベルを付けて関係性を明示する
- 適切な間隔を空けて配置する（最低 40px 以上の間隔）

### ステップ 5: SVG エクスポート

```bash
xvfb-run drawio --export --format svg --embed-svg-fonts true --output docs/wiki/images/<name>.svg docs/wiki/images/<name>.drawio
```

エクスポートが成功したか確認する:

```bash
ls -la docs/wiki/images/<name>.svg
```

### ステップ 6: Wiki ページへの追記

ダイアグラムの内容に最も関連する既存の Wiki ページを特定する:

```bash
ls docs/wiki/*.md 2>/dev/null
```

関連ページを Read で読み込み、適切な位置に以下を追記する:

```markdown
![<ダイアグラムの説明>](./images/<name>.svg)

> [draw.io ソースファイル](./images/<name>.drawio) で編集できます
```

該当する既存ページがない場合は、新しい Wiki ページ `docs/wiki/<Name>.md` を作成し、ダイアグラムを含める。

`_Sidebar.md` が存在する場合は、新規ページ追加時にリンクを追加する。

### ステップ 7: コミット

```bash
git status --short docs/wiki/
```

変更がある場合は Skill ツールで `/smart-commit` を呼び出してコミットする。

### ステップ 8: 完了メッセージ

以下を表示する:

1. 作成したファイル: `.drawio`（ソース）、`.svg`（出力）
2. 更新した Wiki ページ
3. draw.io で編集する場合のパス: `docs/wiki/images/<name>.drawio`
