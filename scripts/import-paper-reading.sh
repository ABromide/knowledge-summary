#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -gt 1 ]]; then
  echo "用法：$0 [论文速读目录]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${1:-/Users/lizewei/Downloads/论文速读}"
SOURCE_FILE="${SOURCE_DIR}/论文速读.md"
SOURCE_ASSETS="${SOURCE_DIR}/图片和附件"
OUTPUT_DIR="${PROJECT_DIR}/docs/paper-reading"
OUTPUT_ASSETS="${PROJECT_DIR}/docs/public/paper-reading/assets"

if [[ ! -f "${SOURCE_FILE}" || ! -d "${SOURCE_ASSETS}" ]]; then
  echo "论文速读源文件或图片目录不存在：${SOURCE_DIR}" >&2
  exit 1
fi

if [[ -e "${OUTPUT_DIR}/index.md" ]]; then
  echo "论文速读已经导入。为保护人工整理后的正文、公式与条目锚点，本脚本不会覆盖现有页面。" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}" "${OUTPUT_ASSETS}"
find "${SOURCE_ASSETS}" -maxdepth 1 -type f -name '*.png' -exec cp -p {} "${OUTPUT_ASSETS}/" \;

node --input-type=module - "${SOURCE_FILE}" "${OUTPUT_DIR}" <<'NODE'
import { readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'

const [, , sourceFile, outputDir] = process.argv
const source = await readFile(sourceFile, 'utf8')
const lines = source.split(/\r?\n/)

const pages = [
  { file: 'index.md', title: '论文速读', description: '模型、强化学习、Agent、VLA、数据、评估与理论资料的主题化阅读索引。', start: 1, end: 64, preset: 'overview', duration: '约 15 分钟', output: '完整论文阅读地图' },
  { file: 'model-architectures.md', title: '模型架构与推理机制', description: '从 Partial RoPE、QK-Norm、混合注意力到条件记忆与交错思考。', start: 65, end: 628, preset: 'architectures', duration: '约 70 分钟', output: '模型架构选型与机制对照表' },
  { file: 'reasoning-vision-models.md', title: '推理、视觉与 OCR 模型', description: 'DeepSeek、Qwen-VL、MiniMax、PaddleOCR、视觉压缩与 Muon 优化方法。', start: 629, end: 1394, preset: 'reasoning-vision', duration: '约 90 分钟', output: '推理与视觉模型技术地图' },
  { file: 'rl-and-distillation.md', title: '强化学习、蒸馏与持续学习', description: '奖励塑形、策略优化、On-policy 蒸馏、记忆和 Agentic RL 的完整笔记。', start: 1395, end: 2477, preset: 'rl', duration: '约 120 分钟', output: 'RL 方法谱系与实验检查表' },
  { file: 'agent-systems.md', title: 'Agent 学习、记忆与调试', description: '交互式学习、长短期记忆、递归模型、多 Agent 调试与可扩展工具集。', start: 2478, end: 2590, preset: 'agents', duration: '约 25 分钟', output: 'Agent 能力形成路径' },
  { file: 'vla-robotics.md', title: 'VLA 与机器人学习', description: '从 CLIPort、RT-1/2/X、OpenVLA 到世界模型和机器人数据治理。', start: 2591, end: 2808, preset: 'vla', duration: '约 45 分钟', output: 'VLA 架构与数据闭环' },
  { file: 'evaluation-and-theory.md', title: '数据、评估与基础理论', description: '安全评测、函数调用、Judge 偏差、数据污染、结构化生成与超连接。', start: 2809, end: 2939, preset: 'evaluation', duration: '约 35 分钟', output: '评估证据链与理论工具箱' },
  { file: 'resources.md', title: '工程资料与延伸阅读', description: '训练部署、Agent 工程、长上下文、并行、集合通信、张量与 Kernel 实践。', start: 2940, end: lines.length, preset: 'resources', duration: '约 30 分钟', output: '可继续验证的工程资料索引' }
]

function incrementHeadings(text) {
  return text.replace(/^(#{1,5})(\s+)/gm, (_, hashes, spacing) => `${hashes}#${spacing}`)
}

function interactiveImages(text) {
  return text.replace(/!\[([^\]]*)\]\(图片和附件\/([^)]+)\)/g, (_, rawAlt, filename) => {
    const alt = rawAlt.replaceAll('\\', '').replaceAll('"', '&quot;') || '论文笔记配图'
    return `<ZoomableImage src="/paper-reading/assets/${filename}" alt="${alt}" />`
  })
}

for (const page of pages) {
  const original = lines.slice(page.start - 1, page.end).join('\n').trim()
  const preserved = interactiveImages(incrementHeadings(original))
  const frontmatter = `---\ntitle: ${page.title}\ndescription: ${page.description}\n---`
  const header = `# ${page.title}\n\n<SummaryHero\n  :goals="['理解研究问题', '掌握关键机制与公式', '形成可验证的工程判断']"\n  duration="${page.duration}"\n  output="${page.output}"\n>\n\n本页由“论文速读”原始笔记按主题重组。研究问题、方法、证据、工程价值与限制直接并入对应条目，并完整保留公式、链接和图片。\n\n</SummaryHero>\n\n<ResearchWorkbench preset="${page.preset}" />`
  const body = `${frontmatter}\n\n${header}\n\n${preserved}\n`
  await writeFile(join(outputDir, page.file), body, 'utf8')
}

console.log(`已生成 ${pages.length} 个论文速读页面。`)
NODE

SOURCE_IMAGE_COUNT="$(find "${SOURCE_ASSETS}" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
OUTPUT_IMAGE_COUNT="$(find "${OUTPUT_ASSETS}" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"

if [[ "${SOURCE_IMAGE_COUNT}" != "${OUTPUT_IMAGE_COUNT}" ]]; then
  echo "图片迁移数量不一致：源 ${SOURCE_IMAGE_COUNT}，目标 ${OUTPUT_IMAGE_COUNT}。" >&2
  exit 1
fi

echo "论文速读导入完成：${OUTPUT_IMAGE_COUNT} 张图片。"
