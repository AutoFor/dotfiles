# Claude Code Config

Personal configuration and automation rules for Claude Code - includes Git commit rules, TODO archiving, and Windows notification settings

## 概要

Claude Code用の個人設定・自動化ルール集です。作業効率を向上させるための各種設定が含まれています。

## 主な機能

### 🔔 Windows通知
- タスク完了時に自動でWindows通知を送信
- 成功/警告/エラーの3段階で通知
- PowerShellスクリプトで実装

### 📝 Gitコミットルール
- 機能単位での細かいコミット
- ブランチ戦略の自動適用
- 日本語での分かりやすいコミットメッセージ

### 📋 TODOアーカイブ
- 完了したTODOの自動アーカイブ
- コミットハッシュとの紐付け
- 作業履歴の可視化

## ファイル構成

```
.claude/
├── CLAUDE.md           # Claude Code用のグローバル設定
├── windows-notify.ps1  # Windows通知用PowerShellスクリプト
└── README.md          # このファイル
```

## セットアップ

1. このリポジトリをクローン
```bash
git clone https://github.com/seiya-kawashima/claude-code-config.git ~/.claude
```

2. PowerShellの実行ポリシーを設定（必要に応じて）
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 使用方法

Claude Codeを起動すると、自動的に`CLAUDE.md`の設定が読み込まれます。

### Windows通知のテスト
```powershell
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[OK] Claude Code' -Message 'テスト通知'"
```

## ライセンス

MIT License

## Author

Seiya Kawashima