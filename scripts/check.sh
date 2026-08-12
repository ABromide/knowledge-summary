#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/docs/.vitepress/dist"

cd "${PROJECT_DIR}"
"${SCRIPT_DIR}/content-check.sh"
"${SCRIPT_DIR}/paper-reading-check.sh"
"${SCRIPT_DIR}/sidebar-check.sh"
npm run docs:check
"${SCRIPT_DIR}/math-check.sh"
"${SCRIPT_DIR}/paper-navigation-check.sh"

test -f "${DIST_DIR}/index.html"
test -f "${DIST_DIR}/assets/logo.svg"
test -f "${DIST_DIR}/assets/logo-dark.svg"
test -f "${DIST_DIR}/ai-infra/index.html"
test -f "${DIST_DIR}/ai-infra/operator-engineering.html"
test -f "${DIST_DIR}/ai-infra/scaling-workloads.html"
test -f "${DIST_DIR}/ai-infra/accelerators-memory.html"
test -f "${DIST_DIR}/ai-infra/interconnect-collectives.html"
test -f "${DIST_DIR}/ai-infra/storage-checkpoint.html"
test -f "${DIST_DIR}/ai-infra/scheduling-platform.html"
test -f "${DIST_DIR}/ai-infra/reliability-observability.html"
test -f "${DIST_DIR}/ai-infra/distributed-training.html"
test -f "${DIST_DIR}/ai-infra/training-memory-numerics.html"
test -f "${DIST_DIR}/ai-infra/inference-serving.html"
test -f "${DIST_DIR}/ai-infra/capacity-economics.html"
test -f "${DIST_DIR}/ai-infra/data-pipeline.html"
test -f "${DIST_DIR}/ai-infra/operator-compiler.html"
test -f "${DIST_DIR}/paper-reading/index.html"
test -f "${DIST_DIR}/paper-reading/model-architectures.html"
test -f "${DIST_DIR}/paper-reading/reasoning-vision-models.html"
test -f "${DIST_DIR}/paper-reading/rl-and-distillation.html"
test -f "${DIST_DIR}/paper-reading/agent-systems.html"
test -f "${DIST_DIR}/paper-reading/vla-robotics.html"
test -f "${DIST_DIR}/paper-reading/evaluation-and-theory.html"
test -f "${DIST_DIR}/paper-reading/resources.html"
test -f "${DIST_DIR}/agents/training-and-reasoning.html"
test -f "${DIST_DIR}/shed/projects.html"
test -f "${DIST_DIR}/appendix/development-rules.html"
test -f "${DIST_DIR}/appendix/notion-sources.html"
test -f "${DIST_DIR}/appendix/paper-reading-sources.html"
test -f "${DIST_DIR}/appendix/attribution.html"
grep -q "个人知识总览" "${DIST_DIR}/index.html"
grep -q "论文速读" "${DIST_DIR}/index.html"
grep -q "写代码前的三个问题" "${DIST_DIR}/ai-infra/operator-engineering.html"
grep -q "On-policy distillation" "${DIST_DIR}/agents/training-and-reasoning.html"
grep -q "项目与实验" "${DIST_DIR}/shed/projects.html"
grep -q "项目开发守则" "${PROJECT_DIR}/AGENTS.md"
grep -q '"index.md"' "${DIST_DIR}/hashmap.json"
grep -q '"ai-infra_index.md"' "${DIST_DIR}/hashmap.json"
grep -q '"agents_training-and-reasoning.md"' "${DIST_DIR}/hashmap.json"
grep -q "interactive-flow" "${DIST_DIR}/ai-infra/index.html"
grep -q "Scaling Law" "${DIST_DIR}/ai-infra/index.html"
grep -q "interactive-flow" "${DIST_DIR}/agents/index.html"
grep -q "Agentic RL" "${DIST_DIR}/agents/index.html"
grep -q "capacity-lab" "${DIST_DIR}/ai-infra/scaling-workloads.html"
grep -q "tradeoff-explorer" "${DIST_DIR}/ai-infra/scaling-workloads.html"
grep -q "topology-explorer" "${DIST_DIR}/ai-infra/interconnect-collectives.html"
grep -q "topology-explorer" "${DIST_DIR}/ai-infra/distributed-training.html"
grep -q "paper-catalog" "${DIST_DIR}/paper-reading/index.html"
grep -q "paper-page-navigator" "${DIST_DIR}/paper-reading/index.html"
grep -q "paper-page-navigator" "${DIST_DIR}/paper-reading/model-architectures.html"
grep -q "research-workbench" "${DIST_DIR}/paper-reading/rl-and-distillation.html"
grep -q "zoomable-image" "${DIST_DIR}/paper-reading/model-architectures.html"
test -f "${DIST_DIR}/paper-reading/assets/image%2025.png" || test -f "${DIST_DIR}/paper-reading/assets/image 25.png"

if grep -R --include='*.md' -q '^```mermaid' "${PROJECT_DIR}/docs"; then
  echo "检测到尚未替换的 Mermaid 源码块。" >&2
  exit 1
fi

if grep -R --include='*.html' -Eq 'language-mermaid|flowchart (LR|TD)|>mermaid<' "${DIST_DIR}"; then
  echo "构建产物中仍包含 Mermaid 源码。" >&2
  exit 1
fi

echo "构建与静态产物检查通过。"
