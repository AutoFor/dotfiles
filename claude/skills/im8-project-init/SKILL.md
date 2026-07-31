---
name: im8-project-init
description: im8 の Power Apps + Power Automate プロジェクト標準構成をセットアップする。新規はテンプレートリポジトリから作成、既存リポジトリには不足分（.gitignore / wiki-sync.yml / docs/wiki 骨格 / README）を差分適用する。「im8 の新しいプロジェクトを作りたい」「標準構成にしたい」「プロジェクトを初期化して」と言ったときに使用します。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - ToolSearch
  - mcp__claude_ai_Google_Drive__create_file
  - mcp__claude_ai_Google_Drive__get_file_metadata
  - mcp__claude_ai_Google_Drive__search_files
---

# im8 Power Platform プロジェクト初期化スキル

im8 の Power Apps + Power Automate + SharePoint 連携プロジェクトの標準「箱」をセットアップする。

- **正本（戦略文書）**: [Power-Platform-Project-Template](https://github.com/AutoFor/im8-seat-presence-app/wiki/Power-Platform-Project-Template)
- **実装テンプレート**: [`AutoFor/im8-power-platform-template`](https://github.com/AutoFor/im8-power-platform-template)（private・テンプレートリポジトリ）

## 使い方

```
/im8-project-init 新規 <リポジトリ名> <案件コード> <プロジェクト名>
/im8-project-init 既存    ← カレントリポジトリに標準構成を差分適用
```

## ステップ0: Google Drive 資料フォルダの連携（両モード共通・最初に実施）

リポジトリ作業に入る前に、案件資料の置き場となる Google Drive フォルダを作成する。

- 親フォルダ（im8 案件資料の置き場）: https://drive.google.com/drive/folders/1b8dsFBXeZiQJhwS-kWAYkkkbDL2YlYRn （ID: `1b8dsFBXeZiQJhwS-kWAYkkkbDL2YlYRn`）
- フォルダ名: `<案件コード>_<プロジェクト名>`（例: `EG056_人事マスターデータの加工と配信の自動化`）

手順:

1. 親フォルダ直下に同名フォルダが既にないか `mcp__claude_ai_Google_Drive__search_files`（`parentId = '1b8dsFBXeZiQJhwS-kWAYkkkbDL2YlYRn'`）で確認する。あれば作成しない
2. 無ければ `mcp__claude_ai_Google_Drive__create_file` で作成する（`contentMimeType: application/vnd.google-apps.folder`、`parentId` に親フォルダ ID を指定）
3. 案件フォルダ直下にデフォルトのサブフォルダを作成する:

   ```
   <案件コード>_<プロジェクト名>/
   ├── 受領資料/    ← 先方から受領したファイル（原本のまま置く）
   ├── MTG/         ← 会議資料・議事メモ・録画
   └── <案件コード>_<プロジェクト名>_要件整理用.xlsx  ← ルート直下（作成は任意。命名規約のみ統一）
   ```

   検証・モック・ヒアリング等のフォルダは案件の必要に応じて随時追加する（デフォルトでは作らない）
4. 作成したフォルダの URL をユーザーに報告し、README の「ドキュメント」節に資料フォルダとしてリンクを追記する

**「Requested entity was not found」になる場合**: Google Drive コネクタが親フォルダの見えないアカウントで接続されている。claude.ai の 設定 → コネクタ → Google Drive を、親フォルダにアクセスできるアカウントで接続し直してもらう（または親フォルダをコネクタのアカウントに編集者権限で共有してもらう）。

## モード1: 新規プロジェクト作成

1. テンプレートから作成（**private 必須**。社内情報を含むため）:
   ```bash
   gh repo create AutoFor/<リポジトリ名> --template AutoFor/im8-power-platform-template --private --clone
   ```
2. プレースホルダを置換する: `README.md` / `CLAUDE.md` / `docs/wiki/Home.md` / `docs/wiki/_Sidebar.md` の `{{PROJECT_NAME}}` `{{PROJECT_CODE}}` `{{リポジトリ名}}` `{{アプリの一言説明}}` などを引数の値で置換。README のテンプレート由来注記ブロック（`> このリポジトリは ... から作成されました` の blockquote）は置換完了後に削除する
3. コミットして push する
4. **手動作業をユーザーに案内する**（下記「Wiki 初期化の手動手順」）

## モード2: 既存リポジトリへの差分適用

カレントディレクトリの git リポジトリに対して、**既存ファイルを上書きせず**不足分だけを追加する。

1. 現状確認: `.gitignore` / `.github/workflows/wiki-sync.yml` / `docs/wiki/Home.md` / `README.md` / `CLAUDE.md` の有無を調べる
2. テンプレートを一時ディレクトリに取得:
   ```bash
   gh repo clone AutoFor/im8-power-platform-template /tmp/im8-template -- --depth 1
   ```
3. 不足しているファイル・フォルダだけをコピーする（プレースホルダはプロジェクトに合わせて置換）:
   - `.gitignore` が無ければコピー。あれば不足パターン（`*.msapp`、`/[0-9]*/`、`*:Zone.Identifier` 等）だけ追記
   - `.github/workflows/wiki-sync.yml` が無ければコピー
   - `docs/wiki/`（Home.md / _Sidebar.md / images/）が無ければ骨格を作成
   - `README.md` / `CLAUDE.md` が無ければ雛形をコピーして置換。**あれば触らない**（変更提案だけ提示）
4. Issue-first 運用に従い、Issue 起票 → ブランチ → PR でコミットする
5. Wiki 未初期化なら「Wiki 初期化の手動手順」を案内する

## Wiki 初期化の手動手順（ユーザーに案内する）

GitHub Wiki の `*.wiki.git` は API では初期化できない。初回のみ:

1. リポジトリの Settings → Features で Wiki を有効化（デフォルト有効）
2. Wiki タブの「Create the first page」で初期ページを作成（内容は仮で OK。同期時に上書きされる）
3. Actions タブ → 「Sync Wiki」→ Run workflow で手動実行し、`docs/wiki/` が Wiki に反映されることを確認

## SharePoint リストの運用方針（im8 共通）

プロジェクトでマスタ等を SharePoint リストとして作る場合は、以下の規約に従う（2026-07 EG056 で確立）。

### 命名・列設計

1. **リスト名は `<案件コード>_` プレフィックス + 英語**にする（例: `EG056_OutputMaster`、`EG056_DepartmentMaster`、`EG041_Building`）
2. **既定のタイトル列（Title）は使わない**。専用列を別途作成し、Title はリスト設定で必須を解除してビューからも外す（削除はできないため未使用のまま残す）
3. 列は**先に内部名（英語）で作成してから表示名を日本語に変更**する（例: 内部名 `DepartmentName` → 表示名「部署名」）。最初から日本語で作ると内部名が `_x90e8_...` のような文字化けになり、Power Automate から参照しづらくなる
4. 複数行テキスト列は種類を**書式なしテキスト**にする
5. マスタは Excel ではなくリストで実装する（列型の強制・バージョン履歴による監査性・「行の取得」での参照しやすさ）

### 定義の出力先は Wiki と Excel の2つ

リスト定義は必ず以下の**2箇所**に出力・維持する（変更時は両方更新）:

1. **Excel**: `dev/list/<案件コード>_SharePointリスト.xlsx` — 先方共有・UI 作成用の定義書。EG041 で確立した形式（シート名「リスト設計」、B列開始、リストごとに「①リスト名: <案件コード>_<リスト名>」見出し + 列名/内部名/型/備考 の4列テーブル、Title 行は赤字で「※利用しない」）
2. **Wiki**: `docs/wiki/SharePoint-Lists.md` — 読者向けドキュメント（Wiki 自動同期の対象）

補助として `dev/list/README.md`（内部名一覧・UI 作成手順）と `provision-lists.sh`（m365 CLI 自動作成）を置いてよい。

- 形式の参考: EG041 の `EG041_SharePointリスト0422_更新.xlsx`（im8-seat-presence-app）
- 実装の参考: [im8-EG056-hr-master-pipeline の dev/list/](https://github.com/AutoFor/im8-EG056-hr-master-pipeline/tree/main/dev/list)

## 絶対禁止事項

- GitHub Wiki（`*.wiki.git`）へ直接 push しないこと（同期時に全上書きされる）
- 既存リポジトリの既存ファイルを確認なしに上書きしないこと
- リポジトリを public で作成しないこと（社内情報を含むため原則 private）
