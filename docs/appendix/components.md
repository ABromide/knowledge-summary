# Markdown 组件示例

VitePress 支持标准 Markdown、代码高亮、表格和提示块，也可以直接使用注册过的 Vue 组件。

## 提示块

::: tip 提示
适合补充方法、捷径或推荐实践。
:::

::: warning 注意
适合说明限制、成本或容易忽略的前置条件。
:::

::: danger 风险
适合说明可能带来数据、安全或生产影响的操作。
:::

## 代码块

```ts
type Note = {
  question: string
  conclusion: string
  evidence: string[]
  nextAction?: string
}
```

## 表格

| 组件 | 用途 |
| --- | --- |
| `SummaryHero` | 展示章节目标、预计耗时和预期产出 |
| `StatGrid` | 展示一组关键指标或方法要点 |
| `InteractiveFlow` | 展示可选择节点、上下游关系和节点说明；用于替代前端 Mermaid 源码块 |
| `CapacityLab` | 用滑块调整容量假设并实时计算量级；结果必须附带估算边界 |
| `TradeoffExplorer` | 用场景标签比较收益、代价和验证动作 |
| `TopologyExplorer` | 用可切换关系图解释集合通信与并行维度的拓扑放置 |
| `ResearchWorkbench` | 用 Tabs 切换论文阅读视角、关键证据与下一步验证动作 |
| `PaperCatalog` | 搜索并按主题筛选论文、模型和工程资料 |
| `ZoomableImage` | 将论文配图呈现为可放大、缩小、还原和关闭的图片预览 |
