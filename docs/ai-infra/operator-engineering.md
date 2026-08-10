---
title: 算子工程方法
description: 从瓶颈判断、HBM 访问与 Shape 稳定性出发的 CUDA/Triton 算子开发方法。
---

# 算子工程方法

写自定义算子的首要任务不是立即写 kernel，而是证明现有实现的瓶颈在哪里，以及专用实现能减少哪一部分真实成本。

## 写代码前的三个问题

### 1. 是 memory-bound、compute-bound 还是 launch-bound？

- **memory-bound**：主要时间花在数据搬运，常见于逐元素运算、归一化和小规模 reduction。
- **compute-bound**：计算单元长期饱和，常见于足够大的矩阵乘。
- **launch-bound**：单个 kernel 很小，启动与调度开销占比过高。

Roofline Model 用 Operational Intensity（单位数据搬运对应的计算量）帮助区分前两类；Profiler 的 kernel 时间、带宽、占用率和调用数量用于验证判断。

### 2. 数据是否重复进出 HBM？

多个 eager op 之间若不断读写中间结果，算术量不大也可能很慢。Fusion 的价值在于减少中间张量和 HBM 往返，但只有在寄存器、shared memory、并行度与编译开销可控时才值得。

RMSNorm、LayerNorm、bias + activation、optimizer step 和 LoRA 更新都是适合练习融合的场景。

### 3. Shape 是否稳定？

固定 shape 更容易针对性调块、展开和选择并行策略；动态 shape 需要 shape bucket、通用 fallback 和更完整的 benchmark。Prefill attention 与 decode attention 的序列形态和瓶颈不同，通常不应被视为同一个优化问题。

## 推荐工作流

1. 明确 PyTorch 或现有库 baseline，固定输入、精度和硬件。
2. 写 reference implementation，先保证可比较的正确性。
3. 实现最简单 kernel，不提前堆优化技巧。
4. 用真实 workload profile，而不是只看合成微基准。
5. 根据瓶颈选择 coalescing、tiling、fusion、reduction 或专用 shape。
6. 覆盖误差、边界 shape、非连续内存、不同 dtype 和回退路径。
7. 验证端到端收益；单 kernel 更快不代表整条模型链路更快。

## 容易误判的指标

- Shared memory 更多不一定更快，可能降低 occupancy。
- Occupancy 更高不一定更快，带宽或指令吞吐可能早已饱和。
- 量化与稀疏不天然等于加速，格式转换、反量化和不规则访问会抵消收益。
- Triton 降低了 kernel 开发门槛，但仍需要理解内存层次、并行映射和 shape 假设。

## 生产化验收

生产算子的难点还包括 PyTorch 集成、自动求导、设备与 dtype 兼容、数值误差、构建发布和回退机制。性能、正确性和可部署性缺一不可。

## 来源

- [Notion：AI Infra 算子开发经验总结](https://app.notion.com/p/AI-Infra-CUDA-Mode-Notes-36f3a54bd6b481e182baf9814158a976)
- [Notion：写算子前先问三个问题](https://app.notion.com/p/01-HBM-Shape-36f3a54bd6b481aab612f04dbc21d15e)
