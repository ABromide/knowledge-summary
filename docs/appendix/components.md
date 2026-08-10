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
