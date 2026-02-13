#!/usr/bin/env bash
# GitHub App Bot による PR 自動承認スクリプト
# 使用方法: bash approve-pr.sh <owner> <repo> <pr_number>
# 依存ツール: bash, openssl, curl

set -euo pipefail

# --- 引数チェック ---
if [ $# -ne 3 ]; then
  echo "Usage: $0 <owner> <repo> <pr_number>" >&2
  exit 1
fi

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# --- 設定ファイル読み込み ---
CONFIG_FILE="$HOME/.claude/github-app-config.env"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  echo "Run the GitHub App setup first." >&2
  exit 1
fi

source "$CONFIG_FILE"

# チルダをホームディレクトリに展開
PRIVATE_KEY_PATH="${GITHUB_APP_PRIVATE_KEY/#\~/$HOME}"

if [ ! -f "$PRIVATE_KEY_PATH" ]; then
  echo "Error: Private key not found: $PRIVATE_KEY_PATH" >&2
  exit 1
fi

# --- base64url エンコード関数 ---
base64url() {
  openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# --- JWT 生成 ---
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 300))

HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | base64url)
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$GITHUB_APP_CLIENT_ID" | base64url)

UNSIGNED="${HEADER}.${PAYLOAD}"
SIGNATURE=$(printf '%s' "$UNSIGNED" | openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" | base64url)

JWT="${UNSIGNED}.${SIGNATURE}"

# --- Installation Access Token 取得 ---
TOKEN_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens")

# jq不要: sedでtokenフィールドを抽出
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"token" *: *"\([^"]*\)".*/\1/p')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Error: Failed to get installation access token" >&2
  echo "Response: $TOKEN_RESPONSE" >&2
  exit 1
fi

# --- PR を APPROVE ---
REVIEW_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: token ${ACCESS_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -d '{"event":"APPROVE","body":"Approved by GitHub App Bot"}' \
  "https://api.github.com/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews")

HTTP_CODE=$(echo "$REVIEW_RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$REVIEW_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "PR #${PR_NUMBER} approved successfully by GitHub App Bot."
else
  echo "Error: Failed to approve PR #${PR_NUMBER} (HTTP ${HTTP_CODE})" >&2
  echo "Response: $RESPONSE_BODY" >&2
  exit 1
fi
