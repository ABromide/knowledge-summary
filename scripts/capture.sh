#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
  echo "用法：$0 <页面 URL> <输出 PNG 路径> [宽度,高度]" >&2
  exit 2
fi

CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PAGE_URL="$1"
OUTPUT_PATH="$2"
WINDOW_SIZE="${3:-1440,1000}"

if [[ ! -x "${CHROME_BIN}" ]]; then
  echo "未找到 Google Chrome：${CHROME_BIN}" >&2
  exit 1
fi

"${CHROME_BIN}" \
  --headless=new \
  --hide-scrollbars \
  --disable-gpu \
  --window-size="${WINDOW_SIZE}" \
  --screenshot="${OUTPUT_PATH}" \
  "${PAGE_URL}"
