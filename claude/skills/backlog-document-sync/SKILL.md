---
name: backlog-document-sync
description: 任意のGitHubリポジトリに、Gitを正本としてBacklogの「ドキュメント」機能へ自動同期する仕組み（GitHub Actionsワークフロー＋同期スクリプト）をセットアップする。「Backlogドキュメント同期を設定して」「このリポジトリでBacklog連携をセットアップして」「GitHub ActionsでBacklogに記事を反映したい」「Backlog Documentを自動更新したい」のように言われたら、対象が今回と別のリポジトリであっても必ずこのスキルを使う。ゼロからスクリプトやワークフローを書き直そうとせず、まずこのスキルのテンプレート（assets/）を使うこと。
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

# Backlog Document 自動同期セットアップスキル

Gitを正本として、`backlog-docs/`（フォルダ名は変更可）配下のMarkdownをBacklogの「ドキュメント」機能へGitHub Actions経由で自動反映する仕組みを、任意のGitHubリポジトリに導入する。

`ourai-run/backlog-general` での実機検証（実際にBacklogへドキュメントを作成・更新するところまで動作確認済み）をもとに作られている。途中で踏んだ落とし穴（後述）は必ず踏まえること。

## 使い方

```
/backlog-document-sync
/backlog-document-sync ~/path/to/other-repo
/backlog-document-sync docs-dir=knowledge-base
```

引数がなければカレントディレクトリのリポジトリが対象、ドキュメント用フォルダ名は `backlog-docs` になる。

## 絶対禁止事項

- **BacklogのAPIキーなど機微情報を、自分で `gh secret set` や GitHub UI に入力しない。** ユーザーがチャットにAPIキーを直接貼っても、それを使って登録作業を代行しない。値の入力は必ずユーザー本人に行わせる（詳細はステップ5）。
- 対象リポジトリの `main`/`master` へ、ユーザーの確認なしにpushしない。
- 既存の `backlog-docs/`・同期スクリプト・ワークフローファイルがある場合、確認なしに上書きしない。

## 前提知識（実機検証済み。必ず踏まえること）

- Backlog Document APIには**更新(update)エンドポイントが存在しない**。「更新」は常に「削除→再作成」で実現する。これは仕様上の制約であり、バグではない。再作成のたびにドキュメントIDが変わることをユーザーに伝えておくとよい。
- 既存ドキュメントの検索には `documents/tree` ではなく **`GET /api/v2/documents?projectIdOrKey=...`（一覧API）を使う**こと。`tree`はサイドバーに手動で追加された記事しか含まれないため、この同期の仕組みで新規作成した記事は次回タイトル照合できず、重複作成されてしまう（実際に踏んだバグ）。
- `documents`・`documents/tree` の検索系エンドポイントは、クエリパラメータに **`projectIdOrKey` を要求する（`projectId`ではない）**。`projectId`を渡すと本文なしの404になり、原因が分かりにくい。
- 一方でドキュメント作成 `POST /api/v2/documents` は、フォームボディに **`projectId`（数値ID）** ・`title`・`content` を渡す（こちらは`projectId`でよい）。
- 認証はクエリパラメータ `apiKey`（Backlog独自の方式）で行う。

これらは `assets/sync-backlog-documents.mjs` に既に反映済みなので、実装をゼロから考え直す必要はない。

## 実行手順

### ステップ1: 対象を確認する

引数から対象リポジトリのパス（省略時はカレントディレクトリ）とドキュメント用フォルダ名（省略時は `backlog-docs`）を決める。対象がGitリポジトリであることを確認する。

```bash
git -C <target> rev-parse --show-toplevel
```

### ステップ2: 既存ファイルの重複確認

以下が既に存在する場合は、上書きしてよいかユーザーに確認してから進める（黙って上書きしない）。

- `<target>/<docs-dir>/`
- `<target>/scripts/sync-backlog-documents.mjs`
- `<target>/.github/workflows/sync-backlog-documents.yml`

### ステップ3: ファイル一式を設置する

`assets/` のテンプレートをコピーし、`__DOCS_DIR__` をユーザー指定のフォルダ名に置換する。

```bash
mkdir -p <target>/scripts <target>/.github/workflows <target>/<docs-dir>

sed "s/__DOCS_DIR__/<docs-dir>/g" assets/sync-backlog-documents.mjs \
  > <target>/scripts/sync-backlog-documents.mjs

sed "s/__DOCS_DIR__/<docs-dir>/g" assets/sync-backlog-documents.yml \
  > <target>/.github/workflows/sync-backlog-documents.yml

sed "s/__DOCS_DIR__/<docs-dir>/g" assets/example-doc.md \
  > <target>/<docs-dir>/example-doc.md
```

サンプルドキュメントの内容についてユーザーから具体的な指示があれば、`example-doc.md` の代わりにその内容で1本目のMarkdownを作成してよい。

コピー後は必ず `node --check` でスクリプトの構文を確認する。

```bash
node --check <target>/scripts/sync-backlog-documents.mjs
```

### ステップ4: READMEへの追記（存在する場合）

対象リポジトリに `README.md` があれば、この同期の仕組みの説明と、必要なSecrets一覧をセクションとして追記する（既存の目次・章構成があれば、その形式に合わせる）。

### ステップ5: 必要なSecretsをユーザーに案内する（自分では入力しない）

以下3つのSecretsを対象リポジトリに登録する必要があることを伝え、コマンドを提示する。**特にAPIキーは値をコマンド引数に含めない**（シェル履歴に平文で残るため）。

```bash
gh secret set BACKLOG_SPACE_HOST --repo <owner>/<repo> --body "<space>.backlog.com"
gh secret set BACKLOG_PROJECT_ID --repo <owner>/<repo> --body "<プロジェクトの数値ID>"
gh secret set BACKLOG_API_KEY --repo <owner>/<repo>
```

3行目は対話プロンプト（`? Paste your secret`）が出るので、そこでAPIキーを貼り付けてもらう。もしユーザーがAPIキーをチャットに直接貼ってきた場合は、その値を使って登録作業をしない。チャット上のキーは漏えいしたものとして扱い、Backlog側での失効・再発行と、上記コマンドでの自分自身での再登録を依頼する。

### ステップ6: コミット・push・動作確認（ユーザーの合意を得てから）

Secrets登録が完了したとユーザーが言ったら:

1. コミットしてよいか確認してからコミット・push
2. `gh workflow run sync-backlog-documents.yml --repo <owner>/<repo>` で手動起動（`backlog-docs/**/*.md` へのpushでも自動起動する）
3. `gh run watch <run-id> --exit-status` で完了を待つ
4. 失敗したら、まず「前提知識」に書いた2つの既知の落とし穴（`projectId` vs `projectIdOrKey`、tree vs 一覧API）に該当していないかを疑い、ログ（`gh run view <run-id> --log --job <job-id>`）で実際のHTTPステータスとレスポンス本文を確認する
5. 成功したら、`bee` CLIが使える環境であれば `bee document list -p <PROJECT_KEY> --json` などで実際にBacklog側に反映されたことを確認する

## 参考

- 実装・落とし穴の発見は `ourai-run/backlog-general` リポジトリでの実機検証に基づく（`docs/backlog-wiki-vs-document.md`, `docs/backlog-document-editing.md` も参照）。
