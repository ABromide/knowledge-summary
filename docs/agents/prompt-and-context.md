---
title: Prompt 与上下文工程
description: Prompt Auto Tuning 的统一框架、适用边界、成本与 Context Engineering 转向。
---

# Prompt 与上下文工程

Prompt Auto Tuning 已从手工试错发展为可系统搜索的工程问题，但推理模型正在改变它的收益边界。对传统 LLM 有效的 few-shot、CoT 和长指令，在内置推理的模型上可能冗余甚至有害。

## 一个统一框架

任何提示优化方法都可以写成四元组 `(S, f, g, C)`：

| 维度 | 含义 | 例子 |
| --- | --- | --- |
| S | 搜索空间 | 离散文本、soft prompt、结构化程序、Agent 代码 |
| f | 搜索策略 | LLM 改写、进化、贝叶斯优化、文本梯度、轨迹优化 |
| g | 评估函数 | accuracy、F1、人工偏好、LLM-as-Judge、多目标评分 |
| C | 约束 | API 成本、token、长度、安全、隐私、黑盒/白盒访问 |

这个框架最重要的启示是：研究工作不应只继续发明搜索策略。评估函数和约束条件往往更决定方法能否进入生产。

## 主要方法怎样选择

- DSPy / MIPRO 适合把多组件 LLM pipeline 结构化并搜索指令、示例组合。
- TextGrad 用文本反馈类比梯度，适合单组件迭代，但多层 pipeline 的反馈可能逐层失真。
- Trace / OptoPrime 使用执行轨迹、变量与错误栈，更适合 Agent 系统调试。
- PhaseEvo、EvoPrompt 等离散进化方法能扩大探索，但算法增益需要与“LLM 本身会重写 Prompt”的先验能力做消融比较。
- CAPO 代表成本感知、多目标优化方向：性能提升必须与调用次数、token 和 prompt 长度一起评估。

## 推理模型带来的边界变化

原 Notion 综述给出的实践判断是：

1. 先在目标模型上测 zero-shot 基线；
2. 再判断 few-shot / CoT 是否真的有增益；
3. 只有收益稳定且可复现时，才投入自动搜索；
4. 对强推理模型，把预算优先放在信息组织、工具结果和评估上。

这不是说 Prompt 不再重要，而是优化对象从“一段指令”扩大为模型运行时看到的完整信息生态。

## 从 Prompt Engineering 到 Context Engineering

Context Engineering 关注：系统指令、用户目标、检索材料、工具描述、历史轨迹、记忆、当前状态和输出约束怎样在有限上下文中组合。其工程重点包括：

- 只保留当前决策需要的信息；
- 为外部事实保留来源与时间；
- 对工具输出做结构化和错误处理；
- 控制长会话中的摘要、遗忘与污染；
- 建立任务级评估，而不是只评价单轮措辞。

## 实践原则

- **先评估 ROI。** 目标模型、任务和基线不同，自动优化收益可能接近零。
- **评估比搜索更重要。** 在不可靠指标上获得更高分没有意义。
- **成本与性能同等记录。** 不报告调用次数和 token 的提升难以用于决策。
- **做消融。** 至少比较原 Prompt、简单 LLM 重写、目标方法和无关反馈重写。
- **区分可读性与性能。** Gibberish prompt 可能得分高，但可维护性和安全性差。

## Skill 收藏条目的处理

Notion 中“Skill Creator – Claude Plugin”页面目前只有收藏快照，没有足够的个人总结，因此本轮不扩写为开发规范。后续补充使用记录、失败案例和适用边界后，再进入正式知识页。

## 来源

- [Notion：Prompt Auto Tuning 深度综述 v3](https://app.notion.com/p/Prompt-Auto-Tuning-v3-2024-2025-34e3a54bd6b481609494dc91c5b64adb)
- [Notion：Skill Creator 收藏页](https://app.notion.com/p/Claude-Anthropic-Skill-Creator-Claude-Plugin-Anthropic-9e98c70dbce74c7ba0ade0cb811a4513)
