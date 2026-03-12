---
name: draw-io-to-wiki
description: 引数の説明から draw.io ダイアグラムを作成し、SVG エクスポートして docs/wiki/ に追加する。ユーザーが「図を描いて」「ダイアグラム作って」「アーキテクチャ図を追加して」「draw-io-to-wiki」と言ったときに使用する。
---

# draw.io ダイアグラム作成スキル

引数で指定された内容に基づいて draw.io ダイアグラムを作成し、SVG にエクスポートして Wiki に追加する。

## 絶対禁止事項

- `docs/wiki/` 以外のファイルを変更しない

## 実行手順

### ステップ 1: 引数の解析

引数からダイアグラムの内容を把握する。引数が空の場合はユーザーに確認する。

### ステップ 2: プロジェクト分析

ダイアグラムに関連するソースコードを読み込む:

```bash
ls -R src/ 2>/dev/null | head -50
```

### ステップ 3: ファイル名の決定

英語のケバブケースでファイル名を決定する（例: `architecture`, `auth-flow`）。

```bash
ls docs/wiki/images/*.drawio 2>/dev/null
```

同名ファイルがある場合は上書き更新する。

### ステップ 4: `.drawio` ファイル作成

```bash
mkdir -p docs/wiki/images
```

`docs/wiki/images/<name>.drawio` を draw.io XML 形式で作成する:

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

ガイドライン:
- ノードには日本語ラベルを付ける
- 色分けでカテゴリを区別（コンポーネント=青系、データ=緑系、外部=灰色系）
- 矢印にはラベルを付けて関係性を明示

### ステップ 5: SVG エクスポート

```bash
xvfb-run drawio --export --format svg --embed-svg-fonts true \
  --output docs/wiki/images/<name>.svg docs/wiki/images/<name>.drawio
ls -la docs/wiki/images/<name>.svg
```

### ステップ 6: Wiki ページへの追記

```bash
ls docs/wiki/*.md 2>/dev/null
```

関連ページを読み込み、適切な位置に追記する:

```markdown
![<ダイアグラムの説明>](./images/<name>.svg)

> [draw.io ソースファイル](./images/<name>.drawio) で編集できます
```

該当ページがない場合は `docs/wiki/<Name>.md` を新規作成する。

### ステップ 7: コミット

```bash
git status --short docs/wiki/
git add docs/wiki/
git commit -m "docs: <ダイアグラム名> ダイアグラムを追加"
git push
```

### ステップ 8: 完了メッセージ

作成ファイル（`.drawio`・`.svg`）と更新した Wiki ページを表示する。
