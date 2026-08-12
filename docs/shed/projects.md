---
title: 项目与实验
description: 按状态与复用价值总结技术棚屋中的 Side Project 和技术实验。
---

# 项目与实验

“技术棚屋”不是项目展示墙，而是保留每个项目的目标、关键决策、当前状态和可复用资产。以下内容来自 Notion「项目列表」，按完成、探索、归档重新分组。

<StatGrid
  title="项目状态"
  :items="[
    { value: '4', label: '已完成' },
    { value: '1', label: '探索中' },
    { value: '1', label: '已归档' },
    { value: '5', label: '主要技术栈' }
  ]"
/>

## 已完成

### daily-input-stats

本地 macOS 统计应用，按天记录键盘事件数、鼠标点击数和屏幕未休眠时的空闲时间。使用 Swift Package Manager + AppKit，数据按日写入本地 JSON，自绘紧凑仪表盘。

最重要的设计边界是隐私：只统计 `keyDown` / `mouseDown` 事件数量，不保存具体按键内容；空闲时间仅在屏幕未休眠且系统空闲超过 60 秒时累计。

### codex-stats-menubar

macOS 菜单栏 Codex 使用统计工具。它解析本地 JSONL，提供 Overview / Models 面板、热力图、模型占比和费用估算，使用 SwiftUI + AppKit `NSStatusBar` 打包为 `.app`。

可复用决策：桌面统计工具保持本地解析；运行入口统一放到 `scripts/*.sh`；AppKit 负责菜单栏生命周期，SwiftUI 负责内容界面。

### service-up

面向本地多个服务的 Textual TUI，支持统一启停、日志查看、CPU / MEM / 端口监控，以及 local、dev、ontest、prod Profile 切换。

工程亮点包括：

- `subprocess.Popen` 管理进程，`psutil` 监控资源；
- TOML 配置与 ProfileManager 生成 `env.sh`；
- token、JWT、base64 日志脱敏；
- 集中日志与统一脚本入口；
- 从 v0.1.0 的 33 个测试增长到 v0.2.0 的 42 个测试。

### pixel-pet

Go + Ebitengine 桌面像素宠物。最终形成透明无边框悬浮窗、属性与成长系统、JSON 存档、20 款皮肤、18 款配饰、22 种动作和 105 句台词。

最有复用价值的是 Pixel Delta 动画：每帧只记录发生变化的像素，而不是复制整张 16×16 精灵矩阵，使动作定义代码量减少约 90%。最终二进制约 12 MB、零运行时依赖。

## 探索中

### work-summary

目标是收集 Git 提交和 AI 对话记录，生成每日工作总结。Notion 当前只有项目摘要，没有足够的实现日志或验证结果，因此保留为“探索中”，不补写未发生的架构与成效。

下一次总结需要补齐：数据来源边界、去重规则、隐私脱敏、日报生成与发布验证。

## 已归档

### memflow-paper / MemIFC

项目尝试把信息流控制用于 Agent 持久记忆安全，经历了论文调研、形式化设计、baseline 实现和多轮评审，最终主动归档。

归档原因不是“实现没完成”，而是核心假设经不起验证：

- `derived_from` 链会导致 taint explosion；
- trust laundering 依赖真实系统并不存在的 source-based trust 标签；
- 谱分析定理错误地把线性方法用于非线性 min-label 操作；
- 写侧 trust downgrade 本质上没有超出既有 Biba 模型。

这次失败留下了更重要的研究方法：先验证攻击与系统假设，再写大量代码；应用旧理论不自动等于创新；自造数据不能替代真实系统证据；内部严苛评审应早于投稿叙事。

可复用资产包括 InjecAgent / FreshQA 数据加载器、tool-calling agent 框架、LLM-judge 评估与 ChromaDB Memory Provider。

## 跨项目共性

| 经验 | 来自项目 | 可复用判断 |
| --- | --- | --- |
| 本地优先、最小数据 | daily-input-stats、codex-stats | 统计工具不应默认采集原始敏感内容 |
| 原生容器 + 声明式 UI | 两个 Swift 项目 | 生命周期和视图职责分离 |
| 统一脚本入口 | codex-stats、service-up | 降低环境差异和运行摩擦 |
| 表达结构而不是复制帧 | pixel-pet | 对低分辨率动画使用 delta 表示 |
| 尽早证伪 | memflow-paper | 研究项目优先验证前提与真实影响 |

## 来源

- [Notion：项目列表](https://app.notion.com/p/33c3a54bd6b481f8b6c0df28e8121d21)
- [Notion：daily-input-stats](https://app.notion.com/p/daily-input-stats-macOS-Swift-36b3a54bd6b481bdb029dc27012bf4ca)
- [Notion：codex-stats-menubar](https://app.notion.com/p/codex-stats-menubar-macOS-Codex-36b3a54bd6b481409d74ec22fee5032c)
- [Notion：service-up](https://app.notion.com/p/service-up-TUI-Profile-33c3a54bd6b4816b8e8cf9db0e2a1d52)
- [Notion：pixel-pet](https://app.notion.com/p/pixel-pet-33c3a54bd6b481e5b68bf3ff8b87f365)
- [Notion：work-summary](https://app.notion.com/p/work-summary-git-AI-33d3a54bd6b481dd9f4cda362efa76b9)
- [Notion：memflow-paper](https://app.notion.com/p/memflow-paper-Agent-memory-security-via-OS-inspired-IFC-33e3a54bd6b48164900bdbbb85ae78f3)
