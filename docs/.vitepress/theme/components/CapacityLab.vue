<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

type CapacityPreset =
  | 'scaling'
  | 'roofline'
  | 'checkpoint'
  | 'training-memory'
  | 'inference'
  | 'capacity'
  | 'recovery'
  | 'data-throughput'

interface LabInput {
  key: string
  label: string
  min: number
  max: number
  step: number
  value: number
  unit: string
}

interface LabMetric {
  label: string
  value: string
  note: string
}

interface LabConfig {
  title: string
  description: string
  warning: string
  inputs: LabInput[]
  calculate: (values: Record<string, number>) => LabMetric[]
}

const props = defineProps<{ preset: CapacityPreset }>()

const compact = new Intl.NumberFormat('zh-CN', { maximumFractionDigits: 2 })
const integer = new Intl.NumberFormat('zh-CN', { maximumFractionDigits: 0 })
const percent = new Intl.NumberFormat('zh-CN', { style: 'percent', maximumFractionDigits: 1 })

function format(value: number) {
  return compact.format(Number.isFinite(value) ? value : 0)
}

const configs: Record<CapacityPreset, LabConfig> = {
  scaling: {
    title: '训练计算量与工期估算',
    description: '调整参数量、训练 token、有效吞吐和 GPU 数量，观察规模决策如何传导到总计算量与墙钟时间。',
    warning: '采用稠密 Transformer 训练约 6NT FLOPs 的粗略模型，未包含通信、停机、评估和数据等待。',
    inputs: [
      { key: 'parameters', label: '模型参数量', min: 1, max: 1000, step: 1, value: 70, unit: 'B' },
      { key: 'tokens', label: '训练 token', min: 10, max: 20000, step: 10, value: 1400, unit: 'B' },
      { key: 'gpus', label: 'GPU 数量', min: 8, max: 8192, step: 8, value: 1024, unit: '张' },
      { key: 'tflops', label: '单卡有效吞吐', min: 20, max: 1000, step: 10, value: 180, unit: 'TFLOPS' }
    ],
    calculate: (v) => {
      const flops = 6 * v.parameters * v.tokens
      const days = (flops * 1e18) / (v.gpus * v.tflops * 1e12) / 86400
      return [
        { label: '训练计算量', value: `${format(flops)} EFLOP`, note: '按 6 × 参数量 × token 数估算' },
        { label: '理想工期', value: `${format(days)} 天`, note: '假设有效吞吐持续稳定' },
        { label: 'Token / 参数', value: format(v.tokens / v.parameters), note: '用于检查数据与模型规模比例' }
      ]
    }
  },
  roofline: {
    title: 'Roofline 瓶颈实验室',
    description: '用峰值算力、显存带宽和算术强度计算理论性能上界，并判断当前算子更可能受计算还是数据移动限制。',
    warning: 'Roofline 给出的是理论上界；实际性能还受占用率、访存合并、同步、指令与 shape 影响。',
    inputs: [
      { key: 'peak', label: '峰值计算能力', min: 10, max: 3000, step: 10, value: 800, unit: 'TFLOPS' },
      { key: 'bandwidth', label: 'HBM 带宽', min: 0.5, max: 10, step: 0.1, value: 3.35, unit: 'TB/s' },
      { key: 'intensity', label: '算术强度', min: 0.5, max: 1000, step: 0.5, value: 64, unit: 'FLOP/Byte' }
    ],
    calculate: (v) => {
      const bandwidthCeiling = v.bandwidth * v.intensity
      const attainable = Math.min(v.peak, bandwidthCeiling)
      const ridge = v.peak / v.bandwidth
      return [
        { label: '理论性能上界', value: `${format(attainable)} TFLOPS`, note: '取计算屋顶与带宽屋顶的较小值' },
        { label: '当前瓶颈', value: bandwidthCeiling < v.peak ? '内存带宽' : '计算能力', note: `拐点约 ${format(ridge)} FLOP/Byte` },
        { label: '峰值利用上界', value: percent.format(attainable / v.peak), note: '不等于实际硬件利用率' }
      ]
    }
  },
  checkpoint: {
    title: 'Checkpoint 时间预算',
    description: '估算模型状态体积、并行写入吞吐和训练阻塞时间，理解保存频率与恢复成本之间的关系。',
    warning: '未计入元数据、小文件、校验、网络争用和对象存储尾延迟；生产前必须用真实状态字典压测。',
    inputs: [
      { key: 'parameters', label: '模型参数量', min: 1, max: 1000, step: 1, value: 70, unit: 'B' },
      { key: 'bytes', label: '每参数保存字节', min: 1, max: 16, step: 1, value: 2, unit: 'Byte' },
      { key: 'multiplier', label: '状态体积倍数', min: 1, max: 12, step: 0.5, value: 4, unit: '×' },
      { key: 'throughput', label: '聚合写入吞吐', min: 1, max: 1000, step: 1, value: 120, unit: 'GB/s' }
    ],
    calculate: (v) => {
      const size = v.parameters * v.bytes * v.multiplier
      const seconds = size / v.throughput
      return [
        { label: 'Checkpoint 体积', value: `${format(size)} GB`, note: '参数、优化器及其他状态的合计估算' },
        { label: '理想写入时间', value: `${format(seconds)} 秒`, note: '假设聚合吞吐可持续' },
        { label: '每小时写入量', value: `${format(size * 3600 / Math.max(seconds, 1))} GB`, note: '仅用于观察带宽需求量级' }
      ]
    }
  },
  'training-memory': {
    title: '训练显存账本',
    description: '把参数、梯度、优化器状态、分片规模与激活显存放在同一张账本中，估算单卡最低容量。',
    warning: '这是静态账本，不包含临时 buffer、通信 bucket、碎片、CUDA context 和峰值 all-gather。',
    inputs: [
      { key: 'parameters', label: '模型参数量', min: 1, max: 1000, step: 1, value: 70, unit: 'B' },
      { key: 'bytes', label: '参数存储字节', min: 1, max: 4, step: 1, value: 2, unit: 'Byte' },
      { key: 'factor', label: '训练状态倍数', min: 2, max: 16, step: 0.5, value: 8, unit: '×' },
      { key: 'shards', label: '状态分片数', min: 1, max: 1024, step: 1, value: 64, unit: '份' },
      { key: 'activation', label: '激活与临时空间', min: 1, max: 200, step: 1, value: 24, unit: 'GB' }
    ],
    calculate: (v) => {
      const states = v.parameters * v.bytes * v.factor / v.shards
      const total = states + v.activation
      return [
        { label: '单卡模型状态', value: `${format(states)} GB`, note: '假设所有状态均匀分片' },
        { label: '单卡最低显存', value: `${format(total)} GB`, note: '模型状态加激活与临时空间' },
        { label: '80GB GPU 下余量', value: `${format(80 - total)} GB`, note: total > 80 ? '负值表示当前配置不可装入' : '尚未扣除碎片和通信峰值' }
      ]
    }
  },
  inference: {
    title: '推理显存与并发预算',
    description: '同时估算模型权重、单请求 KV Cache、并发请求和 GPU 容量，避免只看权重大小。',
    warning: 'KV Cache 取决于层数、KV heads、head dimension、精度与上下文长度；此处直接使用测得的单请求值。',
    inputs: [
      { key: 'parameters', label: '模型参数量', min: 1, max: 1000, step: 1, value: 70, unit: 'B' },
      { key: 'bytes', label: '权重字节', min: 0.5, max: 4, step: 0.5, value: 2, unit: 'Byte' },
      { key: 'kv', label: '单请求 KV Cache', min: 0.1, max: 64, step: 0.1, value: 5, unit: 'GB' },
      { key: 'concurrency', label: '并发请求数', min: 1, max: 512, step: 1, value: 32, unit: '个' },
      { key: 'gpuMemory', label: '单卡可用显存', min: 16, max: 192, step: 8, value: 80, unit: 'GB' }
    ],
    calculate: (v) => {
      const weights = v.parameters * v.bytes
      const kv = v.kv * v.concurrency
      const total = weights + kv
      return [
        { label: '模型权重', value: `${format(weights)} GB`, note: '未计入量化元数据和 runtime buffer' },
        { label: 'KV Cache 合计', value: `${format(kv)} GB`, note: '并发与上下文长度直接放大该项' },
        { label: '最低 GPU 数量', value: `${integer.format(Math.ceil(total / v.gpuMemory))} 张`, note: '仅按显存容量向上取整' }
      ]
    }
  },
  capacity: {
    title: '在线服务容量估算',
    description: '把到达率、平均生成长度、单卡解码能力和目标利用率换算成 GPU 数量。',
    warning: '均值不能代表尾延迟；正式容量必须使用真实请求长度分布、突发流量和 SLO 压测。',
    inputs: [
      { key: 'qps', label: '请求到达率', min: 0.1, max: 500, step: 0.1, value: 12, unit: 'QPS' },
      { key: 'tokens', label: '平均输出长度', min: 8, max: 4096, step: 8, value: 512, unit: 'token' },
      { key: 'throughput', label: '单卡稳定吞吐', min: 100, max: 10000, step: 100, value: 1800, unit: 'token/s' },
      { key: 'utilization', label: '目标利用率', min: 30, max: 95, step: 1, value: 70, unit: '%' }
    ],
    calculate: (v) => {
      const demand = v.qps * v.tokens
      const usable = v.throughput * v.utilization / 100
      const gpus = Math.ceil(demand / usable)
      return [
        { label: 'Token 需求', value: `${format(demand)} token/s`, note: '仅统计输出 token' },
        { label: '规划 GPU 数量', value: `${integer.format(gpus)} 张`, note: '按目标利用率保留排队余量' },
        { label: '理论冗余', value: percent.format((gpus * usable - demand) / Math.max(gpus * usable, 1)), note: '不含副本与故障域冗余' }
      ]
    }
  },
  recovery: {
    title: '故障与恢复预算',
    description: '调整故障间隔、Checkpoint 周期和重启时间，观察一次故障的期望损失及有效可用时间。',
    warning: '假设故障在保存周期内均匀发生；相关故障、坏 Checkpoint 和数据重放会进一步放大损失。',
    inputs: [
      { key: 'mtbf', label: '集群平均故障间隔', min: 1, max: 720, step: 1, value: 48, unit: '小时' },
      { key: 'interval', label: 'Checkpoint 周期', min: 1, max: 240, step: 1, value: 30, unit: '分钟' },
      { key: 'restart', label: '发现与恢复耗时', min: 1, max: 180, step: 1, value: 20, unit: '分钟' },
      { key: 'save', label: '单次保存阻塞', min: 0, max: 30, step: 0.5, value: 2, unit: '分钟' }
    ],
    calculate: (v) => {
      const lost = v.interval / 2 + v.restart
      const savesPerMtbf = v.mtbf * 60 / v.interval
      const overhead = lost + savesPerMtbf * v.save
      return [
        { label: '单次故障期望损失', value: `${format(lost)} 分钟`, note: '半个保存周期加恢复时间' },
        { label: '故障间隔内保存次数', value: `${format(savesPerMtbf)} 次`, note: '保存越频繁，阻塞成本越高' },
        { label: '估算有效时间占比', value: percent.format(Math.max(0, 1 - overhead / (v.mtbf * 60))), note: '同时计入保存与恢复开销' }
      ]
    }
  },
  'data-throughput': {
    title: '数据流水线吞吐预算',
    description: '估算数据规模、训练轮次、并行 worker 与单 worker 吞吐对完整数据遍历时间的影响。',
    warning: '未计入小文件、随机读取、解压、tokenize、shuffle、跨区网络和训练侧背压。',
    inputs: [
      { key: 'dataset', label: '数据集规模', min: 0.1, max: 1000, step: 0.1, value: 20, unit: 'TB' },
      { key: 'epochs', label: '遍历轮次', min: 1, max: 20, step: 1, value: 1, unit: '轮' },
      { key: 'workers', label: '读取 worker', min: 1, max: 2048, step: 1, value: 128, unit: '个' },
      { key: 'throughput', label: '单 worker 有效吞吐', min: 1, max: 2000, step: 1, value: 80, unit: 'MB/s' }
    ],
    calculate: (v) => {
      const aggregate = v.workers * v.throughput
      const seconds = v.dataset * 1e6 * v.epochs / aggregate
      return [
        { label: '聚合读取吞吐', value: `${format(aggregate / 1000)} GB/s`, note: '假设 worker 之间没有共享瓶颈' },
        { label: '理想遍历时间', value: `${format(seconds / 3600)} 小时`, note: '从存储读到训练进程的下界' },
        { label: '每日可遍历数据', value: `${format(aggregate * 86400 / 1e6)} TB`, note: '未计入预处理与训练背压' }
      ]
    }
  }
}

const config = computed(() => configs[props.preset])
const values = reactive<Record<string, number>>({})

watch(config, (next) => {
  for (const key of Object.keys(values)) delete values[key]
  for (const input of next.inputs) values[input.key] = input.value
}, { immediate: true })

const metrics = computed(() => config.value.calculate(values))
</script>

<template>
  <section class="capacity-lab" :aria-label="config.title">
    <header class="capacity-lab__header">
      <span>交互式估算器</span>
      <strong>{{ config.title }}</strong>
      <p>{{ config.description }}</p>
    </header>
    <div class="capacity-lab__body">
      <fieldset class="capacity-lab__controls">
        <legend>调整输入</legend>
        <label v-for="input in config.inputs" :key="input.key" :for="`capacity-${preset}-${input.key}`">
          <span><strong>{{ input.label }}</strong><output>{{ format(values[input.key]) }} {{ input.unit }}</output></span>
          <input
            :id="`capacity-${preset}-${input.key}`"
            v-model.number="values[input.key]"
            type="range"
            :min="input.min"
            :max="input.max"
            :step="input.step"
          />
        </label>
      </fieldset>
      <div class="capacity-lab__results" aria-live="polite">
        <article v-for="metric in metrics" :key="metric.label">
          <span>{{ metric.label }}</span>
          <strong>{{ metric.value }}</strong>
          <p>{{ metric.note }}</p>
        </article>
      </div>
    </div>
    <footer class="capacity-lab__footer">
      <span aria-hidden="true">i</span>
      <p>{{ config.warning }}</p>
    </footer>
  </section>
</template>
