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
test -f "${DIST_DIR}/ai-infra/index.html"
test -f "${DIST_DIR}/ai-infra/operator-engineering.html"
test -f "${DIST_DIR}/agents/training-and-reasoning.html"
test -f "${DIST_DIR}/shed/projects.html"
test -f "${DIST_DIR}/appendix/development-rules.html"
test -f "${DIST_DIR}/appendix/notion-sources.html"
test -f "${DIST_DIR}/appendix/attribution.html"
grep -q "Notion 知识总览" "${DIST_DIR}/index.html"
grep -q "写代码前的三个问题" "${DIST_DIR}/ai-infra/operator-engineering.html"
grep -q "On-policy distillation" "${DIST_DIR}/agents/training-and-reasoning.html"
grep -q "项目与实验" "${DIST_DIR}/shed/projects.html"
grep -q "项目开发守则" "${PROJECT_DIR}/AGENTS.md"
grep -q '"index.md"' "${DIST_DIR}/hashmap.json"
grep -q '"ai-infra_index.md"' "${DIST_DIR}/hashmap.json"
grep -q '"agents_training-and-reasoning.md"' "${DIST_DIR}/hashmap.json"

echo "构建与静态产物检查通过。"
