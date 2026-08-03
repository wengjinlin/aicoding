# 01 · CLI 类 AI 编码工具

> **类别定义**：以终端为主要交互界面，通过自然语言对话或一次性命令调用 LLM Agent 完成代码任务。

---

## 速览表

> ⚠️ **修订记录（2026-07-17 v1.1）**：首版遗漏了 Droid、Amp、Goose、Kimi Code、Qwen Code、CodeBuff、Granitic、Copilot CLI 等工具，本版补全。如发现仍有遗漏，欢迎指出。

### 海外 CLI（11 款）

| 工具 | 母公司 / 国家 | 开源 | 主推模型 | BYOK | MCP | 协议 |
|------|--------------|------|---------|------|-----|------|
| **Claude Code** | Anthropic / 美国 | ❌ | Claude Opus 4.x | ❌ | ✅ 原生 | MCP + 自有 SDK |
| **OpenAI Codex CLI** | OpenAI / 美国 | ✅ Apache-2.0 | GPT-5 Codex | ⚠️ | ✅ | OpenAI Responses API |
| **Gemini CLI** | Google / 美国 | ✅ Apache-2.0 | Gemini 2.5 Pro | ❌ | ✅ | Google AI API |
| **GitHub Copilot CLI** | Microsoft/GitHub / 美国 | ❌ | GPT/Claude/Gemini | ❌ | ✅ | GitHub-native |
| **Aider** | 个人（Paul Gauthier）/ 美国 | ✅ MIT | 任意 | ✅ | ✅ | OpenAI-compatible |
| **Cline**（含 Roo Code 分支） | Cline Bot / 美国 | ✅ Apache-2.0 | 任意 | ✅ | ✅ | OpenAI-compatible |
| **opencode** | SST / 美国·英国 | ✅ MIT | 任意 | ✅ | ✅ | OpenAI-compatible |
| **Crush** | Charmcraft / 美国 | ✅ | 任意 | ✅ | ✅ | OpenAI-compatible |
| **Amp** | Sourcegraph / 美国 | ❌ | 多家 | ✅ | ✅ | OpenAI-compatible |
| **Goose** | Block（Square）/ 美国 → Linux Foundation | ✅ Apache-2.0 | 任意 | ✅ | ✅ | OpenAI-compatible |
| **Droid** | Factory AI / 美国 | ❌ | 多家（含 GLM-4.6） | ✅ | ✅ | OpenAI-compatible |
| **CodeBuff** | 个人 / 美国 | ✅ | 任意 | ✅ | ✅ | OpenAI-compatible |
| **IBM Granitic** | IBM / 美国 | ✅ | 任意 | ✅ | ✅ | OpenAI-compatible |

### 国产 CLI（2 款，独立 CLI 形态）

| 工具 | 母公司 / 国家 | 开源 | 主推模型 | BYOK | MCP |
|------|--------------|------|---------|------|-----|
| **Kimi Code**（前身 Kimi CLI） | 月之暗面 / 中国 | ✅ 部分 | Kimi K2.x | ✅ | ✅ |
| **Qwen Code**（CLI） | 阿里通义 / 中国 | ✅ | Qwen3-Coder | ✅ | ✅ |

> 注：通义灵码 / CodeBuddy / Comate / Trae / CodeGeeX 等虽有命令行模式，但**核心形态是 IDE 插件**，归入 [`04-china-tools.md`](./04-china-tools.md)。

---

## 1. Claude Code（Anthropic）

- **母公司**：Anthropic（美国，旧金山）
- **开源状态**：闭源（CLI 客户端可免费用，但需绑定 Anthropic API 或 Claude Pro/Max 订阅）
- **Agent 能力**：业界公认最强的"原生 Agent CLI"。内置 Plan 模式、Skill 系统、Subagent、Hooks、Slash Commands、Worktree 隔离、Scheduled Tasks——几乎是"Agent 工具链教科书"。
- **外部 API**：**不支持 BYOK**。只能调用 Anthropic 自家模型。这是它的最大争议点。
- **MCP**：✅ MCP 是 Anthropic 自家协议，Claude Code 是**最完整**的 MCP 客户端之一，可作为 MCP 服务端被其他工具调用。
- **社区口碑**：2026 年 SWE-bench Verified 排行榜常驻前列；开发者普遍认为"模型最强但贵"。
- **基准成绩**：Claude Opus 4.6 → SWE-bench Verified 75.6%（官方）；Opus 4.7 → 87.6%（第三方报告）；Claude Code harness 自评 80.8%。
- **典型场景**：愿意付 Anthropic 订阅、需要最深 Agent 能力的重度用户。

---

## 2. Aider

- **母公司**：个人项目（Paul Gauthier，美国）
- **开源状态**：✅ MIT
- **Agent 能力**：纯终端、Git-first（每次改动自动 commit）、Edit/Undo 历史清晰。擅长**单文件改造、批量重构、Repo 级问答**，但**多步规划**能力弱于 Claude Code。
- **外部 API**：✅ 支持 OpenAI / Anthropic / OpenRouter / Ollama / DeepSeek / Gemini / 任意 OpenAI-compatible 端点。BYOK 是它的核心卖点。
- **MCP**：✅ 通过 `--mcp-server` 接入。
- **社区口碑**：开源 CLI 老牌。Reddit/HN 一致评价"最稳定的 BYOK CLI"。
- **基准成绩**：Aider 自己维护 `aider.io leaderboard`（基于编辑成功率），长期在 BYOK 工具中排第一。
- **典型场景**：自托管模型、对成本敏感、喜欢 Git-first 工作流。

---

## 3. Cline / Roo Code

- **母公司**：Cline Bot Inc.（美国）/ Roo Code 是 Cline 的 fork，由社区维护
- **开源状态**：✅ Apache-2.0
- **Agent 能力**：最初是 VS Code 扩展，但提供 CLI 模式。强项是**透明可见的 Agent 决策过程**（每一步动作都要批准）。
- **外部 API**：✅ 全部主流厂商 + Ollama / LM Studio / OpenRouter。BYOK 最完整。
- **MCP**：✅ 完整 MCP 客户端，且可作为 MCP Host 配置多个 server。
- **社区口碑**：开源阵营的 "Cursor 替代品"。Roo Code 比 Cline 功能更多但稳定性略低。
- **典型场景**：不想付费给 Cursor/Windsurf，想完全自控。

---

## 4. opencode（by SST）

- **母公司**：SST 团队（David Mytton 牵头，美国/英国）
- **开源状态**：✅ MIT
- **Agent 能力**：2026 年 GitHub stars 飙升（180k+），主打"替代 Claude Code 的开源方案"。内置 Session、Plugin、TUI（终端 UI）。
- **外部 API**：✅ 任意 OpenAI-compatible 端点。
- **MCP**：✅ 原生支持。
- **社区口碑**：TUI 做得最漂亮的开源 CLI。SST 社区活跃。
- **典型场景**：喜欢 Claude Code 的体验但想用 BYOK。

---

## 5. Gemini CLI

- **母公司**：Google（美国）
- **开源状态**：✅ Apache-2.0
- **Agent 能力**：Gemini 2.5 Pro 原生支持 1M token 上下文，**长上下文场景无敌**。Agent 能力不及 Claude Code，但免费额度大。
- **外部 API**：❌ 仅 Google Gemini。
- **MCP**：✅ 支持。
- **社区口碑**：免费、长上下文、稳定。Google Cloud 用户的"默认选择"。
- **典型场景**：免费起步、大 monorepo 上下文。

---

## 6. OpenAI Codex CLI

- **母公司**：OpenAI（美国）
- **开源状态**：✅ Apache-2.0
- **Agent 能力**：与 ChatGPT/OpenAI API 深度绑定，**并行 Agent**是亮点（多个 Agent 同时跑）。与 Cursor 的"Codex 模式"是同源。
- **外部 API**：部分——主要走 OpenAI 系，可配置 OpenAI-compatible 端点。
- **MCP**：✅ 支持。
- **社区口碑**：OpenAI 重度用户首选。
- **典型场景**：ChatGPT Plus/Team 订阅用户、GPT-5 Codex 模型用户。

---

## 7. Crush（by Charmcraft）

- **母公司**：Charmcraft（Dustin Sparkman 牵头，美国）
- **开源状态**：✅ 开源
- **Agent 能力**：主打"终端原生的 Claude Code 替代品"，体验精致，TUI 美观。
- **外部 API**：✅ 全部主流。
- **MCP**：✅ 支持。
- **社区口碑**：2026 年的新秀，口碑增长快但生态弱于 opencode。

---

## 8. Amp（by Sourcegraph）

- **母公司**：Sourcegraph（美国，旧金山）——企业级代码搜索公司转型 Agent
- **开源状态**：❌ 闭源
- **Agent 能力**：主打"remote agent"——可把任务放到云端跑，本地终端只看进度。四种自主度（low / medium / high / ultra），与 Sourcegraph 的代码图深度结合。
- **外部 API**：✅ 多模型支持。
- **MCP**：✅ 支持。
- **社区口碑**：企业用户认可，但个人用户偏向 opencode/Claude Code。
- **典型场景**：大型 monorepo + Sourcegraph 用户。

---

## 9. Goose（by Block / Linux Foundation）

- **母公司**：Block（前身 Square，美国）→ 2025 年捐赠给 **Linux Foundation**
- **开源状态**：✅ Apache-2.0
- **Agent 能力**：Block 内部用的 Agent 开源化。**重视可扩展性**——开发者可写"Goose Extension"扩展能力。
- **外部 API**：✅ 完整 BYOK。
- **MCP**：✅ 支持（且可作为 MCP server 被其他工具调用）。
- **社区口碑**：开源阵营仅次于 opencode / Cline。Linux Foundation 背书让企业用户安心。
- **典型场景**：企业内部 Agent 平台、可扩展场景。

---

## 10. Droid（by Factory AI）⭐ Terminal-Bench 冠军

- **母公司**：Factory AI（美国，旧金山）
- **开源状态**：❌ 闭源
- **Agent 能力**：Factory 的命令行版，主打"agent design 决定能力"——基准成绩不靠堆模型，靠 Agent 架构。可调用多家模型（含智谱 **GLM-4.6**）。
- **基准成绩**：**Terminal-Bench 2.1 → 58.75%（#1）**，超过 Claude Code、Codex CLI。
- **外部 API**：✅ 多模型 BYOK。
- **MCP**：✅ 支持。
- **社区口碑**：2026 年最大的黑马。Reddit 上有"Stop using Claude Code, start using Droid"的争论帖。但稳定性评价低于 Claude Code（"像 Claude 但有 bug"）。
- **典型场景**：终端 Agent 工作流 + 多模型路由 + 愿意承担新工具风险。

---

## 11. CodeBuff

- **母公司**：个人 / 社区项目（美国）
- **开源状态**：✅ 开源
- **Agent 能力**：早期 CLI Agent，主打"agent-native development"。
- **社区口碑**：早期有一定热度，2025 年后被 opencode、Crush 等新秀盖过。Reddit 评价："tried but forgot what it was like"。
- **典型场景**：尝鲜 / 学习。

---

## 12. IBM Granitic（前身 IBM Bob）

- **母公司**：IBM（美国）
- **开源状态**：✅ 部分开源（2025-05-14 发布）
- **Agent 能力**：企业级 CLI Agent，与 IBM Watsonx 模型生态深度集成。
- **外部 API**：✅ 多模型 BYOK。
- **MCP**：✅ 支持。
- **社区口碑**：企业用户为主，个人用户少。
- **典型场景**：IBM Cloud / Watsonx 用户、强合规企业。

---

## 13. GitHub Copilot CLI

- **母公司**：Microsoft / GitHub（美国）
- **开源状态**：❌ 闭源（GitHub 内置）
- **Agent 能力**：Copilot 的命令行版本，与 Copilot 订阅打通，可在终端直接调用 Copilot Agent。
- **外部 API**：❌ 仅 Copilot 订阅。
- **MCP**：✅ 支持。
- **社区口碑**：已买 Copilot 订阅的用户最省事；Reddit 讨论："Stay in Copilot CLI because I already have a plan"。
- **典型场景**：Copilot Business / Enterprise 订阅用户。

---

## 14. Kimi Code（月之暗面）⭐ 国产 CLI

- **母公司**：月之暗面 / Moonshot AI（中国，北京）
- **开源状态**：✅ 部分开源（2025 年 1024 程序员节开源 Kimi CLI；2026 年初发布 Kimi Code 0.4.0）
- **Agent 能力**：基于 **Kimi K2 → K2.5 → K2.6** 模型。**K2.6 号称可"不间断编码 13 小时、单次修改 4000+ 行代码"**。
- **上下文长度**：**200 万汉字**——业界最长之一。
- **外部 API**：✅ 支持 BYOK + Kimi 会员双通道。
- **MCP**：✅ 支持。
- **技术栈**：0.4.0 版本用 TypeScript 重写，主打"一键安装、毫秒级启动"。
- **平台**：macOS / Linux
- **社区口碑**：国产 CLI 阵营的代表。K2.6 模型在开源社区口碑好。
- **典型场景**：国内开发者 + 长上下文场景 + 想要 BYOK 的国产方案。

---

## 15. Qwen Code（阿里通义）⭐ 国产 CLI

- **母公司**：阿里通义（中国，杭州）
- **开源状态**：✅ 开源
- **底层架构**：**基于 Gemini CLI 二次开发**——增强了解析器和工具调用协议。
- **Agent 能力**：针对 Qwen3-Coder 模型优化，支持 agentic coding。
- **模型能力**：Qwen3-Coder（480B 参数、**1M token 上下文**）。
- **外部 API**：✅ 通过阿里云百炼按量计费 / Coding Plan / Token Plan。
- **MCP**：✅ 支持。
- **社区口碑**：阿里云用户首选 CLI；模型在 Aider 排行榜上长居前列。
- **典型场景**：阿里云生态用户、Qwen3-Coder 模型偏好者。

---

## 横向点评

### Agent 能力排序（主观 + 基准结合）

```
Claude Code ≈ Cursor (Agent mode) ≈ Droid（Terminal-Bench 冠军）
> Cline ≈ Roo Code ≈ opencode ≈ Amp ≈ Goose
> Aider > Gemini CLI ≈ Codex CLI ≈ Qwen Code ≈ Kimi Code
> Crush > CodeBuff > Copilot CLI
```

### Terminal-Bench（终端任务）能力排行

```
Droid (58.75%) > Claude Code > Codex CLI > opencode
> Cline/Roo ≈ Goose ≈ Amp > Aider > 其他
```

### BYOK 友好度排序

```
Aider ≈ Cline ≈ Roo Code ≈ opencode ≈ Crush ≈ Goose ≈ Droid ≈ Amp
≈ Kimi Code ≈ Qwen Code（全开）
> Codex CLI（半开）> Gemini CLI ≈ Claude Code ≈ Copilot CLI（仅自家）
```

### 上下文长度排行

```
Kimi Code (200 万汉字 / ~270 万 token)
> Qwen Code (1M token) ≈ Gemini CLI (1M token)
> Claude Code (200K-1M) ≈ Droid
> 其他多数 128K-256K
```

### 给 Harness V2 用户的建议

- **Harness 基础设施层假设你能跑 MCP**——上面所有工具都满足，可放心选。
- **如果你要完全 BYOK**：选 Aider / Cline / opencode / Crush / Goose / Droid / Kimi Code / Qwen Code。
- **如果你接受 Anthropic 订阅换最强 Agent**：选 Claude Code。
- **如果你已经付费 Google Workspace / OpenAI Plus / GitHub Copilot**：选对应官方 CLI 省钱。
- **如果你要长上下文**：选 Kimi Code（200 万汉字）/ Qwen Code（1M）/ Gemini CLI（1M）。
- **如果你想试 Terminal-Bench #1**：选 Droid（Factory AI）。

---

下一章：[`02-ide-tools.md`](./02-ide-tools.md)
