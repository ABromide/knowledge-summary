---
title: 个人知识总览
description: 按 AI Infra、论文速读、Agent 能力与技术棚屋四条主线整理个人知识。
pageClass: knowledge-home
pageTools: false
---

# 个人知识总览

这里不再放通用教程或演示页面，而是集中呈现从个人 Notion 和论文阅读资料中提炼出的知识。当前内容按“长期知识主题”“论文研究脉络”和“可复用工程实践”分组，研究问题、方法、证据、公式与工程判断直接组织在对应主题中。

<SummaryHero
  :goals="['理解 AI 系统全景', '追踪论文与模型进展', '复用真实工程经验']"
  duration="按主题随时查阅"
  output="主题结论、工程判断与来源索引"
>

Notion 分组基于 2026-08-10 可访问的页面快照；论文速读分组基于本地完整阅读笔记。遇到重复条目会合并，只有标题而没有正文的收藏会明确标记为“待消化”。

</SummaryHero>

<StatGrid
  title="本次整理范围"
  :items="[
    { value: '33', label: 'Notion 页面' },
    { value: '8', label: '论文主题分栏' },
    { value: '97', label: '论文配图' },
    { value: '4', label: '一级知识分组' }
  ]"
/>

## 四个知识分组

<div class="topic-grid">
  <a class="topic-card" href="./ai-infra/">
    <span class="topic-card__index">01 / SYSTEMS</span>
    <strong>AI Infra</strong>
    <p>从计算集群、通信存储到训练、推理与算子优化，建立大模型系统的端到端地图。</p>
    <span class="topic-card__link">进入体系 <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14m-5-5 5 5-5 5" /></svg></span>
  </a>
  <a class="topic-card" href="./paper-reading/">
    <span class="topic-card__index">02 / RESEARCH</span>
    <strong>论文速读</strong>
    <p>逐条整理模型、强化学习、Agent、VLA、评估与理论资料，同时完整保留原始笔记和配图。</p>
    <span class="topic-card__link">进入阅读台 <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14m-5-5 5 5-5 5" /></svg></span>
  </a>
  <a class="topic-card" href="./agents/">
    <span class="topic-card__index">03 / INTELLIGENCE</span>
    <strong>Agent 能力</strong>
    <p>聚合 Agentic RL、on-policy distillation、Prompt Auto Tuning 与研究雷达。</p>
    <span class="topic-card__link">查看主题 <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14m-5-5 5 5-5 5" /></svg></span>
  </a>
  <a class="topic-card" href="./shed/projects">
    <span class="topic-card__index">04 / PRACTICE</span>
    <strong>技术棚屋</strong>
    <p>沉淀个人项目、技术实验、架构经验和真实踩坑，重点记录决策与复用价值。</p>
    <span class="topic-card__link">浏览实践 <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14m-5-5 5 5-5 5" /></svg></span>
  </a>
</div>

## 分组口径

| 分组 | 收录规则 | 不直接收录的内容 |
| --- | --- | --- |
| AI Infra | 能解释大模型系统软硬件链路的课程总结与算子实践 | 只有目录、无正文的占位章节 |
| 论文速读 | 模型、RL、Agent、VLA、评估与理论的主题化正文、公式与实验记录 | 没有来源或无法定位主题的推断不会作为论文结论 |
| Agent 能力 | Agent 训练、反馈、提示优化、研究趋势 | 未经消化的网页标题不会作为结论 |
| 技术棚屋 | 已做项目、实验复盘、可复用工程经验与故障根因 | 单纯进度流水账会被压缩 |

## 阅读方式

如果要建立系统认知，从 [AI Infra 体系总览](/ai-infra/) 开始；如果要按模型或方法追踪研究资料，进入 [论文速读](/paper-reading/)；如果正在研究智能体训练，直接进入 [训练、推理与反馈](/agents/training-and-reasoning)；如果要查可落地的工程做法，查看 [项目与实验](/shed/projects) 和 [工程经验与踩坑](/shed/engineering-notes)。

完整的 Notion 页面映射、重复项和内容边界记录在 [Notion 来源索引](/appendix/notion-sources)。
