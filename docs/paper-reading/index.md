---
title: 论文速读
description: 模型、强化学习、Agent、VLA、数据、评估与理论资料的主题化阅读索引。
pageClass: paper-reading-page
---

# 论文速读

<SummaryHero
  :goals="['理解研究问题', '掌握关键机制与公式', '形成可验证的工程判断']"
  duration="约 15 分钟"
  output="完整论文阅读地图"
>

本页由“论文速读”原始笔记按主题重组。每项资料直接说明阅读用途与需要继续核验的边界，便于按主题定位和延伸阅读。

</SummaryHero>

<ResearchWorkbench preset="overview" />

<PaperCatalog />

<PaperPageNavigator />

## AI 辅助阅读：模型

### 1. Attention Residuals {#model-attention-residuals}

> **资料**：[Attention-residuals](https://li.feishu.cn/docx/DqjKdMYtroIIncxD9nmcDpJWnRe)
>
> **用途**：关注注意力层与残差路径的结构设计，用于理解信息在深层网络中的保留、组合与稳定传播。
>
> **核验 / 局限**：核验具体结构、对照基线、参数量和训练预算；仅有标题无法判断收益来自架构本身还是训练配置。

### 2. 类型系统与 AI Coding {#model-type-system-ai-coding}

> **资料**：[summary-type-system-ai-coding-20260318](https://li.feishu.cn/docx/Ry7vdNtXVoSoRExQuzucexAanhb)
>
> **用途**：聚焦类型系统与 AI Coding 的结合，用于分析类型信息如何约束代码生成、补全和静态验证。
>
> **核验 / 局限**：继续确认覆盖的语言、错误类型、评测集与实际修复率；类型正确不等于业务语义正确。

### 3. Skill 评估 {#model-skill-evaluation}

> **资料**：[Skill 评估指南](https://agentskills.io/skill-creation/evaluating-skills)
>
> **用途**：提供 Skill 创建后的评估入口，用于设计成功率、稳定性、触发准确性和回归测试。
>
> **核验 / 局限**：需要把通用指南转换为项目自己的任务集、失败分类与人工基线，并检查文档版本及适用平台。

### 4. Llama Nemotron {#model-llama-nemotron}

> **资料**：[summary-llama-nemotron-20260325](https://li.feishu.cn/docx/ZgMfdjYN6oxFnZx1I5wcL8t9nZg)
>
> **用途**：了解 Llama Nemotron 的模型定位、训练方法与推理能力，作为开放模型选型材料。
>
> **核验 / 局限**：核验模型具体版本、许可证、上下文长度、推理成本及公开基准的复现条件，避免跨版本比较。

### 5. Nemotron Cascade 2 {#model-nemotron-cascade-2}

> **资料**：[summary-nemotron-cascade2-20260325](https://li.feishu.cn/docx/VLyrd8YeUoZTNUx8Cn0cmlj4nJb)
>
> **用途**：关注级联式训练或推理方案，用于比较单模型与多阶段能力增强路线。
>
> **核验 / 局限**：确认 Cascade 2 的阶段定义、数据流、教师信号和消融实验，并衡量级联带来的延迟与成本。

### 6. Agentic 能力拆解 {#model-agentic-capability-glm5}

> **资料**：[Agentic 能力拆解](https://li.feishu.cn/docx/QvWBdezN3orc6mxvnpPctuf2nxd)，拆分 GLM-5 的训练全过程。
>
> **用途**：建立预训练、后训练、工具使用与任务评估之间的 Agent 能力地图。
>
> **核验 / 局限**：区分公开事实、作者推断和经验总结，并核验训练数据、奖励设计、工具环境及各阶段贡献。

### 7. Gemma 4 31B IT {#model-gemma-4-31b-it}

> **资料**：[gemma-4-31b-it-analysis](https://li.feishu.cn/docx/GYA2dKRQRosJeMxwlELcki1pnVb)
>
> **用途**：面向 Gemma 4 31B 指令模型的技术解读，用于模型能力、部署资源和适用场景选型。
>
> **核验 / 局限**：核验正式模型卡、许可证、量化影响、硬件吞吐和目标任务实测；单一综合榜单不足以支撑生产选型。

### 8. HY-OmniWeaving {#model-hy-omniweaving}

> **资料**：[HY-OmniWeaving-Analysis](https://li.feishu.cn/docx/CdCqdc1cOoPXVexrN3jcOC7Unoc)
>
> **用途**：关注混元 OmniWeaving 的多模态或全模态能力组织方式，用于理解跨模态生成与统一建模路线。
>
> **核验 / 局限**：确认实际支持的模态、输入输出限制、数据与安全过滤策略，并通过跨模态一致性案例验证效果。

### 9. Qwen3.6-27B {#model-qwen-3-6-27b}

> **资料**：[Qwen3.6-27B 深度技术解读](https://li.feishu.cn/docx/S1Iddd2WGoSHcSxMXutcB9DNnDh)
>
> **用途**：了解 Qwen3.6-27B 的架构、训练和能力边界，支持同尺寸模型的选型比较。
>
> **核验 / 局限**：核验模型版本与官方材料，统一精度、上下文、硬件和提示词后再比较；关注中文、代码和 Agent 任务的分项表现。

### 10. LoRA 与 SFT 参数 {#model-lora-vs-sft}

> **资料**：[LoRA 技术文章](https://thinkingmachines.ai/blog/lora/)
>
> **用途**：探究 LoRA 和 SFT 的参数关系，用于理解低秩适配的可训练参数、容量和微调成本。
>
> **核验 / 局限**：复核公式、秩与显存/效果的关系，并在目标模型和数据上做全参 SFT 对照；单篇博客结论不宜直接泛化。

## AI 辅助阅读：产品相关

### 11. CodeMender 自动修复安全漏洞 {#product-codemender}

> **资料**：[CodeMender：AI Agent 如何自动修复代码安全漏洞](https://li.feishu.cn/docx/BxlcdAkLGoVEiUxYCIVc0LxanMe)
>
> **用途**：关注漏洞发现、补丁生成和验证闭环，用于设计安全修复 Agent 的工作流。
>
> **核验 / 局限**：核验漏洞集、补丁正确率、测试与静态分析门禁、误修率及人工介入比例；“生成补丁”不能替代可利用性与回归验证。

### 12. 人与 AI 的 Coding 协作边界 {#product-human-ai-collaboration}

> **资料**：[探索人与 AI 协作的边界——AI Coding 领域](https://li.feishu.cn/slides/WBS6sdF4PlLDnwdwJPIcks1enEU)
>
> **用途**：分析人机分工、审查责任和 AI Coding 的适用边界。
>
> **核验 / 局限**：提炼可量化的人效、质量和风险指标，并用真实开发任务验证；经验性案例可能受团队成熟度影响。

### 13. Anthropic Agent Evals {#product-anthropic-agent-evals}

> **资料**：[面向 Agent 场景的评估方法——Anthropic Agent Evals 探索](https://li.feishu.cn/wiki/Jl4JwUUeYidHhxkUk5MclEodnEh)
>
> **用途**：构建多步任务、工具调用、轨迹质量和最终结果相结合的 Agent 评估体系。
>
> **核验 / 局限**：核验任务代表性、评分器一致性、重复运行方差与污染风险；终态成功率之外还应记录成本和失败轨迹。

### 14. agent-insight 与 AgentHub {#product-agent-insight-agenthub}

> **资料**：[agent-insight：基于 Agent 生态的 Skill 生成优化与评估平台](https://gitcode.com/openeuler/agent-insight#%E4%BC%98%E5%8C%96-skill) / [AgentHub](https://www.agenthub.build/?ref=huntscreens.com)
>
> **用途**：前者面向 Skill 生成、优化与评估，后者可作为 Agent / Skill 生态参考，用于比较资产生产和分发方式。
>
> **核验 / 局限**：分别核验开源代码、维护活跃度、评估可复现性与平台收录规则；两个链接定位不同，不能把生态展示当成能力质量证明。

### 15. OpenClaw 分布式 Agent Platform {#product-openclaw-distributed-platform}

> **资料**：[分布式 Agent Platform 与多人协作 Agentic Loop](https://lfc-qu3actyc.cnhb01-dev.fc.chj.cloud/index.html)
>
> **用途**：把 OpenClaw 做成分布式 Agent Platform，同时跑通多人协作的 Agentic Loop，用于观察编排、状态同步与协作界面。
>
> **核验 / 局限**：实测并发、故障恢复、权限隔离、状态一致性和可观测性；临时部署地址的可用性与实现细节可能变化。

### 16. 前端技术栈 {#product-frontend-tech-stack}

> **资料**：[ChatGPT 共享讨论](https://chatgpt.com/share/6a420fb0-db04-83ec-b9bf-2245ced877b3)
>
> **用途**：记录前端技术选型线索，用于快速回顾框架、组件和工程方案。
>
> **核验 / 局限**：共享对话可能失效或缺少最终决策上下文；应把候选方案与当前仓库依赖、构建体积、可访问性和维护成本逐项核验。

### 17. UI 设计参考 {#product-ui-design}

> **资料**：[掘金文章](https://juejin.cn/post/7073442264688623647)、[知乎文章](https://zhuanlan.zhihu.com/p/664783228)
>
> **用途**：整理布局、视觉层级和交互设计原则。
>
> **核验 / 局限**：核验文章发布时间、目标端和设计规范，并通过实际页面的桌面/移动端、深浅色与键盘操作验证；参考案例不等于可直接复用的设计系统。

### 18. Easy Vibe 前端 {#product-easy-vibe-frontend}

> **资料**：[Easy Vibe：Figma / MasterGo](https://datawhalechina.github.io/easy-vibe/zh-cn/stage-2/frontend/figma-mastergo/)
>
> **用途**：提供从设计工具到前端实现的学习路径，用于建立原型和设计交付基础。
>
> **核验 / 局限**：按当前工具版本走通完整示例，并确认导出物、组件规范和代码实现之间的差距；教程流程未必覆盖生产工程约束。

## 业务算法

### 1. 可信多模态审核 {#business-multimodal-moderation}

> **资料**：[Towards Trustworthy Multimodal Moderation via Policy-Aligned Reasoning and Hierarchical Labeling](https://li.feishu.cn/wiki/LEbsw0CcViB3PIkWy5bcaRyGnJe)
>
> **用途**：关注审核策略、推理过程和层级标签体系，用于提升多模态内容审核的可解释性与策略一致性。
>
> **核验 / 局限**：核验数据来源、标签一致性、不同模态与风险类别的召回/误杀，以及策略更新后的迁移能力；可解释推理文本本身不保证决策真实可靠。

### 2. 智能体强化用于测试与静态检测修复 {#business-agent-rl-testing-static-fix}

> **资料**：[智能体强化在测试用例和静态检测修复的应用](https://li.feishu.cn/docx/Vh1XdxoX4ob8CBx6iy5c6QhYndQ?preview_comment_id=7654924138213117125)
>
> **用途**：在有“规则”判断的 Agent 场景中，通过 guide、指向性 mask、拒绝采样等方法优化测试生成与静态检测修复。
>
> **核验 / 局限**：分别做 guide、mask、拒绝采样的消融，核验规则判定器的误差、奖励投机、修复通过率和回归风险；规则可判定不代表真实语义已覆盖。

### 3. 蚂蚁阿福医疗 Agent {#business-medical-agent-ant-a-fu}

> **资料**：[蚂蚁阿福：从 0 到生产的医疗 Agent 工程化落地](https://mp.weixin.qq.com/s/GQwCRSrXBjSlTE4TEY_wfQ)
>
> **用途**：提供医疗 Agent 从原型到生产的工程案例，用于分析知识、工具、评测、风控和运营闭环。
>
> **核验 / 局限**：医疗属于高风险场景，应核验临床证据、数据合规、医生审核、拒答与追责机制；企业案例中的指标和实现细节可能不完整。

## 安全

### 1. Joern 与代码属性图 {#security-joern-cpg}

> **资料**：[Joern 与 CPG](https://cloud.tencent.com/developer/article/2345095)
>
> **用途**：理解如何把语法、控制流和数据流统一到代码属性图中，支撑漏洞查询与污点分析。
>
> **核验 / 局限**：用目标语言和真实漏洞样例核验前端解析、跨过程数据流、查询准确率与性能；二手文章应与 Joern 官方文档和当前版本对照。

### 2. Tree-sitter {#security-tree-sitter}

> **资料**：[Tree-sitter](https://zhuanlan.zhihu.com/p/716273346)
>
> **用途**：理解增量语法解析及多语言语法树，用于代码索引、编辑器能力和轻量静态分析。
>
> **核验 / 局限**：核验目标语言 grammar 的完整性、错误恢复和版本兼容；Tree-sitter 主要提供语法结构，不能单独替代语义、控制流和数据流分析。

### 3. 待补安全条目 {#security-tbd-3}

> **资料**：原始笔记当前为空，尚未提供可定位的安全主题或链接。
>
> **用途**：保留该编号，如实标记索引中的待补位置。
>
> **核验 / 局限**：后续需补充标题、来源链接、预期用途与核验标准；在补充前不应据此推导任何安全结论。
