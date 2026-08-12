---
title: 大模型分布式训练：并行组合与通信
description: 从切分对象、通信原语与硬件拓扑出发，理解 DP、TP、PP、EP、CP、ZeRO 与 FSDP 如何组合成可运行的训练系统。
---

# 大模型分布式训练：并行组合与通信

分布式训练不是“多开几张卡”，而是把一份计算图、模型状态和样本流拆成多个相互依赖的局部任务。每一种并行策略都在消除某个瓶颈，同时制造新的通信、同步或调度成本。真正重要的不是记住缩写，而是回答四个问题：**切分了什么、每张卡还保存什么、什么时候必须交换数据、交换能否被计算隐藏**。

在一个混合并行作业中，总设备数通常可以写成 `DP × TP × PP × CP`，MoE 模型还要建立 EP 相关进程组；实际进程组并非简单相乘，因为 EP 可能复用或重组 DP 维度。Megatron Core 的[并行策略指南](https://docs.nvidia.com/megatron-core/developer-guide/latest/user-guide/parallelism-guide.html)也把策略选择落在同一组约束上：批量、层内张量、网络深度、序列长度、专家和模型状态分别是不同的切分维度。

<TradeoffExplorer preset="parallelism" />

## 先建立一张并行坐标系

| 策略 | 主要切分对象 | 典型通信 | 主要收益 | 主要代价 |
| --- | --- | --- | --- | --- |
| DP | batch / 样本 | 梯度 AllReduce | 近线性增加样本吞吐 | 参数、梯度和状态默认复制 |
| TP | 单层权重与激活 | AllReduce、AllGather、ReduceScatter | 单层跨卡，缩小局部矩阵 | 层内高频通信，强依赖高速互联 |
| PP | 连续网络层 | 相邻阶段 Send/Recv | 按深度分摊参数和激活 | 流水线气泡、负载不均、调度复杂 |
| CP | token 序列及激活 | KV 的 P2P / AllGather / AllToAll | 长上下文激活按 CP 度下降 | 注意力必须获得全局 KV 信息 |
| EP | MoE 专家 | token dispatch/combine AllToAll | 总参数扩大而每 token 仅激活少数专家 | 路由倾斜、跨节点流量、容量丢弃 |
| ZeRO/FSDP | 参数、梯度、优化器状态 | AllGather、ReduceScatter | 消除数据并行副本冗余 | 更多状态物化通信和生命周期管理 |

这张表最容易被误读的地方是把“显存下降”和“通信下降”等同起来。切分越彻底，本地常驻状态越少，但计算前越可能需要把分片重新物化。训练能否提速，最终取决于局部算子的计算时间是否足以覆盖这些通信，以及进程组是否被放在合适的物理链路上。

## 数据并行：吞吐基线，而不是免费扩展

数据并行在每个 rank 放置完整模型，各自读取不同样本，反向后对梯度求和或平均。经典 DDP 通常把多个梯度装入 bucket，在反向传播尚未结束时就发起 AllReduce，使较早计算完成的梯度通信与后续反向计算重叠。它的优点是模型代码变化少、每个 rank 的算子尺寸不缩小，因而容易保持较高的 GPU 利用率。

代价也很清楚：每张卡都保存参数、梯度和优化器状态，显存不会随着 DP 度增加而下降；每步还要同步相当于梯度规模的数据。全局 batch 为 `micro_batch × gradient_accumulation × DP`，增加 DP 后若仍想保持优化轨迹，就要同步调整微批次、累积步数或学习率。吞吐扩展不能只报 samples/s，还应同时报告固定全局 batch 下的 step time 与收敛到目标质量的总 token 数。

拓扑上，DP 的大消息集合通信比 TP 更能容忍跨节点延迟，通常把高频 TP 组优先留在节点内，把 DP 组扩展到节点间。DP 也最适合承担“剩余设备维度”：先用 TP、PP、CP 解决单模型放不下或长序列放不下，再把余下设备用于复制数据通路。

## 张量并行：把一层矩阵拆开

张量并行在单层内部切分线性层。以 Transformer MLP 为例，第一块矩阵可以按输出维度列切，第二块矩阵按输入维度行切。各 rank 先独立完成局部 GEMM，再在需要恢复完整结果时进行集合通信。注意力的 QKV 投影和输出投影也能使用类似布局。Megatron-LM 的原始工作展示了层内张量并行，后续论文进一步分析了 TP、PP 与 DP 的组合和跨数千 GPU 的放置权衡，见[Efficient Large-Scale Language Model Training on GPU Clusters](https://arxiv.org/abs/2104.04473)。

TP 解决的是“单层太宽”与局部参数、激活显存问题，但每个 Transformer 层都会触发通信。TP 度过高时，局部矩阵变小，GEMM 算术强度下降，而 AllReduce 延迟并不会按比例消失。因此 TP 通常限制在同一台服务器或同一高速互联岛内。若一层已经能高效放进单卡，继续提高 TP 往往只会把大算子切成低效率的小算子。

Sequence Parallel 常与 TP 配套：对 LayerNorm、Dropout 等原本在各 TP rank 重复保存的序列激活，沿序列维度切分，并用 AllGather/ReduceScatter 接回张量并行区域。它不等于完整的 CP，因为它主要覆盖可独立处理 token 的区域，注意力的全序列依赖仍需其他方案。

## 流水线并行：按深度切层，并管理时间

流水线并行把连续层分配给不同阶段，阶段间只传递边界激活及其梯度，通信通常是点对点 Send/Recv。它能让非常深的模型跨设备放置，并避免 TP 那样每层多次集合通信；但同一个微批次仍要依次通过所有阶段，于是需要把全局 batch 切成多个微批次填满流水线。

最简单的 GPipe 式调度先连续前向再连续反向，激活驻留较多。1F1B 调度在暖机后交替执行一次前向和一次反向，降低峰值激活。阶段数为 `p`、微批次数为 `m` 时，朴素流水线的气泡比例可粗略理解为与 `(p-1)/(m+p-1)` 同阶：微批次越多，暖机和排空摊销越小，但调度与累计激活也更复杂。Megatron Core 官方实现同时提供非交错与交错调度，并明确包含阶段间所需的[点对点通信](https://docs.nvidia.com/megatron-core/developer-guide/0.17.0/api-guide/core/pipeline_parallel.html)。

虚拟流水线把每个物理 rank 上的层再分成多个模型块，形成交错 1F1B，可缩短气泡而不增加物理阶段数。它不是无条件收益：模型块越碎，阶段切换、通信次数和框架调度开销越大。阶段切分也不能只按“层数相等”，嵌入层、输出头、不同 MoE 层和重计算配置会让每层耗时、参数和激活显著不同，应该根据实测 profile 做均衡。

<TopologyExplorer preset="parallelism" />

## 上下文并行：长序列的专用维度

上下文并行把输入和所有层的激活沿序列维度切开。Linear、LayerNorm 等逐 token 运算可以直接处理局部片段；注意力不同，因为本地 query 仍需与全序列的 key/value 交互，所以 CP 必须交换 KV 块或重排 QKV。Megatron Core 的[Context Parallelism 说明](https://docs.nvidia.com/megatron-core/developer-guide/latest/user-guide/features/context_parallel.html)明确区分了 CP 与早期 SP：CP 覆盖整个网络的序列激活，并可与 TP、PP、DP 组合；总卡数为 `TP × CP × PP × DP`。

CP 的直接收益是激活显存大致按 CP 度下降，特别适合 8K、32K 乃至更长上下文。通信实现可以是环形 P2P、AllGather 或 AllToAll，不同选择取决于注意力实现、GQA/MQA 的 KV 头数量和网络拓扑。对短序列盲目开启 CP 可能得不偿失：注意力计算不足以覆盖通信，且每卡处理的 token 太少。应把“序列是否导致激活 OOM、完整重计算成本是否过高”作为启用信号，而不是把 CP 当作普通吞吐并行。

## 专家并行：稀疏参数背后的动态通信

MoE 层由路由器为 token 选择少量专家。EP 将不同专家放到不同 rank：先按路由结果把 token dispatch 到专家所在设备，局部完成专家 MLP，再 combine 回原位置。与固定形状的 TP 集合通信不同，EP 的 AllToAll 数据量受 token 分布影响。平均流量看似可控，单个热门专家却可能成为尾部瓶颈。

[GShard](https://arxiv.org/abs/2006.16668)展示了稀疏门控专家与自动切分如何把模型扩展到数千亿参数；[Switch Transformer](https://arxiv.org/abs/2101.03961)则以每 token 选择单一专家简化路由，同时把通信成本和训练不稳定列为 MoE 落地的核心难题。工程上要同时观察路由熵、每专家 token 数、容量因子、丢弃/溢出比例和 AllToAll 尾延迟，不能只看总体 FLOPs。

EP 最适合把同一专家组放在高带宽域内。跨节点 AllToAll 会让每个节点同时与多个对端交换不等长消息，容易受链路争用影响。TP 与 EP 同时启用时还要核对框架约束；Megatron Core 当前指南要求 TP+EP 配置开启 Sequence Parallel。专家参数也有自己的 data-parallel 语义：同一专家的副本之间同步梯度，而不是对所有普通 DP rank 做无差别同步。

## ZeRO 与 FSDP：切分数据并行的模型状态

ZeRO 不切计算图中的层，而是消除 DP rank 间重复的模型状态。[ZeRO 论文](https://arxiv.org/abs/1910.02054)将冗余状态分阶段切分；DeepSpeed 的[官方教程](https://www.deepspeed.ai/tutorials/zero/)给出清晰定义：Stage 1 切优化器状态，Stage 2 再切梯度，Stage 3 进一步切参数，并在前向、反向需要时收集参数分片。

PyTorch FSDP 的 `FULL_SHARD` 与 ZeRO-3 思路相近：前向前 AllGather 参数，之后重新分片；反向前再次物化需要的参数，梯度完成后通过 ReduceScatter 同步并留下本 rank 分片，优化器仅更新本地分片。具体生命周期可查 [PyTorch FSDP 文档](https://docs.pytorch.org/docs/stable/fsdp.html)。`SHARD_GRAD_OP` 则更接近参数在计算期间保留、计算外切分的折中方式。

FSDP/ZeRO-3 把显存压力转成参数物化通信。模块 wrap 粒度太大，峰值 AllGather buffer 高且难与计算重叠；太小则产生大量短消息和调度开销。`limit_all_gathers`、prefetch、bucket 大小、是否在前向后 reshard，都在控制同一件事：同时在途的完整参数数量与通信覆盖窗口。

ZeRO-1/2 常能保留完整参数带来的较好算子调度，同时显著减少 Adam 状态和梯度冗余；当参数本身已经放不下时才需要 Stage 3/FULL_SHARD。CPU 或 NVMe offload 进一步扩大容量，却把瓶颈移到 PCIe、主机内存带宽与存储 I/O；“能训练”与“值得训练”必须分开评估。

## 混合并行如何组合

一个实用顺序是先处理硬约束，再优化吞吐：

1. **单层是否放得下？** 放不下时先增加 TP；能放下后避免继续切碎 GEMM。
2. **整模型状态是否放得下？** 增加 PP 或 ZeRO/FSDP；前者沿层切图，后者沿 DP 组切状态。
3. **序列激活是否放得下？** 优先比较选择性重计算与 CP；长序列下 CP 能保留更多计算。
4. **是否为 MoE？** 按专家数、激活专家数和网络域设计 EP，并单独处理专家 DP。
5. **剩余卡数如何提升吞吐？** 用 DP 扩展样本通路，同时保持全局 batch 与优化语义可比。

例如 256 张 GPU 可以形成 `TP=8, PP=4, CP=2, DP=4`。TP 组应尽量位于同一高速互联域，PP 相邻阶段映射到相邻节点，CP 组需要稳定的 KV 交换带宽，DP 则承担更远距离的梯度/分片同步。这个分解只是候选，不是答案；模型宽度、层数、序列长度、微批次、网络层次与 kernel 效率改变时，最优点也会改变。

并行维度还会相互改变通信量。TP 增大会缩小每个 PP 阶段的参数与计算，却提高层内通信占比；PP 增大会降低单卡层数，却增加气泡和边界通信；CP 降低每卡激活，却引入注意力 KV 交换；FSDP 降低常驻状态，却在每层制造参数 AllGather。不能把各策略的单独加速比相乘。

## 通信原语与拓扑放置

| 原语 | 常见用途 | 性能敏感点 |
| --- | --- | --- |
| AllReduce | DDP 梯度、部分 TP 输出 | 消息大小、环/树算法、跨节点带宽 |
| ReduceScatter | FSDP/ZeRO 梯度分片、SP/TP | 可与反向计算重叠，输出天然分片 |
| AllGather | FSDP 参数物化、SP/TP 激活 | 峰值 buffer、预取距离、并发数量 |
| AllToAll | EP token 路由、部分 CP 实现 | 不等长消息、热点、跨交换机争用 |
| Send/Recv | PP 阶段边界、环形 CP | 相邻 rank 放置、双向重叠、死锁顺序 |

平均带宽不是唯一指标。小消息更受启动延迟影响，大消息更受有效带宽影响；多个并行组同时通信会争用 NIC、PCIe 与 NVLink。应按进程组分别记录通信时间、等待时间、消息大小分布和 overlap，而不是只看整步 “communication percentage”。Megatron Core 的并行状态 API 实际维护 TP、DP、CP、PP、EP 等正交或复合进程组，这也说明[rank 拓扑](https://docs.nvidia.com/megatron-core/developer-guide/latest/apidocs/core/core.parallel_state.html)本身就是系统设计的一部分。

## 两个组合决策案例

### 案例一：稠密模型从八卡扩到六十四卡

假设一个稠密模型在八张同机 GPU 上使用 `TP=8` 才能放下单层，但实测发现每卡矩阵已经较小，层内通信占到步时的三成。扩到八个节点时，直接设 `TP=64` 会把高频 AllReduce 拉到节点间，通常不是合理扩展。更稳妥的候选是保持 `TP=8` 在节点内，再用 `PP=2, DP=4` 消化其余设备。这样总设备数仍为六十四，TP 通信留在高速域，PP 只在阶段边界跨节点，DP 对较大的梯度 bucket 做跨节点同步。

这个候选还要经过三次核对。第一，切成两个流水线阶段后，每个阶段是否都能容纳参数、激活和通信 buffer；若只有输出头所在阶段 OOM，应调整层布局，而不是立刻增加 PP。第二，全局 batch 是否因 DP 从一变四而扩大；若训练语义要求保持不变，就应相应减少梯度累积或单卡微批次。第三，微批次数是否足够覆盖两个阶段的暖机和排空；如果为了减少气泡而增加微批次，却导致同时驻留激活超过预算，就需要在调度、选择性重计算和吞吐之间重新取点。

扩容验收不能只比较六十四卡总吞吐。先在八卡和六十四卡上固定全局 batch，比较单步耗时，这是强扩展效率；再固定每卡 token 数，比较总吞吐，这是弱扩展效率。若弱扩展很好而强扩展很差，问题多半不是算子本身，而是通信占比、气泡或全局 batch 约束。还应分别导出 TP、PP、DP 进程组的通信时间，否则一个“通信变慢”的结论无法指导拓扑调整。

### 案例二：长上下文 MoE 的并行网格

再假设模型含六十四个专家，每个 token 激活两个专家，序列长度从八千扩到六万四千。此时参数总量大、激活长、路由动态，不能只用一种并行解决。决策顺序可以是：用较小 TP 保证注意力和专家矩阵仍有足够算术强度；用 CP 沿序列切激活，先解除长上下文 OOM；用 EP 把专家放入若干高速互联组；必要时用 PP 分摊层数；最后以 DP 或分片数据并行扩展样本通路和切分优化器状态。

例如总卡数允许时，可以先评估 `TP=2, CP=4, PP=4` 的稠密注意力网格，再为 MoE 层建立八路 EP。这里不能机械地把所有数字相乘：框架可能让专家数据并行组复用普通 DP 维，也可能为注意力与专家层建立不同网格。必须从实际 rank group 列表验证每张卡属于哪些组，并确认同一专家副本的梯度只在正确的专家数据并行组内同步。

这个案例的性能门槛是尾部而非平均值。需要同时记录每个专家收到的 token 数、最热专家与平均专家之比、被容量限制丢弃的 token、dispatch 与 combine 两次 AllToAll 的分位耗时，以及 CP 的 KV 交换耗时。若最慢专家决定整层结束时间，提高网络带宽也未必解决问题；应先调整路由辅助损失、容量因子或专家放置。若专家负载均衡但 AllToAll 跨交换机拥塞，才应重排 EP rank，让高频通信尽量局限在同一网络域。

### 用消融实验确认每个并行维度的价值

混合并行出现回退时，不应一次修改多个并行度。先保留可运行基线，每次只改变一个维度，并同步调整使训练语义保持一致的量。例如比较 CP 时固定模型、全局 batch、TP 和 PP，只改变 CP 度与序列切片；比较 ZeRO 阶段时固定计算图和 batch，只观察模型状态峰值、参数 AllGather、梯度 ReduceScatter 与步时。每个候选至少经过暖机后采集稳定区间，并记录最慢 rank，而不是只取全局平均。

一个候选可以用三道门淘汰：**容量门**要求峰值低于预算且保留安全余量；**正确性门**要求 loss、梯度范数和恢复训练连续；**效率门**要求吞吐收益能够覆盖通信、重计算和调度成本。先过容量再谈效率，先过正确性再比较速度。这样即使最终配置包含五种并行，也能解释每一个维度为何存在，而不是得到一组无法迁移的幸运参数。

## 从可运行到可扩展的验证清单

- **正确性**：单卡、较小 DP 与目标混合并行在固定种子下比较 loss 曲线和梯度范数；浮点归约顺序变化会造成小差异，不要求逐位一致。
- **显存**：分别记录常驻参数、梯度、优化器状态、保存激活、通信 bucket、临时 workspace 和峰值 reserved memory。
- **利用率**：区分 GEMM、注意力、通信、数据等待和流水线空闲，不能用单一 GPU utilization 替代。
- **负载均衡**：PP 看最慢阶段，EP 看最热专家，DP 看最慢 rank，CP 看序列长度与 mask 后的有效 token。
- **扩展效率**：强扩展固定问题规模，弱扩展固定每卡工作量；两者结论不可混用。
- **故障恢复**：验证混合并行 checkpoint 能否在相同拓扑恢复；若要求改变 TP/PP/DP 度，需要明确转换工具和一致性测试。

最终配置应该留下可复现实验记录：模型形状、精度、全局与微批次、每个并行度、rank 映射、重计算范围、ZeRO/FSDP 策略、bucket/prefetch、网络环境以及至少一个稳态区间的 profile。没有这些上下文，“某配置更快”几乎无法迁移到另一台集群。

## 来源

- [Megatron Core：Parallelism Strategies Guide](https://docs.nvidia.com/megatron-core/developer-guide/latest/user-guide/parallelism-guide.html)
- [Megatron Core：Context Parallelism](https://docs.nvidia.com/megatron-core/developer-guide/latest/user-guide/features/context_parallel.html)
- [Megatron Core：Pipeline Parallel API](https://docs.nvidia.com/megatron-core/developer-guide/0.17.0/api-guide/core/pipeline_parallel.html)
- [Narayanan et al.：Efficient Large-Scale Language Model Training on GPU Clusters Using Megatron-LM](https://arxiv.org/abs/2104.04473)
- [Rajbhandari et al.：ZeRO: Memory Optimizations Toward Training Trillion Parameter Models](https://arxiv.org/abs/1910.02054)
- [DeepSpeed：Zero Redundancy Optimizer Tutorial](https://www.deepspeed.ai/tutorials/zero/)
- [PyTorch：FullyShardedDataParallel](https://docs.pytorch.org/docs/stable/fsdp.html)
- [Lepikhin et al.：GShard](https://arxiv.org/abs/2006.16668)
- [Fedus et al.：Switch Transformers](https://arxiv.org/abs/2101.03961)
