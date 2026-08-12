---
title: 数据、存储与 Checkpoint
description: 面向大模型训练的数据通路、并行文件系统、分布式检查点与故障恢复方法。
---

# 数据、存储与 Checkpoint

训练存储同时承载样本、缓存、日志、模型与优化器状态，访问形状从随机小读到数 TB 顺序写不等。阵列峰值会掩盖客户端网络、元数据、文件布局和同步停顿。目标是持续供给 GPU，并在故障后从可证明完整的状态恢复。

<CapacityLab preset="checkpoint" />

## 把训练 I/O 分成三条路径

**数据路径**从对象存储或并行文件系统读取语料，经解码、tokenize、shuffle 与组 batch 后进入 GPU。数百万个 JSON 小文件会压垮元数据服务；大分片适合顺序读和预取，却增加索引、随机化与局部重读成本。

**Checkpoint 路径**把训练进程内的一致状态转成持久数据。它是周期性的突发写：所有 rank 往往在相近时刻写出分片，短时间内同时冲击主机 PCIe、节点网络、存储客户端和后端盘。若同步保存，最慢 rank 决定停顿；若异步保存，I/O 与训练重叠，但会消耗额外 CPU 内存、Pinned Memory 和网络带宽。

**恢复路径**与写入方向相反，却不等同于“读回同样文件”。新的作业可能使用不同 world size、张量并行度或 rank 映射，需要重分片；同时还要恢复数据游标、随机数状态、学习率调度器和混合精度缩放器。只恢复模型权重通常适合推理或微调，不足以无缝继续一次训练。

## 数据供应：先修访问形状，再扩容带宽

GPU 饥饿常被误判为存储吞吐不足。一个 step 的输入量并不一定大，瓶颈可能在单线程解压、Python 对象构造、远程小文件 open、全局 shuffle 或 CPU 到 GPU 拷贝。应把 DataLoader 的等待时间拆成定位、读取、解码、变换、组 batch 和 H2D 六段，再决定优化层级。

训练数据通常采用“对象存储作真源、并行文件系统作共享工作集、节点 NVMe 作热缓存”的多层结构。对象存储便宜、耐久且便于版本化，但列举与小对象访问延迟高；并行文件系统提供 POSIX 语义和横向带宽；本地 NVMe 延迟低，却需要容量管理、缓存一致性和节点故障后的回源。缓存键应绑定数据集版本、分片校验和与预处理版本，不能只用文件名，否则同名更新可能静默复用旧数据。

分片太小会制造元数据压力；太大则降低 shuffle 粒度，让重试和缓存淘汰更昂贵。应先测单 worker 读取与解码，再增加节点，观察吞吐扩展、元数据延迟和热点。平均吞吐足够但 P99 open/read 抖动，仍会通过同步 step 变成 GPU 空闲。

## 并行文件系统：元数据与对象数据分离

Lustre 将命名空间与文件属性交给 Metadata Server/Target（MDS/MDT），把文件内容分布在 Object Storage Server/Target（OSS/OST）。客户端拿到布局后可以直接并行访问多个 OST，避免所有数据穿过一个中央文件服务器。[Lustre 官方手册](https://doc.lustre.org/lustre_manual.pdf)详细描述了 MGS、MDT、OST 的创建和客户端结构；这一分离解释了为什么“顺序大文件很快”与“海量小文件很慢”可以同时发生。

Striping 决定一个文件跨多少 OST、每个条带多大。大型 checkpoint 分片若只落一个 OST，会受单目标带宽限制；条带数过多又会占用更多对象、增加锁与小 I/O 开销，并让大量 rank 同时触达几乎全体 OST。布局应按文件尺寸、并发 rank 数和后端 OST 数设计，而不是把 stripe count 一律设为最大。目录级默认布局适合让同一类 checkpoint 保持一致，但变更前要用真实写入尺寸验证。

云托管实现也遵循相同边界。[Amazon FSx for Lustre 性能文档](https://docs.aws.amazon.com/fsx/latest/LustreGuide/performance.html)指出，未命中读和写由网络与磁盘吞吐的较小者决定；后端有数 TB/s 能力，不保证单节点能越过网卡上限。

<TradeoffExplorer preset="storage" />

## 一个完整 Checkpoint 应包含什么

可继续训练的状态通常至少包括：模型参数、优化器一阶/二阶矩、梯度缩放状态、学习率调度器、全局 step、随机数生成器状态、数据集 epoch/游标、并行拓扑与格式版本。若使用 MoE、FSDP/ZeRO 或流水线并行，还需记录参数到逻辑张量的分片元数据。省略数据游标可能导致恢复后重复或跳过样本；省略 RNG 会破坏可复现性；只保存 BF16 工作权重而不保存 FP32 master weights，可能改变后续优化轨迹。

可以用状态构成预估容量：参数量为 `P` 时，BF16 权重约 `2P` Byte，Adam 的 FP32 master weights、m、v 还会增加约 `12P` Byte。分片只降低单 rank 占用，不会消除全局状态；容量还要预留异步 staging 与写入中间态。

## 一致性：Checkpoint 不是若干成功写出的文件

所有 rank 必须对应同一个逻辑 step。若 rank 0 写的是 step 1000，而某个 rank 已更新到 1001，目录即使文件齐全也无法表示真实训练状态。保存入口需要先冻结或复制一致视图，再并行序列化。异步方案通常把张量复制到不会继续被优化器修改的 staging buffer，训练才可安全前进。

持久化建议采用“写临时目录 → 完成所有分片 → 写 manifest 与校验和 → 原子发布完成标记”的协议。恢复器只枚举带提交标记的版本，不把半成品当作最新 checkpoint。manifest 应记录 step、world size、分片键、shape/dtype、文件长度、校验和、格式和框架版本；只检查文件存在无法发现截断、零填充或分片错位。对象存储没有传统目录原子重命名时，可把不可变对象写完后再提交一个很小的 manifest 指针。

保存完成还需定义耐久层级：数据进入本机 Page Cache、落本地 NVMe、被并行文件系统确认、复制到远端对象存储，含义不同。若节点和本地盘一起故障，本地异步 checkpoint 不可用于灾难恢复。系统应明确“快速恢复副本”和“耐久归档副本”，分别暴露完成状态。

## 同步、异步与分层保存

同步保存简单：所有 rank 在训练临界路径上写完再继续，状态边界清楚，额外内存较少；代价是 GPU 全程等待最慢 I/O。异步保存先把训练安全快照移出可变 GPU 状态，再由后台线程或进程写盘。[PyTorch DCP 异步教程](https://docs.pytorch.org/tutorials/recipes/distributed_async_checkpoint_recipe.html)说明，默认做法会把模型与优化器状态复制到 CPU buffer，因此每个 rank 都要承担对应 checkpoint 分片的额外主机内存，并建议同时只保留一个异步请求，避免请求排队叠加内存压力。

异步不等于零开销。GPU→CPU staging 占用 PCIe，后台写入占用 NIC 和文件系统，二者可能与参数 offload、数据读取或集合通信竞争。训练迭代很短而 checkpoint 很大时，后台任务来不及在下一次保存前完成，会形成无界队列。策略必须包含背压：跳过本次、延长间隔或等待已有任务完成，而不是持续申请 buffer。

分层 checkpoint 先写本地 NVMe 或邻居内存，再异步汇聚到共享持久层。[FastPersist](https://arxiv.org/abs/2406.13768)利用 SSD、并行写入和计算重叠降低停顿；[分布式内存 Checkpoint](https://arxiv.org/abs/2310.12670)以内存副本加速恢复。最快的临时层不能替代独立故障域中的耐久副本。

## 分布式 Checkpoint 与重分片

单 rank 聚合完整 state dict 再写文件，在模型变大后会遭遇主机内存峰值、单进程序列化和单链路带宽瓶颈。分布式 checkpoint 让各 rank 并行保存其本地分片并协调元数据。[PyTorch Distributed Checkpoint 文档](https://docs.pytorch.org/docs/main/distributed.checkpoint.html)明确说明 DCP 通常每个 rank 至少产生一个文件，并支持在不同集群拓扑下加载时重分片；这比固定 rank 文件名与固定 world size 的自定义格式更利于弹性恢复。

可重分片也有成本。加载器需要知道逻辑张量的全局 shape、各分片 offset 和目标布局，必要时执行额外读取或 rank 间交换。Megatron Core 的 [Distributed Checkpoint 文档](https://docs.nvidia.com/megatron-core/developer-guide/0.16.0/api-guide/core/dist_checkpointing.html)就区分偏向快速保存/加载的 `dp_reshardable` 与支持任意模型并行变化、但更慢的 `fully_reshardable` 优化器格式。工程上不应默认追求“最通用格式”：日常高频 checkpoint 可选快速格式，在扩缩容或迁移前额外生成可完全重分片的迁移点。

## 保存频率不是固定经验值

间隔太长会增加故障后的重算，太短则让保存开销吞噬吞吐。经典近似根据耗时 `C` 与平均无故障时间 `M` 选择约 `sqrt(2CM)` 的间隔；实际还要加入异步重叠、恢复耗时，并分别考虑节点、机架和存储服务故障。

[CheckFreq 论文](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/12/checkfreq-fast21.pdf)通过后台持久化与细粒度触发降低 DNN checkpoint 对前台训练的影响；[ByteCheckpoint 论文](https://www.usenix.org/system/files/nsdi25-wan-borui.pdf)进一步面向大规模训练统一处理高性能、弹性和可用性。这些系统的共同启示不是照抄一个分钟数，而是测量可重叠阶段、写放大、恢复时间和真实故障分布，再动态选择层级与频率。

## 恢复是一条需要演练的执行链

1. **发现失败并停止旧写入**：用作业代际或 lease 防止失联 rank 继续写同一 checkpoint。
2. **选择版本**：只从提交完成、校验通过且格式兼容的 checkpoint 中选择最新者；最新目录不一定最新可用。
3. **分配新拓扑**：确定 TP/PP/DP/EP 与 rank 映射，验证模型配置和数据集版本一致。
4. **并行加载与重分片**：让 rank 就近读取所需分片，避免所有节点重复读完整状态；监控最慢 OST、节点和 tensor。
5. **恢复控制状态**：还原 step、优化器、调度器、RNG 与数据游标。
6. **验证后继续**：用少量 step 检查 loss 连续性、样本边界和参数摘要。

仅测试 `save()` 返回成功是不够的。每种重要格式都应周期性执行“另起作业、换一组节点、真正加载并跑若干 step”的恢复演练；同时注入缺分片、坏校验和、旧版本元数据和存储超时，验证系统会失败关闭而不是悄悄从随机初始化继续。

## 可观测性与容量治理

数据面至少记录每 rank 读取吞吐、open/stat 延迟、缓存命中、DataLoader wait 和 GPU data stall；checkpoint 面记录逻辑大小、实际写入量、staging 时间、前台停顿、后台完成延迟、最慢 rank、失败阶段和耐久层级；存储侧则关注 MDT 操作率、OST 吞吐与空间倾斜、客户端重试、网络丢包和尾延迟。

保留策略应区分高频恢复点、里程碑与归档，并至少保留一个经过恢复验证的旧版本。容量告警要覆盖完整版本、临时版本、staging 与远端复制。最终评价指标是 GPU 饥饿率、有效吞吐损失、RPO、RTO 和恢复成功率，而不是孤立的 PB 容量。

## 容量预算：同时计算稳态与保存峰值

容量表应从逻辑状态逐项展开，而不是用参数文件大小乘一个经验系数。模型权重、主参数、优化器矩、调度器、随机状态和数据游标分别列出精度、是否分片、复制因子与保留代数；再加入序列化临时文件、异步 CPU staging、本地 NVMe 中转、并行文件系统副本和对象存储上传缓存。稳态容量决定长期成本，保存峰值则决定会不会在两个版本交叠时突然写满。每次修改优化器、精度或并行策略后，都应由一次真实 checkpoint 校准估算。

空间水位至少设置三层动作。进入预警水位时停止非必要里程碑副本并加快过期版本回收；进入保护水位时禁止发起新的异步保存，避免旧任务未完成又申请整份 staging；接近硬上限时应让训练受控停在最近可恢复点，而不是继续写出截断文件。清理器只能删除 manifest 已标记为过期且无活跃 lease 的版本，不能按目录修改时间直接删除，因为后台上传或恢复任务可能仍在引用旧分片。

带宽预算也要覆盖峰值。若 `n` 个 rank 在窗口 `W` 内各写 `S` Byte，后端至少需要承受约 `nS/W` 的有效写入率，还要扣除协议、校验和复制的开销。异步保存虽然缩短前台停顿，却把同样的字节移到更长的竞争窗口；若训练数据读取和 checkpoint 共用网络，应分别给两类流量设上限并观察 GPU 饥饿。容量实验需在多租户高峰执行一次，空闲集群结果不能代表生产余量。

## 恢复验收清单与故障注入

第一类验收是**完整性**。随机抽取多个 checkpoint，逐个核对 manifest 中的分片数量、长度、dtype、shape 与校验和；删除一个分片、截断一个文件或篡改完成标记，加载器都必须在模型执行前明确失败。若系统自动回退旧版本，日志必须记录被拒绝的版本与原因，不能悄悄回退后仍宣称恢复了最新 step。对象存储上传完成还要验证远端对象，而不是只相信本地队列返回成功。

第二类是**一致性**。恢复后比较全局 step、学习率、优化器统计量、随机状态与数据游标，并运行一小段确定性样本。允许浮点并行顺序造成的微小差异，但 loss 不应跳变，样本不得重复或遗漏，所有 rank 对参数元数据的摘要必须一致。对于 MoE，还要验证专家映射和路由状态；对于流水线并行，要确认各 stage 加载的是同一 checkpoint 代际。

第三类是**拓扑变化**。至少验证同 world size 换节点、缩小或扩大数据并行、改变张量/流水线并行三种恢复。每种场景记录元数据规划、实际读取字节、rank 间交换量、最慢 rank 和首个有效 step 时间。若某种格式只支持数据并行重分片，应在提交新作业前拒绝不兼容拓扑，而不是加载中途才失败。迁移演练还应覆盖框架小版本升级和一次显式格式转换。

第四类是**故障时序**。分别在 GPU→CPU staging、写本地盘、写共享文件系统、提交 manifest 和上传对象存储期间杀死进程或断开网络。预期结果应事先写清：哪些中间文件会被清理，哪个完成标记不会出现，重启后选择哪个版本，孤儿对象何时回收。若协调 rank 失败，其余 rank 不得无限等待；若仅一个数据分片失败，整个版本不能进入可恢复集合。

第五类是**性能退化**。注入单个慢 OST、限制一个客户端带宽、制造元数据延迟，确认异步队列有界、背压生效、训练不会耗尽主机内存。恢复测试同样要注入慢分片，观察读取规划能否均衡，而不是让所有 rank 等待一个热点对象。验收报告最终给出前台停顿、后台持久化时间、恢复 P50/P95、RPO、RTO 和成功率，并把阈值接入发布门禁。

## 来源

- [Lustre：Lustre Software Release 2.x Operations Manual](https://doc.lustre.org/lustre_manual.pdf)
- [PyTorch：Distributed Checkpoint](https://docs.pytorch.org/docs/main/distributed.checkpoint.html)
- [PyTorch：Asynchronous Saving with Distributed Checkpoint](https://docs.pytorch.org/tutorials/recipes/distributed_async_checkpoint_recipe.html)
- [NVIDIA Megatron Core：Distributed Checkpointing](https://docs.nvidia.com/megatron-core/developer-guide/0.16.0/api-guide/core/dist_checkpointing.html)
- [AWS：Amazon FSx for Lustre Performance](https://docs.aws.amazon.com/fsx/latest/LustreGuide/performance.html)
- [Eisenman et al.：CheckFreq: Frequent, Fine-Grained DNN Checkpointing](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/12/checkfreq-fast21.pdf)
- [Wan et al.：ByteCheckpoint: A Unified Checkpointing System](https://www.usenix.org/system/files/nsdi25-wan-borui.pdf)
- [Wang et al.：FastPersist: Accelerating Model Checkpointing in Deep Learning](https://arxiv.org/abs/2406.13768)
- [Fault-Tolerant Hybrid-Parallel Training with In-memory Checkpointing](https://arxiv.org/abs/2310.12670)
