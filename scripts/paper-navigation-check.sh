#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

node --input-type=module - "${PROJECT_DIR}" <<'NODE'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'

const projectDir = process.argv[2]
const catalogPath = join(projectDir, 'docs/.vitepress/theme/components/PaperCatalog.vue')
const catalog = await readFile(catalogPath, 'utf8')
const targets = [...catalog.matchAll(/page:\s*'([^']+)'/g)].map((match) => match[1])
const errors = []
const seen = new Set()

if (targets.length < 40) errors.push(`交互目录条目过少：${targets.length}`)

for (const target of targets) {
  if (seen.has(target)) errors.push(`交互目录存在重复目标：${target}`)
  seen.add(target)

  const [route, hash] = target.split('#')
  if (!hash) {
    errors.push(`目录没有定位到具体条目：${target}`)
    continue
  }
  if (!route.startsWith('/paper-reading/')) {
    errors.push(`目录目标不在论文分栏：${target}`)
    continue
  }

  const slug = route.slice('/paper-reading/'.length)
  const markdownPath = join(projectDir, 'docs/paper-reading', `${slug || 'index'}.md`)
  const outputPath = join(projectDir, 'docs/.vitepress/dist/paper-reading', `${slug || 'index'}.html`)
  let markdown = ''
  let output = ''
  try {
    markdown = await readFile(markdownPath, 'utf8')
  } catch {
    errors.push(`目录目标缺少 Markdown：${target}`)
    continue
  }
  try {
    output = await readFile(outputPath, 'utf8')
  } catch {
    errors.push(`目录目标缺少构建产物：${target}`)
    continue
  }

  const sourceHasAnchor = markdown.includes(`{#${hash}}`) || markdown.includes(`id="${hash}"`)
  if (!sourceHasAnchor) errors.push(`目录锚点在 Markdown 中不存在：${target}`)
  if (!output.includes(`id="${hash}"`)) errors.push(`目录锚点没有进入构建产物：${target}`)
}

if (errors.length > 0) {
  console.error(errors.join('\n'))
  process.exit(1)
}

console.log(`论文跳转检查通过：${targets.length} 个目录项均定位到有效条目。`)
NODE
