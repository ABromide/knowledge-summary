#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
AI_INFRA_DIR="${PROJECT_DIR}/docs/ai-infra"

AI_INFRA_FILES=("${AI_INFRA_DIR}"/*.md)

if [[ "${#AI_INFRA_FILES[@]}" -lt 17 ]]; then
  echo "AI Infra 页面不足：当前 ${#AI_INFRA_FILES[@]} 篇，至少需要 17 篇。" >&2
  exit 1
fi

HAN_COUNT="$(perl -CSD -ne '$count += () = /\p{Han}/g; END { print $count }' "${AI_INFRA_FILES[@]}")"
if [[ ! "${HAN_COUNT}" =~ ^[0-9]+$ ]] || (( HAN_COUNT < 50000 )); then
  echo "AI Infra 中文字符不足：当前 ${HAN_COUNT:-0}，至少需要 50000。" >&2
  exit 1
fi

SOURCE_COUNT="$(rg --no-filename -o 'https://[^) >]+' "${AI_INFRA_FILES[@]}" | sed -E 's/[，。；：、]$//' | sort -u | wc -l | tr -d ' ')"
if [[ ! "${SOURCE_COUNT}" =~ ^[0-9]+$ ]] || (( SOURCE_COUNT < 10 )); then
  echo "AI Infra 独立来源不足：当前 ${SOURCE_COUNT:-0}，至少需要 10 个。" >&2
  exit 1
fi

WIDGET_COUNT="$(rg --no-filename -o '<(InteractiveFlow|CapacityLab|TradeoffExplorer|TopologyExplorer)[ >]' "${AI_INFRA_FILES[@]}" | wc -l | tr -d ' ')"
if [[ ! "${WIDGET_COUNT}" =~ ^[0-9]+$ ]] || (( WIDGET_COUNT < 25 )); then
  echo "AI Infra 交互 Widget 不足：当前 ${WIDGET_COUNT:-0}，至少需要 25 个。" >&2
  exit 1
fi

if rg -q '^```mermaid' "${AI_INFRA_FILES[@]}"; then
  echo "AI Infra 中仍包含 Mermaid 源码块。" >&2
  exit 1
fi

echo "AI Infra 内容检查通过：${#AI_INFRA_FILES[@]} 篇，${HAN_COUNT} 个中文字符，${SOURCE_COUNT} 个独立来源，${WIDGET_COUNT} 个交互 Widget。"
