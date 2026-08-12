---
title: 训练显存账本与数值稳定
description: 从参数、梯度、优化器状态、激活和临时缓冲拆解训练显存，并理解重计算、混合精度与稳定性保障的真实边界。
---

# 训练显存账本与数值稳定

大模型训练中两个最常见的误判是：“参数能放下，训练就能放下”和“换成 16 位，显存就减半”。训练需要保存参数、梯度、优化器状态、激活、通信缓冲和算子 workspace；混合精度还可能保留 FP32 主权重。显存优化也会改变计算量、通信量和数值路径。可靠的容量规划必须先建立逐项账本，再讨论技术组合。

本文把显存分为五本账：**模型状态、保存激活、临时张量、通信缓冲、分配器与框架开销**。账本中的理论值是下界，真实峰值由这些对象的生命周期重叠决定。OOM 发生在峰值时刻，而不是平均时刻。

<CapacityLab preset="training-memory" />

## 参数量只是起点

设模型有 `P` 个可训练参数，单个数据元素占 `b` 字节。只做前向时，权重下界约为 `P × b`；训练时还要加入梯度和优化器状态。以常见的 Adam/AdamW 混合精度训练为例，一种典型但并非唯一的布局是：

| 项目 | 每参数典型字节数 | 说明 |
| --- | ---: | --- |
| BF16/FP16 模型权重 | 2 | 前向和反向使用的低精度权重 |
| 低精度或 FP32 梯度 | 2 或 4 | 取决于框架、通信与累积策略 |
| FP32 主权重 | 4 | 用于保留小幅参数更新，部分 BF16 路径可采用不同实现 |
| Adam 一阶矩 | 4 | `m` |
| Adam 二阶矩 | 4 | `v` |
| 合计 | 16 或 18 | 尚未计激活、临时 buffer、碎片和 checkpoint |

因此“70 亿参数 × 2 字节约 14 GB”只描述一份低精度权重，不能说明训练能否放进 24 GB 或 40 GB GPU。若按 16 字节/参数粗估，仅模型状态就约 112 GB；若是 18 字节则约 126 GB。具体实现可能融合状态、使用 FP32 梯度、延迟初始化或把状态放到 CPU，必须以实际 optimizer 和框架为准。

[DeepSpeed ZeRO 教程](https://www.deepspeed.ai/tutorials/zero/)给出的阶段划分正是对这本账的拆分：Stage 1 切分优化器状态，Stage 2 再切梯度，Stage 3 再切参数。假设数据并行度为 `N`，理想下对应项目的单卡占用可除以 `N`，但 AllGather、ReduceScatter bucket 和当前层完整参数仍会形成瞬时峰值。

## 激活为何经常成为第一大项

自动微分在前向时保存反向需要的中间结果，包括层输入、注意力相关张量、归一化统计和非线性输入。激活规模与 micro batch、序列长度、隐藏维度和层数近似成正比；朴素注意力的某些中间量还可能随序列长度平方增长。参数量固定时，把上下文从 4K 扩到 32K，激活账本可能先于参数账本失控。

不要用“每层输出 `B×S×H`”代表整层激活。一个 Transformer 块中，Q/K/V、注意力输出、MLP 扩展维度、残差、Dropout mask 和 kernel 保存张量都可能在反向前存活。融合算子、Flash Attention、GQA、是否保存 attention matrix 会改变常数项。更可靠的方法是：先用结构公式估下界，再在目标配置上测量 `allocated` 峰值，并记录每层 saved tensors。

微批次是最直接的激活旋钮。梯度累积可以在保持全局 batch 的同时降低单次前后向的激活峰值，但会增加每个 optimizer step 的前后向次数。PP 下还要考虑同时在途的微批次：单个微批次变小不代表总保存激活一定同比下降，调度决定多少批激活会重叠驻留。

## 激活重计算：以算力换驻留时间

Activation Checkpointing 只保存少量边界输入，反向需要内部中间结果时重新执行一段前向。[PyTorch 官方文档](https://docs.pytorch.org/docs/stable/checkpoint)直接将其定义为“以计算换显存”；早期论文 [Training Deep Nets with Sublinear Memory Cost](https://arxiv.org/abs/1604.06174)系统化展示了利用重计算把深网内存降到次线性量级的思路。

全量重计算简单但代价大：每层反向前都重跑完整前向。选择性重计算只对激活大而重算相对便宜的区域 checkpoint，例如注意力核心、MLP 中间激活，保留昂贵或状态敏感的结果。最优边界取决于 kernel：若某算子已经受内存带宽限制，重算可能比从 HBM 读取保存结果更划算；若是高算力利用率的巨大 GEMM，重跑成本就很真实。

重计算还有正确性约束。Checkpoint 区域若包含随机操作，必须正确保存和恢复 RNG 状态，否则 Dropout 等操作在重算时会生成不同掩码。若重算期间依赖了前向之后被改变的全局状态，反向图可能与原始前向不一致。PyTorch 文档也提醒：若 checkpoint 函数在反向重调时与前向行为不同，可能导致静默错误或异常。应对小模型做无 checkpoint 与有 checkpoint 的 loss、梯度范数和若干参数梯度对照。

DeepSpeed 的[训练功能说明](https://www.deepspeed.ai/training/)还提供激活分片、CPU checkpoint 与连续内存优化。CPU offload 可以显著降低 GPU 常驻激活，却增加设备间拷贝；只有拷贝能与计算重叠且主机带宽充足时，吞吐损失才可控。连续 buffer 解决碎片问题，但它消耗的是预留空间，不是“零成本整理”。

<TradeoffExplorer preset="precision" />

## 临时张量、通信缓冲与碎片

训练峰值不仅由长生命周期对象决定。矩阵乘法、注意力、归一化、排序或路由 kernel 可能申请 workspace；FSDP 在某层计算前 AllGather 完整参数，DDP/ZeRO 为通信建立 bucket；梯度裁剪可能临时计算范数；保存 checkpoint 时还可能聚合完整 state dict。这些对象各自存在时间短，却可能恰好与激活或梯度峰值重叠。

分配器通常维护 reserved memory 池，已释放 tensor 对应的块未必立即归还驱动，所以 `nvidia-smi`、框架 `reserved` 和活跃 tensor 的 `allocated` 会不同。外部碎片意味着总空闲字节足够，却没有满足一次大申请的连续块。频繁变化的序列长度、不规则 MoE token 数和交替出现的长短生命周期 tensor 都会放大碎片。

正确观测至少包括：当前/峰值 allocated、当前/峰值 reserved、inactive split blocks、OOM 时请求大小、各通信 bucket 尺寸以及目标步骤的 memory snapshot。只在训练结束读取当前值会错过峰值；只看 `nvidia-smi` 又无法把缓存与活跃 tensor 分开。容量预估也应留出 runtime、NCCL、CUDA graph 和偶发长 batch 的余量，而不是把理论账本塞满物理显存。

## 混合精度到底混合了什么

混合精度不是把整个模型无差别 `.half()`。线性层和卷积等算子在低精度输入上通常能使用高吞吐 Tensor Core；归约、指数、对数、Softmax、损失等对动态范围或舍入更敏感的操作常保留 FP32。PyTorch `torch.amp` 的[官方说明](https://docs.pytorch.org/docs/stable/amp.html)即按算子选择 dtype：`autocast` 决定执行精度，FP16 训练通常再配合 `GradScaler`。

三种常见格式的差异不能只用“都是 16 位”概括：

| 格式 | 指数/尾数特性 | 训练含义 |
| --- | --- | --- |
| FP32 | 较宽动态范围与较高精度 | 参考路径、主权重、敏感归约和状态常用 |
| FP16 | 指数范围窄、尾数较 BF16 多 | 精度较细但容易上溢/下溢，通常需要 loss scaling |
| BF16 | 指数范围接近 FP32、尾数更短 | 较少动态范围问题，但舍入误差更大，仍非“不会溢出” |

[Mixed Precision Training 论文](https://arxiv.org/abs/1710.03740)提出用 FP16 执行大量计算，同时保留必要的 FP32 信息，并通过 loss scaling 保护很小的梯度。NVIDIA 的[混合精度训练指南](https://docs.nvidia.com/deeplearning/performance/mixed-precision-training/index.html)也将低精度计算、FP32 主权重和损失缩放列为典型步骤。

FP32 主权重的理由是更新分辨率：当某次梯度更新远小于当前低精度权重的一个 ULP 时，直接加到 FP16/BF16 权重可能被舍入掉。优化器在更高精度副本上累计更新，再转换为计算权重，可保留这些小变化。是否实际保留独立主权重、梯度采用何种 dtype，应查看框架与 fused optimizer 的实现，不应套用固定字节公式。

## Loss Scaling：保护小梯度，不是修复所有 NaN

FP16 的最小可表示范围有限，小梯度可能下溢成零。Loss scaling 在反向前把 loss 乘以尺度 `s`，使链式法则产生的梯度也乘以 `s`；在 optimizer 使用前再除以 `s`，数学更新保持不变，但中间梯度更可能落在 FP16 可表示区间。

静态尺度需要人工选择，过小保护不足，过大又会使梯度上溢。动态 `GradScaler` 会在连续若干步无 Inf/NaN 时增大尺度，检测到非有限梯度时跳过更新并降低尺度。PyTorch 文档特别指出 scale 可能降到 1 以下，且 AMP 不保证任意模型都兼容 FP16；如果 loss 或梯度持续 NaN，应检查模型范围，而不是无限调整 scaler。

Loss scaling 只能缓解低精度梯度下溢。若前向中的 logits、attention score 或指数已经溢出，放大 loss 反而无关；若学习率过大、数据异常、除零、错误 mask 或自定义 kernel 越界，也必须定位原始算子。判断顺序应是：找到首次非有限 tensor，再区分发生在前向、反向还是 optimizer step。

## 数值稳定是一条端到端链路

浮点运算不满足实数运算中的结合律，改变归约树、设备数或 kernel 会改变加法顺序。PyTorch 的[数值精度说明](https://docs.pytorch.org/docs/stable/notes/numerical_accuracy.html)明确指出，数学上相同的浮点计算不保证逐位相同，CPU/GPU、版本与平台间也可能产生差异。因此分布式训练验证应采用误差容限、loss 趋势和任务指标，不应把 bitwise equality 当作普遍正确性条件。

常见稳定化策略都在控制中间量范围：

- Softmax 先减去行最大值，避免 `exp` 对大正数上溢；mask 应使用与 dtype 和 kernel 兼容的表示。
- `log(sum(exp(x)))` 使用 log-sum-exp 形式，避免先指数再求和的极端范围。
- LayerNorm/RMSNorm 的统计和 epsilon 要在足够精度下计算；epsilon 不是越小越准确。
- 梯度裁剪在更新前约束异常大梯度，但它会改变优化轨迹，只能作为明确的算法配置。
- 归约和累加使用 FP32 能降低大量低精度项相加的误差；最终输出 dtype 与内部累加 dtype 需要分别确认。
- 学习率 warmup、合理初始化和归一化位置影响激活与梯度尺度，系统精度策略不能替代算法稳定性设计。

出现不稳定时，应在首次异常之前布置观测：每层激活最大绝对值、均值/方差，loss 分量，缩放前后梯度范数，非有限元素计数，scaler 值与跳步次数。只在最终 loss 变成 NaN 后 dump 整个模型，通常已经丢失了第一现场。

## 优化器状态是容量与精度的交叉点

Adam 为每个参数维护一阶、二阶矩，状态量通常是参数本身的两倍元素数；再加主权重后，优化器相关账本往往超过低精度模型权重。Stage 1/FSDP optimizer-state sharding 因而经常是风险较低、收益明显的第一步：参数计算布局不变，只把不同参数的更新责任分给不同 DP rank。

状态切分后，checkpoint 不再是单文件完整字典。保存时若把全部分片聚合到 rank 0，主机或 GPU 峰值可能突然翻倍；分片 checkpoint 则要求恢复端理解原来的 world size、参数映射与格式。PyTorch FSDP 文档区分 full、sharded 和 local state dict，并说明 `FULL_SHARD` 下参数、梯度和优化器状态的切分与物化生命周期，见 [FSDP API](https://docs.pytorch.org/docs/stable/fsdp.html)。

把优化器 offload 到 CPU 可换取 GPU 容量，但每步要搬运梯度、参数或状态，并在 CPU 上执行更新。瓶颈可能从 HBM 变成 PCIe、主机内存带宽和 CPU 算力。应同时记录 GPU step time、CPU optimizer time、H2D/D2H 字节数和 overlap，而不是只庆祝 GPU 显存下降。

## 一套可执行的容量规划方法

1. **固定训练语义**：模型结构、序列长度、micro batch、梯度累积、精度、优化器和 checkpoint 策略必须先确定。
2. **计算模型状态下界**：逐项写参数、梯度、主权重、各优化器状态的元素数与 dtype，不用模糊的“约几倍”。
3. **估计激活**：按层列 saved tensors，并用目标 kernel 做单层或小层数实测；再考虑 PP 在途微批次。
4. **加入瞬时项**：通信 bucket、FSDP AllGather、attention/GEMM workspace、梯度范数和 checkpoint 聚合。
5. **映射生命周期**：找出前向末尾、反向开始、梯度全部就绪、optimizer step 等候选峰值，而非简单相加所有最大值。
6. **保留运行余量**：覆盖分配器碎片、库上下文、数据长度抖动和版本差异。
7. **用目标配置验证**：先跑数十个 warmup step，再捕获稳态峰值；只跑第一步会混入初始化与 autotune。

如果超出预算，按瓶颈选择手段：模型状态大，优先 optimizer/gradient/parameter sharding；激活大，先降 micro batch、选择性重计算或 CP；瞬时 AllGather 大，调 wrap 粒度和并发预取；碎片高，稳定 shape、使用连续 buffer 或调整分配策略；不能把所有开关同时打开后再猜是谁生效。

## 一个十三亿参数训练的显存估算案例

假设训练一个十三亿参数的稠密模型，采用 BF16 计算、FP32 主权重和 AdamW。先只计算模型状态：BF16 权重约二点六 GB，BF16 梯度约二点六 GB，FP32 主权重约五点二 GB，两个 FP32 动量合计约十点四 GB，总下界约二十点八 GB。这里的 GB 是十进制估算，监控工具若以 GiB 显示会有差异；此外尚未包含激活、临时张量和分配器缓存。

若改用八路数据并行，普通 DDP 每张卡仍保留全部二十点八 GB 状态。ZeRO Stage 1 只把主权重及两个 Adam 状态按八路切分，若实现把这十二字节每参数都归入优化器侧，则单卡模型状态可粗估为 BF16 权重二点六 GB、梯度二点六 GB，加上分片后的优化器相关状态约二点六 GB，合计约七点八 GB。Stage 2 再切梯度，可把梯度常驻部分从二点六 GB 降到约零点三二五 GB；Stage 3 连参数也切分，静态模型状态可进一步接近二十点八除以八，即约二点六 GB。

这些数字不能直接作为购卡结论。Stage 3 在当前模块计算前会 AllGather 参数，峰值还要加至少一个被物化模块、预取模块和通信 bucket；混合精度实现也可能采用 FP32 梯度或不同主权重布局。真正的预算表应同时写“静态分片值”和“峰值物化值”。假设实测每卡保存激活九 GB，当前层和预取层参数合计一点五 GB，算子 workspace 与通信缓冲三 GB，框架及安全余量四 GB，那么即使静态状态只有二点六 GB，总预算仍约二十点一 GB。

接下来做灵敏度分析。把微批次从一加到二，如果激活近似线性增长，九 GB 可能变成十八 GB，而参数状态不变；把序列长度翻倍，普通激活近似翻倍，未使用内存优化注意力时部分中间量甚至增长更快；把重计算打开，激活下降但步时上升。容量实验因此至少要扫描微批次、序列长度和重计算三维，并在每个点记录有效 token 吞吐。只报告“最大能跑 batch”会掩盖该点可能因重计算或通信而极慢。

## 从首个异常张量定位数值故障

数值故障排查的核心是找到**第一次**出现异常的位置。先把一个训练 step 分成前向、缩放后反向、反缩放与裁剪、优化器更新四段，在段边界记录 loss 是否有限、梯度最大值与范数、scaler 值、参数更新前后范围。若最终参数出现 NaN，但反向梯度仍有限，问题更可能位于 optimizer、权重衰减或状态；若 loss 在前向已经非有限，调整 GradScaler 没有意义。

前向异常应从最后一个有限模块向后缩小。若 Softmax 前 attention score 已是 Inf，检查 QK 尺度、mask 和低精度乘积；若 score 有限而 Softmax 输出异常，检查是否出现整行全部被 mask、减最大值和归约精度；若归一化后异常，检查输入范围、方差计算和 epsilon。可以暂时让单个可疑模块在 FP32 执行做定位，但不应把“全模型切回 FP32 后正常”当作根因，因为它只说明故障与精度路径相关。

反向异常要区分下溢、上溢和真实梯度爆炸。大量梯度精确为零、提高 loss scale 后恢复，符合 FP16 下溢；GradScaler 连续回退且最早异常集中于某层，可能是上溢；FP32 基线同样出现快速增大的梯度范数，则更像学习率、数据或模型结构问题。梯度裁剪能阻止一次巨大更新，却会掩盖异常来源，所以调试时应同时保存裁剪前范数和触发比例。

恢复训练后才出现异常，优先比较 checkpoint 前后五类状态：模型参数、优化器一二阶矩、学习率调度步数、AMP scaler、随机数状态。若只恢复了权重而未恢复 Adam 状态，第一步更新幅度会改变；若 scaler 回到很大的初始值，可能连续发生溢出跳步；若数据游标或随机数状态改变，loss 的小幅跳变未必是数值错误。验收应在保存前记录下一批输入标识，并让恢复作业从同一批次继续，才能把恢复完整性与数据差异分开。

最后建立最小复现矩阵：相同 batch 分别运行 FP32 单卡、低精度单卡、低精度分布式三组。第一组失败说明问题不属于混合精度或集合通信；只有第二组失败说明重点检查 autocast 和 loss scaling；前两组正常而第三组失败，则检查归约 dtype、分片生命周期、不同 rank 数据以及自定义通信算子。这个分层对照比反复试学习率更快，也能避免把分布式配置错误误判成模型不稳定。

## 稳定性验收清单

- 在 FP32 小规模基线上记录 loss、梯度范数、关键激活范围和任务指标。
- 切换 BF16/FP16 后逐项确认 autocast 区域、敏感算子 dtype、累加 dtype 与 optimizer state dtype。
- FP16 记录动态 scaler 曲线、Inf/NaN 检测和跳过更新次数；持续回退意味着问题未解决。
- 对比开启/关闭重计算的 loss 与梯度，覆盖 Dropout 和其他随机算子。
- 逐步扩大 DP/TP/PP，使用容限比较而非逐位比较，并观察差异是否随 step 系统性放大。
- 至少做一次完整 save/resume，验证 loss 连续、学习率与 optimizer step 连续、scaler 和 RNG 状态被恢复。
- 报告有效 token 吞吐、峰值 allocated/reserved、重计算比例和达到目标质量的总成本，而不只报告单步速度。

显存与数值从来不是两个独立议题。低精度减少字节也改变动态范围，重计算减少驻留也改变执行顺序，分片减少副本也改变归约顺序与 checkpoint 形式。最稳妥的方法不是寻找一个“最佳开关”，而是保留账本、边界和对照实验，让每次节省都能解释、每次数值偏差都能定位。

## 来源

- [PyTorch：Automatic Mixed Precision](https://docs.pytorch.org/docs/stable/amp.html)
- [PyTorch：Activation Checkpointing](https://docs.pytorch.org/docs/stable/checkpoint)
- [PyTorch：Numerical Accuracy](https://docs.pytorch.org/docs/stable/notes/numerical_accuracy.html)
- [PyTorch：FullyShardedDataParallel](https://docs.pytorch.org/docs/stable/fsdp.html)
- [Micikevicius et al.：Mixed Precision Training](https://arxiv.org/abs/1710.03740)
- [Chen et al.：Training Deep Nets with Sublinear Memory Cost](https://arxiv.org/abs/1604.06174)
- [Rajbhandari et al.：ZeRO](https://arxiv.org/abs/1910.02054)
- [DeepSpeed：Zero Redundancy Optimizer Tutorial](https://www.deepspeed.ai/tutorials/zero/)
- [DeepSpeed：Training Overview and Features](https://www.deepspeed.ai/training/)
- [NVIDIA：Training With Mixed Precision](https://docs.nvidia.com/deeplearning/performance/mixed-precision-training/index.html)
