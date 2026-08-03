# 02 · IDE / 编辑器类 AI 编码工具

> **类别定义**：作为 VS Code fork、JetBrains 插件或独立编辑器存在，提供可视化代码补全 + Agent 面板 + 多文件修改。

---

## 速览表

| 工具 | 母公司 / 国家 | 开源 | 形态 | 主推模型 | BYOK | MCP | 价格 |
|------|--------------|------|------|---------|------|-----|------|
| **Cursor** | Anysphere / 美国 | ❌ | VS Code fork | 多模型可选 | 部分 | ✅ | $15/月起 |
| **Windsurf** | Codeium / 美国 | ❌ | VS Code fork | 多模型 | 部分 | ✅ | $20/月起 |
| **Trae** | ByteDance（字节）/ 中国 | ❌ | VS Code fork | 字节系 + Claude | 有限 | ✅ | 免费 + 订阅 |
| **GitHub Copilot** | Microsoft/GitHub / 美国 | ❌ | 多 IDE 插件 | GPT/Claude 可选 | ❌ | ✅ | $10/月起 |
| **Continue** | Continue Dev（已被 Cursor 收购）/ 美国 | ✅ Apache-2.0 | VS Code/JetBrains | 任意 | ✅ | ✅ | 自托管免费 |
| **Roo Code** | Roo Community / 美国 | ✅ Apache-2.0 | VS Code | 任意 | ✅ | ✅ | 自托管免费 |
| **Cline** | Cline Bot Inc. / 美国 | ✅ Apache-2.0 | VS Code | 任意 | ✅ | ✅ | 自托管免费 |
| **JetBrains AI Assistant** | JetBrains / 捷克 | ❌ | 内置 | 多家 | 部分 | ✅ | 内置订阅 |
| **Codeium** | Codeium / 美国 | ❌ | 多 IDE | 专用 | ❌ | ✅ | 免费 + 团队版 |
| **Tabnine** | Tabnine / 以色列 | 部分 | 多 IDE | 专用 + 开源 | ✅ 企业版 | ✅ | 免费 + 企业版 |
| **Kilo Code** | Kilo Community | ✅ | VS Code fork | 任意 | ✅ | ✅ | 免费 |

---

## 1. Cursor（Anysphere）

- **母公司**：Anysphere（美国，旧金山）；Pivot 至 AI IDE 的标杆公司。
- **开源状态**：❌ 闭源（VS Code fork，保留了 VSC 扩展生态）
- **Agent 能力**：业界公认 IDE 阵营最强。**Composer / Agent / Background Agent** 三种模式，支持多文件并行修改、自动跑测试、自主规划任务。
- **外部 API**：**部分 BYOK**——可以输入自己的 Anthropic / OpenAI key，但 Cursor 强烈引导用户走它的订阅（$15/月 Pro）。
- **MCP**：✅ 完整 MCP 客户端，文档清晰。
- **社区口碑**：2024–2026 长期占据"最流行 AI IDE"位置；批评主要在"BYOK 限制越来越严"。
- **基准成绩**：第三方报告显示 Cursor + Opus 在 SWE-bench Verified 接近 Claude Code harness。
- **典型场景**：愿意月付、追求"开箱即用最强"的工程师。

---

## 2. Windsurf（Codeium）

- **母公司**：Codeium（美国，旧金山）；2024 年起 Pivot 至 AI IDE。
- **开源状态**：❌ 闭源
- **Agent 能力**：核心是 **Cascade Agent**——主打"AI 即工作流"，Agent 自动接管多步操作。比 Cursor 更"放手"，但也更难精确控制。
- **外部 API**：部分——可配置 OpenAI-compatible 端点，但默认走 Codeium 计费。
- **MCP**：✅ 支持。
- **社区口碑**：2026 年与 Cursor 形成双雄。评价："Cursor 控制强、Windsurf 自主性强"。
- **价格**：Pro $20/月、Pro+ $60/月、Ultra $200/月。
- **典型场景**：喜欢"放手让 Agent 跑"的开发者。

---

## 3. Trae（ByteDance / 字节跳动）

- **母公司**：字节跳动（中国 / 新加坡）
- **开源状态**：❌ 闭源
- **Agent 能力**：主打中文场景，深度集成豆包模型与 Claude（海外版）。多文件改、补全、对话均有。
- **外部 API**：有限——主要走字节系模型，BYOK 需付费版。
- **MCP**：✅ 支持。
- **社区口碑**：中文社区口碑好，国际认知度低。免费策略激进。
- **典型场景**：国内开发者、豆包生态用户。

---

## 4. GitHub Copilot

- **母公司**：Microsoft / GitHub（美国）
- **开源状态**：❌ 闭源
- **Agent 能力**：2024 年的"补全工具"标签已褪去——**Copilot Agent / Workspace** 已是完整 Agent。VS Code Insiders 中可用任何 OpenAI-compatible 模型。
- **外部 API**：❌ 不支持（必须走 Copilot 订阅）。
- **MCP**：✅ 支持（2025 年起）。
- **社区口碑**：企业渗透最深；个人用户对"模型选择受限"长期不满。
- **价格**：$10/月（Individual）、$19/月（Business）、$39/月（Enterprise）。
- **典型场景**：企业 GitHub 用户、已买 Copilot 订阅的团队。

---

## 5. Continue.dev（已被 Cursor 收购）

- **母公司**：Continue Dev → **2026 年被 Cursor 收购**，但保留开源版本
- **开源状态**：✅ Apache-2.0
- **Agent 能力**：VS Code / JetBrains 双端，强调"配置驱动"——所有模型、prompt、命令都是 JSON 配置。
- **外部 API**：✅ 完整 BYOK。
- **MCP**：✅ 支持。
- **社区口碑**：开源阵营最早成熟的产品；被收购后社区担心未来走向，但目前版本仍在维护。
- **典型场景**：JetBrains 用户 + 想自控配置 + 不想付费 Cursor。

---

## 6. Roo Code / Cline（VS Code 扩展）

- 见 `01-cli-tools.md` 的 Cline / Roo Code 章节——两者同时提供 CLI 和 VS Code 扩展形态。**Roo Code 比 Cline 功能多、Cline 比 Roo Code 稳定**（社区共识）。

---

## 7. JetBrains AI Assistant

- **母公司**：JetBrains（捷克，布拉格）
- **开源状态**：❌ 闭源（内置于 IntelliJ/PyCharm/WebStorm 等）
- **Agent 能力**：2025 年起内置 AI Agent（Juno），支持多文件修改、跑测试、理解项目结构。
- **外部 API**：部分——可接 OpenAI / Anthropic key。
- **MCP**：✅ 支持（2025 年起）。
- **社区口碑**：JetBrains 重度用户最爱；但模型选择和补全质量弱于 Cursor。
- **典型场景**：Java/Kotlin/Python 重度 JetBrains 用户。

---

## 8. Codeium

- **母公司**：Codeium（美国）——和 Windsurf 是同一家公司，Codeium 是它的"免费插件版"。
- **开源状态**：❌ 闭源
- **Agent 能力**：免费版主打补全 + 问答；付费版（Command / Windsurf）才是完整 Agent。
- **外部 API**：❌ 企业版才支持 BYOK。
- **MCP**：✅ 支持。
- **社区口碑**：免费版是"个人开发者的福音"；企业版定价偏贵。
- **典型场景**：免费起步、不想付费。

---

## 9. Tabnine

- **母公司**：Tabnine（以色列，特拉维夫）
- **开源状态**：部分（私有模型 + 开源客户端）
- **Agent 能力**：早期是纯补全工具，2025 年加入 Agent 模式。
- **外部 API**：✅ **企业版主打私有部署**——支持完全本地化、自托管 LLM。这是它最大的差异化。
- **MCP**：✅ 支持。
- **社区口碑**：**金融/政府/医疗等强合规行业首选**；个人用户少。
- **典型场景**：私有部署、强合规需求。

---

## 10. Kilo Code

- **母公司**：社区项目
- **开源状态**：✅ 开源
- **Agent 能力**：Cline/Roo 的 fork，融合了两者优点。
- **典型场景**：开源阵营的"新秀"。

---

## 横向点评

### "AI 体验"排序（基于 Agent 自主性 + 模型广度）

```
Cursor ≈ Windsurf > JetBrains AI ≈ Copilot > Trae > Codeium
> Continue ≈ Roo Code ≈ Cline（取决于配置）
```

### BYOK 友好度排序

```
Continue ≈ Roo Code ≈ Cline ≈ Kilo Code（全开）
> Tabnine 企业版 > JetBrains AI（部分）
> Cursor > Windsurf > Copilot > Trae（限制最大）
```

### 企业/合规场景推荐

- **金融/医疗/政府**：Tabnine（私有部署）、JetBrains AI（本地化）
- **互联网创业公司**：Cursor / Windsurf（效率优先）
- **开源爱好者**：Continue / Roo Code / Cline
- **JetBrains 重度用户**：JetBrains AI Assistant 或 Continue（JetBrains 版）

---

下一章：[`03-autonomous-agents.md`](./03-autonomous-agents.md)
