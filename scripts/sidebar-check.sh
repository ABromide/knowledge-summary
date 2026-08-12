#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

node --input-type=module - "${PROJECT_DIR}/docs/.vitepress/config.mts" <<'NODE'
import { readFile } from 'node:fs/promises'

const configPath = process.argv[2]
const source = await readFile(configPath, 'utf8')
const start = source.indexOf("text: '论文速读'", source.indexOf('sidebar:'))
const end = source.indexOf("text: 'Agent 能力'", start)

if (start < 0 || end < 0) {
  console.error('无法定位论文速读侧栏配置。')
  process.exit(1)
}

const section = source.slice(start, end)
const itemArrays = [...section.matchAll(/\bitems:\s*\[/g)].length
const links = [...section.matchAll(/link:\s*'([^']+)'/g)].map((match) => match[1])
const expected = [
  '/paper-reading/',
  '/paper-reading/model-architectures',
  '/paper-reading/reasoning-vision-models',
  '/paper-reading/rl-and-distillation',
  '/paper-reading/agent-systems',
  '/paper-reading/vla-robotics',
  '/paper-reading/evaluation-and-theory',
  '/paper-reading/resources'
]

if (itemArrays !== 1) {
  console.error(`论文速读侧栏存在混合嵌套结构：检测到 ${itemArrays} 个 items 数组，预期为 1。`)
  process.exit(1)
}
if (JSON.stringify(links) !== JSON.stringify(expected)) {
  console.error(`论文速读侧栏顺序或页面不完整：${links.join(', ')}`)
  process.exit(1)
}

console.log(`侧栏检查通过：论文速读 ${links.length} 个入口均为统一一级结构。`)
NODE
