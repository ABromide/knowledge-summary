---
title: AI 时代的编程初体验
description: 通过一个 AI 原生小游戏，理解对话式开发的能力边界、迭代方法与工程守则。
pageClass: ai-capabilities-through-games
---

<script setup>
const learningSteps = [
  { title: '困境与机会', description: '理解新的开发入口' },
  { title: '能力初探', description: '完成最小可玩原型' },
  { title: '原生实战', description: '接入生成式能力' },
  { title: '拓展创造', description: '迁移到新的项目' }
]

const capabilityItems = [
  {
    icon: '🧩',
    title: '单页原型与轻量工具',
    description: '目标清晰、反馈可见，适合快速生成第一版并在浏览器中验收。',
    level: 'good',
    label: '适合 AI 主导'
  },
  {
    icon: '🎮',
    title: '小游戏与交互实验',
    description: '玩法边界明确，可以通过多轮对话逐步校准手感、视觉和状态。',
    level: 'good',
    label: '适合快速迭代'
  },
  {
    icon: '🏗️',
    title: '复杂产品与系统集成',
    description: '涉及数据库、权限、并发和跨服务协作，需要人来负责拆解与架构。',
    level: 'human',
    label: '需要工程主导'
  },
  {
    icon: '🛡️',
    title: '支付、医疗与合规场景',
    description: '错误成本高，生成代码必须经过威胁分析、测试、评审与人工确认。',
    level: 'strict',
    label: '必须严格审查'
  }
]
</script>

# AI 时代的编程初体验

这一章采用项目制学习：不从语法清单开始，而是先做出一个能玩的网页小游戏，再从真实反馈中理解 AI 编程究竟擅长什么、哪里仍然需要人的判断。

<div class="completion-note">先让想法跑起来，再把它一步步变好 🐣</div>

<div class="source-notice">
本页改编自 Datawhale 的
<a href="https://datawhalechina.github.io/easy-vibe/zh-cn/stage-1/ai-capabilities-through-games/" target="_blank" rel="noreferrer">Easy-Vibe 对应章节</a>
，遵循 CC BY-NC-SA 4.0。正文为独立改写的学习摘要，组件与视觉适配由本项目重新实现，未复制原站截图。
</div>

## 本章导读

<SummaryHero
  :goals="['对话式 AI 编程', 'AI 原生小游戏', '验证与迭代']"
  duration="约 2 小时，可分多次练习"
  output="1 个可玩的贪吃蛇原型 + 1 份迭代记录"
>

你会从一句自然语言需求出发，逐步完成基础玩法、单词收集和生成式内容三个版本。重点不是让 AI 一次写对全部代码，而是学会定义目标、观察结果、描述偏差并验证修复。

</SummaryHero>

<LearningSteps :active="0" :items="learningSteps" />

## 1. 普通人的困境与机会

许多产品点子并不复杂：记录习惯、整理家庭照片、展示一组数据，或者做一个有趣的浏览器游戏。过去，想法与可运行产品之间往往隔着环境配置、编程语言、框架和部署流程。

对话式开发改变的是入口。你可以先用自然语言说明用户要完成什么、页面有哪些状态、点击后发生什么，再让 AI 生成可运行的第一版。这样不会消除工程问题，却能显著缩短从想法到可验证结果的距离。

<StatGrid
  title="一次有效开发对话需要交代四件事"
  :items="[
    { value: '1 个', label: '明确目标' },
    { value: '3 类', label: '关键状态' },
    { value: '1 组', label: '验收标准' },
    { value: '1 次', label: '真实验证' }
  ]"
/>

真正重要的新能力不是“让 AI 写代码”，而是把模糊想法转换成可以观察、可以测试、可以逐步修正的任务。

## 2. AI 能帮你做到什么程度

当前 AI 很适合处理边界清楚、结果可见、纠错直接的任务。任务越依赖隐含业务规则、长期运行状态或安全边界，人就越需要主动掌控设计和验证。

<CapabilityBoard :items="capabilityItems" />

### 2.1 用一个最小贪吃蛇验证能力

第一次对话只要求一个最小可玩版本。不要在同一轮加入账号、排行榜、多人联机和复杂动画，否则你很难判断失败来自哪一部分。

```text
请创建一个浏览器贪吃蛇小游戏：
- 使用方向键控制移动
- 吃到食物后增加长度和分数
- 撞墙或碰到自己时结束
- 提供开始与重新开始按钮
- 页面需要适配桌面和手机
```

拿到结果后，先完成一轮人工验收：

1. 开始按钮是否真的进入游戏状态？
2. 四个方向是否都能控制，反向操作是否合理？
3. 得分、长度和食物刷新是否同步？
4. 两类碰撞是否都能结束游戏？
5. 重新开始是否清空上一局状态？

::: details 💡 为什么先做“小而完整”的版本？
一个闭环原型能立即暴露输入、状态、渲染和结束条件之间的问题。每次只增加一个能力，失败时就更容易定位原因，也更容易判断 AI 的修改有没有破坏已有功能。
:::

### 2.2 网页编程平台改变了什么

在线 AI 开发工具通常把对话、文件生成、实时预览和发布放在同一个界面里。初学者不必先处理本地环境，也能经历完整的“描述—生成—预览—反馈”循环。

但工具替你隐藏环境，不等于环境不存在。项目进入长期维护后，仍然要面对依赖版本、浏览器差异、数据存储、权限、安全和部署等工程问题。

### 2.3 能写出来，不等于可以上线

判断一段 AI 生成代码能否使用，应当同时检查三层：

| 层级 | 关键问题 | 最低验证 |
| --- | --- | --- |
| 功能 | 用户操作能否完成？ | 逐条执行验收清单 |
| 工程 | 代码能否维护和重复构建？ | 固定依赖、脚本化运行、自动测试 |
| 风险 | 失败会造成什么影响？ | 权限、输入、安全与回退评审 |

::: warning ⚠️ 能力边界
AI 很适合生成 Demo、内部工具和局部模块。涉及真实用户数据、资金、健康或合规要求时，不能把“生成成功”当成“可以上线”。
:::

<LearningSteps :active="1" :items="learningSteps" />

## 3. 动手：你的第一个 AI 原生应用

基础贪吃蛇只是容器。真正的 AI 原生玩法，是让生成式能力参与核心循环，而不是只在页面角落放一个聊天框。

### 3.1 用三轮提示词搭出完整玩法

<div class="prompt-ladder">
  <article>
    <span>VERSION 01</span>
    <strong>先保证可玩</strong>
    <p>完成移动、食物、分数、碰撞与重新开始，逐条验证状态变化。</p>
  </article>
  <article>
    <span>VERSION 02</span>
    <strong>把食物换成单词</strong>
    <p>玩家收集不同词语，页面同步展示本局已经获得的词语列表。</p>
  </article>
  <article>
    <span>VERSION 03</span>
    <strong>加入生成式输出</strong>
    <p>达到目标数量后，用收集到的词生成一段短诗，再提供重新组合入口。</p>
  </article>
</div>

拆成三轮的好处是每一步都有稳定基线。如果第三轮失败，你仍然拥有可以运行的第二版，而不是面对一个无法定位问题的巨大生成结果。

### 3.2 让玩法与 AI 真正发生关系

可以围绕“输入改变生成结果”扩展玩法：

- 不同颜色的词语改变场景风格。
- 特殊词语触发加速、减速或新的障碍。
- 收集顺序影响故事分支，而不只是词语集合。
- 每一局结束后生成可保存的诗、海报或关卡总结。
- 让模型给出目标句子，玩家按正确顺序收集词语。

每次扩展都要回答一个问题：拿掉 AI 后，这个玩法是否失去核心价值？如果答案是否定的，AI 很可能只是装饰，而不是产品机制。

### 3.3 用证据驱动修复

当按钮无响应或游戏状态异常时，不要只说“还是不行”。把问题整理成可复现材料：

```text
现象：第二局开始后分数仍然是上一局的值
复现：开始游戏 → 得 3 分 → 撞墙 → 点击重新开始
期望：分数归零，蛇回到初始长度
实际：分数显示 3，蛇长度已重置
限制：只修改重置逻辑，不调整视觉和变量名
验证：补充一个覆盖连续两局的测试
```

这种反馈同时给出事实、期望、修改边界和验收方式，远比情绪化地要求“再改一次”稳定。

<LearningSteps :active="2" :items="learningSteps" />

### 3.4 把方法迁移到其他创意

掌握“最小闭环—单点扩展—真实验证”之后，可以把同一方法迁移到不同主题：

<div class="concept-grid">
  <article><strong>🎨 生成式画廊</strong><p>上传或选择关键词，生成作品并按主题组织成展览。</p></article>
  <article><strong>🌱 虚拟植物园</strong><p>完成真实生活任务后，虚拟植物获得新的形态和故事。</p></article>
  <article><strong>🎵 节奏共创</strong><p>玩家的点击节奏成为模型继续生成旋律的输入。</p></article>
  <article><strong>🗺️ 故事地图</strong><p>每次选择都改变地点、角色关系和后续事件。</p></article>
  <article><strong>🍳 厨房挑战</strong><p>根据现有食材生成任务卡，再用步骤完成度推进游戏。</p></article>
  <article><strong>🧠 句子拼图</strong><p>模型先给出目标语义，玩家通过收集词语重建表达。</p></article>
</div>

## 4. 从公开案例中观察什么

参考页整理了多个 AI 辅助游戏案例。浏览案例时，不要只看画面，而要观察任务是怎样被拆小、反馈怎样进入下一轮，以及作者如何验证生成结果。

<div class="case-grid">
  <article>
    <strong>WotAI Games</strong>
    <p>观察多个经典玩法如何共享页面骨架、输入系统和排行榜能力。</p>
    <a href="https://games.wotai.co/" target="_blank" rel="noreferrer">访问案例 ↗</a>
  </article>
  <article>
    <strong>Blooming Garden</strong>
    <p>观察简单合并规则如何通过动画、反馈和移动适配形成完整体验。</p>
    <a href="https://in0ho1no.github.io/2025-adhoc-blooming-garden/" target="_blank" rel="noreferrer">访问案例 ↗</a>
  </article>
  <article>
    <strong>CraftMine</strong>
    <p>观察复杂玩法在单一浏览器项目中如何逐步增加内容和规则。</p>
    <a href="https://tront.xyz/craftmine/" target="_blank" rel="noreferrer">访问案例 ↗</a>
  </article>
  <article>
    <strong>Mini Browser Games</strong>
    <p>观察大量小项目如何通过统一目录、零依赖交付和持续迭代管理。</p>
    <a href="https://wangzifan396-wzf.github.io/mini-browser-games/" target="_blank" rel="noreferrer">访问案例 ↗</a>
  </article>
</div>

这些案例共同说明：AI 可以提高原型速度，但可玩性来自持续观察和选择。范围、交互、节奏、错误处理和发布质量，仍然需要创作者负责。

<LearningSteps :active="3" :items="learningSteps" />

## 5. 本章作业

<div class="assignment-card">
  <strong>🎯 完成一个可验证的 AI 原生小游戏</strong>
  <ol>
    <li>完成基础贪吃蛇，并保存一份逐项验收结果。</li>
    <li>增加一个会改变核心玩法的 AI 能力，而不是装饰性聊天框。</li>
    <li>记录至少一次失败：现象、复现步骤、修改范围和最终验证。</li>
    <li>使用静态地址发布，让另一位用户独立完成一局游戏。</li>
  </ol>
</div>

完成标准不是代码行数，也不是界面看起来复杂，而是陌生用户能打开、理解、操作，并且你能解释每个关键决策为什么存在。

## 附录 1：要不要先学前端

你不必先掌握所有语法，但理解三个基本角色会让需求更清晰：

<div class="concept-grid">
  <article><strong>HTML · 页面有什么</strong><p>标题、按钮、输入框、画布和内容结构。</p></article>
  <article><strong>CSS · 页面长什么样</strong><p>颜色、间距、布局、响应式和动画反馈。</p></article>
  <article><strong>JavaScript · 页面如何变化</strong><p>输入、状态、计时器、碰撞检测和网络请求。</p></article>
  <article><strong>框架 · 怎样组织复杂页面</strong><p>用组件、路由和状态管理降低长期维护成本。</p></article>
</div>

## 附录 2：什么是 Vibe Coding

Vibe Coding 可以理解为以自然语言描述意图，由模型生成和修改代码，再由人持续体验、判断和反馈的开发方式。它降低了编码入口，但没有取消需求分析、工程设计和质量责任。

更稳妥的协作方式是：

1. 用明确目标和验收标准启动任务。
2. 让 AI 解释它准备修改的范围。
3. 一次只完成一个可验证变化。
4. 使用测试、日志和真实页面确认结果。
5. 将稳定结论写回代码、文档和脚本，而不是只留在对话里。

## 附录 3：模型上下文

上下文是模型在当前任务中能够使用的信息，包括指令、历史对话、代码和资料。内容过多时，早期约束可能被弱化，模型也更容易混淆当前版本与旧版本。

工程实践中应当主动压缩上下文：只提供与问题有关的文件、说明当前代码基线、标明不可修改区域，并在长任务中重复确认目标和验收标准。

## 附录 4：指令遵循能力

好的模型输出不仅要“看起来合理”，还要满足数量、格式、范围和行为要求。评价一次修改时，应检查它是否完成全部指定项、是否擅自扩展范围、是否保留现有接口，以及验证结果能否重复。

本仓库已经把这些经验整理为 [开发守则](/appendix/development-rules)，后续页面和功能修改都应按该文档执行。

## 参考与说明

- 页面结构参考：[Easy-Vibe · AI 时代的编程初体验](https://datawhalechina.github.io/easy-vibe/zh-cn/stage-1/ai-capabilities-through-games/)
- 固定源码版本：[datawhalechina/easy-vibe@59d0a239](https://github.com/datawhalechina/easy-vibe/tree/59d0a239f5f4e9c20ea8a8cc69b4b34f7a5f910e)
- 上游许可：[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)
- 修改说明：正文重新总结，组件与导航重新实现，未复制上游截图；本改编页继续采用 CC BY-NC-SA 4.0，不代表 Datawhale 对本项目的认可或背书。
- 许可边界和完整归属说明见 [来源与许可](/appendix/attribution)。
