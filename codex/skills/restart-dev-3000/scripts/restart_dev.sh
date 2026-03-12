#!/usr/bin/env bash
set -euo pipefail

PORT="3000"

if [[ "${1:-}" == "--port" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "[ERROR] --port requires a value" >&2
    exit 1
  fi
  PORT="$2"
  shift 2
fi

if [[ "${1:-}" == "--" ]]; then
  shift
fi

if [[ "$#" -eq 0 ]]; then
  DEV_CMD=(npm run dev)
else
  DEV_CMD=("$@")
fi

PROJECT_DIR="$(pwd)"
LOCK_FILE="${PROJECT_DIR}/.next/dev/lock"

echo "[INFO] Project: ${PROJECT_DIR}"
echo "[INFO] Target port: ${PORT}"

# 1) Kill listeners on target port.
PORT_PIDS="$(lsof -tiTCP:"${PORT}" -sTCP:LISTEN 2>/dev/null || true)"
if [[ -n "${PORT_PIDS}" ]]; then
  echo "[INFO] Killing processes listening on :${PORT}: ${PORT_PIDS}"
  # shellcheck disable=SC2086
  kill ${PORT_PIDS} 2>/dev/null || true
  sleep 1
fi

# 2) Kill next dev processes for this project.
NEXT_PIDS="$(ps -eo pid=,args= | awk -v p="${PROJECT_DIR}" 'index($0, "next dev") && index($0, p) {print $1}')"
if [[ -n "${NEXT_PIDS}" ]]; then
  echo "[INFO] Killing stale next dev processes for this project: ${NEXT_PIDS}"
  # shellcheck disable=SC2086
  kill ${NEXT_PIDS} 2>/dev/null || true
  sleep 1
fi

# 3) Remove stale lock only if no related next dev process remains.
REMAINING_NEXT="$(ps -eo args= | awk -v p="${PROJECT_DIR}" 'index($0, "next dev") && index($0, p) {print $0}')"
if [[ -z "${REMAINING_NEXT}" && -f "${LOCK_FILE}" ]]; then
  echo "[INFO] Removing stale lock file: ${LOCK_FILE}"
  rm -f "${LOCK_FILE}"
fi

# 4) Start dev server.
echo "[INFO] Starting: ${DEV_CMD[*]}"
exec "${DEV_CMD[@]}"
