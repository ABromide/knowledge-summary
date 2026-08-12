---
title: Agent 研究雷达
description: 从 2026-03-05 arXiv 日报与 2026-03-03 GitHub Trending 中提炼的阶段性趋势。
---

# Agent 研究雷达

这一页是时间快照，不是长期定论。材料分别来自 2026-03-05 的 arXiv AI 论文日报和 2026-03-03 的 GitHub Trending 技术报告。

## 论文侧的四条信号

1. **多 Agent 拓扑开始进入可学习对象。** Graph-GRPO、CARD 等工作不再只固定协作结构，而是研究拓扑选择与稳定训练。
2. **检索与策略优化进一步融合。** RAPO、Search-R2 等方向把“何时检索、如何筛选证据”纳入策略和奖励，而不是只把搜索当外部 API。
3. **长程任务需要层级策略。** HiMAC 一类工作区分宏观规划与微观执行，说明单一逐 token 策略难以覆盖长时间尺度。
4. **评估平台的重要性上升。** MOSAIC、自动补丁系统研究反映出跨范式对比、真实环境验证和可重复评估正在成为核心基础设施。

## 开源项目侧的工程信号

原 GitHub Trending 报告把项目按 Agent 框架、MCP / 工具生态、模型应用和开发工具分类。对内部 Agent 平台最值得保留的不是某个榜单名次，而是三类工程模式：

- Monorepo 与子包边界怎样承载快速变化的 Agent 模块；
- MCP 等协议怎样接入工具，同时保留权限、审计和失败回退；
- UI、会话状态与执行轨迹怎样形成可观测的产品闭环。

## 使用限制

- 日报只覆盖一天的 arXiv 新增，不能代表完整研究版图。
- Trending 受短期传播与社区热度影响，不等于技术成熟度。
- 进入项目选型前，必须重新核对当前版本、维护活跃度、许可证和真实 benchmark。

## 来源

- [Notion：arXiv AI 论文日报 2026-03-05](https://app.notion.com/p/arXiv-AI-2026-03-05-31a3a54bd6b481bcabc5fa6b973c722b)
- [Notion：GitHub Trending 技术报告 2026-03-03](https://app.notion.com/p/GitHub-Trending-2026-03-03-3183a54bd6b4810b91cece6da8f5a7f1)
