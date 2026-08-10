#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 2 || "$#" -gt 4 ]]; then
  echo "用法：$0 <页面 URL> <输出 PNG 路径> [宽度,高度] [dark]" >&2
  exit 2
fi

CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PAGE_URL="$1"
OUTPUT_PATH="$2"
WINDOW_SIZE="${3:-1440,1000}"
COLOR_MODE="${4:-light}"
CHROME_ARGS=()

if [[ "${COLOR_MODE}" == "dark" ]]; then
  CHROME_ARGS+=(--force-dark-mode)
elif [[ "${COLOR_MODE}" != "light" ]]; then
  echo "颜色模式只支持 light 或 dark。" >&2
  exit 2
fi

if [[ ! -x "${CHROME_BIN}" ]]; then
  echo "未找到 Google Chrome：${CHROME_BIN}" >&2
  exit 1
fi

"${CHROME_BIN}" \
  --headless=new \
  --hide-scrollbars \
  --disable-gpu \
  "${CHROME_ARGS[@]}" \
  --window-size="${WINDOW_SIZE}" \
  --screenshot="${OUTPUT_PATH}" \
  "${PAGE_URL}"
