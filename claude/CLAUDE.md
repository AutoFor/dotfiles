# Claude Code グローバルルール

## コア原則
- **簡潔性**: 必要最小限の指示のみ記載
- **自動化**: 繰り返し作業は自動化

---

## ショートカット集

ショートカットや操作方法を追加・更新する場合、または `.lua` ファイル（WezTerm 設定など）を変更した場合は、必ず以下のファイルも更新する：

- `docs/qiita/terminal-shortcuts.md`

---

## Claude Code Skills

繰り返し実行される作業は **Claude Code Skills** として定義されています。

### 利用可能なグローバルスキル

| スキル名 | 説明 | 呼び出し方法 |
|---------|------|------------|
| `/draw-io-to-wiki` | draw.io ダイアグラムを作成し SVG で Wiki に追加 | 「図を描いて」「ダイアグラム作って」 |
| `/im8-project-init` | im8 Power Platform プロジェクトの標準構成をセットアップ（新規はテンプレリポから作成、既存は差分適用） | 「im8 の新しいプロジェクトを作りたい」「標準構成にしたい」 |
| `/backlog-document-sync` | Git を正本として Backlog ドキュメントへ自動同期する仕組みをセットアップ | 「Backlogドキュメント同期を設定して」 |

スキルは `~/.claude/skills/` に保存されています。

---

## Issue・ブランチ運用ルール

**新規 Issue は GitHub Issues で管理する**（2026-08-01 に全リポジトリで再有効化。一時 Linear に寄せていたが GitHub へ回帰）。

- 全リポジトリの Open Issue は org Project **「All Issues」** に自動集約される: https://github.com/orgs/AutoFor/projects/6
  - 追加: `AutoFor/.github` の GitHub Actions が 15 分おきに同期
  - クローズ: Project 組み込みワークフロー（Item closed → Done）が自動反映
- クローズは PR/コミットメッセージに `Fixes #123`（同一リポジトリの場合）
- 既存の Linear Issue（2026-07-31 以前分）は Linear に残置。Linear 起点で作業する場合は従来どおりブランチ名に Issue キー（例: `seiya/aut-123-fix-login`）、`Fixes AUT-123` / `Part of AUT-123` の運用

### 作業開始フロー（必須・全リポジトリ共通）

コード変更を伴う作業に着手するときは、**変更を始める前に必ず**:

1. GitHub Issue を作成する（該当する既存 Issue があればそれを使う）
2. org Project「All Issues」で その Issue の Status を **In Progress** に変更する

この 2 つは `~/.claude/gh-issue-start.sh` が 1 コマンドで行う（対象リポジトリ内で実行）:

```bash
~/.claude/gh-issue-start.sh "タイトル" "本文"   # 新規 Issue 作成 + In Progress 化
~/.claude/gh-issue-start.sh 123                # 既存 Issue #123 を In Progress 化
```

- 完了時は PR/コミットに `Fixes #123` を書いてクローズする（Project の Status は自動で Done になる）
- 対象は AutoFor org のリポジトリ。質問対応・調査・会話のみでコード変更が無い場合は不要
- リポジトリ個別の CLAUDE.md に別段の定めがある場合（例: dotfiles の「小さな設定調整は main 直コミット」）はそちらを優先してよいが、迷ったら Issue を作る

---

## 推奨ファイル構造
```
project/
├── docs/
│   ├── specification.md    # 仕様書
│   └── todo-archive.md     # 完了TODOのアーカイブ
├── README.md               # プロジェクト説明
└── src/                    # ソースコード
```
