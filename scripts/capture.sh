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

if [[ ! "${WINDOW_SIZE}" =~ ^([0-9]+),([0-9]+)$ ]]; then
  echo "窗口尺寸必须使用宽度,高度格式。" >&2
  exit 2
fi

CAPTURE_WIDTH="${BASH_REMATCH[1]}"
CAPTURE_HEIGHT="${BASH_REMATCH[2]}"

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

if (( CAPTURE_WIDTH < 500 )); then
  PROFILE_ROOT="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
  PROFILE_DIR="$(mktemp -d "${PROFILE_ROOT}/knowledge-capture.XXXXXX")"
  CHROME_PID=""

  cleanup() {
    if [[ -n "${CHROME_PID}" ]] && kill -0 "${CHROME_PID}" 2>/dev/null; then
      kill "${CHROME_PID}" 2>/dev/null || true
      wait "${CHROME_PID}" 2>/dev/null || true
    fi
    if [[
      -n "${PROFILE_DIR}" &&
      -d "${PROFILE_DIR}" &&
      ! -L "${PROFILE_DIR}" &&
      "${PROFILE_DIR}" == "${PROFILE_ROOT}/knowledge-capture."*
    ]]; then
      rm -rf -- "${PROFILE_DIR:?}"
    fi
  }
  trap cleanup EXIT

  "${CHROME_BIN}" \
    --headless=new \
    --hide-scrollbars \
    --disable-gpu \
    --no-first-run \
    --remote-debugging-port=0 \
    --user-data-dir="${PROFILE_DIR}" \
    "${CHROME_ARGS[@]}" \
    about:blank >"${PROFILE_DIR}/chrome.log" 2>&1 &
  CHROME_PID="$!"

  for _ in {1..100}; do
    [[ -s "${PROFILE_DIR}/DevToolsActivePort" ]] && break
    sleep 0.05
  done

  if [[ ! -s "${PROFILE_DIR}/DevToolsActivePort" ]]; then
    echo "Chrome 调试端口启动失败。" >&2
    sed -n '1,80p' "${PROFILE_DIR}/chrome.log" >&2
    exit 1
  fi

  DEVTOOLS_PORT="$(sed -n '1p' "${PROFILE_DIR}/DevToolsActivePort")"
  if [[ ! "${DEVTOOLS_PORT}" =~ ^[0-9]+$ ]]; then
    echo "Chrome 调试端口无效。" >&2
    exit 1
  fi

  node --input-type=module - \
    "${DEVTOOLS_PORT}" \
    "${PAGE_URL}" \
    "${OUTPUT_PATH}" \
    "${CAPTURE_WIDTH}" \
    "${CAPTURE_HEIGHT}" <<'NODE'
import { writeFile } from 'node:fs/promises'

const [, , port, pageUrl, outputPath, widthValue, heightValue] = process.argv
const width = Number.parseInt(widthValue, 10)
const height = Number.parseInt(heightValue, 10)
const target = await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent('about:blank')}`, {
  method: 'PUT'
}).then((response) => {
  if (!response.ok) throw new Error(`创建 Chrome 页面失败：HTTP ${response.status}`)
  return response.json()
})

const socket = new WebSocket(target.webSocketDebuggerUrl)
const pending = new Map()
const eventWaiters = new Map()
let nextId = 1

await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true })
  socket.addEventListener('error', reject, { once: true })
})

socket.addEventListener('message', ({ data }) => {
  const message = JSON.parse(data)
  if (message.id) {
    const handler = pending.get(message.id)
    if (!handler) return
    pending.delete(message.id)
    if (message.error) handler.reject(new Error(message.error.message))
    else handler.resolve(message.result)
    return
  }
  const waiters = eventWaiters.get(message.method)
  if (!waiters) return
  eventWaiters.delete(message.method)
  for (const resolve of waiters) resolve(message.params)
})

function command(method, params = {}) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    socket.send(JSON.stringify({ id, method, params }))
  })
}

function waitForEvent(method) {
  return new Promise((resolve) => {
    const waiters = eventWaiters.get(method) || []
    waiters.push(resolve)
    eventWaiters.set(method, waiters)
  })
}

await command('Page.enable')
await command('Emulation.setDeviceMetricsOverride', {
  width,
  height,
  deviceScaleFactor: 1,
  mobile: false,
  screenWidth: width,
  screenHeight: height
})
await command('Emulation.setScrollbarsHidden', { hidden: true })
const loaded = waitForEvent('Page.loadEventFired')
await command('Page.navigate', { url: pageUrl })
await loaded
await new Promise((resolve) => setTimeout(resolve, 500))

const screenshot = await command('Page.captureScreenshot', {
  format: 'png',
  fromSurface: true,
  captureBeyondViewport: false
})
const image = Buffer.from(screenshot.data, 'base64')
await writeFile(outputPath, image)
console.log(`${image.byteLength} bytes written to file ${outputPath}`)
socket.close()
NODE
  exit 0
fi

"${CHROME_BIN}" \
  --headless=new \
  --hide-scrollbars \
  --disable-gpu \
  "${CHROME_ARGS[@]}" \
  --window-size="${WINDOW_SIZE}" \
  --screenshot="${OUTPUT_PATH}" \
  "${PAGE_URL}"
