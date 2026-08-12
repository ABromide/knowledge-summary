---
title: AI Infra 体系总览
description: 从 Scaling Law 到计算、通信、训练、推理、数据与应用的大模型系统地图。
---

# AI Infra 体系总览

AI Infra 的主线不是“堆更多 GPU”，而是让模型、数据、计算、通信、存储和服务系统在同一个约束下协同。Scaling Law 决定资源投入方向，分布式系统决定训练上限，推理系统决定规模化成本，数据与应用则决定这些能力是否真正产生价值。

<SummaryHero
  :goals="['建立端到端系统地图', '识别各层核心瓶颈', '找到深入阅读入口']"
  duration="约 20 分钟"
  output="一张 AI Infra 学习路线"
>

本页把 Notion 中“00—07”八个模块压缩为四层视图，并把新增的 CUDA / Triton 算子经验接到推理与训练链路中。

</SummaryHero>

## 一条完整链路

<InteractiveFlow preset="infra" />

## 四个核心判断

1. **资源扩展必须服从有效缩放。** Kaplan 规律强调模型规模，Chinchilla 进一步指出模型参数与训练数据需要更均衡地扩展；只增加参数并不等于获得最佳性能。
2. **大规模训练首先是系统问题。** SPTD、上下文并行、专家并行和 ZeRO 解决的是显存、通信与负载切分，而不是改变模型目标函数。
3. **推理优化必须同时看延迟、吞吐和显存。** KV Cache、PagedAttention、Continuous Batching、量化与模型压缩分别作用在不同瓶颈上，没有单一技术能覆盖所有工作负载。
4. **算子优化从瓶颈判断开始。** 在写 CUDA 或 Triton kernel 之前，先确定是 memory-bound、compute-bound 还是 launch-bound，再决定融合、分块或专用实现是否值得。

## 模块地图

| 层次 | 解决的问题 | 代表主题 | 深入阅读 |
| --- | --- | --- | --- |
| 资源层 | 算力如何稳定组成集群 | GPU/NPU、RDMA、集合通信、分布式存储 | [计算、通信与云原生](/ai-infra/compute-network) |
| 执行层 | 模型怎样高效训练与服务 | SPTD、ZeRO、Flash Attention、KV Cache | [训练与推理系统](/ai-infra/training-inference) |
| 模型层 | 训练什么、用什么数据 | Transformer、MoE、Mamba、多模态、数据工程 | [模型、数据与应用](/ai-infra/models-data-apps) |
| 内核层 | 单个热点路径怎样逼近硬件上限 | Profiling、HBM、Fusion、Triton | [算子工程方法](/ai-infra/operator-engineering) |

## 深入专题

这次扩展把原有四篇总览拆成十二篇可独立查阅的工程专题。总览负责建立边界，专题负责回答“怎样估算、怎样选择、怎样验证”。每篇都包含一手资料链接、工程限制和交互模型；Widget 中的数字是帮助形成量级直觉的估算，不替代真实集群压测。

### 规模、硬件与通信

| 专题 | 核心问题 | 交互入口 |
| --- | --- | --- |
| [Scaling 与工作负载建模](/ai-infra/scaling-workloads) | 参数、token、算力和训练工期怎样形成闭环 | 训练计算量估算、工作负载决策卡 |
| [加速器与显存体系](/ai-infra/accelerators-memory) | 算力、HBM、精度与 Roofline 怎样共同决定上限 | Roofline 实验室、精度策略权衡 |
| [互连与集合通信](/ai-infra/interconnect-collectives) | PCIe、NVLink、RDMA 与 collective 怎样映射 | 集合通信拓扑观察、互连方案选择 |
| [存储与 Checkpoint](/ai-infra/storage-checkpoint) | 数据吞吐、状态一致性与恢复目标怎样权衡 | Checkpoint 预算、存储路径选择 |

### 平台、训练与可靠性

| 专题 | 核心问题 | 交互入口 |
| --- | --- | --- |
| [调度与平台工程](/ai-infra/scheduling-platform) | Gang、配额、拓扑和多租户边界怎样协同 | 调度策略、多租户隔离决策 |
| [可靠性与可观测性](/ai-infra/reliability-observability) | 如何从首个故障信号恢复到一致状态 | 恢复预算、可靠性控制面 |
| [分布式训练](/ai-infra/distributed-training) | DP、TP、PP、CP、EP 如何组合和放置 | 并行维度拓扑、策略组合卡 |
| [训练显存与数值](/ai-infra/training-memory-numerics) | 模型状态、激活、重计算和低精度如何记账 | 训练显存账本、精度策略权衡 |

### 推理、数据与算子

| 专题 | 核心问题 | 交互入口 |
| --- | --- | --- |
| [推理服务系统](/ai-infra/inference-serving) | Prefill、Decode、KV Cache 和批处理如何协同 | 推理显存预算、调度策略卡 |
| [容量规划与成本](/ai-infra/capacity-economics) | 如何从长度分布与 SLO 推导容量和单位经济性 | 在线容量估算、成本路径权衡 |
| [数据流水线](/ai-infra/data-pipeline) | 来源、质量、版本和供数吞吐怎样被治理 | 数据吞吐预算、流水线决策卡 |
| [算子与编译器](/ai-infra/operator-compiler) | 如何从性能指纹走到融合、分块和编译 | Roofline 实验室、算子优化路径 |

## 学习顺序

1. 从 [Scaling 与工作负载建模](/ai-infra/scaling-workloads) 建立计算量、数据量与工期的共同口径。
2. 依次阅读 [加速器与显存体系](/ai-infra/accelerators-memory) 和 [互连与集合通信](/ai-infra/interconnect-collectives)，理解单卡与集群扩展的物理边界。
3. 用 [分布式训练](/ai-infra/distributed-training) 把并行维度映射到拓扑，再用 [训练显存与数值](/ai-infra/training-memory-numerics) 校验容量与稳定性。
4. 进入 [推理服务系统](/ai-infra/inference-serving) 和 [容量规划与成本](/ai-infra/capacity-economics)，把系统指标转换为用户 SLO 与成本。
5. 最后以 [可靠性与可观测性](/ai-infra/reliability-observability)、[数据流水线](/ai-infra/data-pipeline) 和 [算子与编译器](/ai-infra/operator-compiler) 补齐生产闭环。

## 来源

- [Notion：00 大模型系统概述](https://app.notion.com/p/33b3a54bd6b481c78d98eeba043ef51e)
- [Notion：AIInfra 文档总结索引](https://app.notion.com/p/AIInfra-33b3a54bd6b4816bb189e32d4f1ee54e)
- 原始课程：[AI Infra 文档](https://infrasys-ai.github.io/aiinfra-docs/)
