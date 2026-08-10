---
title: Notion 来源索引
description: 2026-08-10 Notion 同步快照、分组映射与内容边界。
---

# Notion 来源索引

本索引记录 2026-08-10 从 “Charles's Notion” 只读获取的页面结构。站内内容是主题化总结，不是 Notion 的实时镜像；Notion 页面后续变化不会自动同步到本站。

## AI Infra 知识树

| Notion 页面 | 站内归属 | 处理方式 |
| --- | --- | --- |
| [AI Agent](https://app.notion.com/p/AI-Agent-3183a54bd6b4806a9135f2befb2b1cc7) | Agent 总览 | 作为父级入口 |
| [AIInfra 文档总结索引](https://app.notion.com/p/AIInfra-33b3a54bd6b4816bb189e32d4f1ee54e) | AI Infra 总览 | 作为课程目录 |
| [00 大模型系统概述](https://app.notion.com/p/00-33b3a54bd6b481c78d98eeba043ef51e) | AI Infra 总览 | 压缩全景与 Scaling Law |
| [01 AI 计算集群](https://app.notion.com/p/01-AI-33b3a54bd6b481ca9c04cc173faa7102) | 计算、通信与云原生 | 合并总结 |
| [02 通信与存储](https://app.notion.com/p/02-33b3a54bd6b481d0be5be686660e9c82) | 计算、通信与云原生 | 合并总结 |
| [03 集群容器与云原生](https://app.notion.com/p/03-33b3a54bd6b48108bbfdfae21b318b4a) | 计算、通信与云原生 | 合并总结 |
| [04 大模型训练](https://app.notion.com/p/04-33b3a54bd6b48140ac71d14f9a1e84d2) | 训练与推理系统 | 合并总结 |
| [05 大模型推理](https://app.notion.com/p/05-33b3a54bd6b4819db93fdf38f949cd21) | 训练与推理系统 | 合并总结 |
| [06 大模型算法与数据](https://app.notion.com/p/06-33b3a54bd6b481599537e42346c6ca51) | 模型、数据与应用 | 合并总结 |
| [07 大模型应用](https://app.notion.com/p/07-33b3a54bd6b481a7827cd6068cf22c72) | 模型、数据与应用 | 合并总结 |
| [AI Infra 算子开发经验总结](https://app.notion.com/p/AI-Infra-CUDA-Mode-Notes-36f3a54bd6b481e182baf9814158a976) | 算子工程方法 | 提炼工作流 |
| [写算子前先问三个问题](https://app.notion.com/p/01-HBM-Shape-36f3a54bd6b481aab612f04dbc21d15e) | 算子工程方法 | 合并到判断框架 |

## Agent 与研究材料

| Notion 页面 | 站内归属 | 处理方式 |
| --- | --- | --- |
| [Prompt Auto Tuning 深度综述 v3](https://app.notion.com/p/Prompt-Auto-Tuning-v3-2024-2025-34e3a54bd6b481609494dc91c5b64adb) | Prompt 与上下文工程 | 提炼统一框架与适用边界 |
| [Agentic 能力从哪里来](https://app.notion.com/p/71-16-Agentic-d01f0a2277a345fc8cd2a57972f710c4) | 训练、推理与反馈 | 提炼训练链路与数据合成 |
| [基于强化学习优化通用 LLM Agent](https://app.notion.com/p/68-6-2c97e1af274142c1bb15e26e0256fd36) | 训练、推理与反馈 | 提炼信用分配与多轮 RL |
| [RL / on-policy distillation 进展](https://app.notion.com/p/RL-on-policy-distillation-634ed2bb4abf4f218e6d14d71442df08) | 训练、推理与反馈 | 提炼 rich feedback 与在线蒸馏 |
| [Skill Creator 收藏页](https://app.notion.com/p/Claude-Anthropic-Skill-Creator-Claude-Plugin-Anthropic-9e98c70dbce74c7ba0ade0cb811a4513) | Prompt 与上下文工程 | 仅标记待消化，不扩写 |
| [arXiv AI 论文日报 2026-03-05](https://app.notion.com/p/arXiv-AI-2026-03-05-31a3a54bd6b481bcabc5fa6b973c722b) | 研究雷达 | 作为时间快照 |
| [GitHub Trending 技术报告 2026-03-03](https://app.notion.com/p/GitHub-Trending-2026-03-03-3183a54bd6b4810b91cece6da8f5a7f1) | 研究雷达 | 作为时间快照 |

## 技术棚屋结构

| Notion 页面 / 数据库 | 作用 |
| --- | --- |
| [技术棚屋](https://app.notion.com/p/33c3a54bd6b4805ca4b9c951d7131b9a) | 顶层空间 |
| [Shed Board](https://app.notion.com/p/Shed-Board-33c3a54bd6b4818da0c5de85c8864529) | 项目列表父页 |
| [项目列表](https://app.notion.com/p/33c3a54bd6b481f8b6c0df28e8121d21) | 项目数据库 |
| [Shed Wiki](https://app.notion.com/p/Shed-Wiki-33c3a54bd6b481a58a33c8a3bca3fee6) | 知识条目父页 |
| [知识条目](https://app.notion.com/p/33c3a54bd6b4815eb415d01af29c98f8) | 工程知识数据库 |
| [CC Pitfalls](https://app.notion.com/p/CC-Pitfalls-33c3a54bd6b4814ba666df7cf70c7663) | 踩坑父页 |
| [踩坑记录](https://app.notion.com/p/33c3a54bd6b48186b20be35a273596ab) | 故障数据库 |

### 项目条目

- [daily-input-stats](https://app.notion.com/p/daily-input-stats-macOS-Swift-36b3a54bd6b481bdb029dc27012bf4ca)
- [codex-stats-menubar](https://app.notion.com/p/codex-stats-menubar-macOS-Codex-36b3a54bd6b481409d74ec22fee5032c)
- [service-up](https://app.notion.com/p/service-up-TUI-Profile-33c3a54bd6b4816b8e8cf9db0e2a1d52)
- [pixel-pet](https://app.notion.com/p/pixel-pet-33c3a54bd6b481e5b68bf3ff8b87f365)
- [work-summary](https://app.notion.com/p/work-summary-git-AI-33d3a54bd6b481dd9f4cda362efa76b9)
- [memflow-paper](https://app.notion.com/p/memflow-paper-Agent-memory-security-via-OS-inspired-IFC-33e3a54bd6b48164900bdbbb85ae78f3)

### 工程知识与踩坑

- [Ebitengine 桌面像素应用开发经验](https://app.notion.com/p/Ebitengine-33c3a54bd6b481df8a64ff98f674358f)
- [DebugPrint 中文渲染记录 A](https://app.notion.com/p/Ebitengine-DebugPrint-33c3a54bd6b481c29d2fd39a54f60cec)
- [DebugPrint 中文渲染记录 B](https://app.notion.com/p/Ebitengine-DebugPrint-33c3a54bd6b48181b973f809fab6a09e)
- [verl RL 训练环境版本漂移](https://app.notion.com/p/verl-RL-9-33c3a54bd6b481f8a321c1a78c271d7f)

两条 DebugPrint 记录标题、根因和解决方案一致，站内合并为一条知识，但此处保留两个来源以避免隐藏 Notion 中的重复数据。

## 同步守则

1. 先读取页面与数据库结构，再确定网站分组。
2. 原始内容只读，不因网站整理而修改或删除 Notion 页面。
3. 每条结论至少能回溯到一个明确来源。
4. 只有标题或链接的收藏标记为“待消化”，不生成虚假总结。
5. 重复内容合并展示，同时在来源索引保留映射。
6. 每次同步记录日期；时效性材料标注快照时间。
