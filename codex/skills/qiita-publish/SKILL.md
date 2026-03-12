---
name: qiita-publish
description: Qiita 記事をこのリポジトリから安全に公開する。ユーザーが「Qiita にアップして」「Qiita 公開して」「公開 workflow を実行して」「qiita-publish」と言ったときに使用する。`3_output/qiita/*.md` の front matter 確認、画像素材の同期確認、Markdown と素材を同じ push に載せない運用、GitHub Actions の publish 成否確認まで行う。
---

# Qiita Publish

## Overview

このリポジトリの Qiita 公開フローを安全に実行する。

重要なのは、`publish-qiita.yml` が `3_output/qiita/*.md` の push で動く一方、アクション内部ではコミット内の追加・更新ファイル全体を見る点です。新規記事の Markdown と `.svg` / `.drawio` などの素材を同じ push に含めると、公開アクションが素材ファイルまで記事として解釈して失敗することがある。

## Workflow

### 1. 対象記事を確認する

対象は `3_output/qiita/<slug>.md`。

まず確認する:

```bash
sed -n '1,40p' 3_output/qiita/<slug>.md
```

公開前提:

- YAML front matter がある
- `title` / `topics` / `published` が入っている
- `published: true` になっている
- Qiita 公開に不要な先頭 H1 があれば外す

### 2. 画像・図表の参照先を確認する

記事内で `https://raw.githubusercontent.com/AutoFor/life-public/main/qiita/<slug>/...` を参照している場合、対応する素材が public 側に存在する必要がある。

必要に応じて確認する:

```bash
gh api repos/AutoFor/life-public/contents/qiita/<slug> --jq '.[].name'
```

ローカルに素材があり、public 側にまだ無い場合は、先に素材同期を行う。

### 3. 新規記事は「素材」と「Markdown」を分けて push する

これは最重要ルール。

- 素材追加だけのコミットと push を先に行う
- Qiita 公開用の Markdown は別コミットで push する
- `3_output/qiita/<slug>.md` と `3_output/qiita/<slug>/` を同じ push に載せない

理由:

- `.github/workflows/publish-qiita.yml` は Markdown push を契機に走る
- しかし `noraworld/github-to-qiita` はコミット内の変更ファイルを見て処理する
- 同じ push に `.svg` / `.drawio` が含まれると YAML parse error などで失敗しうる

### 4. 素材を同期する

素材だけを反映したいときは、まずローカル同期スクリプトを使う:

```bash
./scripts/sync_qiita_public_assets.sh
```

その後、必要な素材だけを commit / push する。push 後は `sync-qiita-assets-to-public.yml` の成功を確認する。

### 5. Markdown だけを push して公開する

Markdown だけをステージする:

```bash
git add 3_output/qiita/<slug>.md
git status --short
git commit -m "docs: publish qiita article for <slug>"
git push origin main
```

既存の未整理差分がある場合は、それらを巻き込まないこと。

### 6. GitHub Actions の結果を確認する

push 後に `Publish to Qiita` の最新 run を確認する:

```bash
gh api 'repos/AutoFor/life/actions/runs?per_page=5' \
  --jq '.workflow_runs[] | {name, head_sha, status, conclusion, html_url, created_at}'
```

対象コミットの run が `completed` かつ `success` なら完了。

### 7. 失敗時の確認ポイント

まず確認する順番:

1. front matter が壊れていないか
2. `topics` に空要素や空白入りタグがないか
3. 先頭 H1 が不要に重複していないか
4. 同じ push に素材ファイルを含めていないか
5. run ログの `Run noraworld/github-to-qiita@v1.0.1` で YAML parse error や Qiita API error が出ていないか

ログを確認する例:

```bash
gh api 'repos/AutoFor/life/actions/runs/<run_id>/jobs' --jq '.jobs[] | {name, status, conclusion}'
```

必要なら run ログを取得して失敗ステップだけ読む。

## Sandbox Rule

- `gh api` が `error connecting to api.github.com` で失敗したら、権限昇格付きで再実行する。
- `~/.codex/skills/qiita-publish/` への編集が必要なときも、権限昇格付きコマンドを使う。
