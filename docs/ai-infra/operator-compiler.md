---
title: 算子与编译器：从张量到硬件执行
description: CUDA、Triton、图编译、融合与分块方法，以 FlashAttention 和 Profiling 贯穿验证。
---

# 算子与编译器：从张量到硬件

框架里的一个表达式，落到 GPU 上可能是一次库调用，也可能变成多个 kernel、临时张量和同步点。算子工程的目标不是手写更多 CUDA，而是找到正确执行边界：复用成熟库、为编译器保留图信息，只为现有路径无法覆盖的真实热点投入专用 kernel。

<SummaryHero
  :goals="['理解张量程序如何落到 GPU', '用分块与融合减少真实成本', '建立可复现的 Profiling 闭环']"
  duration="约 40 分钟"
  output="一套从瓶颈到生产验收的算子方法"
>

CUDA、Triton 和编译器不构成优劣榜。CUDA 暴露线程与内存层次，Triton 描述 block 级张量程序，图编译器则在更大范围捕获、变换并生成后端代码。

</SummaryHero>

## 第一条原则：优化执行，而不是优化源码观感

开始前先固定 reference、真实 shape、dtype、布局、硬件与计时方式。算子成本可能来自计算、HBM 搬运、launch、同步、布局转换或编译冷启动。只有 profile 后，才能判断融合、换精度或专用 shape 是否对应当前瓶颈。

成熟 GEMM、卷积和通信应优先调用现有库。自定义算子适合轻量 op 产生大量中间读写、特殊结构无法映射到通用库，或固定 shape 允许更强假设的情况。单 kernel 提速后仍要回到端到端验证，排除 graph break、布局转换和反向退化。

<CapacityLab preset="roofline" />

Widget 用算术强度、峰值带宽和峰值计算构造 Roofline 直觉。点落在斜线区域通常更受数据供给限制，接近水平顶线则更受计算吞吐限制；但它只是起点，缓存命中、指令结构、依赖延迟、占用率和 launch 开销仍需 profiler 证据。

## CUDA 执行模型：层次映射决定性能上限

CUDA 以 grid 启动 thread block，block 被调度到 Streaming Multiprocessor，线程以 warp 为执行和发射的重要粒度。block 之间通常不能依赖执行顺序，因此全局问题必须被切成可独立调度的 tile，或拆成多个 kernel。一个 block 内可用 shared memory 和同步原语协作，线程私有的中间值主要放在寄存器中。

寄存器快但总量有限，使用过多会降低同驻 block 数；shared memory 便于显式复用，也可能出现 bank conflict；HBM 容量大，但数据移动成本更高。[CUDA C++ Best Practices Guide](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html) 把 global memory 合并访问列为高优先级优化：warp 内相邻线程访问连续且对齐的数据，可用更少事务服务请求。

因此布局和线程映射必须一起设计。若每个线程逻辑上处理连续行，但物理地址跨越大步长，一个 warp 会发出分散事务；把线程维映射到内存连续维，往往比增加线程数更有效。二维张量还要处理 leading dimension、padding、非连续 stride 和对齐。生产 kernel 不能假设调用方永远给出 contiguous，除非接口显式检查并提供回退。

占用率不是目标函数。更多活跃 warp 有助于隐藏延迟，但为追求高 occupancy 而缩小 tile，可能降低复用和 Tensor Core 利用。最终仍应检查吞吐和尾延迟是否改善。

## 分块：把大问题映射到内存和并行层次

以矩阵乘 `C = A × B` 为例，直接让每个线程从 HBM 反复读取需要的 A、B 元素，会产生巨大冗余。分块算法让一个 thread block 负责输出矩阵的一个 tile，把 A、B 子块加载到片上存储并复用，再在寄存器中累加局部结果。tile 越大，理论复用越高，但 shared memory 与寄存器压力也越大，可并发 block 数下降，并且边界浪费增加。

高性能 GEMM 往往有多级 tile，并用多 stage 流水重叠数据搬运与计算。[CUTLASS 的 Efficient GEMM 文档](https://github.com/NVIDIA/cutlass/blob/main/media/docs/cpp/efficient_gemm.md) 展示了与 CUDA 并行和内存层次对应的嵌套分块，以及 epilogue 如何把缩放、偏置或激活接到写回之前。

分块不只属于 GEMM。reduction 要决定一个输出由多少线程协作、局部结果放在哪里；softmax 要把最大值和指数和的归约合并，并保证数值稳定；attention 要沿序列块推进并维护在线统计量。每种算法都在回答同一个问题：哪些值值得留在片上复用，哪些工作能独立并行，边界与动态 shape 如何遮罩。

## 融合：少一次往返可能比少一次乘法更重要

假设 eager softmax 依次执行取最大值、减法、指数、求和和除法，每一步都可能生成中间张量并往返 HBM。若一行能装入片上存储，融合 kernel 可以读取一次输入、在片上完成归约和归一化、写回一次输出。[Triton Fused Softmax 教程](https://triton-lang.org/main/getting-started/tutorials/02-fused-softmax.html) 用具体读写量说明了融合对带宽受限操作的价值。

适合融合的常见模式包括 pointwise 链、bias 加激活、归一化前后处理、优化器更新与 GEMM epilogue。融合的收益来自减少中间张量、launch 和同步，而不是把源代码拼成一个大函数。过度融合会让 live value 增多、寄存器溢出、shared memory 上升、occupancy 下降，还可能让一个长 kernel 无法与其他流并发。含有复杂 reduction、不同最优 tile 或跨设备通信的边界，常常应该保留为多个阶段。

编译器遇到无法证明的别名、数据依赖控制流或自定义 op 元信息缺失时，图可能被切断。判断融合是否发生，应查看生成代码和 kernel trace，而不是依赖 API 名称。

## Triton：描述 block 级程序，让编译器完成线程细节

Triton kernel 通常以 program instance 为单位。开发者用 `program_id` 选择工作块，构造一组 block pointer 或 offset，以 mask 保护边界，使用 `tl.load`、张量运算、归约和 `tl.store` 描述块内计算。编译器再把 blocked program 降低到 GPU 线程和指令。它降低了索引、协作与 Tensor Core 使用的门槛，但没有消除硬件约束。

写 Triton 时仍要选择 block、warp、stage、布局和分组顺序。非整除边界要 mask，padding 可能浪费计算，动态 shape 需要多组配置或 fallback。autotune 能搜索候选配置，却会增加首次运行成本，也可能在非生产 shape 上选错方案。

Triton 适合规则的块级并行与定制融合；需要细粒度异步拷贝、特定 warpgroup 或新架构指令时，CUDA/CUTLASS 控制更强；简单 pointwise 链则应先交给图编译器。抽象层越低，维护成本越高。

## 图编译器：更大的优化窗口，也意味着更多边界条件

以 PyTorch 2 为例，[`torch.compile` 官方文档](https://docs.pytorch.org/docs/stable/user_guide/torch_compiler/torch.compiler_get_started.html) 描述的主链路包括图捕获与 TorchInductor 代码生成，后者可为 GPU 生成 Triton kernel，并将 fusion 作为重要优化。图层能看到多个算子之间的依赖，因此可以做常量传播、死代码消除、布局选择、融合和内存规划，而单个自定义 kernel 看不到这些上下文。

编译器用 guard 约束 dtype、device、shape 和 Python 状态，条件变化可能触发重编译，副作用或不支持的 op 可能造成 graph break。线上必须统计编译次数、缓存命中、首请求延迟和 fallback。多 shape 可用动态维、bucket 或预编译控制变体，但不能盲目 padding 到极大形状。

自定义算子要提供 shape/dtype 推导、meta 实现、autograd 和别名信息，否则编译器难以做调度与内存规划。生产级 op 不只是 forward kernel，而是一份框架可理解的契约。

## FlashAttention：同一数学公式，不同执行计划

标准注意力计算 `S = QKᵀ`、逐行 softmax 和 `O = PV`，显式物化 N×N 中间量会大量读写 HBM。[FlashAttention](https://arxiv.org/abs/2205.14135) 将 Q、K、V 切成片上可容纳的块，在块内完成局部矩阵乘与 softmax 更新，避免写回完整注意力矩阵。

softmax 依赖整行最大值与归一化和。分块算法维护运行最大值 `m` 和因子 `l`：读入新块后计算局部 score，用指数缩放修正已有累计量，再加入当前贡献，最终得到等价结果。反向传播保存较小统计量并重算部分 score，以额外计算换取更少内存流量。

该案例说明：复杂度分析还要数内存 I/O；融合、分块和重计算需协同；算法等价不代表实现天然正确。causal mask、padding、dropout、head dimension 和低精度都要验证。prefill 与单 token decode 的瓶颈不同，也不会始终由同一 kernel 最优覆盖。

<TradeoffExplorer preset="kernel" />

Widget 将通用性、开发成本、冷启动和峰值性能放在同一决策面上。选择实现层级前，应先固定工作负载和可接受的维护边界。

## 正确性：性能实验前先建立不可妥协的边界

reference 应使用稳定且更高精度的实现。测试覆盖典型与非整除 shape、非连续布局、不同 dtype/device、极值和 NaN/Inf。误差阈值应结合 dtype、规模和累加顺序定义，并检查误差分布与任务指标。

反向算子用 autograd reference 和有限差分抽查，并测试梯度累积和 mixed precision。非确定性需要声明范围，低精度实现则要明确输入、乘法、累加和输出各自精度。

还要检查越界、未初始化读取、竞争和同步。任何 fast path 都应检测不支持条件并安全回退。

## Profiling：从端到端到 kernel，再返回端到端

第一步记录真实请求或训练 step 的端到端基线，包含预热、同步边界、shape 分布、显存和尾延迟。GPU 操作异步，计时需使用正确 event 或同步；冷启动与稳态要分别报告。

第二步用 timeline 定位 kernel、空洞、同步、拷贝和 launch，再对热点使用 Nsight Compute。[官方文档](https://docs.nvidia.com/nsight-compute/) 覆盖 Memory Workload、Occupancy 与 Roofline。profiler 会扰动运行，最终速度仍由低扰动基准确认。

按假设选指标：带宽问题看 DRAM/L2、请求效率与合并访问；计算问题看 Tensor Core/ALU 与指令；延迟问题看 eligible warp、stall、寄存器与 occupancy；启动问题看 kernel 时长和 CPU 间隙。指标低于 100% 不自动等于缺陷。

第三步只改变一个因素，对完整 shape 矩阵重复测试，并报告中位数和高分位。最后回到真实模型，确认没有把成本移到布局转换、其他 kernel 或冷启动。

## 三类瓶颈的诊断剧本

### 带宽受限：先核对搬运量，再讨论算力

一个归一化 kernel 若 Roofline 点位于带宽斜线附近，第一项工作是算清理论最小读写量：输入至少读取一次，输出至少写入一次，额外中间张量和重复加载分别贡献多少字节。随后用 profiler 对比实际 DRAM 字节、L2 命中与请求合并效率。若实际流量远高于理论值，优先检查非连续布局、重复索引、未融合中间结果和写后再读，而不是调整矩阵乘精度。

优化可按风险递增：先修正线程到连续地址的映射，再融合相邻 pointwise 和 reduction，最后才考虑把重复数据放入 shared memory。每一步都核对寄存器、shared memory、occupancy 和完整 shape 集。若流量已接近理论下限且带宽接近可持续峰值，继续改 kernel 的空间很小，更有效的方向可能是减少上层数据类型宽度、改变算法或避免调用该算子。

### 计算受限：确认执行单元在做有效工作

GEMM 看似计算受限，却可能因为维度、对齐或布局没有走 Tensor Core 路径。诊断时先确认生成指令和数学模式，再看矩阵乘管线利用、warp 活跃度与尾块比例。若 K 维很小或 M、N 极不规则，大量 padding 和边界 tile 会让峰值指标失去意义；此时分组多个小问题、选择更合适 tile 或使用专用 persistent kernel，可能比扩大单个 block 更合理。

计算管线利用不高时，还要区分数据依赖、指令供给和资源限制。长依赖链可能需要更多独立 accumulator，指令发射不足可能来自分支或地址计算，寄存器溢出则会把局部值写回 local memory。修改展开和 tile 后必须检查数值顺序，因为更换累加分组会改变低精度误差。若 kernel 已接近计算顶线，声称额外倍数级加速通常意味着基线、精度或工作量并不等价，应先复核比较契约。

### 启动与调度受限：看时间线中的空隙

大量几微秒 kernel 之间存在主机间隙时，单独优化某个 kernel 百分之十往往几乎不改变端到端延迟。应统计每个 step 的 kernel 数、CPU 提交间隔、同步来源和 graph break，确认小算子链能否由图编译器融合，或能否使用 CUDA Graph 降低重复提交成本。若动态 shape 导致持续重编译，还要把编译事件与请求 shape 对齐，不能把等待误判为 GPU 执行慢。

融合之后重新检查长 kernel 的寄存器压力和调度公平性。面向在线推理，一个占用 GPU 很久的巨型 kernel 可能改善平均吞吐，却阻塞其他请求并恶化高分位延迟。验收因此要同时包含单请求、目标并发和混合 shape，不允许只以离线大 batch 的最快结果代表生产收益。

## 正确性与生产验收清单

正确性测试分四层。数学层将 forward、backward 与高精度 reference 比较；形状层覆盖长度为一、非整除 tile、空 batch、最大支持维度和广播；布局层覆盖 contiguous、转置视图、带 offset 的切片与不对齐地址；数值层覆盖零、极值、NaN、Inf 和会触发 softmax 溢出的输入。每个失败用固定种子固化为回归样例，不只保留随机测试。

性能测试也要建立矩阵，而不是单点。横轴包含真实的 batch、序列长度、head dimension 与 dtype，纵轴包含目标 GPU 架构、冷启动、稳态和并发级别。记录中位数、高分位、显存峰值、编译次数和 fallback 比例，并给出允许回退到基线实现的范围。若某些长尾 shape 变慢，可以选择不启用 fast path，但必须由运行时 guard 明确分流。

框架集成验收需要检查 autograd、自动混合精度、模型保存加载、图编译、分布式训练和内存分配器行为。算子不得在调用方未知的情况下执行全设备同步，也不能把临时 buffer 永久留在缓存中。错误输入应在边界处返回可定位信息；不支持的硬件和 dtype 应走已测试的 fallback，而不是编译失败后悄悄重试多次。

灰度发布先按模型、硬件和 shape 小流量启用，持续比较输出差异、错误率、编译缓存、延迟和显存。若数值漂移、fallback 或尾延迟超过预算，开关必须能立即切回稳定实现。只有经过一个完整业务周期、回滚演练和跨版本重建验证后，专用 kernel 才能成为默认路径。验收材料应保存 reference 版本、源码提交、构建环境、profile 报告和所有未覆盖边界，供后续硬件或编译器升级时重跑。

## 从实验 kernel 到生产组件

生产验收有四组门槛：forward/backward、边界和误差通过；真实 shape 端到端收益稳定；框架、架构、dtype 与动态 shape 有兼容矩阵；版本可回滚、fallback 可观测。

发布时记录源码、编译器与 CUDA 版本、目标架构、编译参数和 benchmark。硬件升级后重新 profile。热门 shape 使用已验证的 fast path，长尾 shape 保留可靠通用实现。

最终判断很朴素：如果上层编译器已经生成等价代码，就不要增加自定义维护面；如果专用 kernel 只在合成形状快，就不要宣称模型加速；如果收益依赖未写入契约的布局或精度假设，就还没有完成。真正优秀的算子工程，是把硬件知识、编译边界和模型工作负载变成一组可验证的选择。

## 来源

- [CUDA C++ Programming Guide](https://docs.nvidia.com/cuda/cuda-programming-guide/)
- [CUDA C++ Best Practices Guide](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html)
- [Triton Tutorials](https://triton-lang.org/main/getting-started/tutorials/)
- [Triton Fused Softmax Tutorial](https://triton-lang.org/main/getting-started/tutorials/02-fused-softmax.html)
- [PyTorch `torch.compile` Getting Started](https://docs.pytorch.org/docs/stable/user_guide/torch_compiler/torch.compiler_get_started.html)
- [CUTLASS: Efficient GEMM in CUDA](https://github.com/NVIDIA/cutlass/blob/main/media/docs/cpp/efficient_gemm.md)
- [FlashAttention: Fast and Memory-Efficient Exact Attention with IO-Awareness](https://arxiv.org/abs/2205.14135)
- [NVIDIA Nsight Compute Documentation](https://docs.nvidia.com/nsight-compute/)
