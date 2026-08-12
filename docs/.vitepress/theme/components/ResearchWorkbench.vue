<script setup lang="ts">
import { computed, ref, watch } from 'vue'

type WorkbenchPreset =
  | 'overview'
  | 'architectures'
  | 'reasoning-vision'
  | 'rl'
  | 'agents'
  | 'vla'
  | 'evaluation'
  | 'resources'

interface Lens {
  label: string
  question: string
  summary: string
  signals: string[]
  action: string
}

interface WorkbenchConfig {
  title: string
  description: string
  lenses: Lens[]
}

const props = defineProps<{ preset: WorkbenchPreset }>()

const configs: Record<WorkbenchPreset, WorkbenchConfig> = {
  overview: {
    title: '论文阅读导航台',
    description: '按目标切换阅读视角，先找到需要回答的问题，再进入完整笔记。',
    lenses: [
      { label: '追踪模型', question: '新模型究竟改了哪一层？', summary: '优先拆分注意力、FFN/MoE、位置编码、记忆与推理模式，避免把参数表当作架构结论。', signals: ['结构配置与实现代码', '训练与推理上下文', '质量和效率基线'], action: '进入模型架构、推理与视觉两组笔记，对照相同机制在不同模型中的实现。' },
      { label: '设计训练', question: '能力变化来自数据、目标还是在线分布？', summary: '把 SFT、RL、蒸馏、奖励塑形和持续学习放在数据分布与优化目标的共同坐标中。', signals: ['On-policy / Off-policy', '奖励归一化与归因', '遗忘和熵变化'], action: '进入强化学习与蒸馏页面，先确认问题定义，再比较算法名字。' },
      { label: '构建系统', question: '如何把论文机制落到可验证系统？', summary: 'Agent、VLA 和评估工作最终都需要明确接口、环境、trace、数据闭环与失败恢复。', signals: ['工具与环境反馈', '记忆读写策略', '端到端评估证据'], action: '沿 Agent → VLA → 数据评估 → 工程资料的顺序建立实现闭环。' }
    ]
  },
  architectures: {
    title: '模型机制对照台',
    description: '从三个最常见的系统约束观察新模型结构。',
    lenses: [
      { label: '长上下文', question: '位置信号与记忆容量如何扩展？', summary: 'Partial RoPE、混合注意力、DeltaNet 与条件记忆分别从位置通道、计算复杂度和外部查找扩展上下文。', signals: ['RoPE 维度与 base', 'KV Cache 增长', '记忆检索与写入成本'], action: '对照 MiniMax、Qwen3-Coder-Next 与 Conditional Memory 的完整笔记。' },
      { label: '训练稳定性', question: '注意力分数为什么会失控？', summary: 'QK-Norm、归一化位置与参数化方式共同影响 logit 尺度、梯度传播和深层训练稳定性。', signals: ['Q/K 范数与注意力熵', 'Pre-Norm / Post-Norm', '每层或每头参数共享'], action: '先核对实现中的 norm 位置，再判断论文中的稳定性解释是否成立。' },
      { label: '推理效率', question: '稀疏化和低秩投影节省了什么？', summary: 'MoE 降低单 token 激活参数，低秩 Q/KV 与混合注意力降低部分投影或缓存成本，但会引入路由和并行约束。', signals: ['激活专家数', 'Q/KV rank 与 head 数', 'TP、EP 与 All-to-All'], action: '把配置换算为每 token 计算、缓存字节和跨卡通信后再比较。' }
    ]
  },
  'reasoning-vision': {
    title: '推理与视觉模型分析台',
    description: '在能力、token 预算与生产复杂度之间切换观察。',
    lenses: [
      { label: '推理能力', question: 'Thinking 与工具调用如何共同训练？', summary: '推理模式不仅是输出更长，还涉及训练数据、奖励信号、工具轨迹和多轮思考保留。', signals: ['推理 token 预算', '工具调用成功率', '能力保持与过度思考'], action: '对照 DeepSeek、QwenLong 与 MiniMax 的训练和对齐笔记。' },
      { label: '视觉压缩', question: '如何减少文档理解的视觉 token？', summary: 'OCR 与视觉文本压缩方法在编码器压缩率、顺序保持和文字细节之间权衡。', signals: ['压缩率与识别精度', '版面与阅读顺序', '多分辨率输入成本'], action: '比较 PaddleOCR-VL、Glyph、DeepSeek-OCR 与 v2 的压缩路径。' },
      { label: '生产部署', question: '论文收益能否转成真实吞吐？', summary: '视觉编码、长上下文、MoE 和低精度优化都可能把瓶颈转移到缓存、调度或数据预处理。', signals: ['端到端 TTFT', '显存与 KV Cache', '真实文档分桶结果'], action: '用生产长度分布和文档类型复测，而不是直接采用论文平均值。' }
    ]
  },
  rl: {
    title: '强化学习实验工作台',
    description: '从奖励、数据分布和稳定性三个入口比较方法。',
    lenses: [
      { label: '奖励与优势', question: '奖励到底在推动哪个行为？', summary: 'GDPO、负强化、失败重放、差分平滑和优势归因都在修正多奖励耦合、稀疏反馈或错误 credit assignment。', signals: ['奖励分量尺度', '正负样本比例', 'token / trajectory 归因'], action: '先画出奖励到更新的完整路径，再做消融与分桶评估。' },
      { label: 'On-policy', question: '为什么在线样本有助于蒸馏和抗遗忘？', summary: 'On-policy 数据与当前模型分布一致，可降低强制拟合偏移，但采样成本和探索覆盖仍需单独控制。', signals: ['采样策略版本', 'Reverse KL / Forward KL', '旧能力保持'], action: '对照 Black-Box Distillation、Retaining by Doing 与 On-Policy Distillation。' },
      { label: '稳定与探索', question: '怎样避免策略过早变尖或停止探索？', summary: '熵、失败步骤、样本遗忘与训练自由经验库从不同层面控制探索范围和策略锐化。', signals: ['策略熵与 KL', '失败步骤占比', '经验库迁移性'], action: '固定评估集与基线策略版本，分别观察质量、覆盖和训练方差。' }
    ]
  },
  agents: {
    title: 'Agent 能力形成工作台',
    description: '切换数据、记忆和诊断视角，观察 Agent 如何从交互中改进。',
    lenses: [
      { label: '交互数据', question: '哪些早期经验值得进入训练？', summary: 'Learn-by-interact 和 Early Experience 关注从环境反馈中收集、筛选和再利用轨迹。', signals: ['任务覆盖', '反馈可验证性', '成功与失败轨迹比例'], action: '保留环境版本与轨迹 provenance，避免把偶然成功当成通用能力。' },
      { label: '记忆系统', question: '短期状态何时应沉淀为长期记忆？', summary: 'Agentic Memory、RLM 与 ToolMem 分别面向对话状态、递归上下文和工具能力经验。', signals: ['写入触发条件', '检索命中与污染', '过期和冲突处理'], action: '把记忆读写作为可评估工具调用，记录每次引用对最终结果的贡献。' },
      { label: '调试与工具', question: '多 Agent 失败如何定位和修复？', summary: 'DOVER 与 DeepAgent 强调干预点、trace 和可扩展工具集，核心不是增加角色数量。', signals: ['首个错误事件', '工具参数与结果', '干预后的因果变化'], action: '用可重放 trace 验证修复，不用最终回答是否看似合理代替诊断。' }
    ]
  },
  vla: {
    title: 'VLA 系统工作台',
    description: '从感知、策略、世界模型和数据四个层次理解机器人基础模型。',
    lenses: [
      { label: '感知到动作', question: '视觉语言表征怎样变成动作序列？', summary: 'CLIPort、RT-1/2 与 OpenVLA 采用不同的融合、token 化和动作解码方式连接语义与控制。', signals: ['视觉 token 压缩', '动作离散化', '控制频率与时延'], action: '比较每种架构的输入输出接口，而不是只比较模型参数量。' },
      { label: '世界模型', question: '策略是否需要显式预测环境变化？', summary: '世界模型可以作为规划器、表征模块或数据生成器，但预测误差会在长时域累积。', signals: ['预测视野', '闭环误差', '模型与策略耦合方式'], action: '用闭环任务成功率验证世界模型价值，避免只看视频重建质量。' },
      { label: '数据扩展', question: '跨机器人数据如何统一？', summary: 'RT-X 代表从单平台走向多机器人混合，关键在动作空间、观测和任务语义的标准化。', signals: ['机器人形态差异', '数据采样偏差', '动作归一化'], action: '记录数据来源和转换链路，并按平台与任务分别报告效果。' }
    ]
  },
  evaluation: {
    title: '评估证据工作台',
    description: '从任务真实性、评审偏差和数据独立性审视评估结论。',
    lenses: [
      { label: '任务与基准', question: '基准是否代表真实使用？', summary: 'SECVULEVAL 与函数调用评估需要覆盖真实代码、工具参数、执行结果和失败类型。', signals: ['样本来源', '可执行验证', '错误类型覆盖'], action: '把准确率拆成召回、误报、执行成功和实际影响。' },
      { label: 'Judge 偏差', question: 'LLM 评分为什么不稳定？', summary: '位置、长度、风格和自偏好都会改变 Judge 结果，需要校准、重复采样和置信区间。', signals: ['顺序交换结果', '人工一致性', '置信区间宽度'], action: '报告评分分布和不确定性，不只报告单个平均分。' },
      { label: '污染与约束', question: '高分来自能力、记忆还是格式约束？', summary: '数据污染检测、XGrammar 与 mHC 分别涉及评估独立性、结构化解码和网络参数化，不能混为同一类收益。', signals: ['训练集重合', '约束前后质量', '参数化消融'], action: '明确每个工具改变了搜索空间、训练过程还是测量过程。' }
    ]
  },
  resources: {
    title: '工程资料核验台',
    description: '把收藏链接转成可以继续验证的工程动作。',
    lenses: [
      { label: '训练与 Agent', question: '资料能否指导真实系统演进？', summary: '训练实践、Agent 工程和 Agent-as-Judge 资料应落到 trace、评估与迭代闭环。', signals: ['版本与运行环境', '失败 trace', '评估器边界'], action: '为每份资料记录适用项目、待实验假设和已验证结论。' },
      { label: '并行与通信', question: '并行策略是否匹配注意力与 MoE 结构？', summary: 'MLA/MQA 的 KV 头、DP Attention、TP/EP 与 collective 共同决定缓存复制和通信开销。', signals: ['KV head 数', 'TP/DP/EP 分组', 'All-to-All / All-Reduce'], action: '先画 rank 与缓存放置，再用真实 shape 压测通信。' },
      { label: '张量与 Kernel', question: '内存视图和算子优化是否正确？', summary: 'stride、view、reshape、expand、einsum 与 Kernel 分块都依赖实际存储布局。', signals: ['连续性与 stride', '内存复制', '端到端而非单 kernel 收益'], action: '用最小张量例子验证别名关系，再进入性能优化。' }
    ]
  }
}

const config = computed(() => configs[props.preset])
const selected = ref(0)
watch(() => props.preset, () => (selected.value = 0))
const lens = computed(() => config.value.lenses[selected.value])

function selectFromKeyboard(event: KeyboardEvent, index: number) {
  const last = config.value.lenses.length - 1
  if (event.key === 'ArrowRight') selected.value = index === last ? 0 : index + 1
  else if (event.key === 'ArrowLeft') selected.value = index === 0 ? last : index - 1
  else if (event.key === 'Home') selected.value = 0
  else if (event.key === 'End') selected.value = last
  else return
  event.preventDefault()
  requestAnimationFrame(() => document.getElementById(`research-${props.preset}-tab-${selected.value}`)?.focus())
}
</script>

<template>
  <section class="research-workbench" :aria-label="config.title">
    <header class="research-workbench__header">
      <span>交互式阅读工具</span>
      <strong>{{ config.title }}</strong>
      <p>{{ config.description }}</p>
    </header>
    <div class="research-workbench__tabs" role="tablist" aria-label="切换阅读视角">
      <button
        v-for="(item, index) in config.lenses"
        :id="`research-${preset}-tab-${index}`"
        :key="item.label"
        type="button"
        role="tab"
        :aria-selected="selected === index"
        :aria-controls="`research-${preset}-panel`"
        :tabindex="selected === index ? 0 : -1"
        @click="selected = index"
        @keydown="selectFromKeyboard($event, index)"
      >
        {{ item.label }}
      </button>
    </div>
    <div
      :id="`research-${preset}-panel`"
      class="research-workbench__panel"
      role="tabpanel"
      :aria-labelledby="`research-${preset}-tab-${selected}`"
      tabindex="0"
    >
      <div class="research-workbench__question">
        <span>关键问题</span>
        <strong>{{ lens.question }}</strong>
        <p>{{ lens.summary }}</p>
      </div>
      <div class="research-workbench__signals">
        <span>阅读时检查</span>
        <ul><li v-for="signal in lens.signals" :key="signal">{{ signal }}</li></ul>
      </div>
      <div class="research-workbench__action">
        <span>下一步</span>
        <p>{{ lens.action }}</p>
      </div>
    </div>
  </section>
</template>
