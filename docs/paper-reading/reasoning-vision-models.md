---
title: 推理、视觉与 OCR 模型
description: DeepSeek、Qwen-VL、MiniMax、PaddleOCR、视觉压缩与 Muon 优化方法。
pageClass: paper-reading-page
---

# 推理、视觉与 OCR 模型

<SummaryHero
  :goals="['理解研究问题', '掌握关键机制与公式', '形成可验证的工程判断']"
  duration="约 90 分钟"
  output="推理与视觉模型技术地图"
>

本页由“论文速读”原始笔记按模型与论文条目重组。每个条目直接整合研究问题、核心方法、关键证据、工程意义、限制与疑问，并完整保留对应原文、公式、链接和图片。

</SummaryHero>

<ResearchWorkbench preset="reasoning-vision" />

<PaperPageNavigator />

## DeepSeek-V3.2-Speciale / DeepSeek-V3.2 {#deepseek-v3-2}

### 研究问题

同时处理长上下文注意力成本、超大规模 RL 后训练的稳定性，以及 Agent 在复杂工具环境中的泛化。传统 KL 梯度估计还存在采样策略与目标策略分布不匹配的问题，极端 token 可能获得过大甚至无界的梯度权重。

### 核心方法

架构上使用 DeepSeek Sparse Attention（DSA），以 Lightning Indexer 和细粒度 token 选择减少无效注意力；后训练使用超过预训练成本 10% 的 RL 预算，并引入无偏 KL 估计、Off-Policy 序列掩码等稳定化策略；Agent 数据侧合成大量环境和复杂提示，并训练“在工具使用中思考”。其中无偏 KL 的关键是用 $\pi_\theta/\pi_{\mathrm{old}}$ 重要性采样比，将旧策略样本校正到当前策略分布下。

### 关键证据

原始笔记记录了超过 **1,800 个环境**、**85,000 个复杂 Prompt**，以及 RL 后训练计算预算超过预训练成本的 **10%**；理论分析说明重要性权重会压低“当前策略已经几乎不会生成”的 token 对 KL 梯度的贡献。笔记未给出 DSA 的具体复杂度、消融实验或最终基准提升值。

### 工程意义

可将其拆成三条可复用链路：稀疏注意力控制长上下文成本；按真实行为策略做 KL 校正以稳定 off-policy RL；通过“环境生成—任务生成—工具轨迹生成”扩展 Agent 训练数据。尤其适合需要频繁更新策略、复用旧轨迹的训练系统。

### 限制与疑问

重要性采样本身仍可能有高方差，笔记没有说明比率裁剪、归一化或有效样本量控制；DSA 的召回损失和硬件加速收益缺少数据；`Speciale` 与标准版 V3.2 的差异、Sequence Masking 的精确定义也未展开。

1. **架构层面**：引入了 **DeepSeek Sparse Attention （DSA）** 。通过“闪电索引器”（Lightning Indexer）和细粒度 Token 选择机制，将长上下文下的注意力计算复杂度降低，同时保持了模型性能。

2. **后训练层面**：构建了可扩展的强化学习（RL）框架。后训练阶段的计算预算超过了预训练成本的 10%。为保证训练稳定性，提出了无偏 KL 估计（Unbiased KL Estimate）、Off\-Policy 序列掩码（Sequence Masking）等改进策略。

3. **Agent 层面**：开发了大规模 Agent 任务合成流水线。通过生成超过 1800 个不同环境和 85,000 个复杂 Prompt，结合“在工具使用中思考”（Thinking in Tool\-Use）的策略，提升了模型在复杂交互环境中的泛化能力。

> 这里主要是在讲「KL 正则项的梯度怎么估」，以及 DeepSeek 为什么要改传统的 K3 估计器。
>
> ### 三个策略分别是谁？
>
> - $\pi_\theta$：当前要更新的策略（current policy）。
>
> - $\pi_{\mathrm{old}}$：用来采样数据的旧策略（behavior policy），比如 PPO 里上一次迭代的策略。
>
> - $\pi_{\mathrm{ref}}$：参考策略（reference policy），一般是 SFT 模型，用来做 KL 惩罚的那个。
>
> KL 项通常是：
>
> $$
> D_{\mathrm{KL}}\!\left(\pi_\theta \parallel \pi_{\mathrm{ref}}\right)
> $$
>
> 但我们手里真正有的采样，是从 $\pi_{\mathrm{old}}$（甚至是 $\pi_{\mathrm{ref}}$）生成的 token 序列。
>
> ---
>
> ### 传统 K3 估计器的问题
>
> Schulman 2020 里的 K3，是一种估计 **KL 项梯度** 的 estimator：在只有「参考策略采样的 token」的情况下，近似
> $$
> \nabla_\theta D_{\mathrm{KL}}\!\left(\pi_\theta \parallel \pi_{\mathrm{ref}}\right)
> $$
>
> 问题在于：
>
> - KL 的期望是对 $\pi_\theta$ 的分布求的：
> $$
> D_{\mathrm{KL}}\!\left(\pi_\theta \parallel \pi_{\mathrm{ref}}\right)
> = \mathbb{E}_{o \sim \pi_\theta}\!\left[\log \frac{\pi_\theta(o)}{\pi_{\mathrm{ref}}(o)}\right]
> $$
>
> - 但采样是从 $\pi_{\mathrm{old}}$（或者 $\pi_{\mathrm{ref}}$）来的，分布对不上；
>
> - 当某个 token 在当前策略下的概率 **远小于** 在参考策略下的概率时
>  （文中写的是 $\pi_\theta \ll \pi_{\mathrm{ref}}$），
>  K3 的梯度会给这个 token 一个**非常大的、甚至无界的权重**。
>
> - 直观地说：
>  「当前策略几乎不会生成这个 token，但因为数据是从参考策略采的，它在样本里出现很多；K3 又给了它非常大的梯度权重」，
>  于是梯度中充满极端 outlier，噪声很大，训练容易炸、KL 控不住。
>
> 这就是文中说的：
>
> 梯度会分配过大且无界的权重，导致梯度更新充满噪声，破坏训练动态。
>
> ---
>
> ### DeepSeek 的修正：用重要性采样做无偏估计
>
> KL 真正的定义是对 $\pi_\theta$ 取期望，但采样来自 $\pi_{\mathrm{old}}$，所以自然想到：
>
> 用 **重要性采样（importance sampling）**把“在 $\pi_{\mathrm{old}}$ 下的样本”校正成“在 $\pi_\theta$ 下的期望”。
>
> 重要性采样的基本形式是：
> $$
> \mathbb{E}_{o \sim \pi_\theta}[f(o)]
> = \mathbb{E}_{o \sim \pi_{\mathrm{old}}}
> \left[\frac{\pi_\theta(o)}{\pi_{\mathrm{old}}(o)} f(o)\right]
> $$
>
> 所以 KL 可以写成：
> $$
> D_{\mathrm{KL}}\!\left(\pi_\theta \parallel \pi_{\mathrm{ref}}\right)
> = \mathbb{E}_{o \sim \pi_{\mathrm{old}}}
> \left[
> \frac{\pi_\theta(o)}{\pi_{\mathrm{old}}(o)}
> \log \frac{\pi_\theta(o)}{\pi_{\mathrm{ref}}(o)}
> \right]
> $$
>
> DeepSeek 给出的形式是（逐 token 表达）：
> $$
> \widehat{D}_{\mathrm{KL}}(o_{i,t}) =
> \frac{
> \pi_\theta(o_{i,t}\mid q,o_{i,<t})
> }{
> \pi_{\mathrm{old}}(o_{i,t}\mid q,o_{i,<t})
> }
> \left(
> \log \frac{
> \pi_{\mathrm{ref}}(o_{i,t}\mid q,o_{i,<t})
> }{
> \pi_\theta(o_{i,t}\mid q,o_{i,<t})
> }
> - 1
> \right)
> $$
>
> 逐项解释一下：
>
> - 重要性采样比率为
>
>   $$
>   w_{i,t} = \frac{\pi_\theta(o_{i,t}\mid q,o_{i,<t})}{\pi_{\mathrm{old}}(o_{i,t}\mid q,o_{i,<t})}.
>   $$
>
>   它表示当前策略 / 旧策略的概率比。
>
>     - 如果某个 token 在当前策略下已经很不可能了（$\pi_\theta$ 很小），即使它在旧策略里常出现，$w$ 也会很小，它对 KL 梯度的贡献会被压下去。
>
> - 与 KL 梯度匹配的那一部分「reward」为
>
>   $$
>   \log \frac{\pi_{\mathrm{ref}}}{\pi_\theta} - 1,
>   $$
>
>   可以理解为：
>
>     - log 比例是「参考策略比当前策略更偏好的程度」；
>
>     - 减 1 的常数项是为了让整个 estimator 在数学上对真实 KL 梯度保持 **无偏**，同时起到 baseline 的效果，减小方差。
>
> 整体上，这个表达式是一个“在 $\pi_{\mathrm{old}}$ 采样下，对 KL 项（或者其梯度）的无偏蒙特卡洛估计”。
>
> ---
>
> ### 这带来的效果
>
> - 通过 $\pi_\theta / \pi_{\mathrm{old}}$ 的 reweight：
>
>     - 采样分布和目标分布（$\pi_\theta$）对齐了；
>
>     - 对于「当前策略已经几乎不会采到的 token」，梯度贡献被削弱，不会出现巨大而无界的梯度。
>
> - 因此：
>
>     - **消除了传统 K3 的系统性估计偏差**；
>
>     - **显著降低了梯度噪声**，KL 正则更准确；
>
>     - 训练过程更平稳，收敛更稳定。
>
>

## QwenLong-L1.5（based on Qwen3-30B-A3B-Thinking） {#qwenlong-l1-5}

### 研究问题

长文档训练不仅缺少高质量、多跳、跨文档任务，还会遇到不同任务奖励尺度不一致、错误探索被过早惩罚，以及物理上下文窗口不足等问题。

### 核心方法

数据合成包含 KG-Guided 多跳问题、Cross-document Table Engine 数值推理和“出题者—解题者—检验者”组成的 MASE 自进化循环；RL 使用任务均衡采样、任务内优势标准化和 AEPO。AEPO 区分错误发生时的熵：高熵错误屏蔽负梯度以保护探索，低熵错误正常惩罚。模型侧还提出记忆管理框架以尝试突破物理窗口。

### 关键证据

笔记给出了完整的答案等价性 LLM Judge 模板，并明确描述了三条数据管线和三项 RL 改造；但没有记录长上下文基准、AEPO 消融、训练规模或记忆框架的定量结果。

### 工程意义

对长文档系统最有价值的是“任务类型显式标记”这一前提：它同时支撑均衡采样、任务内优势估计和分任务评测。MASE 也提供了从无标签文档持续生产、检验和升级任务难度的工程闭环。

### 限制与疑问

原始笔记中的 Memory Management Framework 条目尚未补全，因此“突破物理窗口”的具体读写、压缩和召回机制无法判断；AEPO 屏蔽高熵错误梯度可能保留无效探索，熵阈值如何标定、跨任务是否稳定仍需消融；LLM Judge 的系统性偏差也需要人工抽检。

https://zhuanlan\.zhihu\.com/p/1988973235216327124、https://zhuanlan\.zhihu\.com/p/1984994236756673164

https://arxiv\.org/pdf/2512\.12967

- 可扩展的高质量数据合成管线

    - 知识图谱引导（KG-Guided）：自动挖掘文档间的深层逻辑链，生成环环相扣的多跳推理题，强制模型进行跨段落、跨文档的关联思考。

    - 跨文档表格引擎（Cross-document Table Engine）：从多个非结构化文档中自动抽取出数据，整合成统一的结构化表格，据此生成需要聚合、统计与复杂计算的数值推理题。

    - 多智能体自我进化（MASE）：设计一个由“出题者”“解题者”“检验者”组成的多智能体框架，基于无标签文档自动合成通用长文本任务，通过“出题—解题—检验”的循环，结合历史合成任务提升任务难度和广度。

        - LLM Judge Prompt： You are an expert in verifying if two answers are the same\. Your input is a problem and two answers, Answer 1 and Answer 2\. You need to check if they are equivalent\. Your task is to determine if two answers are equivalent, without attempting to solve the original problem\. Compare the answers to verify they represent identical values or meaning, even when written in different forms or notations\. Your output must follow the following format: 1\) Provide an explanation for why the answers are equivalent or not\. 2\) Then provide your final answer in the form of: \[\[YES\]\] or \[\[NO\]\] Problem: \{question\} Answer 1: \{predicted answer\} Answer 2: \{gold answer\}

- 为长文本定制的强化学习方法

    - 任务均衡采样（Task\-balanced Sampling）：在构建每个训练批次时，强制从不同的任务类型中均匀抽取样本

    - 任务专属优势估计（Task\-specific Advantage Estimation）：在计算优势函数时，不再对整个批次的奖励进行标准化，而是在每个任务类型内部独立进行。

    - 自适应熵控制策略优化（Adaptive Entropy\-Controlled Policy Optimization, [AEPO](https://zhida.zhihu.com/search?content_id=268324302&content_type=Article&match_order=1&q=AEPO&zd_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJ6aGlkYV9zZXJ2ZXIiLCJleHAiOjE3Njk1NjQ3ODYsInEiOiJBRVBPIiwiemhpZGFfc291cmNlIjoiZW50aXR5IiwiY29udGVudF9pZCI6MjY4MzI0MzAyLCJjb250ZW50X3R5cGUiOiJBcnRpY2xlIiwibWF0Y2hfb3JkZXIiOjEsInpkX3Rva2VuIjpudWxsfQ.B3CnK5W2H7zu4snpJr8TCQTaCQ5dmKbWWesZp8sWOFk&zhida_source=entity)）算法：

        - 当模型在高不确定性（高熵）状态下生成了错误答案时，AEPO 会主动屏蔽（mask）其负向梯度。这保护了模型的探索性行为，避免因惩罚不成熟的尝试而丧失学习潜力。

        - 当模型在高置信度（低熵）状态下依然犯错时，负向梯度会被正常施加，以坚决纠正这些高置信度的错误。

- 突破物理窗口的智能体架构

    - 记忆管理框架（Memory Management Framework）：

        -

<ZoomableImage src="/paper-reading/assets/image%209.png" alt="image.png" />

## Qwen-VL-235B-A22B（含 DeepStack） {#qwen-vl-235b-a22b}

### 研究问题

高分辨率图像和长视频会制造大量视觉 token；直接拼接会增加上下文长度和显存，池化或重采样又会损失细节，而且视觉信息只在输入层注入时容易在高层被文本 token 稀释。

### 核心方法

DeepStack 将视觉信息从“横向扩展序列”改为“纵向分层注入”。常规分辨率生成 global tokens，高分辨率特征经二维采样拆成与视觉位置对齐的 stack tokens，再在若干早期 LLM 层通过 $H[\mathrm{vis\_pos}] \mathrel{+}= X_{\mathrm{stack}}^{(k)}$ 残差注入；DeepStack-V 在 ViT 内堆叠不同层级特征，Qwen3-VL 的集成则进一步组合多层 ViT 特征与 LLM 侧注入。

### 关键证据

视频“大海捞针”实验在 **256K tokens 达到 100%**，扩展到 **1M tokens、约 2 小时视频时仍为 99.5%**。笔记还称 DeepStack 在 LLaVA-1.5 基线上的 TextVQA、DocVQA、InfoVQA 等高分辨率任务有明显增益，但未记录具体分数。

### 工程意义

该设计保持视觉序列长度不变，也不要求修改 Attention 本体，可用轻量投影和残差加法接入现有 decoder-only VLM。它特别适合 GUI、文档、多图和视频场景：用层深换取多尺度信息，而不是一味扩大 token 数。

### 限制与疑问

本条原始笔记把 Qwen-VL-235B-A22B 的长视频结果、DeepStack 通用论文、LLaVA 实验和 Qwen3-VL 集成放在一起，证据归属需回看原论文确认；“token 数不增加”不等于总计算不增加，多路高分辨率编码和逐层投影的额外成本尚未量化；各层注入位置、尺度分配与训练稳定性也缺少消融。

Huggingface link:

<ZoomableImage src="/paper-reading/assets/image%2029.png" alt="image.png" />

在长上下文处理能力方面，团队通过“视频大海捞针”实验测试模型对超长视频的理解能力。结果显示，在 256K tokens 上下文长度下，模型准确率达到 100%；当上下文扩展至 1M tokens，对应视频时长约 2 小时，准确率仍保持在 99\.5%，展现出极强的长序列建模能力

---

### DeepStack 要解决什么问题？

典型 LMM / VLM 的视觉接入方式是：

1. ViT/CLIP 等视觉编码器输出一串视觉特征；

2. 通过一个投影头/Perceiver 把这些特征变成视觉 token；

3. 把整串视觉 token 当成前缀，一次性喂进 LLM 的第一层，然后一路往上算完。

问题是：

- 高分辨率图像、多帧视频会产生非常多视觉 token，**内存和算力爆炸**；

- 为了省资源，大家会做 token pooling / resampling / multi\-crop 拼接，这又会**损失细粒度信息**；

- 更糟的是，在 LLM 的高层里，视觉 token 的注意力常常被文本 token “淹没”，**关键信息传不上去**。

DeepStack 的目标：在 **不增加上下文长度** 的前提下，让 LMM 能看更多、更细的视觉信息，同时让这些信息在多层 Transformer 里被有效利用。

---

### 核心思想：把视觉 token 从“横着排”改成“竖着堆”

传统做法是把所有视觉 token 拼成一条长序列，从第 0 层一路算到最后一层，属于 **left\-to\-right** 喂入。

DeepStack 的视角是：LLM 是一堆纵向堆叠的 Transformer 层，那为什么视觉 token 也要只在输入层出现一次？能不能：

> 把视觉 token 变成一个“多层堆叠”的栈，在 **不同的 LLM 层** 持续注入新的视觉信息？
>
>

具体做法（简化版）：

1. 准备两路图像特征

    - 一路：常规分辨率 → 得到一串 “global visual tokens” 记为 `X`；

    - 一路：高分辨率图像 → 通过 ViT 提取更密的特征，再用 2D 采样（dilated sampling）拆成若干组 `X_stack^1, …, X_stack^S`，每一组长度与 `X` 一样，并空间上对齐对应 patch。

2. 按层“分块” LLM

    - 把前几层 decoder 划分为一系列 **DeepStack block**，例如每 1～2 层算一个 block；

    - 剩下的高层保持普通的 prefix 模式。

3. 在不同层“加一层视觉涂料”

    对于第 $i$ 个 DeepStack block，大致做法是：

    $$
    H_i^V = P_i^V\!\left(H_{i-1}^V\right) + X_{\mathrm{stack}}^i.
    $$

    也就是把这一层对应的高分辨率视觉 token $X_{\mathrm{stack}}^i$ 以残差方式加到视觉位置的 hidden states 上（代码中就是 `H[vis_pos] += Xstack[k]`）。

4. 剩余的高层继续正常自回归建模，不再注入新的视觉 token。

直观理解：

- 原来是：**一串视觉 token 所有信息一次性丢给第 0 层**；

- 现在是：**多组视觉 token 像楼层一样依次注入**，低层注入更局部、更密集的 patch，高层保留整合后的表示。

这样：

- 上下文长度没变（视觉位点个数没变）；

- 但 LLM 多层都能接收到不同尺度、不同区域的视觉细节。

---

### 与传统视觉 token 增强策略的对比

DeepStack 主要对比两类传统方法：

1. **Sequence Concatenation（串接序列）**

    - 多 crop 或多视觉编码器 → 直接在 token 维度上拼接，序列长度暴涨；

    - 好处：信息保留较全；

    - 坏处：计算和显存线性甚至超线性上升。

2. **Dimension Concatenation（特征维度拼接）**

    - 在 channel 维拼接不同来源特征，然后再投影到 LLM hidden dim；

    - 序列长度不变，但投影层参数更大，且仍然只在输入层使用一次。

DeepStack 的折中点在于：

- 序列长度**完全不变**；

- 投影模块也可以保持简单（普通 projection）；

- 通过“分层注入 \+ 残差叠加”，让 LLM 的多个层级都看到更细的视觉特征。

实验上，在 LLaVA\-1\.5 等基线之上，在 TextVQA、DocVQA、InfoVQA 等高分辨率任务上有明显增益。

---

### DeepStack\-V：在 ViT 侧的应用

论文还提出了 **DeepStack for ViT （DeepStack\-V）**：

- 把 ViT 的前若干层 \+ patch embedding 用作“基础 tokenization”；

- 把后续几层当作 ViT 里的 “DeepStack block”，在这些层中堆叠不同尺度/不同采样策略的高分辨率特征；

- 最终得到更强的视觉 encoder，给后续的 LMM 或下游任务使用。

这和在 LLM 侧做 DeepStack\-L 类似，只是对象从 decoder\-only LLM 换成了 ViT encoder。

---

### Qwen3\-VL 里的 DeepStack integration 做了什么？

在 Qwen3\-VL 系列（包括 Qwen3\-VL\-MoE、Qwen3\-VL\-Thinking）中，官方描述的 **DeepStack integration** 本质上就是把上述 DeepStack 思路工程化：（[arXiv](https://arxiv.org/abs/2511.21631?utm_source=chatgpt.com)）

- 使用统一的 ViT 视觉编码器，**从多层 ViT 提取 multi\-level features**（低层边缘纹理 \+ 中层局部结构 \+ 高层语义）；

- 通过轻量的连接模块，将这些多层特征：

    - 一部分在 ViT 内部做 DeepStack\-V 式的堆叠；

    - 一部分通过残差/侧路注入到对应层的 LLM 解码器（DeepStack\-L），形成“视觉\-语言多层对齐”；

- 目标是：

    - 在不增加输入 token 数量的前提下，**捕获更细粒度视觉细节**（特别是 GUI、文档、多图场景）；

    - 缩小游戏中视觉表示与文本 token 在中高层的“解耦”，提升图文对齐与推理质量。

很多介绍 Qwen3\-VL 的文档会直接总结成一句话：

> DeepStack：融合多层 ViT 特征，提升细粒度视觉理解和图文对齐。（[GitHub](https://github.com/QwenLM/Qwen3-VL?utm_source=chatgpt.com)）
>
>

---

### 可以如何理解/使用这个概念（工程角度）

如果自己在搭一个 VLM / VLM\-MoE，可以把 DeepStack 看成一个通用设计模式：

1. 不再把视觉 token 只塞到第 0 层，而是在若干早期层里做“分层注入”；

2. 对高分辨率图像：

    - 用标准分辨率做 global tokens；

    - 用高分辨率 \+ 2D 采样做 stack tokens；

3. 用简单的 `H[vis_pos] += Xstack[k]` 残差实现，不需要改动 Attention 结构或增加序列长度。





## MiniMax-M2 {#minimax-m2}

### 研究问题

排行榜成绩不能保证真实 Agent 可用性；CoT 过短、答案格式过拟合、脏数据和任务分布单一都会损害泛化。同时，高效注意力在复杂多跳任务上可能隐藏退化，而饱和基准难以揭示这些问题。

### 核心方法

数据侧强调逻辑完整但不过度冗余的 CoT、答案格式多样性、规则加 LLM 裁判清洗，并用数学和代码提升通用推理、用多领域数据扩展思维范式；按通过率或复杂度调整难度，将数据分为可验证与不可验证两条自动化管线。Agent 对齐引入 Interleaved Thinking，并对工具信息、系统提示、用户目标、环境和每步工具响应进行全轨迹扰动训练；注意力侧探索 Lightning Attention 与 Full Attention 混合，并以多跳代理指标持续迭代。

### 关键证据

笔记记录了多方向融合、1Q 多 A、多周期和增加训练步数均能带来稳步提升，也记录了冷启动框架内测中的良好泛化；但这些均为定性描述，没有具体模型规模、评测集分数或消融表。注意力部分还明确承认尚未完成更大规模下游相关性实验。

### 工程意义

比单纯扩充工具列表更重要的是覆盖完整 Agent 操作空间，并把生产 bad case 反查到训练数据缺陷。可验证/不可验证双管线便于分别采用程序裁判和模型裁判；针对高效注意力建立专门的多跳压力测试，也比只看饱和通用榜单更接近真实风险。

### 限制与疑问

内部测试缺少可复现指标；规则和 LLM 联合清洗仍可能继承裁判偏差；“更难数据更有效”需要防止难度选择把分布推向窄域。混合注意力是否能在更大规模上保持与 MHA 一致、代理指标能否预测真实下游表现，原笔记明确仍是开放问题。

Huggingface link: https://huggingface\.co/MiniMaxAI

### 数据

CoT 的质量体现在其逻辑完整性上，且不包含过多冗余。例如，在指令跟随任务中，过于简短的 CoT 常常导致模型跳过步骤或变得过于自信，从而对模型的最终性能和泛化能力造成显著损害。对于回复而言，我们注意到大多数开源工作为了在排行榜上获得更好的分数，会过度拟合某些基准格式模式。虽然这在单一数据方向上有效，但严重阻碍了通用模型的泛化能力。因此，在合成数据时，我们引入了格式多样性，并在多方向融合实验中观察到显著提升。同时，针对 CoT 和回复中的潜在不良案例，如幻觉、指令跟随失败和逻辑错误，我们使用规则\+LLM 作为裁判进行数据清洗。通过不断迭代这一消除偏差的流程，我们越来越确信每个不良案例都有其对应的脏乱训练数据，数据质量的提升必将反映在模型性能上。

我们的实验也发现**数学和代码数据对于提升推理能力**至关重要。这两种类型的数据所带来的推理能力通常能帮助所有任务，例如 STEM 和 IF。然而，我们也发现我们仍然需要足够多样化的数据来覆盖更多领域，例如逻辑推理、科学、指令遵循和开放式创造性任务。不同领域的任务具有不同的思维范式，而推理的多样性是能力泛化的基础。此外，我们在实验中注意到更难、更复杂的查询对于模型训练更有效，因此我们根据通过率（针对可验证任务）或复杂度分数（针对不可验证任务）调整了数据分布。

无论是**增加查询数量、进行 1Q 多 A、多周期训练，甚至混合不同方向的数据**以增加训练步骤，模型都能稳步提升。在实践中，数据扩展是一个高度工程化的问题，因此我们尝试根据任务特征整合所有数据，将其分为两个数据管道：可验证和非可验证，用于自动化数据合成和处理。实际上，推理团队几乎完全由实习生组成，这个数据管道有效地确保了团队协作效率和数据输出的一致性。

### 对齐：

同一个模型在一个框架中表现卓越，在另一个框架中却毫无用处。一个代理可能在工具使用排行榜上大获全胜，但在一个简单的现实任务中却表现糟糕。基准性能与实际可用性之间的这种差距是该领域面临的最大挑战之一。

它需要具备泛化能力。**我们通过基准测试来培养技能，但最终必须通过确保这些技能在任何地方都能发挥作用来与用户对齐。**

引入能力：

1. *Interleaved Thinking 交错思考，在任何地方都可以进行思考*

2. 智能体的泛化能力并不仅仅是适应新工具，而是适应模型整个操作空间中的扰动。这听起来很抽象，让我们来分解一下。想想在单个智能体任务中所有可能发生变化的东西：

    - The Tool Info and available toolset\.
    工具信息和可用工具集。

    - The System Prompt defines the agent's persona and rules\.
    定义智能体角色和规则的系统提示。

    - The User Prompt and its specific goal\.
    用户提示及其特定目标。

    - The Environment itself（files, codebases, APIs）。
    环境本身（文件、代码库、API）。

    - 每一步返回的工具响应。我们旧的"工具扩展"方法仅解决了第一项问题，忽略了流程中其他部分的扰动。基于这一新认识，我们的团队构建了一个全面的数据管道，专为全轨迹泛化设计。它生成的数据训练模型在每一步都能保持稳定，不受扰动。结果非常令人鼓舞。在内测中，我们向 M2 抛出了晦涩的、"冷启动"的框架——这些框架我们几乎未曾考虑过——其表现超出了我们的预期。无论是工具调用还是指令跟随能力，都泛化得非常出色。

### Attention

高效注意力机制在能够明确击败全注意力机制之前还有很长的路要走。从实际角度来看，高效注意力机制的竞争实际上是一场节省计算资源的竞赛。

模型越好，评估就越困难：在开发 MiniMax\-Text\-01 时，大家仍在评估 MMLU、BBH、MATH 和 LongBench（这些现在都已饱和）。从一年前的角度来看，Lightning Attention 和 Full Attention 的混合效果与纯 Full Attention 相当。我们自己的小规模混合模型在排行榜上证实了这一点。模型在复杂的、多跳推理任务上存在明显缺陷。好吧，一旦问题暴露出来，就可以修复它。我们针对这种特定弱点开发了代理指标，并不断迭代，直到混合模型似乎与 MHA 匹配。但是，这个代理指标是否仍然与更大规模的实际下游性能相关？是否存在其他隐藏的弱点？谁知道呢。我们还没有运行这些实验。

## PaddleOCR-VL {#paddleocr-vl}

### 研究问题

传统文档 OCR 的分阶段流水线容易累积布局与识别误差，纯端到端方案又可能在复杂布局中乱序、幻觉并消耗较多资源，需要在可控性与整体理解之间折中。

### 核心方法

先由轻量模型定位文字块、表格等版面区域，再由 PaddleOCR-VL-0.9B 对各区域做内容识别；训练数据结合公开数据、合成的手写公式和异形表格等困难样本，并通过自动标注与人工复核控制质量。

### 关键证据

原始笔记记录核心模型规模为 **0.9B**，训练数据超过 **3,000 万条**，并附有结果图；正文没有提供具体 benchmark、语言覆盖率、表格/公式分项指标或推理吞吐。

### 工程意义

这是“轻量布局路由器 + 统一内容理解模型”的混合架构，能够保留区域级可观测性和故障定位能力，同时避免为每种文档元素维护完全独立的识别链路，适合成本敏感的文档解析服务。

### 限制与疑问

布局模型漏检仍会向后级传播，区域切分也可能破坏跨栏阅读顺序和跨区域关系；3,000 万数据的真实/合成比例、去重与人工抽检标准未说明；仅凭当前笔记还无法比较它与端到端大模型的精度—延迟—显存帕累托边界。

paperlink: https://arxiv\.org/pdf/2510\.14528

方法： 之前有的工具是 “分步处理”，比如先识别布局再认内容，步骤多、容易出错；有的是 “一步到位”，但处理复杂文档时容易乱序、甚至 “瞎编内容”，还特别耗电脑资源。而 PaddleOCR\-VL 把两者的优点结合了，先靠一个轻量模型快速分析文档布局（比如哪里是文字块、哪里是表格），再用核心的 “PaddleOCR\-VL\-0\.9B” 模型精准识别每个部分的内容，既稳又高效。

数据： 为了让模型好用，收集了 3000 多万条训练数据，既有公开的文档数据，也自己生成了很多 “特殊案例”（比如难认的手写公式、奇怪布局的表格），还靠智能工具自动标注和人工核对保证数据质量，让模型能应对各种真实场景。

<ZoomableImage src="/paper-reading/assets/image%2022.png" alt="image.png" />

<ZoomableImage src="/paper-reading/assets/image%2031.png" alt="image.png" />

<ZoomableImage src="/paper-reading/assets/image%2013.png" alt="image.png" />

## Glyph：Scaling Context Windows via Visual-Text Compression {#glyph}

### 研究问题

超长文本直接以文字 token 输入会迅速占满上下文，并使注意力计算成本随序列长度显著增长，需要一种不修改文本模型物理窗口的压缩表示。

### 核心方法

先把长文本排版并渲染成图片，再由视觉语言模型读取图片中的视觉片段。一个视觉片段可承载多个字符或文字 token，从而用视觉 token 代替更长的文本 token 序列，同时尽量保留原始语义。

### 关键证据

原始笔记给出了论文和代码链接及一张方法图，说明了“文本渲染—视觉编码—VLM 理解”的总体路径；没有记录压缩倍数、下游准确率、最大上下文、延迟或与纯文本基线的定量比较。

### 工程意义

视觉压缩可以作为现有长上下文系统前的独立预处理层，无需为每种语言设计新的文本压缩编码；它也提示工程上可以联合优化字体、字号、页面密度、分辨率和视觉 token 预算。

### 限制与疑问

渲染会引入字体、分辨率、排版、OCR 和视觉编码误差，对代码、公式、表格、多语言及精确引用尤其敏感；压缩后的随机访问、原文定位和可编辑性变差；图片编码成本与端到端总时延是否真正优于文本长上下文，当前笔记无法回答。

paperlink: https://arxiv\.org/pdf/2510\.17800

code: https://github\.com/thu\-coai/Glyph?tab=readme\-ov\-file

不直接处理文字 tokens ，而是先把超长文本 “画” 成图片 —— 就像把文字排版后存成图片那样，再用能理解图片 \+ 文字的 “视觉语言模型”（VLMs）来分析这些图片。这样一来，原本很多文字 tokens 才能表达的内容，一张图片里的视觉片段就能涵盖，相当于把文本 “压缩” 了，而且还能保留文字的核心意思。

<ZoomableImage src="/paper-reading/assets/image%2030.png" alt="image.png" />

## DeepSeek-OCR：Contexts Optical Compression {#deepseek-ocr}

### 研究问题

长文本的文字 token 数量大，注意力计算随长度快速增长；多轮对话若等量保留所有历史，也会持续消耗上下文预算。论文尝试把图片作为长文本“压缩包”，并进一步用分辨率衰减模拟近期清晰、远期模糊的渐进式遗忘。

### 核心方法

使用 DeepEncoder 将渲染后的文本图像压成较少视觉 token；历史记忆场景中，先把旧文本图像化，再按时间远近逐级缩小分辨率，使视觉 token 数与可辨认细节同步减少。工程上可在页面横纵尺寸、通道和 token 数之间调节压缩强度。

### 关键证据

笔记记录压缩在 **9～10 倍以内时 OCR 准确率超过 96%**，**10～12 倍时约 90%**，**20 倍时约 60%**。Fox 图中，600～1000 文本 token 使用 100 个视觉 token 的精度约 **98.5%～96.8%**，而 1200～1300 文本 token 时为 **91.5%～87.1%**；64 个视觉 token 在长文本区间会降至 **79.8%～59.6%**。OmniDocBench 图则显示 DeepSeek-OCR 多个版本位于较低视觉 token、较低编辑距离区域。

### 工程意义

该方法把上下文管理转化为可显式控制的“分辨率—视觉 token—精度”预算问题，可用于归档长文档、压缩旧会话、降低文档预训练成本。渐进缩放还提供了比整段删除更平滑的记忆降级策略。

### 限制与疑问

压缩超过约 10 倍后精度下降明显，不能把“仍保留大致语义”视为所有任务都成立，精确数字、代码和实体可能优先丢失；文本渲染、图像存储和视觉编码也有额外成本；如何挑选应保持清晰的关键历史、如何验证跨语言与复杂版式，以及“模拟人类遗忘”究竟是论文实验还是延伸设想，仍需回到原文核实。

link: https://www\.arxiv\.org/pdf/2510\.18234

code: http://github\.com/deepseek\-ai/DeepSeek\-OCR\.

### 思考：

新的压缩方法，很有意思。

可以仿照类似的方法，横纵坐标、通道进行不同的参数定义，进行微调

**计算量会随着文本长度 “平方级暴涨”**。

给新思路：用 “图片” 当长文本的 “压缩包”。同样是 1000 字的文章，存成纯文字可能需要 1500 个文字令牌，但存成一张清晰的图片，可能只需要 200 个 “视觉令牌”—— 相当于用图片给文本做了一次 “高效压缩”，这就是 “光学压缩” 的核心逻辑。

- 当文字令牌是视觉令牌的 9\-10 倍（压缩 10 倍以内）时，OCR 准确率能达到 96% 以上；

- 压缩到 10\-12 倍时，准确率还有 90% 左右；

- 就算压缩到 20 倍，准确率也能保住 60%。

Contribution:

1. 设计了高效的 “视觉编码器” DeepEncoder

<ZoomableImage src="/paper-reading/assets/截屏2025-10-23%2017.51.10.png" alt="截屏2025-10-23 17.51.10.png" />

### 1\. 核心出发点：模拟人类记忆的 “遗忘本质”

人类记忆的关键特征之一是 “渐进式遗忘”—— 近期记忆清晰、远期记忆模糊（如能清晰回忆今天的对话，却难以精准记起上周的聊天细节）。而传统大语言模型处理多轮对话或长文档时，通常会 “平等保留所有历史文本”，导致历史文本越长，令牌消耗越多、计算效率越低。因此，DeepSeek\-OCR 提出用 “光学压缩” 模拟人类遗忘机制，在减少资源消耗的同时，让模型对历史文本的处理更符合人类认知规律。

### 2\. 实现步骤：三步完成 “多水平压缩与遗忘”

该机制通过 “文本→图像→渐进式缩放” 的链路实现遗忘，具体流程如下：

- **第一步：历史文本图像化（初始压缩）**将多轮对话中 “前几轮的历史文本”（如第一轮、第二轮对话内容）先转换为图像格式（如将文本渲染成类似文档截图的图像）。这一步本身就是一次 “光学压缩”—— 文本对应的文字令牌数量远多于图像对应的视觉令牌数量，初步减少历史文本的资源占用。

- **第二步：旧图像渐进式缩放（多水平压缩）**对不同时间远近的 “历史文本图像” 进行差异化缩放：近期的历史文本图像（如前一轮）缩放比例小，保留较多细节；远期的历史文本图像（如前三轮）缩放比例大，主动减少图像分辨率。例如，近期图像缩放到 800×600，远期图像缩放到 400×300，甚至更小尺寸，形成 “近期清晰、远期模糊” 的多水平压缩层级。

- **第三步：令牌减少与文本模糊（实现遗忘）**图像分辨率的渐进式降低会直接带来两个关键变化：一是**视觉令牌数量逐步减少**（低分辨率图像拆分的 16×16 补丁更少，编码后的视觉令牌数随之下降），大幅降低模型处理历史文本的计算量；二是**文本信息逐步模糊**（低分辨率图像中的文字边缘变虚、细节丢失），模拟人类对远期记忆 “细节遗忘” 的效果，且模糊程度与时间远近正相关 —— 时间越远，文本越模糊，遗忘程度越深。

### 3\. 核心效果：平衡 “遗忘” 与 “关键信息保留”

该机制并非无差别丢弃历史信息，而是在 “遗忘冗余细节” 和 “保留核心语义” 间找到平衡：

- 远期历史文本虽因缩放导致视觉模糊、令牌减少，但仍能保留文本的整体语义（如大致主题、关键结论），避免模型完全丢失历史上下文；

- 近期历史文本保持较高清晰度和足够令牌，确保模型能精准参考近期对话逻辑，不影响当前轮次的交互效果。

<ZoomableImage src="/paper-reading/assets/image%2011.png" alt="image.png" />





<ZoomableImage src="/paper-reading/assets/image%2026.png" alt="image.png" />

#### 图（a）：Fox 基准测试下的“压缩与精度”关系

- **核心目的**：展示 DeepSeek\-OCR 在不同文本长度下，“视觉令牌数量（vis toks）”与“识别精度（Precision）”、“压缩倍数（Compression）”的关联。

- **坐标轴**：

    - 横轴：`Text Tokens in Per Page (Ground-truth)`，即每页真实文本的“文字令牌数”（可以理解为文字的信息量，数值越大文本越长）。

    - 左纵轴：`Precision (%)`，即文字识别的准确率。

    - 右纵轴：`Compression (×)`，即“文字令牌数”与“视觉令牌数”的比值（压缩倍数，数值越大压缩效果越强）。

- **数据系列**：

    - 紫色柱/点：`64 vis toks`（用 64 个视觉令牌压缩）。

    - 蓝色柱/点：`100 vis toks`（用 100 个视觉令牌压缩）。

    - 柱形（left）：对应左纵轴的\*\*识别精度\*\*；点线（right）：对应右纵轴的\*\*压缩倍数\*\*。

- **趋势解读**：

    - 识别精度：文本长度在 600\-1000 令牌时，`100 vis toks`的精度（98\.5%～96\.8%）高于\`64 vis toks\`（96\.5%～85\.8%）；文本更长（1000\-1300 令牌）时，两者精度均有下降，但`100 vis toks`仍保持更高准确率（91\.5%～87\.1% vs 79\.8%～59\.6%）。

    - 压缩倍数：文本越长，压缩倍数越高（比如 1200\-1300 令牌时，`64 vis toks`压缩近 20 倍，`100 vis toks`压缩超 12 倍）。这说明\*\*文本越长，DeepSeek\-OCR 的压缩效率越高\*\*，且“多给一点视觉令牌（如从 64 到 100）”能显著提升长文本的识别精度。

#### 图（b）：Omnidocbench 基准测试下的“性能与视觉令牌消耗”对比

- **核心目的**：横向对比 DeepSeek\-OCR 与其他 OCR 工具的“识别性能”和“视觉令牌消耗”，看谁“又准又省资源”。

- **坐标轴**：

    - 横轴：`Average Vision Tokens per Image`，即每张图片平均消耗的视觉令牌数（数值越小，资源消耗越少）。

    - 纵轴：`Overall Performance (Edit Distance)`，即“编辑距离”（衡量识别结果与真实文本的差异，数值越小，识别越准确）。

- **数据系列**：

    - 不同颜色/形状的点：代表不同 OCR 工具，比如`DeepSeek-OCR (Gundam)`、`MinerU2.0`、`GOT-OCR2.0`等。

    - 图例标注：`Encoder Series`区分了不同技术路线的编码器；`High Accuracy ED < 0.25`标注了“识别精度高（编辑距离\<0\.25）”的区间；`Vision Tokens > 1500`和`Vision Tokens < 1000`则区分了资源消耗的多少。

- **趋势解读**：

    - DeepSeek\-OCR 的多个版本（Gundam、Large、Base、Small、Tiny）都集中在“视觉令牌少、编辑距离小”的区域，比如`DeepSeek-OCR (Gundam)`只用约 1000 视觉令牌，编辑距离就远低于 0\.25；而像`MinerU2.0`、`InternVL3-7B8`等工具，要么消耗视觉令牌极多（超 5000），要么识别精度差（编辑距离超 0\.3）。

    - 结论：\*\*DeepSeek\-OCR 在“资源消耗”和“识别精度”的平衡上显著优于其他同类工具\*\*，用更少的视觉令牌就能实现更高的识别准确率。

## DeepSeek-OCR-v2 {#deepseek-ocr-v2}

### 研究问题

传统 VLM 按固定光栅顺序排列视觉 token，难以表达多栏文档、表格、公式等内容的真实阅读顺序。目标是在 256～1120 个视觉 token 的较低预算内，同时提高文本、结构化元素和阅读顺序解析质量。

### 核心方法

DeepEncoder V2 用 SAM-base 加卷积作为视觉 tokenizer，并用轻量 Qwen2-0.5B 替代传统 CLIP ViT；原始视觉 token 采用双向注意力保持全局视野，可学习查询 token 使用因果掩码，只访问全部视觉信息和前序查询，从而形成语义化“视觉因果流”。全局 1024×1024 视图配置 256 个查询，局部 768×768 裁剪各配置 144 个共享查询，总预算由裁剪数控制。训练分为编码器预训练、查询增强、冻结编码器后的 LLM 续训三阶段。

### 关键证据

OmniDocBench v1.5 上，Overall 从 **87.36% 提升到 91.09%（+3.73%）**，Text Edit 从 **0.073 降至 0.048**，R-order Edit 从 **0.085 降至 0.057**；公式 CDM 提升 **6.17%**，表格 TEDs 提升 **3.05%**。在 1120 token 预算下 Overall Edit 为 **0.100**，优于笔记所列 Gemini-3 Pro 的 **0.115**。线上用户日志图像重复率从 **6.25% 降至 4.17%**，预训练 PDF 重复率从 **3.69% 降至 2.88%**。

### 工程意义

因果查询可视为视觉编码器与语言解码器之间的“有序压缩接口”：视觉侧保留全局双向理解，输出侧按语义顺序逐步汇聚。多裁剪数量直接控制成本，三阶段冻结策略则降低联合训练难度，并让最后阶段训练速度翻倍。

### 限制与疑问

报纸类 Text Edit 仍高于 **0.13**，笔记归因为仅约 25 万相关样本和 token 上限；增加裁剪会改善密集文本，但也会增加延迟。160 张 A100、多个训练阶段的成本不低；与闭源模型在输入分辨率、提示和评测协议上的可比性需核验；笔记中的掩码描述写有 $n=m$，但查询数又由全局/局部配置决定，符号与实现对应关系值得回看原论文。

### 一、研究背景

1. **传统视觉语言模型（VLMs）的固有局限**<br>

    传统VLMs处理图像时，会将视觉tokens按“光栅扫描顺序”（从左上到右下）固定排列，并采用固定位置编码，这种模式与人类视觉感知逻辑相悖。人类视觉会基于图像的语义连贯性和内在逻辑（如文档的文字顺序、表格结构、公式关联）灵活扫描，尤其对复杂布局图像（如学术论文、报表、多元素文档），会遵循因果驱动的顺序处理信息，而非机械的空间顺序。

    借鉴：

<ZoomableImage src="/paper-reading/assets/image.png" alt="image.png" />

2. **文档OCR任务的特殊挑战**<br>

    文档OCR需应对复杂布局（文字、公式、表格共存）、多语言混合、非线性阅读顺序等问题，传统VLMs的刚性token顺序设计难以捕捉文档的语义逻辑，导致文本识别准确率、阅读顺序合理性、结构化元素（公式/表格）解析效果受限。

3. **现有技术的改进空间**<br>

    此前的DeepSeek\-OCR虽在文档OCR领域有一定表现，但仍依赖传统编码器（如CLIP ViT）的固定顺序处理；其他主流模型（如GPT\-4o、Gemini\-2\.5 Pro）要么视觉token数量过大（超过6000）导致效率低，要么在低token预算下性能不足，缺乏“高效压缩”与“语义化排序”的平衡。

### 二、解决的核心问题

1. 突破传统VLMs的“刚性顺序偏见”，实现视觉tokens的**语义化动态重排序**，让模型按图像内在逻辑（而非空间位置）处理信息，匹配人类视觉因果感知模式。<br>

2. 在保持高视觉token压缩率（256\-1120 tokens，匹配Gemini\-3 Pro的token预算）的同时，提升文档OCR的整体性能，尤其改善阅读顺序合理性、公式识别（CDM）、表格识别（TEDs）精度。<br>

3. 验证“LLM风格架构作为VLM编码器”的可行性，探索“两级级联1D因果推理”（编码器重排序\+解码器自回归）实现2D图像理解的新范式，为统一多模态编码（图像、文本、语音）提供基础。

### 三、具体架构与方法

#### 1\. 整体架构

DeepSeek\-OCR 2继承“编码器\-解码器”框架，核心升级在于将原编码器替换为**DeepEncoder V2**，解码器沿用3B参数的MoE结构（约500M激活参数），整体流程可通过公式表示：<br>

$$
O = \mathcal{D}\!\left(
\pi_Q\!\left(
\mathcal{T}^L\!\left(\mathcal{E}(I) \oplus Q_0; M\right)
\right)
\right).
$$

- $I$：输入图像；

- $\mathcal{E}$（视觉 tokenizer）：将图像转为 $m$ 个视觉 token $V$；

- $Q_0$：可学习因果查询嵌入；

- $\mathcal{T}^L$：带掩码注意力的 $L$ 层 Transformer；

- $\pi_Q$：提取后 $n$ 个查询 token（仅输入解码器）；

- $\mathcal{D}$：语言解码器；

- $O$：LLM 词汇表上的输出日志概率。



<ZoomableImage src="/paper-reading/assets/image%2034.png" alt="image.png" />

---

---

<ZoomableImage src="/paper-reading/assets/image%208.png" alt="image.png" />

v2

---

<ZoomableImage src="/paper-reading/assets/截屏2025-10-23%2017.51.10%201.png" alt="截屏2025-10-23 17.51.10.png" />

---

#### 2\. 核心模块：DeepEncoder V2设计

DeepEncoder V2是实现“视觉因果流”的关键，通过四大创新突破传统编码器局限：

|模块/设计|具体实现|核心作用|
|---|---|---|
|**视觉Tokenizer优化**|基于80M参数的SAM\-base\+2个卷积层，输出维度从1024降至896；通过窗口注意力实现16×token压缩|降低计算成本与激活内存，参数规模（80M）与LLM文本嵌入层（约100M）匹配，确保模态一致性|
|**LLM风格编码器替换**|用轻量级Qwen2\-0\.5B（500M参数）替代原CLIP ViT（300M参数），避免额外计算开销|结合LLM的因果注意力机制，为视觉tokens的语义化重排序提供架构基础|
|**双向\+因果双流注意力**|\- 视觉tokens：采用双向注意力（类似ViT），保留全局视野<br>\- 因果流查询（可学习）：采用因果注意力（三角掩码），仅关注所有视觉tokens和前序查询|视觉tokens保持全局信息，查询tokens按语义逻辑实现动态重排序，避免刚性顺序偏见<br>|
|**多裁剪策略与token控制**|\- 全局视图（1024×1024）：256个查询嵌入<br>\- 局部视图（768×768）：144个共享查询嵌入，局部裁剪数量0\-6个<br>\- 总token数范围：256\-1120（匹配Gemini\-3 Pro预算）|适配不同分辨率图像，平衡压缩率与识别精度，覆盖从简单到复杂文档的需求|
|**定制化注意力掩码**|掩码矩阵 $M$ 由两部分拼接：$m$ 为视觉 token 数，$n$ 为查询 token 数，原笔记记为 $n=m$|严格区分视觉 token 的双向交互（全局信息）与查询 token 的因果交互（语义排序），确保推理逻辑正确|

定制化注意力掩码的矩阵定义为：

$$
M =
\begin{bmatrix}
\mathbf{1}_{m \times m} & \mathbf{0}_{m \times n} \\
\mathbf{1}_{n \times m} & \operatorname{LowerTri}(n)
\end{bmatrix}.
$$

#### 3\. 三阶段训练流程

为让模型逐步掌握“特征提取\-语义排序\-解码适配”能力，设计分阶段训练策略：

|训练阶段|目标|关键设置|
|---|---|---|
|**阶段1：DeepEncoder V2预训练**<br>|让视觉tokenizer和LLM风格编码器掌握特征提取、token压缩与基础重排序能力<br>|\- 目标函数：语言建模（next token预测）<br>\- 数据：768×768和1024×1024分辨率图像<br>\- 优化器：AdamW，学习率1e\-4→1e\-6（余弦衰减）<br>\- 硬件：160张A100 GPU，批大小640，40k迭代|
|**阶段2：查询增强**|强化编码器的token重排序能力，提升视觉知识压缩效果<br>|\- 冻结视觉tokenizer，联合优化LLM编码器与解码器<br>\- 多裁剪策略统一分辨率，4阶段流水线并行<br>\- 学习率5e\-5→1e\-6，批大小1280，15k迭代|
|**阶段3：LLM续训**|让解码器适配重排序后的视觉tokens，加速训练|\- 冻结DeepEncoder V2，仅更新LLM解码器<br>\- 学习率1e\-6→5e\-8，20k迭代，训练速度翻倍|

### 四、实验验证与结果

#### 1\. 实验设置

- **基准数据集**：OmniDocBench v1\.5（1355个文档页，9大类别，含中英文，覆盖杂志、学术论文、报表、试卷等，评估维度包括整体性能、文本编辑距离、公式CDM、表格TEDs、阅读顺序编辑距离）。<br>

- **对比基线**：DeepSeek\-OCR（原模型）、主流OCR模型（如GPT\-4o、Gemini\-2\.5 Pro、Qwen3\-VL\-235B、PaddleOCR\-VL）及端到端模型（如OCRFlux、InternVL3）。<br>

- **核心指标**：Overall（整体性能，越高越好）、Text Edit（文本编辑距离，越低越好）、Formula CDM（公式识别精度，越高越好）、Table TEDs（表格识别精度，越高越好）、R\-order Edit（阅读顺序编辑距离，越低越好）。

#### 2\. 关键实验结果

##### （1）整体性能超越基线

在OmniDocBench v1\.5上，DeepSeek\-OCR 2以更低的视觉token上限（1120 vs 原模型1156）实现3\.73%的整体性能提升，核心指标全面优化：

|模型|V\-token max|Overall|Text Edit|R\-order Edit|
|---|---|---|---|---|
|DeepSeek\-OCR|1156|87\.36%|0\.073|0\.085|
|DeepSeek\-OCR 2|1120|91\.09%|0\.048|0\.057|
|提升幅度|\-36|\+3\.73%|\-0\.025|\-0\.028|

##### （2）低token预算下性能领先

在1120视觉token预算（与Gemini\-3 Pro一致）下，DeepSeek\-OCR 2的Overall Edit（0\.100）低于Gemini\-3 Pro（0\.115），证明其在高压缩率下仍保持更优的文档解析能力；对比高token模型（如InternVL3，\>7000 tokens），其整体性能（91\.09%）远超后者（80\.33%），效率优势显著。

##### （3）各文档类型表现与改进空间

- **优势**：阅读顺序（R\-order）在所有9类文档中均优于原模型，验证因果流设计对语义逻辑捕捉的有效性；公式识别（CDM）提升6\.17%，表格识别（TEDs）提升3\.05%，结构化元素解析能力增强。<br>

- **待改进**：报纸类文本识别（Text Edit \>0\.13）表现较弱，原因是训练数据不足（仅250k样本）及token上限可能限制文本密集型场景，可通过增加局部裁剪数量解决。

##### （4）生产环境验证

在实际应用场景中，DeepSeek\-OCR 2的重复率（衡量输出一致性的关键指标）显著降低：在线用户日志图像重复率从6\.25%降至4\.17%，预训练PDF数据重复率从3\.69%降至2\.88%，证明其逻辑视觉理解能力在真实场景中有效。

## Kimi-K2 {#kimi-k2}

### 研究问题

Transformer 二维权重的常规 SGD-momentum 或 Adam 更新可能条件数很高、近似低秩，学习被少数方向主导；注意力 Q/K 权重的谱放大还可能造成 logit 爆炸。训练数据侧还要保证工具多样性，并避免 RL 问题过易或过难而缺少学习信号。

### 核心方法

Muon 对隐藏层二维参数的动量更新执行 Newton-Schulz 迭代，使更新矩阵近似正交，放大原本较弱但可能有用的方向；Muon-QK-Clip 估计每个注意力头 $W_q^h$、$W_k^h$ 的最大奇异值并做谱归一化，将线性映射的最大放大倍数约束到 1。数据侧包含重写，并用工具 embedding 的 t-SNE 检查覆盖；RL 则根据 SFT 模型 pass@k 选择中等难度问题。

### 关键证据

笔记记录 QK-Clip 将初始 attention logits 上限设为 **100**，训练过程中最大 logit 会自行衰减到正常工作区间，无需继续调节 $\tau$；其余证据主要是优化器、数据重写、工具分布和 Safety 图片，没有给出 Muon 相对 Adam 的收敛曲线、端到端基准或安全指标。

### 工程意义

优化器、注意力稳定和数据选择形成互补的训练控制面：Muon 改善更新方向利用率，QK-Clip 可用最大奇异值作为可监控的稳定性信号，pass@k 则把 RL 数据筛选从主观难度改成基于当前模型能力的动态课程。

### 限制与疑问

Newton-Schulz 正交化和逐头谱估计会增加训练开销，近似迭代次数、数值精度及适用参数范围未说明；一次幂迭代只能近似最大奇异值；t-SNE 适合观察而不是可靠的多样性度量。当前笔记也没有交代 Kimi-K2 的完整架构、Muon 的参数覆盖规则、对照实验、数据重写细节和 Safety 结论。

Muon：神经网络隐藏层的优化器： https://kellerjordan\.github\.io/posts/muon/

<ZoomableImage src="/paper-reading/assets/截屏2025-07-24%2010.38.48.png" alt="截屏2025-07-24 10.38.48.png" />

### Muon Optimizer

NS 迭代（Newton\-Schulz iterations ）的作用是使更新矩阵近似正交化
（SGD\-momentum 和 Adam 对基于 Transformer 的神经网络中的二维参数产生的更新通常具有非常高的条件数。也就是说，它们几乎是低秩矩阵，**所有神经元的更新仅由少数几个方向主导**。我们推测，正交化有效地增加了其他“稀有方向”的规模，这些方向在更新中幅度较小，但对学习仍然很重要。）

<ZoomableImage src="/paper-reading/assets/截屏2025-07-24%2010.20.07.png" alt="截屏2025-07-24 10.20.07.png" />

<ZoomableImage src="/paper-reading/assets/image%2046.png" alt="image.png" />

### 最大奇异值

**最大奇异值**（spectral norm）就是矩阵作为线性变换时，能把一个单位向量拉得最长的“放大倍数”；它等于矩阵与其转置乘积最大特征值的平方根，也是矩阵的 **Lipschitz 常数**。

1. 数学定义：设矩阵 $A \in \mathbb{R}^{m \times n}$，其**奇异值**是矩阵 $A^{\mathsf T}A$（或 $AA^{\mathsf T}$）的所有非负特征值的平方根，按降序排列：

    $$
    \sigma_1 \ge \sigma_2 \ge \cdots \ge \sigma_r \ge 0.
    $$

    最大的那个 $\sigma_1$ 就是**最大奇异值**，常记作：

    $$
    \sigma_{\max}(A) = \lVert A \rVert_2.
    $$

2. 直观理解<br>

    - 把矩阵 $A$ 看成线性映射 $x \mapsto Ax$；

    - 在所有单位向量 $\lVert x \rVert_2=1$ 中，$Ax$ 的最大长度就是 $\sigma_{\max}$；

    - 因此 $\sigma_{\max}$ 也是该映射的 **Lipschitz 常数**：

        $$
        \lVert Ax \rVert_2 \le \sigma_{\max}(A)\,\lVert x \rVert_2.
        $$

    - 数值越大，矩阵越容易把输入“放大”甚至爆炸。



3. 计算方法<br>

    - **精确**：对 $A^{\mathsf T}A$ 做特征分解，取最大特征值再开平方。

    - **近似**：在 GPU 上常用 **幂迭代一次** 就够：<br>

        ```Python
        u = torch.randn(n, 1, device=A.device)
        with torch.no_grad():
            v = A @ u; v /= v.norm()
            u = A.T @ v; u /= u.norm()
        sigma_max = (v.T @ A @ u).item()
        ```

    - **库函数**：`torch.linalg.norm(A, ord=2)` 或 `scipy.linalg.norm(A, 2)`。

#### 例子

```Python
import torch, math
A = torch.tensor([[3.0, 0.0],
                  [4.0, 0.0]])   # 2×2 矩阵
## 精确计算
sigma_max = torch.linalg.matrix_norm(A, ord=2).item()
print(sigma_max)   # 5.0
## 几何验证：A 把向量 [0.6, 0.8] 映射成 [1.8, 2.4]，长度 3.0
## 但把 [1,0] 映射成 [3,4]，长度 5.0，正是 σ_max
```

#### 在 Muon\-QK\-Clip 中的角色

- 每个注意力头的 $W_q^h$、$W_k^h$ 先计算 $\sigma_{\max}$；

- 用 $\sigma_{\max}$ 做一次**谱归一化**：

    $$
    W \leftarrow \frac{W}{\sigma_{\max}(W)}.
    $$

- 归一化后 $\sigma_{\max}(W)=1$，梯度不会爆炸，训练更稳。

Initially, the logits are capped at 100 due to QK\-Clip\. Over the course of training, the maximum logits gradually decay to a typical operating range **without requiring any adjustment** to $\tau$.

<ZoomableImage src="/paper-reading/assets/截屏2025-07-24%2010.40.45.png" alt="截屏2025-07-24 10.40.45.png" />

### 数据重写

<ZoomableImage src="/paper-reading/assets/截屏2025-07-24%2010.43.16.png" alt="截屏2025-07-24 10.43.16.png" />

### 工具调用生成

**作者使用 t\-SNE visualizations of tool embeddings 来看工具的多样性！（有道理）**

<ZoomableImage src="/paper-reading/assets/截屏2025-07-24%2010.45.37.png" alt="截屏2025-07-24 10.45.37.png" />

### RL

Moderate Difficulty\. The RL prompt\-set should be neither too easy nor too hard, both of which may produce little signal and reduce learning efficiency\. **We assess the difficulty of each problem using the SFT model’s pass@k accuracy and select only problems with moderate difficulty\.**



### Safety

<ZoomableImage src="/paper-reading/assets/截屏2025-07-24%2010.50.52.png" alt="截屏2025-07-24 10.50.52.png" />

https://zhuanlan\.zhihu\.com/p/1931008210808070426
