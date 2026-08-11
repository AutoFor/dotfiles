#!/usr/bin/env bash
# gh-issue-start.sh -- 作業開始時の issue 起票と、org Project「All Issues」での
# In Progress 化を 1 コマンドで行う。グローバル CLAUDE.md の
# 「作業を始めるときは必ず issue を作って In Progress にする」運用の実行部。
#
# 使い方 (対象リポジトリのディレクトリ内で実行):
#   gh-issue-start.sh "タイトル" ["本文"]   # issue を新規作成して In Progress に
#   gh-issue-start.sh 123                   # 既存 issue #123 を In Progress に (作成しない)
#
# 各 ID は org Project「All Issues」(https://github.com/orgs/AutoFor/projects/6) のもの。
# Project を作り直したときの再取得方法:
#   gh project view 6 --owner AutoFor --format json | jq .id          # PROJECT_ID
#   gh project field-list 6 --owner AutoFor --format json             # Status の field/option ID
set -euo pipefail

OWNER=AutoFor
PROJECT_NUMBER=6
PROJECT_ID=PVT_kwDOD7WBKM4BfC0y
STATUS_FIELD_ID=PVTSSF_lADOD7WBKM4BfC0yzhZYn9s
IN_PROGRESS_OPTION_ID=fe00097a

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") \"<title>\" [\"<body>\"] | <issue番号>" >&2
  exit 1
fi

if [[ "$1" =~ ^[0-9]+$ ]]; then
  url=$(gh issue view "$1" --json url -q .url)
else
  # gh issue create は最終行に issue の URL を出力する
  url=$(gh issue create --title "$1" --body "${2:-}" | tail -n 1)
fi

# 追加済みの issue に対しても item-add は既存アイテムを返すので冪等
item_id=$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$url" --format json | jq -r '.id')
gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" \
  --field-id "$STATUS_FIELD_ID" --single-select-option-id "$IN_PROGRESS_OPTION_ID" > /dev/null

echo "$url (In Progress)"
