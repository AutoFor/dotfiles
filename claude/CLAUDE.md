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

## Issue・ブランチ運用ルール（Linear 起点）

Issue 管理は **Linear** で行う。GitHub Issues 機能は AutoFor 全リポジトリで無効化済み（2026-07-30）。`gh issue` コマンドは使わない。

- ブランチ名に Linear の Issue キーを入れる（例: `seiya/aut-123-fix-login`）。Linear が push / PR 作成時に自動リンクする
- PR マージで Linear 側が自動で Done になる（チームの Issue statuses & automations 設定による）
- main へ直接コミットする場合は、コミットメッセージに `Fixes AUT-123` を書けば同様にリンク＋クローズされる。リンクのみでクローズさせたくない場合は `Part of AUT-123`

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
