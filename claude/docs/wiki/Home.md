# Claude Code dotfiles

Claude Code によるAI駆動開発のためのグローバル設定・スキル・MCP 設定をまとめた dotfiles リポジトリです。

## このリポジトリについて

このリポジトリは、[Claude Code](https://claude.com/claude-code)（AI コーディングアシスタント）の設定やスキル（自動化された作業手順）を管理しています。開発者が AI と協力してコードを書く際に、繰り返し行う作業を自動化し、効率的な開発を実現します。

## 主な特徴

- **Issue-first ワークフロー**: すべての作業は GitHub Issue から始まり、AI が何を実行したかの記録が残ります
- **Git Worktree 並走**: 複数の課題を同時に進行できる作業環境を自動構築します
- **ワンコマンド完結**: `/gh-finish` コマンドひとつで、Issue 作成から PR マージまでを一気に実行できます
- **PR 自動承認**: GitHub App Bot が PR を自動承認し、スムーズなマージを実現します
- **ダイアグラム自動生成**: draw.io でダイアグラムを作成し、SVG として Wiki に自動追加します

## セットアップ

詳しいセットアップ手順は [README.md](https://github.com/AutoFor/dotfiles/blob/main/claude/README.md) を参照してください。

基本的な手順:

1. シンボリックリンクで設定ファイルを配置
2. MCP サーバーの設定
3. GitHub App の設定（PR 自動承認用）

## スキル一覧

利用可能なスキルの詳細は [[Specification]] を参照してください。

---

*最終更新: 2026-02-28*
