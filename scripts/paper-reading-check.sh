#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PAPER_DIR="${PROJECT_DIR}/docs/paper-reading"
ASSET_DIR="${PROJECT_DIR}/docs/public/paper-reading/assets"

PAGES=(
  index.md
  model-architectures.md
  reasoning-vision-models.md
  rl-and-distillation.md
  agent-systems.md
  vla-robotics.md
  evaluation-and-theory.md
  resources.md
)

for page in "${PAGES[@]}"; do
  file="${PAPER_DIR}/${page}"
  test -f "${file}"
  rg -q '<ResearchWorkbench preset=' "${file}"
  rg -q '^pageClass: paper-reading-page$' "${file}"
  rg -q '<PaperPageNavigator />' "${file}"
done

if rg -q 'STRUCTURED_SUMMARY|结构化导读|^## 完整原始笔记' "${PAPER_DIR}"/*.md; then
  echo "论文速读仍包含已废弃的双层导读结构。" >&2
  exit 1
fi

CHAR_COUNT="$(wc -m "${PAPER_DIR}"/*.md | tail -n 1 | awk '{print $1}')"
if [[ ! "${CHAR_COUNT}" =~ ^[0-9]+$ ]] || (( CHAR_COUNT < 100390 )); then
  echo "论文速读内容规模异常：当前 ${CHAR_COUNT:-0} 字符，不能少于源文件的 100390。" >&2
  exit 1
fi

IMAGE_REFERENCE_COUNT="$(rg --no-filename -o '<ZoomableImage ' "${PAPER_DIR}"/*.md | wc -l | tr -d ' ')"
IMAGE_ASSET_COUNT="$(find "${ASSET_DIR}" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
if [[ "${IMAGE_REFERENCE_COUNT}" != "97" || "${IMAGE_ASSET_COUNT}" != "97" ]]; then
  echo "论文图片不完整：引用 ${IMAGE_REFERENCE_COUNT}，资源 ${IMAGE_ASSET_COUNT}，预期均为 97。" >&2
  exit 1
fi

while IFS= read -r encoded_name; do
  decoded_name="$(node -e 'process.stdout.write(decodeURIComponent(process.argv[1]))' "${encoded_name}")"
  if [[ ! -f "${ASSET_DIR}/${decoded_name}" ]]; then
    echo "论文图片引用缺失：${decoded_name}" >&2
    exit 1
  fi
done < <(rg --no-filename -o 'src="/paper-reading/assets/[^"]+' "${PAPER_DIR}"/*.md | sed 's#src="/paper-reading/assets/##' | sort -u)

EXTERNAL_LINK_COUNT="$(rg --no-filename -o 'https?://[^) >]+' "${PAPER_DIR}"/*.md | sort -u | wc -l | tr -d ' ')"
if [[ ! "${EXTERNAL_LINK_COUNT}" =~ ^[0-9]+$ ]] || (( EXTERNAL_LINK_COUNT < 110 )); then
  echo "论文速读外链数量异常：当前 ${EXTERNAL_LINK_COUNT:-0}，至少应为 110。" >&2
  exit 1
fi

if rg -q '图片和附件/' "${PAPER_DIR}"/*.md; then
  echo "论文速读仍包含未迁移的本地图片路径。" >&2
  exit 1
fi

echo "论文速读检查通过：${#PAGES[@]} 个分栏，${CHAR_COUNT} 字符，${EXTERNAL_LINK_COUNT} 个独立外链，${IMAGE_REFERENCE_COUNT} 张可交互图片。"
