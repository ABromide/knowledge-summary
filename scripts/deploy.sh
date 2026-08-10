#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"
BASE_PATH="${BASE_PATH:-/knowledge-summary/}" "${SCRIPT_DIR}/build.sh"
npm exec -- gh-pages \
  --dist docs/.vitepress/dist \
  --message "部署知识总结站点"
