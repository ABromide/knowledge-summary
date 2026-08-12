#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PAPER_DIR="${PROJECT_DIR}/docs/paper-reading"
DIST_DIR="${PROJECT_DIR}/docs/.vitepress/dist/paper-reading"

node --input-type=module - "${PAPER_DIR}" <<'NODE'
import { readdir, readFile } from 'node:fs/promises'
import { join } from 'node:path'

const paperDir = process.argv[2]
const files = (await readdir(paperDir)).filter((file) => file.endsWith('.md'))
const errors = []

for (const file of files) {
  const source = await readFile(join(paperDir, file), 'utf8')
  const withoutFences = source.replace(/```[\s\S]*?```/g, '')
  const withoutInlineCode = withoutFences.replace(/`[^`\n]*`/g, '')
  const lines = withoutInlineCode.split(/\r?\n/)

  lines.forEach((line, index) => {
    const lineNumber = index + 1
    if (/\\\(\s*\$|\$\s*\\\)/.test(line)) errors.push(`${file}:${lineNumber} 混用了 \\( 与 $ 定界符`)
    if (/^\s*\$\s*$/.test(line)) errors.push(`${file}:${lineNumber} 存在孤立的 $`)
    if (/\$\\text\{[^}]+\}[^$]*$/.test(line)) errors.push(`${file}:${lineNumber} 行内公式没有闭合`)
  })

  const dollars = [...withoutInlineCode.matchAll(/(?<!\\)\$/g)].length
  if (dollars % 2 !== 0) errors.push(`${file} 的未转义 $ 总数为奇数：${dollars}`)
}

if (errors.length > 0) {
  console.error(errors.join('\n'))
  process.exit(1)
}
NODE

if [[ -d "${DIST_DIR}" ]]; then
  MATH_COUNT="$(rg --no-filename -o 'class="MathJax"' "${DIST_DIR}"/*.html | wc -l | tr -d ' ')"
  if [[ ! "${MATH_COUNT}" =~ ^[0-9]+$ ]] || (( MATH_COUNT < 20 )); then
    echo "构建产物中的 MathJax 公式数量异常：${MATH_COUNT:-0}。" >&2
    exit 1
  fi
  if rg -q 'mjx-merror|data-mjx-error|\$\\text\{|\$\$|\\begin\{(array|aligned|matrix)\}' "${DIST_DIR}"/*.html; then
    echo "构建产物仍包含公式错误标记或未渲染的 TeX 源码。" >&2
    exit 1
  fi
  if ! rg -q 'id="delta-attention-pattern"[\s\S]*class="MathJax"' "${DIST_DIR}/model-architectures.html"; then
    echo "DeltaNet/Attention 层排布公式没有在目标小节中渲染。" >&2
    exit 1
  fi
  echo "公式检查通过：构建产物包含 ${MATH_COUNT} 个 MathJax 公式。"
else
  echo "公式源码检查通过。"
fi
