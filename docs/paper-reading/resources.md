---
title: 工程资料与延伸阅读
description: 训练部署、Agent 工程、长上下文、并行、集合通信、张量与 Kernel 实践。
pageClass: paper-reading-page
---

# 工程资料与延伸阅读

<SummaryHero
  :goals="['理解研究问题', '掌握关键机制与公式', '形成可验证的工程判断']"
  duration="约 30 分钟"
  output="可继续验证的工程资料索引"
>

本页由“论文速读”原始笔记按主题重组。每项资料直接汇集用途、结论、工程价值、限制、原文链接和图片，便于连续阅读与后续核验。

</SummaryHero>

<ResearchWorkbench preset="resources" />

<PaperPageNavigator />

## 训练、Agent 与智驾

### 1. 训练实践与平台部署 {#training-deployment}

- **用途 / 问题**：作为模型训练到平台部署的实践入口，帮助串联训练工程与上线环境。
- **关键结论**：现有笔记只记录资料链接，没有摘录具体方案或结果，暂不能判断其技术栈、部署拓扑和推荐实践。
- **工程价值**：适合作为搭建训练—制品—部署—观测闭环时的补充清单来源。
- **限制 / 核验动作**：阅读原文后补齐适用平台、依赖版本、资源规模、发布步骤、回滚与监控要求；所有命令需在隔离环境复现后再采用。

[资料：训练实践与平台部署](https://li.feishu.cn/wiki/Ve6ZwPAL5i9etNk2aIEcgBEVngd)

### 2. Agent 在商业分析场景下的工程化落地 {#agent-business-analysis}

- **用途 / 问题**：讨论商业分析 Agent 如何从能力演示走向可评估、可定位、可迭代的工程系统。
- **关键结论**：原笔记保留两点：其一，评估体系仍然依靠 LLM；其二，Multi-Agent 最重要的工程能力是通过 **trace 定位问题并快速解决**。
- **工程价值**：建设时应把 Judge 评估和全链路 trace 作为基础设施：前者支持规模化回归，后者把失败定位到规划、路由、工具调用或协作步骤。
- **限制 / 核验动作**：LLM 评估不能替代人工金标，trace 完整也不自动等于可诊断。需建立人工校准集、Judge 一致性测试、统一 trace schema、步骤级输入输出与耗时记录，并用真实失败案例验证平均定位和修复时间是否下降。

[资料：Agent 在商业分析场景下的工程化落地指南与演进思考](https://li.feishu.cn/wiki/Um9gwJFaniAhRTkwCWxcK522nKg)

### 3. The Magic of Tesla FSD, Part 6（纯视觉） {#tesla-fsd-vision}

- **用途 / 问题**：作为 Tesla 纯视觉自动驾驶路线的延伸阅读，理解视觉输入如何支撑感知与驾驶决策。
- **关键结论**：现有笔记未摘录文章论点、实验或架构信息，不能据此断言纯视觉路线的能力边界。
- **工程价值**：可用于对照纯视觉方案与多传感器方案在数据闭环、模型设计和部署约束上的取舍。
- **限制 / 核验动作**：核对原文发布时间、所指 FSD 版本、数据来源和是否包含可复现实验；将作者观点、公开事实和推测分开记录。

[资料：第 6 篇 *The Magic of Tesla FSD, Part 6*（纯视觉）](https://li.feishu.cn/docx/I73JdFoyZoduX2xpTm8cPnLonFc)

### 4. Tesla 智驾负责人 Ashok Elluswamy ICCV 演讲逐字稿 {#tesla-iccv-talk}

- **用途 / 问题**：从负责人公开演讲了解 Tesla 智驾系统、数据和训练路线的第一方表述。
- **关键结论**：现有笔记仅保存“2025 年 10 月中文逐字稿”链接，没有转录演讲结论。
- **工程价值**：可与第 3 项交叉阅读，用于建立 Tesla 路线的时间线和术语表，并区分公开架构描述与二手解读。
- **限制 / 核验动作**：中文逐字稿可能存在翻译或转录误差，应对照 ICCV 官方视频/材料核验关键术语、数字和上下文，并确认时间标注与会议场次。

[资料：Tesla 智驾负责人 Ashok Elluswamy ICCV 演讲中文逐字稿（2025 年 10 月）](https://li.feishu.cn/docx/MMkcd6gM1ordRcxVFHgc6w1dn9c)

### 5. DEPO 轨迹训练 {#depo-trajectory-training}

- **用途 / 问题**：探索利用轨迹数据训练或优化决策策略的方案。
- **关键结论**：原笔记留下“效果来看没用”的主观观察，但没有任务、基线、指标、数据规模和实验数字，因此不能视为普遍结论。
- **工程价值**：可作为负向候选方案保留，提醒在投入大规模轨迹采集或训练前先做小规模可证伪实验。
- **限制 / 核验动作**：回到项目页和论文明确算法目标及适用任务；复核该判断来自公开实验还是内部复现，并在相同数据、预算与基线下比较成功率、样本效率和训练成本。

[项目：DEPO](https://opencausalab.github.io/DEPO/)

### 6. Causal Sufficiency and Necessity：精简 CoT 数据 {#causal-cot-pruning}

- **用途 / 问题**：研究如何用因果充分性与必要性筛选或压缩思维链，减少冗余推理数据，同时保留真正支持答案的步骤。
- **关键结论**：现有笔记仅以“数据 CoT 精简”概括资料，没有摘录方法、压缩率或效果数值。
- **工程价值**：可用于构建更短、更聚焦的 SFT/蒸馏轨迹，潜在降低训练 token、推理长度和无效推理模式的学习。
- **限制 / 核验动作**：需核对“充分/必要”的操作化定义、删减算法、是否依赖外部 Judge，以及精简后准确率、鲁棒性和迁移能力；在自有任务上同时测 token 降幅与质量变化。

[资料：*Causal Sufficiency and Necessity Improves Chain-of-Thought Reasoning*](https://li.feishu.cn/wiki/Gy6zwNaPaiCkpnkY8TJcqd1Tnfb)

### 7. Agent-as-a-Judge：智能体评测 {#agent-as-judge}

- **用途 / 问题**：用具备规划和工具使用能力的 Agent 评估另一个 Agent 的完整过程，而不只比较最终文本答案。
- **关键结论**：原笔记明确记录的一个评测维度是**工具调用冗余**：即使任务完成，也应检查是否存在重复、无效或可以合并的调用。
- **工程价值**：可把评测对象扩展为结果质量、调用正确性、步骤效率和成本；工具冗余率、无效调用数、关键工具覆盖率可成为 trace 级指标。
- **限制 / 核验动作**：Judge Agent 自身也可能误用工具或偏好更短但不可靠的路径。应以人工标注轨迹校准，区分必要的验证/重试与真正冗余，并核对评测协议、预算公平性和 Judge 稳定性。

[资料：智能体评测论文调研分享](https://li.feishu.cn/docx/JgwMdIWoaoJJgFxrnuIcpLhTnvg)

## 推理与并行系统

### 8. 超长上下文 {#long-context}

- **用途 / 问题**：理解模型标称上下文长度与真实可用上下文能力的差异。
- **关键结论**：现有笔记只保留 context-length 文章链接，没有转录其测量方法或结论。
- **工程价值**：可用于设计长文档、代码仓库和长期 Agent 记忆场景的模型选型测试，避免只依据厂商标称窗口。
- **限制 / 核验动作**：核对文章测试模型和版本、needle 深度、输入类型、并发与成本；本地评测需同时测召回准确率、位置偏差、长上下文延迟、显存/KV Cache 占用和单位任务成本。

[资料：Context Length](https://datanorth.ai/blog/context-length)

### 9. vLLM MoE 并行化指南 {#vllm-moe-parallelism}

- **用途 / 问题**：解决 MLA/MQA 与 MoE 推理在多 GPU 上的 KV Cache、注意力和专家分布问题。
- **关键结论**：TP 能沿注意力头切分 QKV 计算，却不能沿仅有一个 head 的 MLA/MQA KV Cache 切分，导致缓存被每个 TP rank 完整复制；DP Attention 改为在单个模型副本内按请求/token 分区逻辑 batch，并通过 AllToAll 通信。启用 EP 后，专家分布同时受 TP 和 DP 规模影响。
- **工程价值**：为 vLLM MoE 部署选择 TP、DP、EP 组合提供依据，可在控制 TP 组内集合通信的同时减少 MLA/MQA KV Cache 复制。
- **限制 / 核验动作**：理想分片比例不代表端到端最优，性能还受请求长度分布、负载均衡、AllToAll 拓扑、共享专家、显存碎片和 vLLM/ROCm 版本影响。原摘录中“单个逻辑 batch 分区”与“各 DP group 处理不同请求”的层级表述也需回到原文核对。

[资料：vLLM MoE 并行化指南](https://rocm.blogs.amd.com/software-tools-optimization/vllm-moe-guide/README.html)

#### TP、DP Attention 与专家分布摘录

> **The Problem with TP for MLA/MQA**:
> TP 用于 MLA/MQA 的问题：
>
> - MLA and MQA use a single KV head in the KV\-cache
> MLA 和 MQA 在 KV 缓存中使用单个 KV 头
>
> - With Tensor Parallelism, you can shard QKV along attention heads
> 使用张量并行，你可以将 QKV 沿注意力头进行分片
>
> - But you **cannot shard KV cache along the head dimension** (there is only one head)
> 但你不能沿着头维度分片 KV 缓存（只有一个头）
>
> - Result: **Full KV cache must be duplicated on all TP ranks**
> 结果：全 KV 缓存必须在所有 TP 排名上复制
>
> **Example**: With TP=32 for attention layers:
> 示例：对于注意力层 TP=32：
>
> - Linear computation per GPU: 1/32 attention heads ✓
> 每 GPU 的线性计算：1/32 个注意力头 ✓
>
> - KV cache per GPU: **Full KV cache** (duplicated 32×) ✗
> 每 GPU 的 KV 缓存：全 KV 缓存（复制 32×） ✗
>
> - This wastes massive amounts of memory
> 这浪费了大量内存
>
> **DP Attention Solution**: Instead of replicating full models independently, DP Attention operates **within a single model replica** and partitions the KV cache by requests/tokens [[4]](https://rocm.blogs.amd.com/software-tools-optimization/vllm-moe-guide/README.html#references):
> DP 注意力解决方案：DP 注意力在单个模型副本内运行，并通过请求/token 对 KV 缓存进行分区 [4]：
>
> - Each GPU holds full non-MoE layers (attention, dense)
> 每个 GPU 持有完整的非 MoE 层（注意力、密集层）
>
> - **Single logical batch** is partitioned across GPUs
> 单个逻辑批次在 GPU 之间进行分区
>
> - KV cache is **partitioned** across GPUs by request/token (each GPU holds $1/\text{DP\_SIZE}$ of the batch's KV cache)
> KV 缓存通过请求/token 在 GPU 之间分区（每个 GPU 持有该 batch KV Cache 的 $1/\text{DP\_SIZE}$）。
>
> - Communication happens during inference via AllToAll (unlike traditional DP with independent batches)
> 推理过程中通过 AllToAll 进行通信（不同于传统的 DP，其批次独立）
>
> - **Contrast with traditional DP**: Each GPU processes its own separate batch with its own full KV cache (no partitioning, no inter-GPU communication)
> 与传统 DP 对比：每个 GPU 处理自己的独立批次，并拥有完整的 KV 缓存（无分区，无 GPU 间通信）
>
> **Example**: With TP=4 and DP=8 for attention layers (32 GPUs total):
> 示例：对于注意力层，设置 TP=4 和 DP=8（总共 32 个 GPU）：
>
> - 8 independent DP groups, each containing 4 GPUs in a TP group
> 8 个独立的 DP 组，每个 TP 组包含 4 个 GPU
>
> - Non-MoE computation per GPU: 1/4 of attention heads (TP-sharded across 4 GPUs)
> 每张 GPU 的非 MoE 计算：1/4 的注意力头（跨 4 张 GPU 进行 TP 分片）
>
> - KV cache per GPU: ideally 1/8 of the total batch requests (partitioned by DP rank)
> 每张 GPU 的 KV 缓存：理想情况下为总 batch 请求的 1/8（按 DP rank 分区）
>
> - AllReduce overhead: Only within 4-GPU TP groups (not across all 32)
> AllReduce 开销：仅在 4\-GPU TP 组内部（不跨越所有 32 张 GPU）
>
> - Each DP group processes different requests independently
> 每个 DP 组独立处理不同的请求
>
>

> **Expert Distribution Formula (for Routed Experts)**:
> 专家分配公式（用于路由专家）：
>
> $$
> \text{EP\_SIZE} = \text{TP\_SIZE} \times \text{DP\_SIZE}
> $$
> $$
> N_{\text{routed/GPU}} = \frac{N_{\text{routed}}}{\text{EP\_SIZE}}
> $$
>
> **Example: DeepSeek-R1 (256 routed experts + 1 shared expert)**:
> 示例：DeepSeek-R1（256 个路由专家 + 1 个共享专家）：
>
> **Key Insight**: For the same number of GPUs (8 GPUs in this case), `TP=8` and `DP=8` give the same routed expert distribution (32 experts/GPU) when EP is enabled.
> 关键洞察：在启用专家并行（EP）的情况下，对于相同数量的 GPU（本例中为 8 个 GPU）， `TP=8` 和 `DP=8` 会给出相同的路由专家分布（每个 GPU 分配 32 个专家）。
>
>

<ZoomableImage src="/paper-reading/assets/截屏2026-01-20%2016.07.21.png" alt="截屏2026-01-20 16.07.21.png" />

<ZoomableImage src="/paper-reading/assets/截屏2026-01-20%2016.08.48.png" alt="截屏2026-01-20 16.08.48.png" />

### 10. NCCL AllToAll 与 AllReduce {#nccl-collectives}

- **用途 / 问题**：理解分布式推理/训练中的两类基础集合通信：AllToAll 用于各 rank 间交换不同分片，AllReduce 用于聚合并把规约结果返回所有 rank。
- **关键结论**：本项资料与第 9 项的 DP Attention/EP 通信和 TP 组内聚合直接相关，但笔记没有记录特定算法、性能数字或配置建议。
- **工程价值**：可用于检查并行方案中通信语义是否匹配，并通过通信量、消息大小和拓扑判断瓶颈属于计算还是集合通信。
- **限制 / 核验动作**：按实际 NCCL 版本核对 API、数据类型、原地操作和异步语义；用目标节点拓扑做基准测试，记录带宽、延迟、组规模及与计算重叠后的端到端收益。

[NCCL 官方文档：Collective Operations](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/usage/collectives.html)

### 11. Pre-Norm 与 Post-Norm {#pre-norm-post-norm}

- **用途 / 问题**：比较 LayerNorm 位于子层前后时，残差路径、训练稳定性与特征校准方式的差异。
- **关键结论**：Post-Norm 先融合子层输出和残差，再归一化；Pre-Norm 先归一化子层输入，再把子层输出加回未经归一化的残差主路。
- **工程价值**：阅读或修改 Transformer 实现时可据此快速确认归一化位置，分析深层网络梯度路径、训练稳定性和 checkpoint 兼容性。
- **限制 / 核验动作**：不能仅凭“现代主流”判断某模型优劣；还要核对最终层归一化、RMSNorm/LayerNorm 类型、残差缩放和初始化，并以相同预算比较收敛、梯度范数、最终质量和深度扩展表现。

#### Post-Norm

原始 Transformer 采用“子层计算 → 残差连接 → LayerNorm”：

$$
x' = \operatorname{Norm}\!\left(x + F(x)\right).
$$

可理解为“先加工再修正”：特征经子层与残差融合后，再归一化校准分布。

#### Pre-Norm

现代常见形式采用“LayerNorm → 子层计算 → 残差连接”：

$$
x' = x + F\!\left(\operatorname{Norm}(x)\right).
$$

可理解为“先校准再加工”：先归一化输入，子层计算后与原始输入融合。

<ZoomableImage src="/paper-reading/assets/image%2024.png" alt="image.png" />





## 张量、算子与沙箱

### 12. einsum / einops 基础 {#einsum-einops}

- **用途 / 问题**：用维度语义清晰地表达张量重排、归约与乘法，减少手写 `reshape`、`transpose` 和索引造成的维度错误。
- **关键结论**：现有笔记标题写作 einsum，但链接指向 einops basics；二者相关但并不等价，尚未记录具体示例结论。
- **工程价值**：适合为注意力、批处理和多头张量操作建立可读的 shape 变换说明，并配合 shape 测试降低静默错位风险。
- **限制 / 核验动作**：先确认实际要学习的是 Einstein 求和 `einsum`，还是 einops 的 `rearrange`、`reduce`、`repeat`；对关键表达式核对输入输出 shape、广播和归约维，并用 profiler 比较性能。

[资料：Einops Basics](https://einops.rocks/1-einops-basics/)

### 13. strides、view 与张量内存语义 {#tensor-strides}

- **用途 / 问题**：理解张量的 shape、stride、连续性和底层 storage 关系，避免 reshape、广播或复制操作产生错误别名与隐性内存开销。
- **关键结论**：原笔记记录“`view`、连续数组上的 `reshape`、`expand` 会共享内存，而 `clone()`、`contiguous()`、`detach()` 会创建独立副本”。其中前半句只在特定布局下成立，后半句中的 `contiguous()` 与 `detach()` 也不是无条件复制，必须修正性理解。
- **工程价值**：这组概念直接影响高性能算子的输入布局、原地修改安全性、显存峰值与 autograd 行为，适合配合第 14 项的 Kernel 优化一起学习。
- **限制 / 核验动作**：`reshape` 必要时可能复制；`contiguous()` 在输入已连续时可能返回自身；`detach()` 通常共享 storage，只切断梯度关系。应通过 `data_ptr()`、stride、`is_contiguous()`、原地修改和反向传播小实验验证当前框架版本；真正需要独立副本并切断梯度时应核验 `detach().clone()`。

[资料：strides 与张量内存](https://www.doubao.com/thread/w9d925f032aed31c6)

### 14. Kernel 算子高效计算 {#kernel-optimization}

- **用途 / 问题**：以 Pallas/TPU 矩阵乘 Kernel 为入口，理解如何通过分块、内存层级与并行映射提高算子效率。
- **关键结论**：现有笔记只有一条 Pallas TPU MatMul 链接，没有摘录 tile 设计、数据搬运、数值精度或性能结果。
- **工程价值**：可用于从算子视角分析 MatMul 的算术强度、片上缓存复用和布局约束，并将高层模型瓶颈映射到具体 Kernel。
- **限制 / 核验动作**：核对目标是 TPU/Pallas 还是 GPU/Triton/CUDA，避免直接迁移硬件特定结论；用正确性对照、不同 shape/dtype、编译时间、吞吐和端到端占比验证优化，不能只看单一 microbenchmark。

[资料：使用 Pallas 编写高效的 TPU MatMul Kernel](https://sqtian.com/zh/post/pallas_tpu_matmul_kernel/#:~:text=%E7%9F%A9%E9%98%B5%E4%B9%98%E6%B3%95%EF%BC%88MatMul%EF%BC%89%E6%98%AF%E6%9C%BA%E5%99%A8,%E7%9A%84%E3%80%81%E9%AB%98%E5%BA%A6%E4%BC%98%E5%8C%96%E7%9A%84Kernel%E3%80%82)

### 15. 在 Vagrant 沙箱中运行 Claude Code {#vagrant-claude-code}

- **用途 / 问题**：通过 Vagrant 虚拟机隔离 Claude Code 的执行环境，降低 Agent 操作宿主机文件、凭据和网络资源的风险。
- **关键结论**：现有笔记只保存资料链接与一张截图，没有转录沙箱配置、权限边界或运行结果。
- **工程价值**：可作为本地 Agent 隔离方案的实践参考，重点评估可复现环境、目录映射、网络限制和销毁重建能力。
- **限制 / 核验动作**：Vagrant 只提供虚拟化载体，安全性仍取决于共享目录、端口转发、凭据注入、镜像来源和 hypervisor 配置。复现时应检查最小权限、快照/销毁流程、出入站网络、secret 生命周期，以及宿主机是否存在意外可写挂载。

[资料：20260113—在 Vagrant 沙箱中运行 Claude Code](https://li.feishu.cn/docx/CPxId4ZfxohYMoxdbSLcaiQcnWb)

<ZoomableImage src="/paper-reading/assets/截屏2026-01-23%2009.21.24.png" alt="截屏2026-01-23 09.21.24.png" />
