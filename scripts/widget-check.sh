#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -gt 1 ]]; then
  echo "用法：$0 [站点根 URL]" >&2
  exit 2
fi

SITE_URL="${1:-http://127.0.0.1:5173/}"
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [[ ! -x "${CHROME_BIN}" ]]; then
  echo "未找到 Google Chrome：${CHROME_BIN}" >&2
  exit 1
fi

PROFILE_ROOT="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
PROFILE_DIR="$(mktemp -d "${PROFILE_ROOT}/knowledge-widget-check.XXXXXX")"
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
    "${PROFILE_DIR}" == "${PROFILE_ROOT}/knowledge-widget-check."*
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
  about:blank >"${PROFILE_DIR}/chrome.log" 2>&1 &
CHROME_PID="$!"

for _ in {1..300}; do
  [[ -s "${PROFILE_DIR}/DevToolsActivePort" ]] && break
  if ! kill -0 "${CHROME_PID}" 2>/dev/null; then
    break
  fi
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

node --input-type=module - "${DEVTOOLS_PORT}" "${SITE_URL}" <<'NODE'
const [, , port, siteUrl] = process.argv
const target = await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent('about:blank')}`, {
  method: 'PUT'
}).then((response) => {
  if (!response.ok) throw new Error(`创建 Chrome 页面失败：HTTP ${response.status}`)
  return response.json()
})

const socket = new WebSocket(target.webSocketDebuggerUrl)
const pending = new Map()
const eventWaiters = new Map()
const browserErrors = []
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
  if (message.method === 'Runtime.exceptionThrown') {
    browserErrors.push(message.params.exceptionDetails.text)
  }
  if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') {
    browserErrors.push(message.params.args.map((arg) => arg.value || arg.description).join(' '))
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

async function evaluate(expression) {
  const response = await command('Runtime.evaluate', {
    expression,
    awaitPromise: true,
    returnByValue: true
  })
  if (response.exceptionDetails) throw new Error(response.exceptionDetails.text)
  return response.result.value
}

function assert(value, message) {
  if (!value) throw new Error(message)
}

async function pressKey(key, code, virtualKeyCode) {
  await command('Input.dispatchKeyEvent', { type: 'rawKeyDown', key, code, windowsVirtualKeyCode: virtualKeyCode })
  if (key === 'Enter') {
    await command('Input.dispatchKeyEvent', {
      type: 'char',
      key,
      code,
      text: '\r',
      unmodifiedText: '\r',
      windowsVirtualKeyCode: virtualKeyCode
    })
  }
  await command('Input.dispatchKeyEvent', { type: 'keyUp', key, code, windowsVirtualKeyCode: virtualKeyCode })
}

await command('Page.enable')
await command('Runtime.enable')

const cases = [
  { path: 'agents/', width: 1440, mobile: false, label: 'Agent 桌面端' },
  { path: 'agents/', width: 390, mobile: true, label: 'Agent 移动端' },
  { path: 'ai-infra/', width: 1440, mobile: false, label: 'AI Infra 桌面端' },
  { path: 'ai-infra/', width: 390, mobile: true, label: 'AI Infra 移动端' }
]

for (const testCase of cases) {
  await command('Emulation.setDeviceMetricsOverride', {
    width: testCase.width,
    height: 1000,
    deviceScaleFactor: 1,
    mobile: false,
    screenWidth: testCase.width,
    screenHeight: 1000
  })
  const loaded = waitForEvent('Page.loadEventFired')
  await command('Page.navigate', { url: new URL(testCase.path, siteUrl).href })
  await loaded
  await new Promise((resolve) => setTimeout(resolve, 400))

  const layout = await evaluate(`(() => {
    const widget = document.querySelector('.interactive-flow')
    const canvas = document.querySelector('.interactive-flow__canvas')
    const mobile = document.querySelector('.interactive-flow__mobile')
    if (!widget || !canvas || !mobile) return { found: false }
    const bounds = widget.getBoundingClientRect()
    return {
      found: true,
      url: location.href,
      pageFits: document.documentElement.scrollWidth <= window.innerWidth,
      widgetFits: widget.scrollWidth <= widget.clientWidth && bounds.left >= -1 && bounds.right <= window.innerWidth + 1,
      canvasVisible: getComputedStyle(canvas).display !== 'none',
      mobileVisible: getComputedStyle(mobile).display !== 'none'
    }
  })()`)

  assert(layout.found, `${testCase.label}：未找到交互关系图`)
  assert(layout.pageFits, `${testCase.label}：页面出现横向溢出`)
  assert(layout.widgetFits, `${testCase.label}：Widget 超出视口`)
  assert(layout.canvasVisible === !testCase.mobile, `${testCase.label}：桌面图层显示状态错误`)
  assert(layout.mobileVisible === testCase.mobile, `${testCase.label}：移动节点列表显示状态错误`)

  const selector = testCase.mobile ? '.interactive-flow__mobile button' : '.interactive-flow__node'
  await evaluate(`document.querySelector(${JSON.stringify(selector)}).focus()`)
  await pressKey('Enter', 'Enter', 13)
  await new Promise((resolve) => setTimeout(resolve, 50))
  const keyboardSelected = await evaluate(`document.querySelector(${JSON.stringify(selector)}).getAttribute('aria-pressed')`)
  assert(keyboardSelected === 'true', `${testCase.label}：Enter 未选中节点`)

  await pressKey('Escape', 'Escape', 27)
  await new Promise((resolve) => setTimeout(resolve, 50))
  const cleared = await evaluate(`document.querySelector(${JSON.stringify(selector)}).getAttribute('aria-pressed')`)
  assert(cleared === 'false', `${testCase.label}：Escape 未清除选择`)

  const clicked = await evaluate(`(async () => {
    const nodes = document.querySelectorAll(${JSON.stringify(selector)})
    nodes[1].dispatchEvent(new MouseEvent('click', { bubbles: true }))
    await new Promise((resolve) => requestAnimationFrame(resolve))
    return {
      pressed: nodes[1].getAttribute('aria-pressed'),
      detail: document.querySelector('.interactive-flow__detail').textContent.trim()
    }
  })()`)
  assert(clicked.pressed === 'true', `${testCase.label}：点击未选中节点`)
  assert(clicked.detail.length > 20, `${testCase.label}：详情区没有更新`)
  console.log(`${testCase.label}：通过`)
}

const infraCases = [
  { path: 'ai-infra/scaling-workloads', width: 1440, label: '容量与决策 Widget 桌面端', capacity: true, tradeoff: true },
  { path: 'ai-infra/scaling-workloads', width: 390, label: '容量与决策 Widget 移动端', capacity: true, tradeoff: true },
  { path: 'ai-infra/interconnect-collectives', width: 1440, label: '通信拓扑 Widget 桌面端', topology: true, tradeoff: true },
  { path: 'ai-infra/distributed-training', width: 390, label: '并行拓扑 Widget 移动端', topology: true, tradeoff: true }
]

for (const testCase of infraCases) {
  await command('Emulation.setDeviceMetricsOverride', {
    width: testCase.width,
    height: 1000,
    deviceScaleFactor: 1,
    mobile: false,
    screenWidth: testCase.width,
    screenHeight: 1000
  })
  const loaded = waitForEvent('Page.loadEventFired')
  await command('Page.navigate', { url: new URL(testCase.path, siteUrl).href })
  await loaded
  await new Promise((resolve) => setTimeout(resolve, 400))

  const layout = await evaluate(`(() => {
    const widgets = [...document.querySelectorAll('.capacity-lab, .tradeoff-explorer, .topology-explorer')]
    return {
      count: widgets.length,
      pageFits: document.documentElement.scrollWidth <= window.innerWidth,
      widgetsFit: widgets.every((widget) => {
        const bounds = widget.getBoundingClientRect()
        return widget.scrollWidth <= widget.clientWidth && bounds.left >= -1 && bounds.right <= window.innerWidth + 1
      })
    }
  })()`)
  assert(layout.count >= 2, `${testCase.label}：交互 Widget 数量异常`)
  assert(layout.pageFits, `${testCase.label}：页面出现横向溢出`)
  assert(layout.widgetsFit, `${testCase.label}：Widget 超出视口`)

  if (testCase.capacity) {
    const changed = await evaluate(`(async () => {
      const input = document.querySelector('.capacity-lab input[type="range"]')
      const metric = document.querySelector('.capacity-lab__results strong')
      const before = metric?.textContent
      input.value = input.max
      input.dispatchEvent(new Event('input', { bubbles: true }))
      await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
      return { before, after: metric?.textContent }
    })()`)
    assert(changed.before !== changed.after, `${testCase.label}：滑块没有更新估算结果`)
  }

  if (testCase.tradeoff) {
    const changed = await evaluate(`(async () => {
      const tabs = document.querySelectorAll('.tradeoff-explorer__tabs button')
      const panel = document.querySelector('.tradeoff-explorer__panel')
      const before = panel?.textContent
      tabs[1].click()
      await new Promise((resolve) => requestAnimationFrame(resolve))
      return { selected: tabs[1].getAttribute('aria-selected'), changed: before !== panel?.textContent }
    })()`)
    assert(changed.selected === 'true' && changed.changed, `${testCase.label}：决策标签没有切换内容`)
  }

  if (testCase.topology) {
    await evaluate(`document.querySelector('.topology-explorer__toggles button').focus()`)
    await pressKey('ArrowRight', 'ArrowRight', 39)
    await new Promise((resolve) => setTimeout(resolve, 50))
    const changed = await evaluate(`(() => {
      const tabs = document.querySelectorAll('.topology-explorer__toggles button')
      return {
        selected: tabs[1].getAttribute('aria-selected'),
        labelledBy: document.querySelector('.topology-explorer__panel')?.getAttribute('aria-labelledby')
      }
    })()`)
    assert(changed.selected === 'true', `${testCase.label}：方向键没有切换拓扑`)
    assert(changed.labelledBy?.endsWith('-1'), `${testCase.label}：拓扑面板无障碍关联未更新`)
  }
  console.log(`${testCase.label}：通过`)
}

const paperCases = [
  { path: 'paper-reading/', width: 1440, label: '论文目录桌面端', catalog: true },
  { path: 'paper-reading/', width: 390, label: '论文目录移动端', catalog: true },
  { path: 'paper-reading/model-architectures', width: 1440, label: '论文图片桌面端', image: true },
  { path: 'paper-reading/rl-and-distillation', width: 390, label: '论文长文移动端', image: true }
]

for (const testCase of paperCases) {
  await command('Emulation.setDeviceMetricsOverride', {
    width: testCase.width,
    height: 1000,
    deviceScaleFactor: 1,
    mobile: false,
    screenWidth: testCase.width,
    screenHeight: 1000
  })
  const expectedUrl = new URL(testCase.path, siteUrl).href
  const loaded = waitForEvent('Page.loadEventFired')
  await command('Page.navigate', { url: expectedUrl })
  await loaded
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const ready = await evaluate(`(() => {
      const expected = new URL(${JSON.stringify(expectedUrl)})
      return location.pathname === expected.pathname
        && Boolean(document.querySelector('.research-workbench'))
        && document.querySelectorAll('.paper-page-navigator__list a').length >= 2
    })()`)
    if (ready) break
    await new Promise((resolve) => setTimeout(resolve, 100))
  }

  const layout = await evaluate(`(() => {
    const workbench = document.querySelector('.research-workbench')
    const navigator = document.querySelector('.paper-page-navigator')
    if (!workbench || !navigator) return { found: false }
    const bounds = workbench.getBoundingClientRect()
    const navigatorBounds = navigator.getBoundingClientRect()
    return {
      found: true,
      pageFits: document.documentElement.scrollWidth <= window.innerWidth,
      widgetFits: workbench.scrollWidth <= workbench.clientWidth && bounds.left >= -1 && bounds.right <= window.innerWidth + 1,
      navigatorFits: navigator.scrollWidth <= navigator.clientWidth && navigatorBounds.left >= -1 && navigatorBounds.right <= window.innerWidth + 1
    }
  })()`)
  assert(layout.found, `${testCase.label}：未找到论文阅读工作台（${await evaluate('location.href')}）`)
  assert(layout.pageFits, `${testCase.label}：页面出现横向溢出`)
  assert(layout.widgetFits, `${testCase.label}：阅读工作台超出视口`)
  assert(layout.navigatorFits, `${testCase.label}：页内主题导航超出视口`)

  const navigatorChanged = await evaluate(`(async () => {
    const links = [...document.querySelectorAll('.paper-page-navigator__list a')]
    if (links.length < 2) return {
      count: links.length,
      allHeadings: document.querySelectorAll('.VPDoc .vp-doc h2[id]').length,
      directHeadings: document.querySelectorAll('.VPDoc .vp-doc > h2[id]').length,
      articleClass: document.querySelector('.VPDoc .vp-doc')?.className
    }
    links[1].click()
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    return {
      count: links.length,
      hash: location.hash,
      target: links[1].hash,
      current: links[1].getAttribute('aria-current')
    }
  })()`)
  assert(navigatorChanged.count >= 2, `${testCase.label}：页内主题导航条目不足（${JSON.stringify(navigatorChanged)}）`)
  assert(navigatorChanged.hash === navigatorChanged.target, `${testCase.label}：页内主题导航没有更新锚点`)
  assert(navigatorChanged.current === 'location', `${testCase.label}：页内主题导航没有更新选中状态`)

  await evaluate(`document.querySelector('.research-workbench__tabs button').focus()`)
  await pressKey('ArrowRight', 'ArrowRight', 39)
  await new Promise((resolve) => setTimeout(resolve, 50))
  const workbenchChanged = await evaluate(`(() => {
    const tabs = document.querySelectorAll('.research-workbench__tabs button')
    return {
      selected: tabs[1]?.getAttribute('aria-selected'),
      labelledBy: document.querySelector('.research-workbench__panel')?.getAttribute('aria-labelledby')
    }
  })()`)
  assert(workbenchChanged.selected === 'true', `${testCase.label}：方向键没有切换阅读视角`)
  assert(workbenchChanged.labelledBy?.endsWith('-1'), `${testCase.label}：阅读面板关联未更新`)

  if (testCase.catalog) {
    const catalogChanged = await evaluate(`(async () => {
      const input = document.querySelector('#paper-catalog-search')
      input.value = 'On-policy'
      input.dispatchEvent(new Event('input', { bubbles: true }))
      await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
      const results = [...document.querySelectorAll('.paper-catalog__results a')]
      return {
        count: results.length,
        text: results.map((item) => item.textContent).join(' '),
        href: results[0]?.href,
        pageFits: document.documentElement.scrollWidth <= window.innerWidth
      }
    })()`)
    assert(catalogChanged.count >= 2, `${testCase.label}：搜索结果数量异常`)
    assert(catalogChanged.text.toLowerCase().includes('on-policy'), `${testCase.label}：搜索结果内容异常`)
    assert(catalogChanged.href?.includes('#'), `${testCase.label}：搜索结果没有精确条目锚点`)
    assert(catalogChanged.pageFits, `${testCase.label}：筛选后出现横向溢出`)

    await evaluate(`document.querySelector('.paper-catalog__results a').click()`)
    for (let attempt = 0; attempt < 30; attempt += 1) {
      const arrived = await evaluate(`(() => {
        const expected = new URL(${JSON.stringify(catalogChanged.href)})
        return location.href === expected.href && Boolean(document.getElementById(decodeURIComponent(expected.hash.slice(1))))
      })()`)
      if (arrived) break
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    await new Promise((resolve) => setTimeout(resolve, 500))
    const jump = await evaluate(`(() => {
      const id = decodeURIComponent(location.hash.slice(1))
      const target = document.getElementById(id)
      const heading = target?.matches('h2, h3, h4') ? target : target?.nextElementSibling
      return {
        url: location.href,
        hash: location.hash,
        found: Boolean(target),
        heading: heading?.textContent?.trim(),
        top: target?.getBoundingClientRect().top,
        headingIds: [...document.querySelectorAll('.vp-doc h2[id]')].slice(0, 12).map((item) => item.id)
      }
    })()`)
    assert(jump.hash === new URL(catalogChanged.href).hash, `${testCase.label}：URL 锚点没有保留`)
    assert(jump.found && jump.heading, `${testCase.label}：没有定位到论文条目（${JSON.stringify(jump)}）`)
    assert(jump.top >= 48 && jump.top <= 220, `${testCase.label}：条目被固定导航遮挡或未滚动到可视区（${JSON.stringify(jump)}）`)
  }

  if (testCase.image) {
    const preview = await evaluate(`(async () => {
      const trigger = document.querySelector('.zoomable-image__trigger')
      const sourceImage = trigger?.querySelector('img')
      if (!trigger || !sourceImage) return { found: false }
      sourceImage.loading = 'eager'
      trigger.scrollIntoView({ block: 'center' })
      if (!sourceImage.complete) {
        await Promise.race([
          new Promise((resolve) => sourceImage.addEventListener('load', resolve, { once: true })),
          new Promise((resolve) => setTimeout(resolve, 3000))
        ])
      }
      trigger.click()
      await new Promise((resolve) => requestAnimationFrame(resolve))
      const dialog = document.querySelector('.zoomable-image__dialog')
      const buttons = [...dialog.querySelectorAll('footer button')]
      buttons.find((button) => button.textContent.includes('放大'))?.click()
      await new Promise((resolve) => requestAnimationFrame(resolve))
      const zoomText = dialog.querySelector('output')?.textContent
      dialog.querySelector('header button')?.click()
      return {
        found: true,
        loaded: sourceImage.naturalWidth > 0,
        zoomText,
        closed: !dialog.open
      }
    })()`)
    assert(preview.found && preview.loaded, `${testCase.label}：图片资源没有加载`)
    assert(preview.zoomText === '125%', `${testCase.label}：图片缩放没有更新`)
    assert(preview.closed, `${testCase.label}：图片预览没有关闭`)
  }
  console.log(`${testCase.label}：通过`)
}

assert(browserErrors.length === 0, `浏览器错误：${browserErrors.join(' | ')}`)
socket.close()
console.log('全部交互 Widget 检查通过。')
NODE
