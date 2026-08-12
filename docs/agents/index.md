---
title: Agent 能力主题总览
description: 从基模训练、Agentic RL、反馈学习到 Prompt 与上下文工程的知识地图。
---

# Agent 能力主题总览

Agent 能力并不是由一个提示词突然产生。它来自基模能力、可执行数据、工具环境、反馈学习、上下文管理和推理时计算的共同作用。

<SummaryHero
  :goals="['拆解能力来源', '理解反馈学习', '区分 Prompt 与上下文工程']"
  duration="约 15 分钟"
  output="一张 Agent 能力形成图"
>

本组把原 Notion 中的长文收藏、研究综述和阶段性技术报告压缩为三个可追踪主题。网页收藏中的观点会与个人总结区分，不把标题当作已验证事实。

</SummaryHero>

## 能力形成链路

<InteractiveFlow preset="agent" />

## 三个主题

| 主题 | 核心问题 | 页面 |
| --- | --- | --- |
| 训练与推理 | Agent 怎样在多轮环境中学会规划、工具调用和纠错？ | [训练、推理与反馈](/agents/training-and-reasoning) |
| Prompt 与上下文 | 何时值得自动调优 Prompt，何时应重构完整上下文？ | [Prompt 与上下文工程](/agents/prompt-and-context) |
| 研究雷达 | 近期论文与开源项目透露出哪些方向？ | [研究雷达](/agents/research-radar) |

## 当前总判断

1. Agentic 训练的关键不是生成更多轨迹，而是构建可执行、可验证、能提供有效信用分配的环境。
2. 结果奖励过于稀疏时，回合级、token 级或 rich feedback 能提供更细的学习信号。
3. 推理模型削弱了传统 few-shot / CoT 提示优化的普适价值，工程重点正在转向上下文、工具、记忆和评估。
4. 多 Agent 并不会自然产生协作能力；拓扑、角色、奖励、通信成本和停止条件都需要明确设计。

## 来源入口

- [Notion：AI Agent](https://app.notion.com/p/AI-Agent-3183a54bd6b4806a9135f2befb2b1cc7)
- [Notion：Prompt Auto Tuning 深度综述](https://app.notion.com/p/Prompt-Auto-Tuning-v3-2024-2025-34e3a54bd6b481609494dc91c5b64adb)
