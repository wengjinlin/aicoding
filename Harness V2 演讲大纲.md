# Harness V2 演讲大纲

> **主题**：从 Vibe Coding 到工程化护栏 — Harness V2 架构与落地
> **建议时长**：60-90 分钟

---

## 一、开场：AI Coding 的现状与痛点

- 真实场景：AI 加字段却顺手重构、假报测试通过
- 痛点：正确性失控 / 架构一致性缺失 / 需求歧义 / 缺乏可追溯性
- 三次范式跃迁：Prompt → Context → Harness
- 渐进路径：Rule → Spec → Loop → Harness
- 金句：Harness 让 AI 的聪明可被组织信任

---

## 二、Harness 是什么

- 定义：为 Claude Code 设计的分层 AI 开发工作流架构
- 七大理念：规范先行 / 纪律内置 / 审查自适应 / 编排自动化 / 领域感知 / 工具精确 / 越用越聪明
- 衰变定律：模型越强，Harness 越简单

---

## 三、七层架构

- **L1 规范层**（OpenSpec）：proposal → specs → design → tasks
- **L2 纪律层**（Superpowers）：TDD 红绿重构 5 步强约束
- **L3 审查层**（双轨）：quick-review 3 关 / gstack 9 关自动路由
- **L4 领域知识层**（ECC 技能）：springboot / jpa / api
- **L5 工具精度层**（OMC MCP）：LSP + AST
- **L6 持续学习层**（ECC 本能）：跨会话知识沉淀
- **L7 编排层**（HyperSpec）：12 checkpoint 状态机
- **横切保护层**：4 个 Hook + 模型路由（haiku/sonnet/opus）


---

## 四、落地实操

- 时间预算：4-6 天（准备 0.5 / 分层 2-3 / 文档 1-2 / 验证 0.5）
- 适配性：Spring Boot 后端、≥3 人团队、长期维护项目
- 分层落地：L1→L7 逐层独立配置
- 项目文档：8 类文档让 AI 读代码自动生成
- 实战演示：PLM变体视图接口，60-100 分钟跑通

---

## 五、Agent Team 角色编排

- 方案：单实例多角色（不引入多 agent 框架）
- 8 角色：PM / Architect / Tech Lead / Developer / Reviewer / Tester / DevOps / Coordinator
- 关键设计：Reviewer 用 opus 避免共谋；Coordinator 用 haiku 省 token
- 交接方式：工件驱动，不靠记忆

