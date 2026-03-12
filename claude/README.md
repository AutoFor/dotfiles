# Claude Code dotfiles

Claude Code によるAI駆動開発のためのグローバル設定・スキル・MCP 設定をまとめた dotfiles リポジトリ。

## 開発スタイル

Git Worktree を活用して**複数の課題を並走**させるワークフローを採用しています。

- **Issue-first**: すべての作業は GitHub Issue から始まる。AI が何を実行したかのログとして Issue を必ず残す
- **Worktree 並走**: `git worktree` で課題ごとに独立した作業ディレクトリを持ち、複数タスクを同時進行
- **Bot 自動承認**: GitHub App Bot が PR を自動承認し、セルフマージの制限を回避
- **ワンコマンド完結**: `/gh-finish` で Issue 作成からマージまでを一気通貫で実行可能

```
# 典型的な並走ワークフロー

# Worktree A: ダークモード実装中
~/projects/my-app-issue-10-dark-mode/

# Worktree B: バグ修正中
~/projects/my-app-issue-12-fix-login/

# メインリポジトリ: 次のタスクを開始
~/projects/my-app/
```

## 構成

```
.
├── CLAUDE.md                        # グローバルルール（全プロジェクト共通）
├── settings.json                    # フック設定（応答完了・入力待ち通知）
├── windows-notify.ps1               # Windows トースト通知スクリプト
├── github-app-config.env.example    # GitHub App 認証情報のテンプレート
├── docs/
│   └── wiki/                        # Wiki ソース（GitHub Actions で Wiki に同期）
├── .github/
│   └── workflows/
│       └── wiki-sync.yml            # docs/wiki/ → Wiki 自動同期
├── mcp/
│   └── mcp-config.json.example      # MCP サーバー設定のテンプレート
└── skills/
    ├── _shared/
    │   └── copy-to-clipboard.sh     # クロスプラットフォーム クリップボードユーティリティ
    ├── gh-branch/                   # diff から Issue + ブランチ作成（Worktree なし）
    ├── gh-worktree-branch/          # 新規 Issue + Worktree + ブランチ作成
    ├── gh-worktree-from-issue/      # 既存 Issue から Worktree + ブランチ作成
    ├── gh-pr-create/                # PR 作成（Draft PR → Ready for Review）
    ├── gh-pr-approve/               # PR 承認・マージ・後処理（GitHub App Bot）
    ├── gh-finish/                   # ブランチ作成〜マージまで一括実行
    ├── gh-wiki-init/                # Wiki 初期セットアップ（docs/wiki/ + ワークフロー生成）
    ├── gh-wiki-update/              # コード変更から Wiki ドキュメント自動更新
    ├── japanese-comments/           # TypeScript/JS に日本語コメント追加
    └── smart-commit/                # テーマ別に自動分割コミット
```

## セットアップ

### 1. シンボリックリンク作成

```bash
ln -sf $(pwd)/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf $(pwd)/settings.json ~/.claude/settings.json
ln -sf $(pwd)/windows-notify.ps1 ~/.claude/windows-notify.ps1
ln -sf $(pwd)/skills ~/.claude/skills
```

### 2. MCP サーバー設定

```bash
cp mcp/mcp-config.json.example ~/.claude/mcp.json
# ~/.claude/mcp.json を編集して GitHub PAT を設定
```

### 3. GitHub App 設定（PR 自動承認用）

```bash
cp github-app-config.env.example ~/.config/claude-github-app.env
# 環境変数ファイルを編集して認証情報を設定
```

GitHub App は PR の自動承認に使用します。Claude が作成した PR を Bot が承認することで、ブランチ保護ルール（承認必須）を満たしつつセルフマージを実現します。

## スキル一覧

### Git ワークフロー

| スキル | コマンド | 説明 |
|--------|---------|------|
| gh-worktree-branch | `/gh-worktree-branch <説明>` | 新規 Issue 作成 → Worktree + ブランチ作成 → Draft PR |
| gh-worktree-from-issue | `/gh-worktree-from-issue [番号]` | 既存 Issue → Worktree + ブランチ作成 → Draft PR |
| gh-branch | `/gh-branch` | diff から Issue + ブランチ作成（Worktree なし） |
| gh-pr-create | `/gh-pr-create` | Draft PR を Ready for Review に変更し、承認・マージまで実行 |
| gh-pr-approve | `/gh-pr-approve` | Bot で PR 承認 → マージ → Issue クローズ → Worktree 削除 |
| gh-finish | `/gh-finish` | 状況を自動判定し、Issue 作成〜マージまで一括実行 |

### コーディング

| スキル | コマンド | 説明 |
|--------|---------|------|
| japanese-comments | `/japanese-comments` | TypeScript/JS コードに日本語の行末コメントを追加 |
| smart-commit | `/smart-commit` | 変更をテーマ別に分割し Conventional Commits 形式でコミット |

### ユーティリティ

| スキル | コマンド | 説明 |
|--------|---------|------|
| z-cheatsheet | `/z-cheatsheet` | dotfiles のショートカット・コマンド検索 |
| z-cheatsheet-add | `/z-cheatsheet-add` | チートシートに項目を追加 |
| gh-wiki-init | `/gh-wiki-init` | Wiki 初期セットアップ（docs/wiki/ + ワークフロー生成） |
| gh-wiki-update | `/gh-wiki-update` | コード変更を分析して Wiki ドキュメントを自動更新 |

## 通知

`settings.json` のフック設定により、以下のタイミングで Windows トースト通知が表示されます（WSL2 環境、[BurntToast](https://github.com/Windos/BurntToast) モジュールが必要）。

| イベント | 通知内容 | サウンド |
|---------|---------|---------|
| Stop（応答完了） | 処理が完了しました | Reminder |
| Notification（入力待ち） | 許可または入力を待っています | IM |

## ワークフロー例

### 複数課題を並走させる場合

```bash
# 課題 A: Worktree で作業開始
/gh-worktree-branch ダークモード追加

# コーディング...
「ダークモードのトグルボタンを実装して」

# 作業完了 → PR 作成 → Bot 承認 → マージまで一括
/gh-pr-create

# 課題 B: 別の Issue から Worktree で作業開始
/gh-worktree-from-issue 15

# コーディング...

# 作業完了
/gh-pr-create
```

### main 上で手早く完結させる場合

```bash
# コーディング後、Issue 作成〜マージまで一発（Wiki 更新含む）
/gh-finish
```

### Wiki ドキュメントの仕組み

- `docs/wiki/` 配下の Markdown ファイルがドキュメントのソース
- `/gh-wiki-update` または `/gh-finish` でコード変更に基づき自動更新
- main にマージされると GitHub Actions が Wiki リポジトリに自動同期
