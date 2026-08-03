# 03 · 自主智能体（Autonomous Agent）类

> **类别定义**：云端运行的 Agent，接收一个高层任务描述（如"实现这个 GitHub issue"），自主完成规划、写码、测试、提 PR 的全流程。区别于 CLI/IDE——**它不需要你盯着屏幕**。

---

## 速览表

| 工具 | 母公司 / 国家 | 开源 | 核心能力 | 部署方式 | 价格 |
|------|--------------|------|---------|---------|------|
| **Devin** | Cognition AI / 美国 | ❌ | 全自主软件工程师 | 云 SaaS | $500/月起（企业） |
| **OpenHands** | All Hands AI / 美国 | ✅ MIT | Devin 开源替代 | 自托管 / 云 | 免费 + 商用支持 |
| **SWE-agent** | Princeton NLP / 美国 | ✅ MIT | SWE-bench 评测系 Agent | 自托管 | 免费 |
| **Devika** | Stitionai / 印度 | ✅ MIT | Devin 的早期开源 clone | 自托管 | 免费 |
| **Factory** | Factory AI / 美国 | ❌ | 企业级 Agent 团队 | 云 | 企业议价 |
| **CodeRabbit** | CodeRabbit / 美国 | ❌ | PR 自动审查 Agent | 云 | $12/月起 |
| **Graphite AI Reviewer** | Graphite / 美国 | ❌ | PR 审查 + 自动修复 | 云 | 免费 + 订阅 |
| **Pull Request Rabbit / Diamond** | 各家 | — | PR 审查 | 云 | — |

---

## 1. Devin（Cognition AI）

- **母公司**：Cognition AI（美国，旧金山）——2024 年 3 月发布，号称"首个 AI 软件工程师"。
- **开源状态**：❌ 闭源
- **核心能力**：
  - 接收任务描述 → 自主规划 → 写码 → 跑测试 → 提 PR
  - 并行云端 Agent（多个任务同时跑）
  - 集成 Slack / GitHub / Jira / Linear 等工作流
- **基准成绩**：
  - 2024 年 3 月发布时：SWE-bench 端到端 13.86%
  - 2026 年第三方报告：明显进步，但具体数字有争议
- **社区口碑**：
  - **初期批评激烈**："演示视频被夸大"等质疑声 2024 年持续发酵
  - **2025–2026 年回暖**：Goldman Sachs、IBM 等大企业"雇佣 Devin"作为 AI 员工
  - Reddit 长帖讨论："Devin 适合什么场景"——共识是**重复性、可批量的明确任务**，而非复杂多步设计
- **价格**：$500/月（团队版起），贵但企业愿意付。
- **典型场景**：大企业想"外包"批量 issue、PR 自动化、SaaS 维护。

---

## 2. OpenHands（前身 OpenDevin）

- **母公司**：All Hands AI（美国，由 Princeton 研究人员创办）
- **开源状态**：✅ MIT
- **核心能力**：Devin 的开源替代，支持：
  - 多 Agent 协作（Planner / Coder / Reviewer）
  - 浏览器操作（解决前端 issue）
  - 调用任意 LLM（BYOK）
- **部署**：Docker 自托管或云
- **基准成绩**：SWE-bench Verified 高分保持者之一（不同模型搭配下分数差异大）
- **社区口碑**：**开源自主 Agent 的事实标准**。HN/Reddit 推崇。
- **价格**：免费；商用支持另议。
- **典型场景**：想自托管 Devin 替代品的研究/工程团队。

---

## 3. SWE-agent

- **母公司**：Princeton NLP Lab（美国，学术项目）
- **开源状态**：✅ MIT
- **核心能力**：**SWE-bench 的官方搭档 Agent**——Agent Computer Interface (ACI) 是它的核心创新。学术属性强。
- **典型场景**：评测研究、复现论文、对比 baseline。

---

## 4. Devika

- **母公司**：Stitionai（印度）
- **开源状态**：✅ MIT
- **核心能力**：Devin 火爆后的第一个开源 clone，2024 年 4 月起迅速崛起。
- **社区口碑**：起步猛、维护节奏放缓，2025 年后被 OpenHands 盖过。
- **典型场景**：学习/玩具项目，不建议生产。

---

## 5. Factory

- **母公司**：Factory AI（美国，旧金山）
- **开源状态**：❌ 闭源
- **核心能力**：企业级"Agent 团队"——多个专精 Agent（前端 / 后端 / 测试 / 审查）协作。
- **典型场景**：企业大规模工程外包、跨团队代码统一改造。

---

## 6. CodeRabbit / Graphite AI / 其他 PR 审查 Agent

这是一类**垂直 Agent**——不做开发，只做 PR 自动审查。

| 工具 | 定位 | 价格 |
|------|------|------|
| **CodeRabbit** | 自动 PR Review，逐行评论 | $12/月起 |
| **Graphite AI Reviewer** | 智能 Review + 自动修复建议 | 免费 + 订阅 |
| **Diamond (CodeRabbit)** | 高级版 + 修复执行 | 企业版 |

**口碑**：CodeRabbit 在 GitHub 开源项目渗透率最高；Graphite 体验更轻。

---

## 横向点评

### "自主度"排序

```
Devin（全自主，云端跑）> Factory ≈ OpenHands
> SWE-agent（评测向）> Devika（早期）> CodeRabbit（仅审查）
```

### "可靠性"排序（综合第三方评测）

```
OpenHands（开源 + 自托管）≈ Devin（商业 + 闭源）
> Factory > SWE-agent（学术向）
> Devika
```

### Harness V2 视角的提示

Harness V2 不直接对接 Devin/Factory 这种云端 Agent——它们是**黑盒**，无法塞入 HyperSpec 检查点机。但可以：
- 让 Devin 跑完后**人工把 PR 拉下来**，进入 HyperSpec 的 `reviewed` 检查点
- 让 CodeRabbit 作为 `review-request` 后的**辅助 Reviewer**（但不应替代主 Reviewer，因为不可控）

---

下一章：[`04-china-tools.md`](./04-china-tools.md)
