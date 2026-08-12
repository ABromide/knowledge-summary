<script setup lang="ts">
import { computed, ref } from 'vue'

type FlowPreset = 'agent' | 'infra'

interface FlowNode {
  id: string
  label: string
  lines: string[]
  group: string
  description: string
  x: number
  y: number
}

interface FlowEdge {
  from: string
  to: string
  path?: string
}

interface FlowGraph {
  title: string
  description: string
  nodes: FlowNode[]
  edges: FlowEdge[]
}

const props = defineProps<{ preset: FlowPreset }>()

const graphs: Record<FlowPreset, FlowGraph> = {
  agent: {
    title: 'Agent 能力形成链路',
    description: '从能力底座到环境交互与反馈闭环，点击任一节点查看它的直接上下游。',
    nodes: [
      {
        id: 'pretrain',
        label: '预训练与中期训练',
        lines: ['预训练与', '中期训练'],
        group: '能力底座',
        description: '建立语言、代码、知识与长上下文能力，为后续任务学习提供可迁移的表示。',
        x: 90,
        y: 220
      },
      {
        id: 'sft',
        label: 'SFT',
        lines: ['SFT'],
        group: '行为塑形',
        description: '用高质量示范把基模能力转化为格式遵循、任务接口和基本工具使用行为。',
        x: 250,
        y: 220
      },
      {
        id: 'reasoning',
        label: 'Reasoning RL',
        lines: ['Reasoning', 'RL'],
        group: '推理训练',
        description: '通过可验证奖励强化多步推理、搜索和自我修正能力。',
        x: 410,
        y: 220
      },
      {
        id: 'agentic',
        label: 'Agentic RL',
        lines: ['Agentic RL'],
        group: '智能体训练',
        description: '让模型在多轮环境中学习规划、行动、观察和错误恢复。',
        x: 570,
        y: 220
      },
      {
        id: 'environment',
        label: '工具与环境交互',
        lines: ['工具与', '环境交互'],
        group: '执行环境',
        description: '提供真实工具、状态变化和任务约束，使轨迹具有可执行性。',
        x: 730,
        y: 220
      },
      {
        id: 'feedback',
        label: '可验证反馈',
        lines: ['可验证反馈'],
        group: '学习信号',
        description: '把结果、过程与规则检查转化为稳定反馈，并回流到智能体训练。',
        x: 890,
        y: 220
      },
      {
        id: 'distillation',
        label: 'On-policy Distillation',
        lines: ['On-policy', 'Distillation'],
        group: '训练增强',
        description: '在学生自己的采样分布上吸收教师信号，降低训练与部署分布偏差。',
        x: 410,
        y: 70
      },
      {
        id: 'context',
        label: 'Context Engineering',
        lines: ['Context', 'Engineering'],
        group: '运行时增强',
        description: '组织指令、记忆、工具和检索结果，让模型在行动前获得有效上下文。',
        x: 730,
        y: 70
      },
      {
        id: 'scaling',
        label: 'Test-time Scaling',
        lines: ['Test-time', 'Scaling'],
        group: '运行时增强',
        description: '在推理阶段投入更多采样、搜索或验证预算，提升复杂任务成功率。',
        x: 730,
        y: 370
      }
    ],
    edges: [
      { from: 'pretrain', to: 'sft' },
      { from: 'sft', to: 'reasoning' },
      { from: 'reasoning', to: 'agentic' },
      { from: 'agentic', to: 'environment' },
      { from: 'environment', to: 'feedback' },
      { from: 'feedback', to: 'agentic', path: 'M 890 253 C 890 320, 570 320, 570 253' },
      { from: 'distillation', to: 'reasoning' },
      { from: 'context', to: 'environment' },
      { from: 'scaling', to: 'environment' }
    ]
  },
  infra: {
    title: 'AI Infra 端到端链路',
    description: '从缩放规律到应用交付，点击节点查看每一层承担的系统职责。',
    nodes: [
      {
        id: 'scaling-law',
        label: 'Scaling Law',
        lines: ['Scaling Law'],
        group: '资源方向',
        description: '描述模型、数据和计算投入之间的经验规律，决定资源扩展方向。',
        x: 80,
        y: 220
      },
      {
        id: 'compute',
        label: '计算集群',
        lines: ['计算集群'],
        group: '资源层',
        description: '把 GPU、NPU、主机和故障域组织成可持续提供算力的集群。',
        x: 220,
        y: 220
      },
      {
        id: 'network',
        label: '通信与存储',
        lines: ['通信与存储'],
        group: '资源层',
        description: '通过集合通信、RDMA 与分布式存储连接计算节点和训练数据。',
        x: 360,
        y: 220
      },
      {
        id: 'cloud',
        label: '云原生与调度',
        lines: ['云原生与调度'],
        group: '平台层',
        description: '处理任务编排、资源隔离、弹性伸缩、观测与故障恢复。',
        x: 500,
        y: 220
      },
      {
        id: 'training',
        label: '分布式训练',
        lines: ['分布式训练'],
        group: '执行层',
        description: '组合数据、张量、流水线、上下文和专家并行，完成大规模模型训练。',
        x: 640,
        y: 220
      },
      {
        id: 'inference',
        label: '推理与服务',
        lines: ['推理与服务'],
        group: '执行层',
        description: '围绕延迟、吞吐和显存预算组织 KV Cache、批处理、量化与服务编排。',
        x: 780,
        y: 220
      },
      {
        id: 'application',
        label: 'Agent / RAG / 应用',
        lines: ['Agent / RAG', '/ 应用'],
        group: '应用层',
        description: '将模型能力接入检索、工具、业务流程和用户体验。',
        x: 920,
        y: 220
      },
      {
        id: 'models-data',
        label: '模型与数据',
        lines: ['模型与数据'],
        group: '模型层',
        description: '定义模型结构、训练目标、数据配比和质量控制。',
        x: 640,
        y: 70
      },
      {
        id: 'operator',
        label: '算子与编译优化',
        lines: ['算子与', '编译优化'],
        group: '内核层',
        description: '通过 Profiling、融合、分块和专用 Kernel 提升训练与推理热点路径效率。',
        x: 710,
        y: 370
      }
    ],
    edges: [
      { from: 'scaling-law', to: 'compute' },
      { from: 'compute', to: 'network' },
      { from: 'network', to: 'cloud' },
      { from: 'cloud', to: 'training' },
      { from: 'training', to: 'inference' },
      { from: 'inference', to: 'application' },
      { from: 'models-data', to: 'training' },
      { from: 'operator', to: 'training' },
      { from: 'operator', to: 'inference' }
    ]
  }
}

const graph = computed(() => graphs[props.preset])
const selectedId = ref<string | null>(null)
const selectedNode = computed(() => graph.value.nodes.find((node) => node.id === selectedId.value) ?? null)
const upstream = computed(() => {
  if (!selectedId.value) return []
  const ids = graph.value.edges.filter((edge) => edge.to === selectedId.value).map((edge) => edge.from)
  return graph.value.nodes.filter((node) => ids.includes(node.id))
})
const downstream = computed(() => {
  if (!selectedId.value) return []
  const ids = graph.value.edges.filter((edge) => edge.from === selectedId.value).map((edge) => edge.to)
  return graph.value.nodes.filter((node) => ids.includes(node.id))
})

function selectNode(id: string) {
  selectedId.value = selectedId.value === id ? null : id
}

function isRelated(id: string) {
  if (!selectedId.value) return true
  return id === selectedId.value || graph.value.edges.some((edge) => {
    return (edge.from === selectedId.value && edge.to === id) || (edge.to === selectedId.value && edge.from === id)
  })
}

function isEdgeActive(edge: FlowEdge) {
  return !selectedId.value || edge.from === selectedId.value || edge.to === selectedId.value
}

function edgePath(edge: FlowEdge) {
  if (edge.path) return edge.path
  const from = graph.value.nodes.find((node) => node.id === edge.from)
  const to = graph.value.nodes.find((node) => node.id === edge.to)
  if (!from || !to) return ''

  const dx = to.x - from.x
  const dy = to.y - from.y
  const horizontal = Math.abs(dx) / 72
  const vertical = Math.abs(dy) / 32
  const divisor = Math.max(horizontal, vertical, 1)
  const offsetX = dx / divisor
  const offsetY = dy / divisor

  return `M ${from.x + offsetX} ${from.y + offsetY} L ${to.x - offsetX} ${to.y - offsetY}`
}
</script>

<template>
  <section class="interactive-flow" :aria-label="graph.title" @keydown.esc="selectedId = null">
    <header class="interactive-flow__header">
      <div>
        <span class="interactive-flow__eyebrow">交互式关系图</span>
        <strong>{{ graph.title }}</strong>
        <p>{{ graph.description }}</p>
      </div>
      <button type="button" :disabled="selectedId === null" @click="selectedId = null">查看全图</button>
    </header>

    <div class="interactive-flow__canvas" aria-hidden="false">
      <svg viewBox="0 0 1000 440" role="group" :aria-labelledby="`flow-title-${preset} flow-desc-${preset}`">
        <title :id="`flow-title-${preset}`">{{ graph.title }}</title>
        <desc :id="`flow-desc-${preset}`">{{ graph.description }}</desc>
        <defs>
          <marker :id="`flow-arrow-${preset}`" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
            <path d="M 0 0 L 10 5 L 0 10 z" fill="context-stroke" />
          </marker>
        </defs>

        <g class="interactive-flow__edges">
          <path
            v-for="edge in graph.edges"
            :key="`${edge.from}-${edge.to}`"
            :d="edgePath(edge)"
            :class="{ 'is-muted': !isEdgeActive(edge), 'is-active': selectedId && isEdgeActive(edge) }"
            :marker-end="`url(#flow-arrow-${preset})`"
          />
        </g>

        <g
          v-for="node in graph.nodes"
          :key="node.id"
          class="interactive-flow__node"
          :class="{
            'is-selected': selectedId === node.id,
            'is-related': selectedId && selectedId !== node.id && isRelated(node.id),
            'is-muted': !isRelated(node.id)
          }"
          :transform="`translate(${node.x - 72} ${node.y - 32})`"
          role="button"
          tabindex="0"
          :aria-label="`${node.label}，${node.group}`"
          :aria-pressed="selectedId === node.id"
          @click="selectNode(node.id)"
          @keydown.enter.prevent="selectNode(node.id)"
          @keydown.space.prevent="selectNode(node.id)"
        >
          <title>{{ node.label }}：{{ node.description }}</title>
          <rect width="144" height="64" rx="10" />
          <text class="interactive-flow__node-group" x="12" y="18">{{ node.group }}</text>
          <text class="interactive-flow__node-label" x="12" :y="node.lines.length === 1 ? 43 : 36">
            <tspan v-for="(line, index) in node.lines" :key="line" x="12" :dy="index === 0 ? 0 : 16">{{ line }}</tspan>
          </text>
        </g>
      </svg>
    </div>

    <div class="interactive-flow__mobile" role="list" aria-label="关系图节点">
      <div v-for="node in graph.nodes" :key="node.id" role="listitem">
        <button
          type="button"
          :class="{ 'is-selected': selectedId === node.id, 'is-muted': !isRelated(node.id) }"
          :aria-pressed="selectedId === node.id"
          @click="selectNode(node.id)"
        >
          <span><small>{{ node.group }}</small><strong>{{ node.label }}</strong></span>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 18 6-6-6-6" /></svg>
        </button>
      </div>
    </div>

    <div class="interactive-flow__detail" aria-live="polite">
      <template v-if="selectedNode">
        <div class="interactive-flow__detail-copy">
          <span>{{ selectedNode.group }}</span>
          <strong>{{ selectedNode.label }}</strong>
          <p>{{ selectedNode.description }}</p>
        </div>
        <dl class="interactive-flow__relations">
          <div>
            <dt>直接上游</dt>
            <dd v-if="upstream.length">
              <button v-for="node in upstream" :key="node.id" type="button" @click="selectNode(node.id)">{{ node.label }}</button>
            </dd>
            <dd v-else>起点节点</dd>
          </div>
          <div>
            <dt>直接下游</dt>
            <dd v-if="downstream.length">
              <button v-for="node in downstream" :key="node.id" type="button" @click="selectNode(node.id)">{{ node.label }}</button>
            </dd>
            <dd v-else>终点节点</dd>
          </div>
        </dl>
      </template>
      <div v-else class="interactive-flow__empty">
        <span aria-hidden="true">↗</span>
        <p><strong>选择一个节点</strong>查看它在链路中的职责、直接上游和直接下游。</p>
      </div>
    </div>
  </section>
</template>
