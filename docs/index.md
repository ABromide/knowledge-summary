---
title: Notion 知识总览
description: 按 AI Infra、Agent 能力与技术棚屋三条主线整理个人 Notion 笔记。
pageClass: knowledge-home
---

# Notion 知识总览

这里不再放通用教程或演示页面，而是集中呈现从个人 Notion 中提炼出的知识。当前内容按“长期知识主题”和“可复用工程实践”分组，原始页面保留为来源，不在站内逐篇照搬。

<SummaryHero
  :goals="['理解 AI 系统全景', '追踪 Agent 训练方法', '复用真实工程经验']"
  duration="按主题随时查阅"
  output="主题结论、工程判断与来源索引"
>

本轮整理基于 2026-08-10 可访问的 Notion 页面快照。遇到重复条目会合并，只有标题而没有正文的收藏会明确标记为“待消化”。

</SummaryHero>

<StatGrid
  title="本次整理范围"
  :items="[
    { value: '33', label: 'Notion 页面' },
    { value: '8', label: 'AI Infra 模块' },
    { value: '6', label: '项目与实验' },
    { value: '3', label: '结构化数据库' }
  ]"
/>

## 三个知识分组

<div class="topic-grid">
  <a class="topic-card topic-card--infra" href="./ai-infra/">
    <span class="topic-card__index">01 / SYSTEMS</span>
    <strong>AI Infra</strong>
    <p>从计算集群、通信存储到训练、推理与算子优化，建立大模型系统的端到端地图。</p>
    <span class="topic-card__link">进入体系 →</span>
  </a>
  <a class="topic-card topic-card--agent" href="./agents/">
    <span class="topic-card__index">02 / INTELLIGENCE</span>
    <strong>Agent 能力</strong>
    <p>聚合 Agentic RL、on-policy distillation、Prompt Auto Tuning 与研究雷达。</p>
    <span class="topic-card__link">查看主题 →</span>
  </a>
  <a class="topic-card topic-card--shed" href="./shed/projects">
    <span class="topic-card__index">03 / PRACTICE</span>
    <strong>技术棚屋</strong>
    <p>沉淀个人项目、技术实验、架构经验和真实踩坑，重点记录决策与复用价值。</p>
    <span class="topic-card__link">浏览实践 →</span>
  </a>
</div>

## 分组口径

| 分组 | 收录规则 | 不直接收录的内容 |
| --- | --- | --- |
| AI Infra | 能解释大模型系统软硬件链路的课程总结与算子实践 | 只有目录、无正文的占位章节 |
| Agent 能力 | Agent 训练、反馈、提示优化、研究趋势 | 未经消化的网页标题不会作为结论 |
| 技术棚屋 | 已做项目、实验复盘、可复用工程经验与故障根因 | 单纯进度流水账会被压缩 |

## 阅读方式

如果要建立系统认知，从 [AI Infra 体系总览](/ai-infra/) 开始；如果正在研究智能体训练，直接进入 [训练、推理与反馈](/agents/training-and-reasoning)；如果要查可落地的工程做法，查看 [项目与实验](/shed/projects) 和 [工程经验与踩坑](/shed/engineering-notes)。

完整的 Notion 页面映射、重复项和内容边界记录在 [Notion 来源索引](/appendix/notion-sources)。
