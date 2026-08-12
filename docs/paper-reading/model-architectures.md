---
title: 模型架构与推理机制
description: 从 Partial RoPE、QK-Norm、混合注意力到条件记忆与交错思考。
pageClass: paper-reading-page
---

# 模型架构与推理机制

<SummaryHero
  :goals="['理解研究问题', '掌握关键机制与公式', '形成可验证的工程判断']"
  duration="约 70 分钟"
  output="模型架构选型与机制对照表"
>

本页由“论文速读”原始笔记按模型与论文主题重组。每个条目直接给出研究问题、核心机制、工程意义与待核验点，并保留对应原文、公式、链接和图片。

</SummaryHero>

<ResearchWorkbench preset="architectures" />

<PaperPageNavigator />

## MiniMax-M2.5 {#minimax-m25}

### 研究问题

如何在约 200K 的长上下文中兼顾注意力训练稳定性、位置表达能力与 KV Cache 成本，并避免位置编码完全占据每个注意力头的表示空间。

### 核心机制

62 层解码器采用 Full Attention 与 GQA（48 个 Query 头、8 个 KV 头）；每头 128 维中仅前 64 维应用 Partial RoPE，其余维度保留为内容通道；Q、K 在线性投影后、拆头前分别通过每层独立的 RMSNorm，使注意力竞争更多依赖方向而非向量尺度。

|参数|数值|说明|
|---|---|---|
|**隐藏层维度（`hidden_size`）**|**3,072**|相对较小的主维度，控制激活参数量|
|**层数（`num_layers`）**|**62**|较深的网络结构（0-61 层）|
|**上下文长度**|**196,608 tokens（约 200K）**|支持长文档处理|
|**词表大小（`vocab_size`）**|**200,064**|多语言优化词表|
|**位置编码**|**Partial RoPE**<br>|部分旋转位置编码，`rope_dim=64`，`base=5e6`|

|参数|数值|计算与说明|
|---|---|---|
|**注意力头数（`num_heads`）**|**48**|多头注意力|
|**KV 头数（`num_kv_heads`）**|**8**|**GQA（Grouped Query Attention）**，压缩 KV Cache|
|**每头维度（`head_dim`）**|**128**|48 × 128 = 6,144 ≠ 3,072，说明存在 **QK-Norm** 特殊处理|
|**QK-Norm**|**每层独立**<br>|每个注意力头有独立的 RMSNorm 参数|
|**注意力类型**|**Full Attention**|早期版本尝试过 Lightning Attention 和 SWA，M2.5 发布版为全注意力|

#### Partial RoPE

**Partial RoPE**（部分旋转位置编码）指：在每个注意力头的向量维度里，**只对前 `rotary_dim` 个通道应用 RoPE 的旋转**，其余 `head_dim - rotary_dim` 个通道**不做旋转**、保持“纯内容向量”。
 直观上就是：

- **Full RoPE**：`[ r r r r r r r r ]`

- **Partial RoPE**：`[ r r r r — — — — ]`

其中 `r` 表示参与 RoPE 旋转的位置编码通道，`—` 表示不加 RoPE。

##### 例子 A：最常见的配置（“半维 RoPE”）

- 每个 attention head 的维度 `head_dim = 128`，设`rotary_dim = 64`

那么对任意 token 的 query/key 向量（按 head 拆分后）：

- 前 64 维：做 RoPE 旋转（带位置信息）

- 后 64 维：不旋转（更像 NoPE / content-only 通道）

```Bash
q, k = proj_q(x), proj_k(x)        # shape [..., head_dim]
  q1, q2 = q[..., :rotary_dim], q[..., rotary_dim:]
  k1, k2 = k[..., :rotary_dim], k[..., rotary_dim:]

  q1, k1 = apply_rope(q1, k1, pos_ids)     # 只旋转一部分通道
  q,  k  = concat([q1, q2]), concat([k1, k2])
```

> 直觉：模型在计算注意力分数时，同时拥有
>
> - 一部分“会随位置旋转”的特征（更强的位置/相对距离信号）
>
> - 一部分“完全不转”的特征（更纯的语义相似度）
>
>

#### QK-Norm

**QK-Norm（per_layer）** = 在每一层 self-attention 里，**先把 Query（Q）和 Key（K）做归一化**（通常用 RMSNorm/LayerNorm 这类“向量归一化 + 可学习缩放”）。“**per_layer**”表示：**每一层都有自己的一套 Q/K 归一化参数**（不跨层共享），并且在 MiniMax-M2/M2.5 这类实现里，归一化是**在“拆分成多头之前”对整层的 Q/K 向量做的**（所以是“按层”的）。

标准注意力（没有 QK-Norm）的打分为：

$$
x_{ij}=\frac{\mathbf{q}_i^\top \mathbf{k}_j}{\sqrt{d_h}}
$$

- $i$ 是 query token 的位置，$j$ 是 key token 的位置。

- $d_h$ 是**每个注意力头的维度（head dimension）**。

- softmax 对 $x_{ij}$ 做归一化得到注意力权重。

这个式子说明了一个训练不稳定来源：如果 $\lVert\mathbf{q}\rVert$ 和 $\lVert\mathbf{k}\rVert$ 变大，logit 就会整体变大，softmax 更容易饱和、注意力更“尖”（熵塌缩），训练更敏感。

经典 QK-Norm 的想法是把 Q、K 先做 $\ell_2$ 归一化（向量长度归一），让 $QK^\top$ 更像**余弦相似度**，并通常配一个可学习缩放系数：

$$
x_{ij}=g\cdot \left(\frac{\mathbf{q}_i}{\lVert\mathbf{q}_i\rVert_2}\right)^\top
\left(\frac{\mathbf{k}_j}{\lVert\mathbf{k}_j\rVert_2}\right)
=g\cdot \cos(\theta_{ij})
$$

Henry 等人在提出 QKNORM 时也明确指出：归一化后 $QK^\top$ 的元素变成了对应 token 表征的余弦相似度，并引入可学习参数替代固定缩放。

> **直觉**：
>
> - 不做 QK-Norm：模型既可以通过“改变角度（语义）”也可以通过“把向量变长（尺度）”来拉开 logits。
>
> - 做了 QK-Norm：**尺度被钳住**，主要靠“角度/方向”（更接近语义）来竞争注意力 → 稳定性更好。

- `"qk_norm_type": "per_layer"`

##### 实现流程

- 先做线性投影得到 `query_states = q_proj(hidden_states)`、`key_states = k_proj(hidden_states)`。

- **如果启用 `use_qk_norm`**，就对**还没 reshape 成 `(heads, head_dim)` 的整块 Q/K**先过 RMSNorm：

    - `self.q_norm = RMSNorm(head_dim * num_attention_heads)`

    - `self.k_norm = RMSNorm(head_dim * num_key_value_heads)`

    - 然后再 `view(..., heads, head_dim)` 拆成多头去做注意力。

- **按层（per_layer）**：每一层 attention 模块里各自有一对 `q_norm/k_norm`（参数不跨层共享）。

- **不是按头（per_head）**：它不是给每个 head 单独一套 norm；而是把所有 heads 拼起来当成一个更长的向量 norm 一次，再拆分。

### 工程意义

GQA 直接压缩长上下文推理的 KV Cache；Partial RoPE 在位置敏感特征与纯语义特征之间留出显式通道；QK-Norm 有助于抑制 logit 过大和注意力熵塌缩，适合深层、长序列模型的稳定训练。

### 限制与待核验

原笔记中“48 × 128 ≠ 3,072，因此存在 QK-Norm 特殊处理”的因果关系并不充分，Q 投影维度大于隐藏维度也可能只是架构选择；“按层而非按头”的具体归一化轴、M2.5 发布版是否完全取消早期 Lightning Attention/SWA，以及 196,608 上下文下的质量与显存收益，仍需对照官方配置和实现核验。

## GLM-4.7-Flash {#glm-47-flash}

### 研究问题

如何让 MoE 模型在 200K 上下文、工具调用和多轮推理场景中同时获得较低的注意力成本、较高生成吞吐与可控的思考行为。

### 核心机制

47 层解码器仅首层使用 Dense MLP，其余层采用 64 个路由专家、1 个共享专家且每 token 激活 Top-4 的 MoE；注意力继承 DeepSeek-V3 路线，以 Q/KV 低秩投影和 RoPE/NoPE 分维降低长上下文成本；推理侧提供 Interleaved、Preserved、Turn-level thinking，并通过 MTP 或 EAGLE 做推测解码。

- 结构上是 **47 层**解码器堆叠，注意力部分采用 DeepSeek-V3 风格的 Attention 实现（在 Transformers 里直接继承 `DeepseekV3Attention`），并配合低秩 Q/KV 投影参数（`q_lora_rank`/`kv_lora_rank`）来提升效率，支持 **200K 上下文**。

---

> **Token → Embedding → [47× Transformer Decoder Layer] → LM Head → logits**
>
>

#### Attention 子层

- `num_attention_heads = 20`，`num_key_value_heads = 20`（是 **MHA** 形态；如果 KV 头更少是 GQA/MQA）。Transformers 实现里该注意力层继承自 `DeepseekV3Attention`，并在配置项中暴露了 **KV/Q 的低秩 rank**。

#### MLP 子层（MoE）

- 默认 **第 1 层是 dense MLP**，从第 2 层开始变为 **sparse（MoE）**（`["dense"] + ["sparse"]*(L-1)`）。

- MoE 配置：`n_routed_experts = 64`（路由专家）+ `n_shared_experts = 1`（共享专家），每个 token 选 `num_experts_per_tok = 4` 个专家参与计算（Top-K 路由）。（[Hugging Face](https://huggingface.co/zai-org/GLM-4.7-Flash/blob/main/config.json)）

---

#### DeepSeek-V3 风格 Attention + 低秩 Q/KV

在 Transformers 的实现里：

- `Glm4MoeLiteAttention` 直接继承 `DeepseekV3Attention`；（[GitHub](https://raw.githubusercontent.com/huggingface/transformers/main/src/transformers/models/glm4_moe_lite/modular_glm4_moe_lite.py)）

- 配置里有 `q_lora_rank=768`、`kv_lora_rank=512`，并把 Q/K head 维度拆成 **RoPE 部分**与**非 RoPE 部分**：`qk_rope_head_dim=64`、`qk_nope_head_dim=192`，以及 `v_head_dim=256`。

这类设计通常服务于：**降低注意力投影与 KV Cache 的成本 / 提升长上下文吞吐**（具体实现细节以 `DeepseekV3Attention` 为准）。

#### Thinking 模式：Interleaved / Preserved / Turn-level

- **Interleaved thinking**：工具调用前后都可插入推理（链式工具使用更稳）。

- **Preserved thinking**：在多轮里保留 reasoning 内容，提高连续推理一致性与缓存命中（偏 coding/agent 场景）。

- **Turn-level thinking**：每一轮独立开关推理，做成本/时延控制。

#### 推理加速：MTP layer + Speculative decoding（EAGLE）

官方仓库部署示例里明确提到：

- 使用 **MTP** 做 speculative（vLLM 示例里 `--speculative-config.method mtp`），以及 SGLang 的 **EAGLE** speculative 配置；并说明“所有模型都使用 MTP 层”。

- **Speculative decoding（推测解码）**：先用“草稿策略”快速提出候选 token，再由主模型验证/纠正，以提升吞吐；这里提到 MTP/EAGLE 是具体实现路线。

    **并行重打分（scoring）**：把“前缀 + 草稿序列”一次性喂给主模型（teacher forcing 方式），主模型能在 **一次 forward** 里得到每个草稿位置的 logits/概率。

    **逐 token 决策**：按顺序检查草稿 token 是否应被接受；一旦拒绝，就丢弃该 token 及其后续草稿，并用主模型自己的分布“纠正”。

### 工程意义

低秩注意力与稀疏专家有利于降低长上下文和大容量模型的在线成本；三种 thinking 控制分别服务于工具链稳定性、多轮连续性和单轮成本治理；推测解码可在不更换主模型输出分布的前提下提升生成吞吐。

### 限制与待核验

原笔记对低秩投影如何具体减少 KV Cache 只给出概括，需结合 `DeepseekV3Attention` 的张量布局确认；Preserved thinking 对缓存命中和质量的实际收益、MTP/EAGLE 的接受率与端到端加速比，以及 200K 场景的精度退化和硬件条件均未给出实测。

## Qwen3-Coder-Next-80B-A3B {#qwen3-coder-next-80b-a3b}

### 研究问题

如何为代码智能体提供超长上下文和高总容量，同时把单 token 激活参数、注意力二次复杂度与部署成本控制在可用范围内。

### 核心机制

模型以 48 层为一个“3 层 Gated DeltaNet + 1 层 Gated Attention”的重复结构，其中线性递推状态负责低成本处理长历史，标准注意力周期性补足精细 token 交互；注意力输出再经 sigmoid 门控；每层配合细粒度 MoE，仅激活少数路由专家与共享专家，并以 MTP 加速生成。

Qwen3-Coder-Next-80B-A3B 本质上是：“超稀疏 MoE（80B 总参、每 token 只激活约 3B）+ 混合注意力（线性注意力 Gated DeltaNet 为主，少量 Gated Attention 兜底）+ 超长上下文（256K 原生，YaRN 可扩到约 1M）+ 推理加速（MTP）”的 *agentic coding* 模型。

这个模型可以理解成一栋 48 层的大楼：

- **大多数楼层用“便宜但够用”的办法读超长文本**（这就是 **Gated DeltaNet**，主打长上下文省算力/省显存）。

- **每隔几层插一层“更精细但更贵”的标准注意力**（这就是 **Gated Attention**，用来做关键对齐/精细交互）。

- **每层的“思考/加工”（FFN）用 MoE 专家机制**：总能力很大，但每次只叫来少数专家干活（所以叫 **80B 总参、A3B 激活**）。

#### 为什么 `num_key_value_heads=2` 会卡 TP（张量并行）？

TP（Tensor Parallel）就是把同一层的计算切成几份，分到多张 GPU 同时算。

很多实现里，“注意力 head” 会沿着 GPU 切分：比如 TP=4，就希望把 head 切成 4 份，每张卡负责一部分 head。

**KV head 太少，没法均匀切给很多 GPU。**

- 你的 **KV heads = 2，**如果想 TP=4：KV 只有 2 份，怎么切成 4 份？
→ 要么有 GPU 分不到 KV head，要么要做复杂的复制/通信，很多框架就直接不支持或效率很差。

因此工程上常见的限制就是：

- **TP 需要整除 KV heads**

- 所以很多情况下：**TP ≤ `num_key_value_heads`**

---

#### Gated Attention 是什么？

本质仍是注意力，但多了一层控制，让它在某些情况下更稳定/更高效（细节实现不同库略有差异，你可以先把它当成“更强但更贵的注意力层”）。在 Qwen3-Next 里，**Gated Attention** 负责更精细的 token-token 交互。

**先计算 SDPA**：

$$
O=\mathrm{Attn}(Q,K,V)
$$

**再应用门控**：

$$
O' = O \cdot \sigma(XW_g)
$$

- 计算流程：

    1. `q,k,v` 正常算（含 RoPE 等）

    2. `attn_output = Attention(q,k,v)`（也就是 SDPA / flash-attn 的输出）

    3. **`attn_output *= sigmoid(gate)`**

    4. 再走 `o_proj(attn_output)`



    - 先从 `qkv` 里 split 出 `q_gate, k, v`

    - `q_gate` 再 reshape 成 `[num_heads, 2*head_dim]`

    - 然后一刀切成 `q` 和 `gate`（每份都是 `[num_heads, head_dim]`）

    - `gate = sigmoid(gate)`

    - `attn_output *= gate`

```Python
import torch
import torch.nn as nn

class GatedAttention(nn.Module):
    def __init__(self, hidden_size, num_heads, head_dim, num_kv_heads):
        super().__init__()
        self.hidden_size = hidden_size
        self.num_heads = num_heads
        self.head_dim = head_dim
        self.num_kv_heads = num_kv_heads

        q_size = num_heads * head_dim
        kv_size = num_kv_heads * head_dim

        # 融合投影：输出 [Q, Gate, K, V]
        self.qkv = nn.Linear(hidden_size, 2*q_size + 2*kv_size, bias=False)
        self.o_proj = nn.Linear(q_size, hidden_size, bias=False)

        # 这里省略：q_norm/k_norm、RoPE、FlashAttention/SDPA 内核等

    def forward(self, x, positions):
        # x: [B, T, H]
        B, T, _ = x.shape
        q_size = self.num_heads * self.head_dim
        kv_size = self.num_kv_heads * self.head_dim

        qkv = self.qkv(x)  # [B, T, 2*q_size + 2*kv_size]
        q_gate, k, v = torch.split(qkv, [2*q_size, kv_size, kv_size], dim=-1)

        # 拆出 q 和 gate（每个都是 [B, T, num_heads*head_dim]）
        q_gate = q_gate.view(B, T, self.num_heads, 2*self.head_dim)
        q, gate = torch.split(q_gate, [self.head_dim, self.head_dim], dim=-1)
        q = q.reshape(B, T, q_size)
        gate = gate.reshape(B, T, q_size)

        # ... 这里省略：q_norm/k_norm、RoPE(positions, q, k) ...

        # attn(q,k,v) 输出通常是 [B, T, q_size]（内部做了 GQA 广播等）
        attn_out = attn(q, k, v)  # 伪函数

        # 关键：SDPA 输出后门控
        attn_out = attn_out * torch.sigmoid(gate)

        return self.o_proj(attn_out)

```

---

#### Gated DeltaNet 又是什么？为什么说它适合超长上下文？

**它用“更便宜的方式”把长序列的信息逐步压进一个状态里**，避免每次都跟所有历史 token 做两两比较（那是 $O(n^2)$ 的贵操作）。

**最原始线性注意力（无衰减）**

递推更新：

$$
S_t = S_{t-1} + v_t k_t^\top,\qquad o_t = S_t q_t
$$

矩阵形式（整段序列）：

$$
O = (QK^\top \odot M)V
$$

其中：

- $M$：因果 mask（下三角）。

- $S_t \in \mathbb{R}^{d_v \times d_k}$：状态矩阵。

- $\odot$：Hadamard 积（逐元素乘法）。

**带衰减的线性注意力**

加入遗忘机制：

$$
S_t = \alpha_t S_{t-1} + v_t k_t^\top
$$

- $\alpha_t \in (0,1)$：衰减因子。

- $\alpha_t \to 1$：保留历史。

- $\alpha_t \to 0$：快速遗忘。

**Gated Delta rule（Gated DeltaNet 的核心公式）**

$$
S_t = S_{t-1}\bigl(\alpha_t(I-\beta_t k_tk_t^\top)\bigr)+\beta_t v_tk_t^\top
$$

**拆解为三步**：

1. **遗忘 + 纠错**：

$$
A_t = \alpha_t(I-\beta_t k_tk_t^\top)
$$

2. **写入**：

$$
B_t = \beta_t v_tk_t^\top
$$

3. **合并**：

$$
S_t = S_{t-1} A_t + B_t
$$

**参数说明**：

- $\alpha_t \in (0,1)$：门控遗忘因子。

- $\alpha_t$ 越小 → 旧记忆衰减越快（更“忘”）。

- $\alpha_t$ 越大 → 更保留旧记忆。

- $\beta_t \in (0,1)$：纠错步长/写入强度。

- $I$：单位矩阵。

- $k_t k_t^\top$：key 的外积（rank-1 矩阵）。

---

#### “3 层 DeltaNet + 1 层 Attention”的排布有什么用？ {#delta-attention-pattern}

**大多数层用 DeltaNet 省钱**，每隔几层插一次 Attention **补强精细交互**。

直觉上就是：

- **DeltaNet**：负责“扛长度、扛成本”

- **Attention**：负责“关键精度、关键对齐”

这样模型既能吃长上下文，又不至于完全丢掉标准注意力的能力。

$$
\text{Layer}_{\text{pattern}}
=\underbrace{[\text{DeltaNet}\times 3,\ \text{Attention}]}_{\text{重复 12 次}}
\times \text{MoE}
$$

**比例**:

- Gated DeltaNet: 36 层（75%）→ 负责长上下文、低成本

- Gated Attention: 12 层（25%）→ 负责精细对齐、关键交互

#### 完整流程

对于 token $t$:

1. **DeltaNet 层**：

$$
o_t^{\text{DN}} = q_t^\top S_t
$$

2. **Gated Attention 层**：

$$
o_t^{\text{GA}}
=\left[\mathrm{softmax}\left(\frac{q_t K^\top}{\sqrt{d_k}}\right)V\right]
\cdot \sigma(g_t)
$$

3. **MoE 层**（每层后）：

$$
y_t
=\sum_{i \in \operatorname{TopK}(r_t)} w_i(r_t)\cdot \operatorname{Expert}_i(o_t)
+\operatorname{SharedExpert}(o_t)
$$

其中 $r_t$ 是路由分数。

- Top-k：选择 10 个专家（从 512 个中）。

- 共享专家总是激活。

### 工程意义

75% 线性注意力层适合长代码库与长轨迹，25% 标准注意力层保留全局对齐能力；超稀疏 MoE 以约 3B 激活参数承载 80B 总容量；笔记还指出 KV 头数为 2 时会限制常见张量并行切分，能直接指导部署并行度选择。

### 限制与待核验

DeltaNet 的递推状态存在容量瓶颈与遗忘风险，不能等价替代完整历史检索；YaRN 扩展到约 1M 的有效质量、MTP 的真实收益及不同推理框架对 KV 复制/TP 的支持需要基准验证；原笔记中的“512 个专家选 Top-10”等参数应与目标 checkpoint 的官方 `config.json` 再核对，避免与其他 Qwen3-Next 变体混用。

## Step 3.5 Flash / Step 3.7 Flash {#step-flash}

### 研究问题

如何面向高频智能体和多模态生产负载，在 256K 上下文下同时兼顾模型容量、单流生成速度、代码/终端任务能力与推理深度控制。

### 核心机制

Step 3.5 Flash 以细粒度 MoE（每层 288 个路由专家、1 个共享专家、每 token Top-8）结合 3:1 的 SWA/Full Attention 混合层；专用 MTP Head 使用 SWA 与 Dense FFN，一次前向预测 4 个 token。Step 3.7 Flash 延续约 11B 激活参数的稀疏 MoE，并加入 1.8B 视觉编码器和 low/medium/high 三档推理级别。

#### Step 3.5 Flash

[Step 3.5 Flash README（中文）](https://github.com/stepfun-ai/Step-3.5-Flash/blob/main/README.zh-CN.md)

- 兼具前沿智能与极速响应：聊天机器人重在“读”，而智能体必须快在“想”。得益于三路多 Token 预测（MTP-3）技术，Step 3.5 Flash 在典型场景下的生成吞吐量可达 100–300 tok/s（单流代码任务峰值可达 350 tok/s）。复杂多步骤的推理链也能实现即时响应。

- 代码与智能体的稳健引擎：Step 3.5 Flash 专为智能体任务打造，集成了可扩展的强化学习（RL）框架，驱动模型持续自我进化。它在 SWE-bench Verified 分数达到 74.4%，在 Terminal-Bench 2.0 测试中分数达 51.0%。

- 高效的长上下文处理：Step 3.5 Flash 采用 3:1 的滑动窗口注意力（SWA）比例（即每层全注意力层搭配三层 SWA 层），该模型支持极具成本效益的 256K 上下文窗口。这种混合机制确保了在处理海量数据或超长代码库时性能不减，同时显著降低了传统长上下文模型常见的计算开销。

与传统的稠密模型不同，Step 3.5 Flash 使用细粒度路由策略来最大化效率：

- 细粒度专家：每层 288 个路由专家 + 1 个共享专家（始终激活）。

- 稀疏激活：每 token 仅选择 Top-8 专家。

- 结果：模型保留了 196B 参数模型的“记忆容量”，但以 11B 模型的速度执行。

我们利用了一个专门的 MTP Head，包含滑动窗口注意力机制和稠密前馈网络（FFN）。该模块在单次前向传播中同时预测 4 个 token，在不降低质量的情况下显著加速推理。

#### Step 3.7 Flash

[Step 3.7 Flash 官方博客](https://static.stepfun.com/blog/step-3.7-flash/)

Step 3.7 Flash is a 198B-parameter sparse Mixture-of-Experts (MoE) vision-language model that combines a 196B-parameter language backbone with a 1.8B-parameter vision encoder for native image understanding. Engineered for high-frequency production workloads, it activates approximately 11B parameters per token and delivers a throughput of up to 400 tokens per second. Step 3.7 Flash supports a 256K context window and offers three selectable reasoning levels (low, medium, and high) so developers can easily balance speed, cost, and cognitive depth.

### 工程意义

混合注意力压低 256K 上下文的计算与 KV Cache 压力，MTP 面向智能体的长输出吞吐，稀疏激活让接近 200B 的总容量以较小在线计算量运行；3.7 的原生图像理解与推理档位便于按请求在时延、成本和深度之间做产品化调度。

### 限制与待核验

100–350 tok/s、最高 400 tok/s、SWE-bench Verified 74.4% 和 Terminal-Bench 2.0 51.0% 均来自项目方材料，需核对硬件、并发、量化、评测版本和是否使用工具脚手架；“单次预测 4 token”与“MTP-3”的命名关系、质量无损条件，以及 3.7 相比 3.5 的语言主干改动尚未在笔记中展开。

## Qwen3-Coder-Next 模型卡 {#qwen3-coder-next-model-card}

### 研究问题

该条目指向 [Qwen3-Coder-Next 的 Hugging Face 模型页](https://huggingface.co/Qwen/Qwen3-Coder-Next)，研究主题应与长上下文代码智能体的高效架构和部署相关，但原始条目没有附带进一步摘录。

### 核心机制

当前页面仅提供二级来源链接，不能仅凭这一条目独立确认模型规模、混合注意力排布、MoE 路由、上下文长度或推理加速配置；上一个同名近似条目的机制不能自动视为本条目的已核验内容。

### 工程意义

模型卡可作为核对 checkpoint 配置、许可证、推理模板、框架兼容性和部署示例的一级入口，也可用于消除名称大小写及具体变体带来的参数歧义。

### 限制与待核验

这是明显的内容缺口。后续应从模型卡和仓库补齐版本号、发布时间、配置文件、架构说明、评测设置与许可证，并判断它与前述 `Qwen3-coder-next-80b-a3b` 是否为同一 checkpoint；在完成核验前不宜合并两条来源或重复引用前一条的数字。

## Conditional Memory via Scalable Lookup（Engram） {#conditional-memory-engram}

### 研究问题

在固定总参数与训练 FLOPs 下，容量应如何分配给负责动态计算的 MoE 与负责静态模式存储的条件记忆，才能避免 Transformer 用宝贵深度反复重建常见 n-gram 和事实模式。

### 核心机制

Engram 将压缩后的局部 token 模式经多头哈希确定性映射到可训练静态表，再由当前 hidden state 的上下文化门控决定是否、以及以多大强度融合检索结果；论文用 U 型缩放关系描述 MoE/Engram 的容量权衡，并利用索引可提前确定的特性异步预取分层存储中的向量。

论文标题为 *Conditional Memory via Scalable Lookup: A New Axis of Sparsity for Large Language Models*，原笔记记录的来源时间为 DeepSeek 2026-01-12。

[Engram 论文 PDF](https://github.com/deepseek-ai/Engram/blob/main/Engram_paper.pdf)

#### 主要贡献（Key Contributions）

- Sparsity Allocation: We formulate the trade-off between neural computation (MoE) and static memory (Engram), identifying a U-shaped scaling law that guides optimal capacity allocation.
稀疏性分配：我们提出了神经计算（MoE）和静态内存（Engram）之间的权衡，确定了一种 U 形缩放规律，指导最佳容量分配。

- Empirical Verification: Under strict iso-parameter and iso-FLOPs constraints, the Engram-27B model demonstrates consistent improvements over MoE baselines across knowledge, reasoning, code and math domains.
实证验证：在严格的等参数和等 FLOPs 约束下，Engram-27B 模型在知识、推理、代码和数学领域均表现出对 MoE 基线的持续改进。

- Mechanistic Analysis: Our analysis suggests that Engram relieves early layers from static pattern reconstruction, potentially preserving effective depth for complex reasoning.
机制分析：我们的分析表明，Engram 使早期层从静态模式重建中解脱出来，有可能保留有效深度以进行复杂推理。

- System Efficiency: The module employs deterministic addressing, enabling the offloading of massive embedding tables to host memory with minimal inference overhead.
系统效率：该模块采用确定性寻址，能够将庞大的嵌入表卸载到主机内存中，同时保持极低的推理开销。

<ZoomableImage src="/paper-reading/assets/image%2025.png" alt="image.png" />

本研究的一个核心理论贡献在于形式化了 **稀疏性分配（Sparsity Allocation）** 问题。在给定的总参数预算和训练计算预算下，如何在 MoE 专家（神经计算）和 Engram 内存（静态存储）之间分配容量？

<ZoomableImage src="/paper-reading/assets/截屏2026-01-14%2011.11.13.png" alt="截屏2026-01-14 11.11.13.png" />

#### 分配比率与 U 型曲线

<ZoomableImage src="/paper-reading/assets/截屏2026-01-14%2011.12.06.png" alt="截屏2026-01-14 11.12.06.png" />

<ZoomableImage src="/paper-reading/assets/image%2028.png" alt="image.png" />

- $\rho \to 1$（MoE 主导）：缺乏专用记忆，模型被迫用计算深度重构静态模式。

- $\rho \to 0$（Engram 主导）：丧失条件计算能力，损害需要动态推理的任务。



#### 技术细节

1. **分词器压缩（Tokenizer Compression）**

<ZoomableImage src="/paper-reading/assets/截屏2026-01-14%2011.15.36.png" alt="截屏2026-01-14 11.15.36.png" />

2. **多头哈希（Multi-Head Hashing）**：[原笔记补充链接](https://chatgpt.com/s/t_69670f6340a08191920db455d3b98911)

<ZoomableImage src="/paper-reading/assets/截屏2026-01-14%2011.37.37.png" alt="截屏2026-01-14 11.37.37.png" />

1. **多头哈希**负责：把局部 n-gram 以 $O(1)$ 的寻址方式映射到可训练的静态表，并用多头降低 collision 破坏性。原笔记将这一复杂度连续写作三次 `O（1）`，此处统一为规范记法。

2. **上下文化门控**负责：让这些静态 lookup 不会“硬塞”进模型；是否使用、使用多少，由当前上下文的 hidden state 决定，从而抑制冲突与歧义噪声。

这也解释了为什么论文把 Engram 描述为：**静态存储（lookup）+ 动态融合（gating）**的组合，而不是纯粹的哈希嵌入回归。

<ZoomableImage src="/paper-reading/assets/截屏2026-01-15%2010.00.43.png" alt="截屏2026-01-15 10.00.43.png" />

Engram 的一个关键系统优势在于其检索逻辑的 **确定性（Determinism）**。与 MoE 依赖运行时隐藏状态进行动态路由不同，Engram 的检索索引仅取决于输入 Token 序列。在推理阶段，由于内存索引在执行前层计算之前即可知晓，系统可以从主机内存（Host Memory， DRAM）异步预取嵌入到 GPU 显存。

- **存储层级：** 利用 Zipfian 分布特性，将高频 n-gram 缓存在 GPU HBM 或 Host DRAM 中，长尾低频模式存储在 NVMe SSD 或大容量 DRAM 中。

- **通信掩盖：** 将 Engram 模块放置在主干网络的较深层（如第 2 层或第 15 层），利用前序 Transformer 层（Attention/MoE）的计算时间作为缓冲，完全掩盖 PCIe 数据传输延迟。

<ZoomableImage src="/paper-reading/assets/image%202.png" alt="image.png" />

### 工程意义

静态 lookup 与动态推理形成新的稀疏轴，能够释放早期网络层的有效深度；确定性寻址允许把大表卸载至 Host DRAM/NVMe，并用前序层计算掩盖 PCIe 传输，理论上可在等参数、等 FLOPs 约束下扩展知识容量而保持较小推理开销。

### 限制与待核验

哈希冲突、歧义 n-gram、门控失效和长尾访问都可能削弱收益；U 型最优分配是否跨模型规模、数据域和语言稳定，以及 Host/NVMe 分层在不同批大小、命中率和硬件互连下能否真正隐藏延迟，需要复现实验；原笔记中的 $O(1)$ 表述主要指寻址复杂度，不代表端到端访存成本恒定。

## Interleaved Thinking Models {#interleaved-thinking-models}

### 研究问题

传统“先完整规划、再连续调用工具”的智能体容易在首个工具结果后继续执行过时计划；若历史中遗漏 thinking 或 tool call，又会导致失忆、重复调用和循环。该条目关注如何让模型在行动之间持续基于新证据更新决策。

### 核心机制

交错式思考把流程组织为“推理—工具调用—观察结果—再次推理”，每次工具返回后都允许校验假设、修正计划并决定继续或终止；多轮实现还要求按模型协议保留必要的 reasoning/tool-call 历史。笔记以 Claude、GLM、MiniMax、Kimi 等模型的演进和代码修复流程说明这一模式。

模型演进时间线：Claude 4（2025-05）→ GLM-4.5（2025-07）→ MiniMax-M2 / M2.1（2025-10）→ Kimi K2 Thinking（2025-11）→ Claude Opus 4.5（2025-11）。

<ZoomableImage src="/paper-reading/assets/image%2045.png" alt="image.png" />

#### A. 传统 think-and-tool（常见两种形态）

> 1. **先想一大段计划 → 然后按计划连调工具**
>
>     - 风险：计划在第 1 次工具返回后就可能过时，但模型仍按旧计划“惯性执行”，容易走偏、重复、或者错过更优路径。
>
> 2. **工具回合切开，但思考不被保留/不被回填**（实现层面常见 bug）
>
>     - 你每次只把工具结果回给模型，却没有把它上一次输出的 thinking / `tool_calls` “完整塞回历史”。
>
>     - 结果：模型像失忆一样重建上下文，出现**重复调用同一工具、循环、或前后不一致**。MiniMax-M2 的仓库直接强调：它是 interleaved thinking 模型，必须保留 `<think>...</think>` 原样回传。
>
>

#### B. Interleaved Thinking（交错式）

> - 每次工具返回后，模型都会插入一个“反思/校验/更新计划”的 thinking block，再决定下一步工具或结束。
>
> - Claude 文档把它概括为：能在 tool call 之间推理、串联多次工具调用、基于中间结果做更细粒度决策。
>
>

#### 例子 1：代码修复（编译失败 → 定位 → 再验证）

**think-and-tool（先想后用工具，或不保留思考链）**

1. 思考：我需要 `run_tests → search_error → edit_file → run_tests`

2. 调用 `run_tests` → 返回：`ModuleNotFoundError: x`

3. （没有在工具结果后反思更新）继续按原计划 `search_error`，甚至去搜错关键词，最后可能陷入重复。

**Interleaved Thinking**

1. 思考摘要：先跑测试拿到真实错误

2. `run_tests` → 返回 `ModuleNotFoundError: x`

3. 思考摘要：错误类型更像依赖/导入路径问题，先查依赖声明与导入点

4. `search_repo("import x")` → 返回若干文件位置

5. 思考摘要：优先改依赖声明或替换包名，再跑测试验证

6. `edit_file(...)` → `run_tests` → 通过

这种差异在 Claude 的描述里就是：工具返回后继续推理、再决定下一步。

### 工程意义

对编译修复、检索、数据分析等不可预先确定完整路径的任务，交错式思考能缩短错误路径、减少重复调用，并把验证结果纳入下一步决策；它也为工具编排器提出了清晰的会话状态契约。

### 限制与待核验

不同供应商对隐藏思维、可回传 reasoning block、签名字段和缓存的协议并不相同，不能一概要求保存可见思维链；更多推理回合会增加 token、时延与提示注入暴露面。页面给出的模型时间线、各模型对 preserved thinking 的精确要求和相对成功率仍需查阅官方文档与对照实验。

## AllenAI OLMo 3 {#allenai-olmo-3}

### 研究问题

如何构建不仅开放最终权重、而且能完整复现预训练到后训练过程的语言模型家族，并系统验证 DPO、RLVR 与推理训练对通用指令能力的影响。

### 核心机制

OLMo 3 发布 Base、Think、Instruct 与 RL-Zero 等 7B/32B 变体及对应数据、代码、中间 checkpoint 和训练日志；架构采用 RMSNorm、SwiGLU、RoPE，并以 3 层 4096 窗口 SWA + 1 层 Full Attention 的模式支持 8192 上下文；YaRN 仅用于全注意力层。后训练侧强调从高对比度偏好对构建的 DPO checkpoint 启动 RLVR，以及从 Think SFT 向 Instruct 迁移推理特征。

[OLMo 3 二手解读来源（微信文章）](https://mp.weixin.qq.com/s?__biz=MzkxNTU5NDM4Mg==&mid=2247488455&idx=1&sn=a1f6a414e67493ad06cfe4a5e906ea35&scene=21&poc_token=HCufMmmj3Drve1RUaPxhCf7gba9EHJ1gFq2s1lqq)

#### 模型流与后训练

近日 AllenAI（AI2）开源了 OLMo 3 系列，OLMo 3 是一个包含 7B 和 32B 参数规模的开源语言模型家族，涵盖了 Base（基座）、Think（推理/思维链）、Instruct（指令遵循）以及 RL-Zero 版本。与以往的开源模型不同，**OLMo 3 强调发布完整的“模型流（Model Flow）”，即不仅仅公开最终的权重，还包括从预训练到后训练各个阶段的数据集（Dolma 3、Dolci）、代码（OLMo-core、OlmoRL）、中间检查点以及训练日志**。

- **DPO 是 RL 的最佳起点**：相比于 SFT 模型，以 DPO 模型为起点进行强化学习（RLVR），能获得更高的初始 Pass@K 性能和更稳定的训练收益。**对比是 DPO 的核心**：DPO 的成功取决于“胜出”与“拒绝”响应之间的高对比度（High Contrast）。通过引入弱模型（如 Qwen3-0.6B）生成拒绝响应，构建偏好数据对，能有效驱动模型突破 SFT 的瓶颈。

- **推理能力的迁移**：虽然 Instruct 模型不输出思维链，但从 **Think SFT** 检查点开始训练 Instruct 模型，比从 Base 模型开始效果更好。这证明推理训练中学到的特征可以被“内化”并迁移到通用指令遵循任务中。

<ZoomableImage src="/paper-reading/assets/image%2037.png" alt="image.png" />

#### 架构细节

- **基础架构**：基于 Transformer，但在层归一化、激活函数和位置编码上采用了现代大模型的通用配置（如 SwiGLU 激活函数、RMSNorm、旋转位置编码 RoPE）。

- **上下文窗口**：在预训练和中期训练阶段，上下文窗口长度设置为 **8192** tokens，相比 OLMo 2 的 4096 tokens 增加了一倍。

- **滑动窗口注意力（Sliding Window Attention，SWA）**：为了在处理长序列时保持计算效率，OLMo 3 引入了滑动窗口注意力机制。

    - 窗口大小设定为 4096。

    - 采用混合注意力模式：每四层中有三层使用滑动窗口注意力，而第四层使用全注意力（Full Attention）。这种设计旨在平衡局部关注能力和全局上下文捕捉能力，同时控制推理时的 KV Cache 显存占用。

- **Tokenizer**：沿用了 OLMo 2 的分词器，基于 OpenAI 的 `cl100k` 词表。

#### 训练配方

- **位置编码调整**：使用 **YaRN** 方法扩展 RoPE。关键发现是：**仅在全注意力层（Full Attention Layers）应用 YaRN**，而不调整滑动窗口注意力层，能获得最佳性能。

### 工程意义

完整 Model Flow 使数据配方、训练阶段和中间模型都可审计、复现与二次研究；混合注意力降低 KV Cache；DPO→RLVR 和 Think SFT→Instruct 的路径为开源模型选择后训练起点提供了可操作假设，而不只是报告最终榜单。

### 限制与待核验

原笔记主要引用二手微信文章，且偏好数据对的具体构造描述不完整，应回到 AI2 官方技术报告、模型卡和训练日志核对；8192 上下文与当前长上下文模型相比偏短，SWA 对跨窗口信息的影响、仅在 Full Attention 层应用 YaRN 的消融结果，以及弱模型生成 rejected response 的偏差与安全风险仍需评估。
