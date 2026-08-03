# 07 · 选型建议（基于场景）

> 没有最好的工具，只有最合适的工具。本章按"你是谁、在做什么、有什么约束"给出建议。

---

## 一、按角色选

### 1. 独立开发者 / 学生

**约束**：预算有限，希望快速上手，不想折腾。

| 推荐顺序 | 工具 | 理由 |
|---------|------|------|
| 1 | **Trae / 通义灵码** | 国内免费、开箱即用 |
| 2 | **Gemini CLI** | 国际免费、长上下文 |
| 3 | **Aider + DeepSeek API** | BYOK + 极便宜的模型，每月几美元搞定 |

### 2. 全栈工程师（小公司 / 创业）

**约束**：愿意每月付 $15–20，追求最强生产力。

| 推荐顺序 | 工具 | 理由 |
|---------|------|------|
| 1 | **Cursor Pro** | 综合体验最强 |
| 2 | **Windsurf Pro** | Cascade Agent 更放手 |
| 3 | **Claude Code Max** | 命令行重度用户 |

### 3. 大厂工程师（已有企业订阅）

**约束**：公司已采购某家工具。

| 已采购 | 建议用法 |
|-------|---------|
| GitHub Copilot Enterprise | 用其 Agent + 工作区 + CodeRabbit 辅助审查 |
| JetBrains AI Enterprise | IntelliJ 内置 + Continue 补 BYOK |
| Tabnine Enterprise | 强合规下首选，BYOK 私有部署 |

### 4. 研究者 / 学术界

**约束**：需要复现、对比、自托管。

| 推荐顺序 | 工具 | 理由 |
|---------|------|------|
| 1 | **OpenHands** | 自主 Agent 复现 baseline |
| 2 | **SWE-agent** | SWE-bench 官方搭档 |
| 3 | **Aider + 开源模型** | 完全可控 |

### 5. DevOps / SRE / 平台工程

**约束**：大量脚本、CI/CD、终端任务。

| 推荐顺序 | 工具 | 理由 |
|---------|------|------|
| 1 | **Claude Code** | Terminal-Bench 强、Skill 系统丰富 |
| 2 | **Aider** | Git-first 适合脚本仓库 |
| 3 | **opencode / Crush** | 开源替代 |

### 6. 金融 / 医疗 / 政府

**约束**：合规要求高，数据不能出境。

| 推荐顺序 | 工具 | 理由 |
|---------|------|------|
| 1 | **Tabnine Enterprise** | 完全私有部署 |
| 2 | **通义灵码企业版** | 国内合规 |
| 3 | **CodeGeeX 本地部署** | 开源模型自托管 |

---

## 二、按场景选

### 场景 A：快速原型 / MVP

**特征**：单文件、几小时完成、不需要严谨测试。

- **首选**：Cursor（Composer 体验最丝滑）
- **替代**：Claude Code（命令行 + Plan 模式）

### 场景 B：复杂多文件改造

**特征**：跨目录、跨模块、需要理解依赖。

- **首选**：Claude Code（Plan + Subagent + Worktree）
- **替代**：Cursor（Agent 模式）/ Windsurf（Cascade）

### 场景 C：批量化 issue 处理

**特征**：100+ 重复性 issue，需要自动 PR。

- **首选**：OpenHands（开源 + 自托管 + 并行）
- **替代**：Devin（商业，如果预算允许）

### 场景 D：代码审查自动化

**特征**：PR 自动 review。

- **首选**：CodeRabbit（性价比高）
- **辅助**：Graphite AI Reviewer

### 场景 E：调试难问题

**特征**：bug 难复现，需要深挖。

- **首选**：Claude Code（systematic-debugging 类 skill 配合最强）
- **替代**：Cursor + 手动 prompt

### 场景 F：写测试

**特征**：TDD 流程、大量样板测试。

- **首选**：Cline / Roo Code（透明决策、可控）
- **替代**：Aider（Git-first 自动提交）

### 场景 G：从零搭建新项目

**特征**：空仓库 → 完整 MVP。

- **首选**：Claude Code（HyperSpec-like 工作流 + Plan 模式）
- **替代**：Cursor（Composer + Agent）

### 场景 H：维护遗留代码

**特征**：老旧代码、文档缺失、小心翼翼。

- **首选**：Aider（Git-first，每次改动可回滚）
- **替代**：Claude Code（长上下文 + Plan）

---

## 三、按预算选

### $0/月

- Aider + DeepSeek-Coder API（每次几美分）
- Cline + Ollama（本地模型）
- 通义灵码 / Trae / CodeGeeX（国内免费）

### $10–20/月

- Cursor Pro ⭐ 推荐
- Windsurf Pro
- GitHub Copilot

### $20–100/月

- Claude Code Max（Anthropic 订阅）
- Cursor Pro + Ultra 加包
- Windsurf Pro+

### $100+/月（团队/企业）

- Devin 团队版
- Factory
- CodeRabbit Teams
- Tabnine Enterprise

---

## 四、按"你相信谁"选

这是一个被低估的维度——**AI 编码工具一旦用熟，切换成本极高**。选谁等于长期和谁绑定。

| 你相信… | 选 |
|--------|---|
| Anthropic 的工程审美 | Claude Code + Opus |
| OpenAI 的研究能力 | Codex CLI + GPT-5 |
| Google 的算力 + 长上下文 | Gemini CLI |
| 开源社区 + 自主可控 | OpenHands / Cline / Aider |
| 中国互联网大厂生态 | 通义灵码 / CodeBuddy / Trae |
| 谁都不信，自己跑模型 | Aider/Cline + Ollama + DeepSeek/Qwen/CodeGeeX 本地部署 |

---

## 五、Harness V2 用户的特殊建议

Harness V2 已经把"模型 + Agent + 工具链"分层解耦。你只需要在**最底层**选一个 Agent 容器：

### 推荐组合

| 组合 | 适合 |
|------|------|
| **Claude Code + Opus 4.x + MCP** | 想要最强默认体验，愿意付订阅 |
| **Cursor + BYOK + Anthropic Key** | 想要 IDE 体验 + Anthropic 模型 |
| **Aider + DeepSeek + Ollama 本地** | 完全 BYOK + 极低成本 |
| **Cline + Qwen3 + 通义灵码 MCP** | 国内场景 + 自主可控 |
| **OpenHands + Claude BYOK** | 自主 Agent + HyperSpec 接力 |

### 不推荐组合

- ❌ Devin + Harness（Devin 是黑盒，无法接 HyperSpec 检查点机）
- ❌ Tabnine 免费版 + Harness（功能受限，Agent 能力弱）
- ❌ Comate + Harness（MCP 支持不明确）

---

## 六、什么时候应该换工具

信号清单：

- [ ] 工具产生的代码**超过 30% 需要重写** → 模型不够强
- [ ] 工具**不支持 MCP** → 已经过时
- [ ] 工具**强制使用某家模型**且你不想被绑定 → BYOK 受限
- [ ] 月费 **> $50 但你只用几次** → 价值不匹配
- [ ] 工具**更新停滞 6 个月以上** → 维护风险

---

## 七、本报告的局限性

本报告基于 2026 年 7 月公开数据，存在以下局限：

1. **AI 编码领域演化极快**——3 个月后部分结论可能失效
2. **第三方榜单可信度参差**——尤其是引用了未确认模型版本的内容
3. **国产工具的海外资料不足**——可能存在评价偏差
4. **未涵盖**：代码生成模型层（Codestral、StarCoder 等）、CI/CD 类 AI 工具、低代码平台

建议每 6 个月回看一次，参考 `SOURCES.md` 中的链接交叉验证。

---

下一章：[`SOURCES.md`](./SOURCES.md) 看全部参考来源。
