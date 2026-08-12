<script setup lang="ts">
import { computed, ref, watch } from 'vue'

type TopologyPreset = 'collectives' | 'parallelism'

interface TopologyChoice {
  label: string
  title: string
  summary: string
  communication: string
  placement: string
  nodes: string[]
  edges: Array<[number, number]>
}

interface TopologyConfig {
  title: string
  description: string
  choices: TopologyChoice[]
}

const props = defineProps<{ preset: TopologyPreset }>()

const configs: Record<TopologyPreset, TopologyConfig> = {
  collectives: {
    title: '集合通信路径观察器',
    description: '切换通信模式，观察参与者、主要数据流和拓扑放置重点。示意图表达通信关系，不代表 NCCL 的实际执行时序。',
    choices: [
      {
        label: 'Ring All-Reduce',
        title: '环形分块传递，带宽利用率优先',
        summary: '每个 rank 只与相邻 rank 交换分块，通常由 Reduce-Scatter 与 All-Gather 两阶段组成。',
        communication: '大消息下链路利用较均衡，但步骤数随参与者增加。',
        placement: '让环尽量沿高速链路闭合，避免某一跳绕行低速 PCIe 或拥塞链路。',
        nodes: ['GPU 0', 'GPU 1', 'GPU 2', 'GPU 3', 'GPU 4', 'GPU 5', 'GPU 6', 'GPU 7'],
        edges: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 0]]
      },
      {
        label: 'Tree All-Reduce',
        title: '树形归约与广播，延迟路径更短',
        summary: '数据沿树向根节点聚合，再由根节点向下广播结果，通信轮次随规模近似按对数增长。',
        communication: '适合延迟更敏感或消息较小的场景，但树干链路可能承担更多流量。',
        placement: '根与中间节点应落在稳定的高速路径上，并避免跨层流量集中到单一上联。',
        nodes: ['根节点', '中间 1', '中间 2', 'GPU 0', 'GPU 1', 'GPU 2', 'GPU 3'],
        edges: [[0, 1], [0, 2], [1, 3], [1, 4], [2, 5], [2, 6]]
      },
      {
        label: '分层 All-Reduce',
        title: '节点内聚合，再跨节点交换',
        summary: '先利用节点内 NVLink / NVSwitch 完成局部归约，再经 NIC 做跨节点交换，最后在节点内分发。',
        communication: '把高频数据尽量留在本地通信域，减少跨节点总字节数和参与者数量。',
        placement: '校准 GPU—NIC 亲和性、rail 与机架边界；跨节点代表 rank 不应绕过本地 NIC。',
        nodes: ['节点 A / GPU', '节点 A / GPU', '节点 A / NIC', '节点 B / NIC', '节点 B / GPU', '节点 B / GPU'],
        edges: [[0, 1], [0, 2], [1, 2], [2, 3], [3, 4], [3, 5], [4, 5]]
      }
    ]
  },
  parallelism: {
    title: '并行维度放置观察器',
    description: '选择并行策略，查看通信域应如何映射到设备拓扑。真实方案通常是多个维度的组合。',
    choices: [
      {
        label: '数据并行',
        title: '复制模型，按 step 同步梯度或分片状态',
        summary: '每个副本处理不同样本，吞吐扩展直观；FSDP / ZeRO 会把模型状态分散到数据并行组。',
        communication: '主要是梯度 All-Reduce，或参数 All-Gather 与梯度 Reduce-Scatter。',
        placement: '通信频率相对低，可扩展到跨节点；仍需关注全局带宽与慢 rank。',
        nodes: ['副本 0', '副本 1', '副本 2', '副本 3'],
        edges: [[0, 1], [1, 2], [2, 3], [3, 0]]
      },
      {
        label: '张量并行',
        title: '切分层内矩阵，通信发生在关键路径',
        summary: '同一层的矩阵乘被多个 GPU 共同完成，几乎每层都可能触发集合通信。',
        communication: '高频 All-Reduce / All-Gather，对延迟、带宽和 shape 都敏感。',
        placement: '优先限制在单节点高速互连域，TP 组跨慢链路往往会直接拉低 step time。',
        nodes: ['TP 0', 'TP 1', 'TP 2', 'TP 3'],
        edges: [[0, 1], [1, 2], [2, 3], [3, 0], [0, 2], [1, 3]]
      },
      {
        label: '流水线并行',
        title: '按层分阶段，沿单向路径传递激活',
        summary: '模型层被切成连续阶段，micro-batch 在阶段间流水执行，以容纳更大的模型。',
        communication: '相邻阶段传递激活与梯度；空泡取决于阶段数、micro-batch 与负载均衡。',
        placement: '相邻阶段尽量靠近，避免某个边界跨越拥塞域；同时平衡每个阶段的计算量。',
        nodes: ['阶段 0', '阶段 1', '阶段 2', '阶段 3'],
        edges: [[0, 1], [1, 2], [2, 3]]
      },
      {
        label: '专家并行',
        title: 'Token 动态路由，All-to-All 决定长尾',
        summary: 'MoE 层把 token 分发到不同专家，路由不均衡会同时造成网络热点和设备空闲。',
        communication: '主要是 All-to-All；消息大小和目的 rank 会随 token 路由动态变化。',
        placement: '专家组应覆盖稳定的高速网络域，并持续监控每个专家的 token 数与尾部延迟。',
        nodes: ['专家 0', '专家 1', '专家 2', '专家 3'],
        edges: [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]
      }
    ]
  }
}

const positions = [
  { x: 90, y: 58 },
  { x: 220, y: 36 },
  { x: 350, y: 58 },
  { x: 405, y: 150 },
  { x: 350, y: 242 },
  { x: 220, y: 264 },
  { x: 90, y: 242 },
  { x: 35, y: 150 }
]

const config = computed(() => configs[props.preset])
const selected = ref(0)
watch(() => props.preset, () => (selected.value = 0))
const choice = computed(() => config.value.choices[selected.value])

function selectFromKeyboard(event: KeyboardEvent, index: number) {
  const last = config.value.choices.length - 1
  if (event.key === 'ArrowRight') selected.value = index === last ? 0 : index + 1
  else if (event.key === 'ArrowLeft') selected.value = index === 0 ? last : index - 1
  else if (event.key === 'Home') selected.value = 0
  else if (event.key === 'End') selected.value = last
  else return
  event.preventDefault()
  requestAnimationFrame(() => document.getElementById(`topology-${props.preset}-tab-${selected.value}`)?.focus())
}

function point(index: number) {
  return positions[index] ?? positions[0]
}
</script>

<template>
  <section class="topology-explorer" :aria-label="config.title">
    <header class="topology-explorer__header">
      <span>交互式拓扑卡</span>
      <strong>{{ config.title }}</strong>
      <p>{{ config.description }}</p>
    </header>
    <div class="topology-explorer__toggles" role="tablist" aria-label="选择拓扑模式">
      <button
        v-for="(item, index) in config.choices"
        :id="`topology-${preset}-tab-${index}`"
        :key="item.label"
        type="button"
        role="tab"
        :aria-selected="selected === index"
        :aria-controls="`topology-${preset}-panel`"
        :tabindex="selected === index ? 0 : -1"
        @click="selected = index"
        @keydown="selectFromKeyboard($event, index)"
      >
        {{ item.label }}
      </button>
    </div>
    <div
      :id="`topology-${preset}-panel`"
      class="topology-explorer__panel"
      role="tabpanel"
      :aria-labelledby="`topology-${preset}-tab-${selected}`"
      tabindex="0"
    >
      <div class="topology-explorer__visual" aria-hidden="true">
        <svg viewBox="0 0 440 300">
          <g class="topology-explorer__edges">
            <line
              v-for="([from, to], index) in choice.edges"
              :key="`${from}-${to}-${index}`"
              :x1="point(from).x"
              :y1="point(from).y"
              :x2="point(to).x"
              :y2="point(to).y"
            />
          </g>
          <g
            v-for="(node, index) in choice.nodes"
            :key="`${node}-${index}`"
            class="topology-explorer__node"
            :transform="`translate(${point(index).x} ${point(index).y})`"
          >
            <circle r="27" />
            <text text-anchor="middle" dominant-baseline="middle">{{ node }}</text>
          </g>
        </svg>
        <div class="topology-explorer__mobile-map">
          <span v-for="(node, index) in choice.nodes" :key="`${node}-mobile-${index}`">{{ node }}</span>
        </div>
      </div>
      <div class="topology-explorer__copy">
        <span>当前模式</span>
        <strong>{{ choice.title }}</strong>
        <p>{{ choice.summary }}</p>
        <dl>
          <div><dt>通信特征</dt><dd>{{ choice.communication }}</dd></div>
          <div><dt>放置重点</dt><dd>{{ choice.placement }}</dd></div>
        </dl>
      </div>
    </div>
  </section>
</template>
