#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/docs/.vitepress/dist"

cd "${PROJECT_DIR}"
npm run docs:check

test -f "${DIST_DIR}/index.html"
test -f "${DIST_DIR}/assets/logo.svg"
grep -q "把零散知识沉淀为可复用体系" "${DIST_DIR}/index.html"
grep -q '"index.md"' "${DIST_DIR}/hashmap.json"

echo "构建与静态产物检查通过。"
