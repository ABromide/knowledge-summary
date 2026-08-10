#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/docs/.vitepress/dist"

cd "${PROJECT_DIR}"
npm run docs:check

test -f "${DIST_DIR}/index.html"
test -f "${DIST_DIR}/assets/logo.svg"
test -f "${DIST_DIR}/assets/logo-dark.svg"
test -f "${DIST_DIR}/zh-cn/stage-1/ai-capabilities-through-games/index.html"
test -f "${DIST_DIR}/appendix/development-rules.html"
test -f "${DIST_DIR}/appendix/attribution.html"
grep -q "把零散知识沉淀为可复用体系" "${DIST_DIR}/index.html"
grep -q "AI 时代的编程初体验" "${DIST_DIR}/zh-cn/stage-1/ai-capabilities-through-games/index.html"
grep -q "项目开发守则" "${PROJECT_DIR}/AGENTS.md"
grep -q '"index.md"' "${DIST_DIR}/hashmap.json"
grep -q '"zh-cn_stage-1_ai-capabilities-through-games_index.md"' "${DIST_DIR}/hashmap.json"

echo "构建与静态产物检查通过。"
