---
name: linear-session-link
description: Linear の課題(issue)・プロジェクトを作成・更新・参照するとき、その項目の Links(Resources)欄に「いまの Claude 会話へ戻る claude:// リンク」を付ける。無ければ追加し、あれば何もしない。「Linear に課題作って」「AUT-123 見て」「このプロジェクトの状況は」「Linear に起票」などで発動。検索結果を一覧で眺めるだけのときは付けない。Use when creating, updating or opening a specific Linear issue or project, to attach a back-link to the current Claude session.
---

# Linear 項目に Claude 会話へのリンクを付ける

目的: Linear の課題・プロジェクトからクリック一つで、関係する Claude デスクトップの会話(Code タブのセッション)に戻れるようにする。
`claude://` リンクはデスクトップアプリが直接受け取るので、ブラウザの新規タブではなく既存のアプリで会話が開く。

## 前提(使えない環境では何もしない)

- いまの会話のリンクは Claude デスクトップアプリのツール `mcp__ccd_session_mgmt__get_session` でしか取れない。
- このツールが無い環境(Codex、tmux 内の素の Claude Code CLI など)では、リンク付けはせず、
  「この環境では会話リンクを取得できないので Linear へのリンク追加は省略しました」と一言伝えて本来の作業を続ける。
- デスクトップアプリから devbox などへ SSH 接続したセッションでもツールがあれば同じ手順で使える。

## 動作確認済みの形式(2026-11-07, AUT-1154 / P-AUT-34 で確認)

- プロジェクト: Overview の **Resources 欄**(`save_project` の `links`)← 標準
- 課題: **Links 欄(Resources)への添付**(`save_issue` の `links`)← 標準
- 本文の Markdown リンク `[表示名](claude://claude.ai/epitaxy/local_<id>)` / `[表示名](claude://code/continue?session=local_<id>)` も動く
- 本文に URL を裸で書く形は使わない(動作未確認)

## 手順

### 1. いまの会話のリンクを取得する

`mcp__ccd_session_mgmt__get_session` を `session_id: "self"` で呼び、返ってきた `link`(例: `claude://claude.ai/epitaxy/local_xxxx`)と `title` を使う。
deferred なら先に ToolSearch で `select:mcp__ccd_session_mgmt__get_session` を読み込む。
`link` が返らない(組織でアプリリンクが無効など)ときは `claude://claude.ai/epitaxy/<sessionId>` を組み立てて使い、その旨を一言伝える。

### 2. Linear 項目を作るとき

- プロジェクト: `save_project` の `links` に `[{url: <link>, title: "Claude会話: <セッションのtitle>"}]` を渡す(Overview の Resources に並ぶ)。
- 課題: `save_issue` の `links` に同じ形で渡す。
- どちらも本文(description)には書かない。ユーザーが本文にも欲しいと言った場合だけ Markdown リンクで追記する。

### 3. 既存の Linear 項目を参照・更新するとき

- 課題: `get_issue`(`attachments` を含む)で添付を確認する。
- プロジェクト: `get_project` を `includeResources: true` で呼び、Resources の links を確認する。
- 判定:
  - いまの会話の `local_<id>` を含む `claude://` リンクがある → 何もしない。
  - 無い → `save_issue` / `save_project` に `id` と `links` を渡して追加する(append-only なので既存リンクは消えない)。
  - 別の会話のリンクだけがある → それも残し、いまの会話のリンクを追加する(会話ごとに1本ずつ並べる)。
- `list_issues` の検索結果を眺めるだけのときは付けない。ユーザーが具体的に扱う課題・プロジェクトにだけ付ける。

### 4. 報告

付けた/既にあった/省略した、を一行で伝える。例: 「AUT-123 の Links 欄にこの会話へのリンクを追加しました」。

## 注意

- 本番の Linear ワークスペースへの書き込みになる。リンク追加はこのスキルで承認済みの範囲だが、それ以外の変更はいつも通りユーザーの依頼に従う。
- セッション ID は会話ごとに違う。前の会話の ID を使い回さず、必ず `self` で取り直す。
