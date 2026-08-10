---
title: 工程经验与踩坑
description: 从 Ebitengine 桌面应用和 verl 训练环境故障中提炼的可复用工程守则。
---

# 工程经验与踩坑

本页合并 Notion「知识条目」与「踩坑记录」。两个同名的 Ebitengine 中文渲染记录内容重复，站内只保留一份结论。

## Go + Ebitengine 桌面像素应用

### 技术选择

Go + Ebitengine 适合低占用桌面小工具：可编译为单文件、运行时依赖少，并支持透明窗口、置顶和无边框。它的优势来自明确的小型 2D 场景，不应扩展成所有桌面 UI 的通用选择。

### 精灵与动画

- 用数字矩阵表示颜色区域，运行时映射皮肤；一套形状可复用多套配色。
- 用 Pixel Delta 记录变更像素，适合低分辨率动作。
- 配饰作为独立叠加层，不修改基础精灵。
- 动作与台词使用独立随机定时器，避免相互阻塞和机械节奏。
- 固定窗口尺寸配合 hover 显隐，比动态缩放更稳定。

### 透明窗口 UI

透明窗口上不适合覆盖大块不透明背景。交互元素应尽量与像素视觉语言一致，并检查拖拽、焦点和点击区域是否仍然清晰。

## 踩坑一：DebugPrint 不显示中文

### 症状

`ebitenutil.DebugPrintAt` 渲染中文或 emoji 时，文字被静默跳过，只看到背景，不抛出错误。

### 根因

内置 bitmap 字体只覆盖 ASCII 可打印字符（`0x20—0x7E`），不是完整 Unicode 字体。这是能力边界，不是业务逻辑 bug。

### 方案

- 如果像素风允许，只使用 ASCII，保持零额外字体依赖；
- 如果必须显示中文，使用 `text/v2` 加载支持 CJK 的 `.ttf`，并接受二进制体积增长。

### 可复用规则

在确定文案系统前先做最小字符集渲染测试，覆盖中文、标点、emoji 和目标平台字体打包。

## 踩坑二：verl 启动失败形成版本错误链

### 症状

一次 GRPO 训练启动先后暴露 `transformers` 导入、FSDP wrap policy、vLLM API、CUDA kernel、显存 profiling 和 sampler OOM 等九类错误。逐个 monkey patch 只能不断揭开下一层不兼容。

### 根因

- `transformers` 已升级到 5.2.0，而旧版 verl 预期 4.x；
- vLLM 是自定义 dev build，版本号与实际 API 不一致；
- Ray Worker 不继承主进程的 `PYTHONPATH` patch；
- 共享 GPU 中其他进程释放显存，会让 vLLM profiling 的假设失效。

### 最终处理方向

升级 verl 核心代码以恢复与新依赖的大范围兼容，只对自定义 vLLM 的版本/API 差异做少量定向 patch，并降低 `gpu_memory_utilization`、`max_num_seqs`，关闭冲突的 offload 配置。

### 更重要的诊断顺序

1. 先输出 Python、CUDA、torch、transformers、vLLM、训练框架版本；
2. 与框架 lockfile / requirements / 官方兼容矩阵比对；
3. 判断问题是单点 API 变化还是整体版本漂移；
4. 整体漂移时优先恢复可复现环境或升级框架，不连续叠加 monkey patch；
5. 使用容器或锁定环境保存最终可运行组合；
6. 在独占或已知负载的 GPU 上做显存与性能验证。

## 工程守则摘要

- 先验证依赖契约，再解释表面错误。
- 最小复现必须进入真实子进程 / Worker 环境。
- 一次补丁解决一个已证实的不兼容，不用 patch 掩盖版本矩阵失控。
- 对“成功启动”继续验证训练指标、显存、输出产物和可重复启动。
- 重复踩坑条目在展示层合并，但在 [Notion 来源索引](/appendix/notion-sources) 保留两个源记录。

## 来源

- [Notion：Ebitengine 桌面像素应用开发经验](https://app.notion.com/p/Ebitengine-33c3a54bd6b481df8a64ff98f674358f)
- [Notion：DebugPrint 中文渲染记录 A](https://app.notion.com/p/Ebitengine-DebugPrint-33c3a54bd6b481c29d2fd39a54f60cec)
- [Notion：DebugPrint 中文渲染记录 B](https://app.notion.com/p/Ebitengine-DebugPrint-33c3a54bd6b48181b973f809fab6a09e)
- [Notion：verl 环境版本漂移记录](https://app.notion.com/p/verl-RL-9-33c3a54bd6b481f8a321c1a78c271d7f)
