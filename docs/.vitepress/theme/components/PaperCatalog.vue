<script setup lang="ts">
import { computed, ref } from 'vue'
import { withBase } from 'vitepress'

interface PaperEntry { title: string; category: string; page: string; focus: string }

const categories = ['全部', '模型', '强化学习', 'Agent', 'VLA', '评估与理论', '工程资料']
const selected = ref('全部')
const query = ref('')

const entries: PaperEntry[] = [
  { title: 'MiniMax-M2.5', category: '模型', page: '/paper-reading/model-architectures#minimax-m25', focus: 'Partial RoPE 与 QK-Norm' },
  { title: 'GLM-4.7-Flash', category: '模型', page: '/paper-reading/model-architectures#glm-47-flash', focus: '低秩注意力、MoE 与 Thinking' },
  { title: 'Qwen3-Coder-Next-80B-A3B', category: '模型', page: '/paper-reading/model-architectures#qwen3-coder-next-80b-a3b', focus: 'Gated Attention 与 DeltaNet' },
  { title: 'Step 3.5 / 3.7 Flash', category: '模型', page: '/paper-reading/model-architectures#step-flash', focus: '模型结构与效率' },
  { title: 'Conditional Memory via Scalable Lookup', category: '模型', page: '/paper-reading/model-architectures#conditional-memory-engram', focus: '条件记忆与稀疏查找' },
  { title: 'Interleaved Thinking Models', category: '模型', page: '/paper-reading/model-architectures#interleaved-thinking-models', focus: '思考与工具交错' },
  { title: 'AllenAI OLMo 3', category: '模型', page: '/paper-reading/model-architectures#allenai-olmo-3', focus: '开放模型训练' },
  { title: 'DeepSeek-V3.2 / Speciale', category: '模型', page: '/paper-reading/reasoning-vision-models#deepseek-v3-2', focus: '推理与对齐' },
  { title: 'QwenLong-L1.5', category: '模型', page: '/paper-reading/reasoning-vision-models#qwenlong-l1-5', focus: '长上下文强化学习' },
  { title: 'Qwen-VL-235B-A22B', category: '模型', page: '/paper-reading/reasoning-vision-models#qwen-vl-235b-a22b', focus: 'DeepStack 视觉融合' },
  { title: 'MiniMax-M2', category: '模型', page: '/paper-reading/reasoning-vision-models#minimax-m2', focus: 'Agent 数据与对齐' },
  { title: 'PaddleOCR-VL', category: '模型', page: '/paper-reading/reasoning-vision-models#paddleocr-vl', focus: '文档视觉理解' },
  { title: 'Glyph', category: '模型', page: '/paper-reading/reasoning-vision-models#glyph', focus: '视觉文本压缩' },
  { title: 'DeepSeek-OCR', category: '模型', page: '/paper-reading/reasoning-vision-models#deepseek-ocr', focus: '上下文光学压缩' },
  { title: 'DeepSeek-OCR-v2', category: '模型', page: '/paper-reading/reasoning-vision-models#deepseek-ocr-v2', focus: '视觉因果流压缩' },
  { title: 'Kimi-K2', category: '模型', page: '/paper-reading/reasoning-vision-models#kimi-k2', focus: 'Muon、数据与工具调用' },
  { title: 'Let It Flow', category: '强化学习', page: '/paper-reading/rl-and-distillation#rl-sandbox', focus: 'Agentic RL Sandbox' },
  { title: 'Self-Distillation Enables Continual Learning', category: '强化学习', page: '/paper-reading/rl-and-distillation#self-distillation-continual-learning', focus: '自蒸馏与持续学习' },
  { title: 'GDPO', category: '强化学习', page: '/paper-reading/rl-and-distillation#gdpo', focus: '多奖励解耦归一化' },
  { title: 'Negative Reinforcement in LLM Reasoning', category: '强化学习', page: '/paper-reading/rl-and-distillation#negative-reinforcement', focus: '负强化与推理' },
  { title: 'Replay Failures as Successes', category: '强化学习', page: '/paper-reading/rl-and-distillation#hindsight-instruction-replay', focus: '失败样本重放' },
  { title: 'Differential Smoothing', category: '强化学习', page: '/paper-reading/rl-and-distillation#differential-smoothing', focus: '熵与策略锐化' },
  { title: 'MiniRL', category: '强化学习', page: '/paper-reading/rl-and-distillation#minirl', focus: 'LLM RL 稳定实践' },
  { title: 'Titans', category: '强化学习', page: '/paper-reading/rl-and-distillation#titans-test-time-memory', focus: '测试时记忆' },
  { title: 'Importance-Aware Data Selection', category: '强化学习', page: '/paper-reading/rl-and-distillation#importance-aware-data-selection', focus: '指令数据选择' },
  { title: 'Black-Box On-Policy Distillation', category: '强化学习', page: '/paper-reading/rl-and-distillation#black-box-on-policy-distillation', focus: '黑盒在线蒸馏' },
  { title: 'Retaining by Doing', category: '强化学习', page: '/paper-reading/rl-and-distillation#retaining-by-doing', focus: 'On-policy 与抗遗忘' },
  { title: 'On-Policy Distillation', category: '强化学习', page: '/paper-reading/rl-and-distillation#on-policy-distillation', focus: 'Reverse KL 与在线采样' },
  { title: 'Training-Free GRPO', category: '强化学习', page: '/paper-reading/rl-and-distillation#training-free-grpo', focus: '自然语言经验库' },
  { title: 'EEPO', category: '强化学习', page: '/paper-reading/rl-and-distillation#eepo', focus: 'Sample-Then-Forget' },
  { title: 'Effective Reasoning and FSF', category: '强化学习', page: '/paper-reading/rl-and-distillation#cot-reasoning-quality', focus: 'CoT 质量与失败步骤' },
  { title: 'Agentic Reinforced Policy Optimization', category: '强化学习', page: '/paper-reading/rl-and-distillation#agentic-rpo', focus: 'Agentic RPO 与优势归因' },
  { title: 'Learn-by-interact', category: 'Agent', page: '/paper-reading/agent-systems#agent-learn-by-interact', focus: '交互数据闭环' },
  { title: 'Agentic Memory', category: 'Agent', page: '/paper-reading/agent-systems#agent-agentic-memory', focus: '统一长短期记忆' },
  { title: 'Recursive Language Models', category: 'Agent', page: '/paper-reading/agent-systems#agent-recursive-language-models', focus: '递归上下文处理' },
  { title: 'DOVER', category: 'Agent', page: '/paper-reading/agent-systems#agent-dover', focus: '干预驱动多 Agent 调试' },
  { title: 'DeepAgent', category: 'Agent', page: '/paper-reading/agent-systems#agent-deepagent', focus: '可扩展工具集' },
  { title: 'Vision-Language-Action Models for Robotics', category: 'VLA', page: '/paper-reading/vla-robotics#vla-overview', focus: 'VLA 发展路径' },
  { title: 'CLIPort', category: 'VLA', page: '/paper-reading/vla-robotics#cliport', focus: '语义与空间双流' },
  { title: 'RT-1', category: 'VLA', page: '/paper-reading/vla-robotics#rt-1', focus: '机器人 Transformer' },
  { title: 'RT-2', category: 'VLA', page: '/paper-reading/vla-robotics#rt-2', focus: '视觉语言动作迁移' },
  { title: 'RT-X', category: 'VLA', page: '/paper-reading/vla-robotics#rt-x', focus: '跨本体数据与模型' },
  { title: 'OpenVLA', category: 'VLA', page: '/paper-reading/vla-robotics#openvla', focus: '开源 VLA 工程化' },
  { title: 'SECVULEVAL', category: '评估与理论', page: '/paper-reading/evaluation-and-theory#secvuleval', focus: '真实 C/C++ 漏洞检测' },
  { title: 'Self-Guided Function Calling', category: '评估与理论', page: '/paper-reading/evaluation-and-theory#seer-function-calling', focus: '逐步经验回忆' },
  { title: 'LLM-as-a-Judge 偏差修正', category: '评估与理论', page: '/paper-reading/evaluation-and-theory#llm-as-judge-calibration', focus: '置信区间与校准' },
  { title: 'Detecting Data Contamination', category: '评估与理论', page: '/paper-reading/evaluation-and-theory#codec-contamination-detection', focus: '上下文学习污染检测' },
  { title: 'XGrammar', category: '评估与理论', page: '/paper-reading/evaluation-and-theory#xgrammar', focus: '结构化生成约束' },
  { title: 'mHC', category: '评估与理论', page: '/paper-reading/evaluation-and-theory#mhc', focus: '流形约束超连接' },
  { title: '训练与部署资料', category: '工程资料', page: '/paper-reading/resources#training-deployment', focus: '训练框架与部署索引' },
  { title: 'vLLM MoE 并行', category: '工程资料', page: '/paper-reading/resources#vllm-moe-parallelism', focus: '专家并行与缓存策略' },
  { title: 'NCCL Collectives', category: '工程资料', page: '/paper-reading/resources#nccl-collectives', focus: '集合通信原语' },
  { title: 'Tensor Strides', category: '工程资料', page: '/paper-reading/resources#tensor-strides', focus: '张量布局与步长' },
  { title: 'Kernel 优化', category: '工程资料', page: '/paper-reading/resources#kernel-optimization', focus: '算子实现与性能分析' }
]

const filtered = computed(() => {
  const normalized = query.value.trim().toLocaleLowerCase('zh-CN')
  return entries.filter((entry) => {
    const categoryMatches = selected.value === '全部' || entry.category === selected.value
    const queryMatches = !normalized || `${entry.title} ${entry.focus}`.toLocaleLowerCase('zh-CN').includes(normalized)
    return categoryMatches && queryMatches
  })
})

function resolvePage(page: string) {
  return withBase(page)
}
</script>

<template>
  <section class="paper-catalog" aria-label="论文与模型目录">
    <header>
      <span>交互式目录</span>
      <strong>按主题查找笔记</strong>
      <p>筛选或搜索论文、模型与工程资料，结果会直接定位到对应条目。</p>
    </header>
    <div class="paper-catalog__controls">
      <label for="paper-catalog-search">搜索标题或技术点</label>
      <input id="paper-catalog-search" v-model="query" type="search" placeholder="例如：On-policy、OCR、记忆、NCCL" />
      <div class="paper-catalog__filters" role="group" aria-label="按主题筛选">
        <button
          v-for="category in categories"
          :key="category"
          type="button"
          :aria-pressed="selected === category"
          @click="selected = category"
        >{{ category }}</button>
      </div>
    </div>
    <p class="paper-catalog__count" aria-live="polite">找到 {{ filtered.length }} 项</p>
    <div class="paper-catalog__results">
      <a v-for="entry in filtered" :key="`${entry.category}-${entry.title}`" :href="resolvePage(entry.page)">
        <span>{{ entry.category }}</span>
        <strong>{{ entry.title }}</strong>
        <p>{{ entry.focus }}</p>
      </a>
    </div>
  </section>
</template>
