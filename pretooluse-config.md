# PreToolUse Configuration Guide

## 概要
`smart-tag.ps1`を使用して、作業の目的やマイルストーンをClaudeに伝える仕組みです。

## settings.json への設定例

```json
{
  "PreToolUse": {
    "Read": "powershell -Command \"& 'C:\\Users\\SeiyaKawashima\\.claude\\smart-tag.ps1' -Action show -Json\"",
    "Write": "powershell -Command \"& 'C:\\Users\\SeiyaKawashima\\.claude\\smart-tag.ps1' -Action show -Json\"",
    "Edit": "powershell -Command \"& 'C:\\Users\\SeiyaKawashima\\.claude\\smart-tag.ps1' -Action show -Json\"",
    "Bash": "powershell -Command \"& 'C:\\Users\\SeiyaKawashima\\.claude\\smart-tag.ps1' -Action show -Json\""
  }
}
```

## 使い方

### 1. タグの作成
```powershell
# プロジェクト用タグ
./smart-tag.ps1 -Action add -Tag "feature-auth" -Description "認証機能の実装"

# グローバルタグ（全プロジェクト共通）
./smart-tag.ps1 -Action add -Tag "refactoring" -Description "コード品質の改善" -Global
```

### 2. タグの切り替え
```powershell
# アクティブタグの設定
./smart-tag.ps1 -Action set -Tag "feature-auth"

# タグのクリア
./smart-tag.ps1 -Action clear
```

### 3. ゴールの追加
```powershell
# 現在のタグにゴールを追加
./smart-tag.ps1 -Action goal -Description "ログイン画面の実装"
./smart-tag.ps1 -Action goal -Description "JWT認証の実装"
./smart-tag.ps1 -Action goal -Description "ユーザー権限管理"
```

### 4. 状態の確認
```powershell
# タグ一覧
./smart-tag.ps1 -Action list

# 現在のタグ（Claude用JSON）
./smart-tag.ps1 -Action show -Json
```

## Claudeへの情報提供

PreToolUseが実行されると、以下のような情報がClaudeに提供されます：

```json
{
  "mode": "project",
  "active_tag": "feature-auth",
  "context": {
    "purpose": "認証機能の実装",
    "created": "2025-09-03 06:00:00",
    "goals": [
      {
        "text": "ログイン画面の実装",
        "completed": false,
        "created": "2025-09-03 06:01:00"
      },
      {
        "text": "JWT認証の実装",
        "completed": false,
        "created": "2025-09-03 06:01:30"
      }
    ]
  }
}
```

## 活用例

### 例1: 新機能開発
```powershell
# タグを作成して開発開始
./smart-tag.ps1 -Action add -Tag "feat-dashboard" -Description "ダッシュボード機能の開発"
./smart-tag.ps1 -Action goal -Description "統計グラフの実装"
./smart-tag.ps1 -Action goal -Description "リアルタイム更新の実装"

# Claudeに質問
"ダッシュボードのグラフ表示を実装して"
# → Claudeは自動的に「ダッシュボード機能の開発」という文脈を理解
```

### 例2: バグ修正
```powershell
# バグ修正タグを設定
./smart-tag.ps1 -Action add -Tag "fix-memory-leak" -Description "メモリリークの修正"

# Claudeに依頼
"メモリ使用量を最適化して"
# → Claudeは「メモリリークの修正」が目的だと理解
```

### 例3: リファクタリング
```powershell
# グローバルタグとして設定
./smart-tag.ps1 -Action add -Tag "clean-code" -Description "コードの可読性向上" -Global
./smart-tag.ps1 -Action goal -Description "変数名の改善"
./smart-tag.ps1 -Action goal -Description "重複コードの削除"

# どのプロジェクトでも有効
"このコードをリファクタリングして"
# → Claudeは「コードの可読性向上」を意識して提案
```

## ファイル構造

```
~/.claude/
├── tags/
│   └── global-tags.json      # グローバルタグ
└── smart-tag.ps1             # タグ管理スクリプト

<project>/
└── .claude/
    └── project-tags.json      # プロジェクト固有タグ
```

## メリット

1. **文脈の自動共有**: Claudeが現在の作業目的を自動的に理解
2. **一貫性の向上**: 複数の質問にわたって同じ目的を維持
3. **効率的な作業**: 毎回目的を説明する必要がない
4. **ゴール管理**: 作業の進捗を可視化

## 注意事項

- PreToolUseは各ツール実行前に毎回実行される
- JSON出力によりClaudeが構造化データとして認識
- プロジェクトタグとグローバルタグを使い分け可能