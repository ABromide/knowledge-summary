<script setup lang="ts">
import { computed, ref, watch } from 'vue'

type TradeoffPreset =
  | 'workload'
  | 'precision'
  | 'interconnect'
  | 'storage'
  | 'scheduling'
  | 'tenant-isolation'
  | 'reliability'
  | 'parallelism'
  | 'serving'
  | 'economics'
  | 'data'
  | 'kernel'

interface Choice {
  label: string
  headline: string
  when: string
  gains: string[]
  costs: string[]
  checks: string[]
}

interface ExplorerConfig {
  title: string
  description: string
  choices: Choice[]
}

const props = defineProps<{ preset: TradeoffPreset }>()

const configs: Record<TradeoffPreset, ExplorerConfig> = {
  workload: {
    title: '工作负载建模决策',
    description: '选择最接近的项目阶段，查看容量模型真正需要锁定的变量。',
    choices: [
      { label: '预训练', headline: '先锁定 token 预算与稳定吞吐', when: '模型结构和数据配比已稳定，需要规划数周到数月训练。', gains: ['预算可由总 FLOPs 推导', '短跑结果可外推集群工期'], costs: ['数据质量变化会使预算失真', '故障与评估时间需要额外预留'], checks: ['固定 token 口径', '记录有效 TFLOPS', '完成恢复演练'] },
      { label: '后训练', headline: '吞吐之外还要建模采样与验证', when: 'SFT、偏好优化或 RL 阶段包含生成、奖励与多轮环境。', gains: ['能看清训练与环境的等待比例', '便于拆分在线和离线资源池'], costs: ['轨迹长度方差大', '奖励服务可能成为瓶颈'], checks: ['记录每阶段 wall time', '拆分生成与更新吞吐', '监控失败轨迹比例'] },
      { label: '在线推理', headline: '使用长度分布和尾延迟建模', when: '请求持续到达，并受 TTFT、ITL、吞吐或成本 SLO 约束。', gains: ['容量与用户体验直接对应', '可区分 prefill 与 decode 瓶颈'], costs: ['均值会掩盖突发与长尾', '缓存命中率随业务变化'], checks: ['保留 P50/P95/P99', '回放真实长度分布', '压测突发流量'] }
    ]
  },
  precision: {
    title: '精度策略权衡',
    description: '低精度不是单一开关；选择目标后比较性能、容量和验证成本。',
    choices: [
      { label: 'BF16 训练', headline: '优先稳定和较宽动态范围', when: '硬件原生支持 BF16，模型对 FP16 溢出敏感。', gains: ['通常不需要 loss scaling', '数值迁移成本较低'], costs: ['吞吐未必达到 FP8 上界', '仍需保留 FP32 累加路径'], checks: ['对齐 loss 曲线', '检查梯度范数', '固定随机种子比较'] },
      { label: 'FP8 训练', headline: '用缩放元数据换吞吐与容量', when: 'Transformer 主干占比高，硬件与框架提供成熟 FP8 recipe。', gains: ['降低张量核心计算和带宽成本', '可扩大 batch 或模型'], costs: ['amax 与 scaling 策略更复杂', '异常层需要回退高精度'], checks: ['逐层误差对比', '观察溢出与下溢', '验证最终任务质量'] },
      { label: '低比特推理', headline: '把质量门槛写进性能验收', when: '权重或 KV Cache 主导显存与带宽，需要提高并发。', gains: ['降低权重与缓存体积', '可能提高 memory-bound 吞吐'], costs: ['校准和专用 kernel 有成本', '不同任务的质量损失不一致'], checks: ['按任务分桶评测', '检查长上下文退化', '确认硬件 kernel 支持'] }
    ]
  },
  interconnect: {
    title: '互连方案选择',
    description: '根据通信范围和消息特征选择拓扑，而不是只比较标称带宽。',
    choices: [
      { label: '节点内', headline: '优先利用 NVLink / NVSwitch 局部性', when: 'Tensor Parallel 等高频大消息主要发生在单机 GPU 间。', gains: ['低延迟高带宽', '拓扑更稳定'], costs: ['受单机 GPU 数限制', '错误绑核会绕行 PCIe'], checks: ['核对 topo -m', '测双向带宽', '验证 rank 排布'] },
      { label: '跨节点', headline: '把 GPU、NIC 与交换网络视为一条链', when: '数据并行或流水线并行跨越多台主机。', gains: ['可扩展到更大集群', '支持多轨与分层 collective'], costs: ['拥塞与 oversubscription 更明显', 'GDR 路径依赖部署细节'], checks: ['运行 ib_write_bw', '验证 GDR 路径', '记录机架与 rail'] },
      { label: '跨机架', headline: '先控制通信域，再追求规模', when: '训练需要多个网络故障域或超大规模 GPU。', gains: ['获得更大资源池', '可按层级规划并行维度'], costs: ['长尾和故障面扩大', '全局 collective 成本高'], checks: ['限制高频通信跨域', '压测拥塞场景', '演练链路降级'] }
    ]
  },
  storage: {
    title: '存储路径选择',
    description: '按数据温度、访问模式与恢复目标选择分层路径。',
    choices: [
      { label: '训练热数据', headline: '吞吐、并发和抖动优先', when: '大量 worker 连续或随机读取训练 shard。', gains: ['本地缓存可降低共享压力', '大对象顺序读取效率高'], costs: ['副本占用容量', '缓存一致性需要治理'], checks: ['压测并发 reader', '检查 shard 均衡', '记录 P99 读取延迟'] },
      { label: 'Checkpoint', headline: '一致性与恢复能力优先', when: '需要周期保存模型、优化器和数据游标。', gains: ['分片保存可扩展', '异步路径减少训练阻塞'], costs: ['状态完整性更复杂', '拓扑变化需要重分片'], checks: ['故障注入恢复', '校验 manifest', '跨 world size 加载'] },
      { label: '长期归档', headline: '成本与可追溯性优先', when: '保存数据版本、模型产物和审计证据。', gains: ['对象存储成本较低', '版本与保留策略清晰'], costs: ['恢复延迟高', '大量小文件效率差'], checks: ['定义生命周期', '演练批量恢复', '验证权限与删除策略'] }
    ]
  },
  scheduling: {
    title: '调度策略选择',
    description: '选择作业形态，查看准入与放置阶段应该优先解决什么。',
    choices: [
      { label: '单机任务', headline: '设备健康与 NUMA 局部性优先', when: '作业只需一台主机上的一到多张 GPU。', gains: ['启动快', '故障域小'], costs: ['容易产生小块碎片', 'GPU 型号混用受限'], checks: ['验证设备插件', '绑定 CPU/NIC', '检查剩余碎片'] },
      { label: '分布式训练', headline: '先做成组准入，再做节点放置', when: '所有 worker 必须同时到位才能工作。', gains: ['避免部分占卡等待', '可表达拓扑和 flavor'], costs: ['队头阻塞更明显', '大作业等待时间长'], checks: ['启用 gang 语义', '记录准入原因', '模拟节点故障'] },
      { label: '在线服务', headline: '滚动变更与副本分散优先', when: '长期运行并受可用性、延迟和弹性约束。', gains: ['可按负载扩缩', '支持故障域分散'], costs: ['冷启动和模型加载昂贵', '弹性可能滞后'], checks: ['设置拓扑分散', '压测冷启动', '保留容量余量'] }
    ]
  },
  'tenant-isolation': {
    title: '多租户隔离决策',
    description: '资源隔离需要同时覆盖容量、性能、数据和控制面。',
    choices: [
      { label: '配额隔离', headline: '先限制可占用资源总量', when: '团队共享集群，需要避免单租户耗尽 GPU。', gains: ['边界清晰', '便于成本归属'], costs: ['闲置配额降低利用率', '借用规则更复杂'], checks: ['验证 hard quota', '记录借用与回收', '检查队列公平性'] },
      { label: '性能隔离', headline: '隔离共享链路和干扰源', when: '多个作业会竞争 PCIe、NIC、存储或 CPU。', gains: ['尾延迟更可控', '故障归因更清晰'], costs: ['降低装箱率', '需要拓扑感知'], checks: ['做 noisy-neighbor 压测', '监控链路带宽', '验证 NUMA 绑定'] },
      { label: '安全隔离', headline: '身份、数据和设备访问共同设防', when: '租户之间存在不同数据权限或供应链边界。', gains: ['降低横向访问风险', '审计证据完整'], costs: ['运维与密钥管理复杂', '调试权限受限'], checks: ['最小权限', '隔离凭证和缓存', '审计设备与数据访问'] }
    ]
  },
  reliability: {
    title: '可靠性控制面',
    description: '从症状出发选择恢复层级，避免所有故障都直接重启整个任务。',
    choices: [
      { label: '进程故障', headline: '快速失败并从一致状态恢复', when: '单个 worker OOM、异常退出或 collective 超时。', gains: ['恢复动作明确', '可自动化重启'], costs: ['需要可靠 Checkpoint', '重启可能改变 rank'], checks: ['保留首个错误', '验证 elastic 语义', '检查数据游标'] },
      { label: '设备故障', headline: '先隔离设备，再恢复工作负载', when: '出现 Xid、ECC、NVLink 或 GPU reset 事件。', gains: ['避免坏卡反复污染任务', '可建立健康历史'], costs: ['容量下降', '需要 drain 与复测'], checks: ['关联 DCGM/Xid', '执行 drain/reset', '通过健康基准后回池'] },
      { label: '服务退化', headline: '用 SLO 燃烧率触发分级处置', when: '没有明确崩溃，但 TTFT、ITL 或队列持续恶化。', gains: ['面向用户影响', '支持渐进降级'], costs: ['指标口径需要统一', '扩容可能来不及'], checks: ['拆分排队与执行', '检查缓存命中', '预置限流和降级'] }
    ]
  },
  parallelism: {
    title: '并行策略组合',
    description: '模型装得下不代表跑得快；按首要约束选择并行维度。',
    choices: [
      { label: '显存不足', headline: '先分片模型状态和激活', when: '单卡无法容纳参数、优化器或激活峰值。', gains: ['FSDP/ZeRO 降低状态冗余', '重计算降低激活显存'], costs: ['all-gather 与重计算增加', '调度更复杂'], checks: ['建立显存账本', '测通信重叠', '观察峰值而非均值'] },
      { label: '单层过大', headline: '使用 TP/CP 切分层内计算', when: '单个矩阵、Attention 或长上下文无法在单卡执行。', gains: ['突破单层容量', '可利用节点内高速互连'], costs: ['每层都可能通信', '对拓扑和 kernel 敏感'], checks: ['优先节点内成组', '测小消息延迟', '验证序列维度切分'] },
      { label: '设备数量多', headline: '用 DP/PP 扩大吞吐和设备规模', when: '模型已可执行，需要扩展全局 batch 或跨节点。', gains: ['DP 实现成熟', 'PP 可降低跨阶段状态'], costs: ['PP 有 bubble', '全局 batch 影响优化'], checks: ['计算 micro-batch', '记录 bubble', '验证收敛等价性'] }
    ]
  },
  serving: {
    title: '推理调度策略',
    description: '根据请求形态选择 batching、缓存和部署拓扑。',
    choices: [
      { label: '短问答', headline: '优先连续批处理与低排队', when: '输入输出都较短，请求频率高。', gains: ['批处理复用权重带宽', '单池运维简单'], costs: ['大 batch 可能伤害 ITL', '突发时队列增长'], checks: ['限制 token budget', '监控排队时间', '压测突发流量'] },
      { label: '长输入', headline: '隔离或切分 prefill 工作', when: '文档、RAG 或多模态输入显著长于输出。', gains: ['chunked prefill 控制干扰', '前缀缓存可复用输入'], costs: ['缓存命中依赖业务', 'prefill 占用计算资源'], checks: ['统计长度分布', '测 TTFT/ITL 权衡', '核对缓存命中率'] },
      { label: '长输出', headline: '围绕 KV Cache 与 decode 带宽规划', when: '代码生成、Agent 或推理任务持续生成大量 token。', gains: ['分页缓存降低碎片', 'decode 池可独立扩容'], costs: ['KV 占用随并发增长', 'P/D 解耦引入传输'], checks: ['估算每请求 KV', '监控 token/s', '验证传输尾延迟'] }
    ]
  },
  economics: {
    title: '成本优化路径',
    description: '便宜的 GPU 小时不等于便宜的有效请求，先选择成本口径。',
    choices: [
      { label: '降低单价', headline: '比较可交付容量而非标价', when: '可选择不同 GPU、云型或预留方式。', gains: ['采购动作直接', '可利用折扣'], costs: ['迁移与兼容成本', '低价资源可能不稳定'], checks: ['统一 SLO 下压测', '计入网络与存储', '核对可获得性'] },
      { label: '提高利用率', headline: '减少空闲、碎片和排队错配', when: '资源已采购但平均利用率或 goodput 偏低。', gains: ['不增加硬件即可扩容', '可通过调度持续改进'], costs: ['过高利用率伤害尾延迟', '多租户干扰增加'], checks: ['看 goodput 而非 busy', '保留故障余量', '按负载分池'] },
      { label: '减少工作量', headline: '从 token、精度和缓存减少需求', when: '应用允许压缩输入、复用前缀或使用更小模型。', gains: ['同时降低延迟和成本', '减少基础设施复杂度'], costs: ['可能影响质量', '需要路由与评估'], checks: ['建立质量门槛', '测缓存实际命中', '按任务选择模型'] }
    ]
  },
  data: {
    title: '数据流水线决策',
    description: '选择当前最主要的数据风险，查看应优先建设的控制点。',
    choices: [
      { label: '质量不稳', headline: '把质量规则前移到解析和混合阶段', when: '训练 loss 或评测随数据版本异常波动。', gains: ['问题可在训练前发现', '数据版本可比较'], costs: ['规则可能误伤长尾', '质量指标需持续校准'], checks: ['保留抽样审查', '按来源分桶', '记录规则命中变化'] },
      { label: '吞吐不足', headline: '先定位存储、CPU 还是训练背压', when: 'GPU 出现周期性空闲或数据等待。', gains: ['可针对瓶颈扩容', '避免盲目增加 worker'], costs: ['端到端观测更复杂', '预处理可能改变顺序'], checks: ['拆分读取/解析/tokenize', '测队列水位', '压测单 worker 上限'] },
      { label: '治理缺失', headline: '建立来源、许可和派生关系', when: '无法回答样本来自哪里、能否使用、影响哪些模型。', gains: ['支持撤回和审计', '变更影响可追踪'], costs: ['元数据维护成本高', '历史数据补录困难'], checks: ['保存不可变 manifest', '记录处理版本', '演练来源撤回'] }
    ]
  },
  kernel: {
    title: '算子优化路径',
    description: '从观测到优化动作，选择最接近的性能指纹。',
    choices: [
      { label: '带宽受限', headline: '减少 HBM 往返与中间张量', when: '算术强度低，带宽接近上限但计算单元不满。', gains: ['融合与分块可直接减流量', '收益容易用 bytes 验证'], costs: ['寄存器和共享内存压力增加', '融合降低复用性'], checks: ['计算读写字节', '看缓存命中', '比较融合前后流量'] },
      { label: '计算受限', headline: '提高张量核心和指令利用率', when: '算术强度高，kernel 时间随 FLOPs 线性增长。', gains: ['布局和 tile 可提升吞吐', '低精度可能扩大峰值'], costs: ['精度和 shape 约束更强', '自动调优成本高'], checks: ['核对数据类型', '检查 occupancy', '扫描关键 shape'] },
      { label: '启动受限', headline: '减少小 kernel 与 CPU 调度开销', when: '大量微小 kernel、同步或 graph break 占据时间线。', gains: ['融合、编译和 CUDA Graph 有效', '端到端延迟改善明显'], costs: ['动态图可能频繁重编译', '捕获与缓存有生命周期'], checks: ['看系统时间线', '统计 kernel 数', '验证动态 shape'] }
    ]
  }
}

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
  requestAnimationFrame(() => document.getElementById(`tradeoff-${props.preset}-tab-${selected.value}`)?.focus())
}
</script>

<template>
  <section class="tradeoff-explorer" :aria-label="config.title">
    <header>
      <span>交互式决策卡</span>
      <strong>{{ config.title }}</strong>
      <p>{{ config.description }}</p>
    </header>
    <div class="tradeoff-explorer__tabs" role="tablist" aria-label="选择场景">
      <button
        v-for="(item, index) in config.choices"
        :id="`tradeoff-${preset}-tab-${index}`"
        :key="item.label"
        type="button"
        role="tab"
        :aria-selected="selected === index"
        :aria-controls="`tradeoff-${preset}-panel`"
        :tabindex="selected === index ? 0 : -1"
        @click="selected = index"
        @keydown="selectFromKeyboard($event, index)"
      >
        {{ item.label }}
      </button>
    </div>
    <div
      :id="`tradeoff-${preset}-panel`"
      class="tradeoff-explorer__panel"
      role="tabpanel"
      :aria-labelledby="`tradeoff-${preset}-tab-${selected}`"
      tabindex="0"
    >
      <div class="tradeoff-explorer__summary">
        <span>推荐关注点</span>
        <strong>{{ choice.headline }}</strong>
        <p>{{ choice.when }}</p>
      </div>
      <div class="tradeoff-explorer__columns">
        <section><span>主要收益</span><ul><li v-for="item in choice.gains" :key="item">{{ item }}</li></ul></section>
        <section><span>代价与限制</span><ul><li v-for="item in choice.costs" :key="item">{{ item }}</li></ul></section>
        <section><span>验证动作</span><ul><li v-for="item in choice.checks" :key="item">{{ item }}</li></ul></section>
      </div>
    </div>
  </section>
</template>
