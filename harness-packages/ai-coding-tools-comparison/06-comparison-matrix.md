# 06 · 横向对比矩阵

> 一张大表 + 几张细分表，覆盖前面章节的核心维度。

---

## 一、主矩阵（35+ 工具）

> 图例：✅ 完整支持 / ⚠️ 部分 / ❌ 不支持 / — 不适用
>
> ⚠️ **v1.1 补丁**：相比首版新增 8 款工具（Amp / Goose / Droid / CodeBuff / IBM Granitic / GitHub Copilot CLI / Kimi Code / Qwen Code）。

| 工具 | 类别 | 母公司（国家） | 开源 | 主推模型 | BYOK | MCP | Agent | 价格（个人） |
|------|------|---------------|------|---------|------|-----|-------|------------|
| **Claude Code** | CLI | Anthropic（美） | ❌ | Claude Opus 4.x | ❌ | ✅ | ⭐⭐⭐⭐⭐ | $20/月（Max 起） |
| **OpenAI Codex CLI** | CLI | OpenAI（美） | ✅ Apache | GPT-5 Codex | ⚠️ | ✅ | ⭐⭐⭐⭐ | 订阅 |
| **Gemini CLI** | CLI | Google（美） | ✅ Apache | Gemini 2.5 | ❌ | ✅ | ⭐⭐⭐ | 免费 + 订阅 |
| **GitHub Copilot CLI** | CLI | Microsoft/GitHub（美） | ❌ | GPT/Claude/Gemini | ❌ | ✅ | ⭐⭐⭐⭐ | $10/月起 |
| **Aider** | CLI | 个人（美） | ✅ MIT | 任意 | ✅ | ✅ | ⭐⭐⭐ | 免费（API 自付） |
| **Cline** | CLI/IDE | Cline Bot（美） | ✅ Apache | 任意 | ✅ | ✅ | ⭐⭐⭐⭐ | 免费 |
| **Roo Code** | CLI/IDE | 社区（美） | ✅ Apache | 任意 | ✅ | ✅ | ⭐⭐⭐⭐ | 免费 |
| **opencode** | CLI | SST（美/英） | ✅ MIT | 任意 | ✅ | ✅ | ⭐⭐⭐⭐ | 免费 |
| **Crush** | CLI | Charmcraft（美） | ✅ | 任意 | ✅ | ✅ | ⭐⭐⭐ | 免费 |
| **Amp** | CLI | Sourcegraph（美） | ❌ | 多家 | ✅ | ✅ | ⭐⭐⭐⭐ | 订阅 |
| **Goose** | CLI | Block（美）→ Linux Foundation | ✅ Apache | 任意 | ✅ | ✅ | ⭐⭐⭐⭐ | 免费 |
| **Droid** ⭐ | CLI | Factory AI（美） | ❌ | 多家（含 GLM-4.6） | ✅ | ✅ | ⭐⭐⭐⭐⭐ | 订阅 |
| **CodeBuff** | CLI | 个人（美） | ✅ | 任意 | ✅ | ✅ | ⭐⭐ | 免费 |
| **IBM Granitic** | CLI | IBM（美） | ✅ | 任意 | ✅ | ✅ | ⭐⭐⭐ | 企业 |
| **Cursor** | IDE | Anysphere（美） | ❌ | 多模型 | ⚠️ | ✅ | ⭐⭐⭐⭐⭐ | $15/月起 |
| **Windsurf** | IDE | Codeium（美） | ❌ | 多模型 | ⚠️ | ✅ | ⭐⭐⭐⭐⭐ | $20/月起 |
| **Trae** | IDE | 字节（中/新） | ❌ | 豆包 + Claude | ⚠️ | ✅ | ⭐⭐⭐⭐ | 免费 + 订阅 |
| **GitHub Copilot** | IDE/插件 | Microsoft（美） | ❌ | GPT/Claude | ❌ | ✅ | ⭐⭐⭐⭐ | $10/月起 |
| **Continue** | IDE | Continue（美，被 Cursor 收购） | ✅ Apache | 任意 | ✅ | ✅ | ⭐⭐⭐ | 免费 |
| **JetBrains AI** | IDE | JetBrains（捷克） | ❌ | 多家 | ⚠️ | ✅ | ⭐⭐⭐⭐ | 订阅 |
| **Codeium** | 插件 | Codeium（美） | ❌ | 专用 | ❌ | ✅ | ⭐⭐⭐ | 免费 + 团队版 |
| **Tabnine** | 插件 | Tabnine（以色列） | 部分 | 专用 + 自托管 | ✅ 企业版 | ✅ | ⭐⭐⭐ | 免费 + 企业版 |
| **Kilo Code** | IDE | 社区 | ✅ | 任意 | ✅ | ✅ | ⭐⭐⭐ | 免费 |
| **通义灵码** | IDE/插件 | 阿里云（中） | ❌ | Qwen3 | ⚠️ | ✅ | ⭐⭐⭐⭐ | 免费 + 企业版 |
| **CodeBuddy** | 插件 | 腾讯云（中） | ❌ | 混元 | ⚠️ | ✅ | ⭐⭐⭐ | 免费 |
| **Comate** | 插件 | 百度（中） | ❌ | 文心 | — | ⚠️ | ⭐⭐ | 免费 |
| **CodeGeeX** | IDE/CLI | 智谱 AI（中） | ✅ 模型 | CodeGeeX | ✅ | ✅ | ⭐⭐⭐ | 免费 |
| **MarsCode** | 插件/云 IDE | 字节（中） | ❌ | 豆包 | ⚠️ | ✅ | ⭐⭐⭐ | 免费 |
| **Kimi Code** ⭐ | CLI | 月之暗面（中） | ✅ 部分 | Kimi K2.x | ✅ | ✅ | ⭐⭐⭐⭐ | 免费 + 会员 |
| **Qwen Code** ⭐ | CLI | 阿里通义（中） | ✅ | Qwen3-Coder | ✅ | ✅ | ⭐⭐⭐⭐ | 免费 + API |
| **DeepSeek Coder** | 模型/API | 深度求索（中） | ✅ 模型 | DeepSeek-Coder | — | — | — | API 极便宜 |
| **Devin** | 自主 | Cognition（美） | ❌ | 多家 | ❌ | — | ⭐⭐⭐⭐⭐ | $500/月起 |
| **OpenHands** | 自主 | All Hands AI（美） | ✅ MIT | 任意 | ✅ | — | ⭐⭐⭐⭐⭐ | 免费 |
| **SWE-agent** | 自主 | Princeton NLP（美） | ✅ MIT | 任意 | ✅ | — | ⭐⭐⭐ | 免费 |
| **Devika** | 自主 | Stitionai（印） | ✅ MIT | 任意 | ✅ | — | ⭐⭐ | 免费 |
| **Factory** | 自主 | Factory AI（美） | ❌ | 多家 | ❌ | — | ⭐⭐⭐⭐ | 企业议价 |
| **CodeRabbit** | PR 审查 | CodeRabbit（美） | ❌ | 多家 | ❌ | — | ⭐⭐⭐ | $12/月起 |

---

## 二、按能力维度的"Top 3"

### 模型推理能力（SWE-bench Verified）

1. Claude Opus 4.x（Anthropic）
2. GPT-5 Codex（OpenAI）
3. GLM-5 high reasoning（智谱 AI）

### Agent 自主度

1. Devin / OpenHands（并列）
2. Claude Code / Cursor（并列）
3. Factory / Windsurf

### BYOK 友好度

1. Aider / Cline / Roo Code / opencode / Crush（全开并列）
2. Continue / Kilo Code
3. Tabnine 企业版

### MCP 支持深度

1. Claude Code（自家协议）
2. Cursor / Cline（最完整客户端）
3. 通义灵码（魔搭广场生态）

### 中文场景适配

1. 通义灵码（阿里）
2. CodeBuddy（腾讯） / Comate（百度）
3. Trae / CodeGeeX

### 价格友好

1. Aider / Cline / OpenHands / Continue（开源自托管）
2. Gemini CLI（免费额度大）
3. DeepSeek-Coder API（极便宜）

### 企业/合规

1. Tabnine（私有部署）
2. GitHub Copilot Enterprise
3. JetBrains AI Enterprise

### 社区生态（开源）

1. OpenHands（自主 Agent）
2. Cline / Roo Code（IDE）
3. Aider（CLI）

---

## 三、协议与生态对照

| 协议 | 提出方 | 主要采用方 | 状态 |
|------|--------|----------|------|
| **MCP**（Model Context Protocol） | Anthropic（2024） | Cursor / Windsurf / Claude Code / Cline / Roo Code / Continue / 通义灵码 / Trae / JetBrains AI / Copilot | ⭐ 事实标准 |
| **LSP**（Language Server Protocol） | Microsoft | 所有 IDE / 编辑器 | ⭐ 老牌标准 |
| **OpenAI-compatible API** | OpenAI（事实） | Aider / Cline / Continue / DeepSeek / Qwen / 几乎所有 BYOK 工具 | ⭐ 事实标准 |
| **DAP**（Debug Adapter Protocol） | Microsoft | VS Code / Cursor / Windsurf 等 | ⭐ 老牌标准 |
| **Google AI API** | Google | Gemini CLI / Codeium 部分功能 | 单一 |
| **OpenRouter API** | OpenRouter | Aider / Cline / 部分 BYOK 工具 | 多模型聚合 |

---

## 四、地缘与开源分布

### 美国

- **闭源商业**：Claude Code、Cursor、Windsurf、GitHub Copilot、Devin、Factory、Codeium
- **开源**：Aider、Cline、Roo Code、opencode、Continue（被 Cursor 收购）、OpenHands、SWE-agent

### 中国

- **闭源商业**：通义灵码、CodeBuddy、Comate、Trae、MarsCode
- **开源**：CodeGeeX（模型开源）、DeepSeek-Coder（模型开源）

### 其他

- **捷克**：JetBrains AI
- **以色列**：Tabnine
- **印度**：Devika

### 观察

- **闭源商业工具**绝大多数在美国；中国以"闭源 + 免费"模式为主
- **开源**阵营由美国主导（学术 + 个人项目）；中国的开源贡献主要在**模型**层（Qwen、DeepSeek、CodeGeeX）

---

## 五、价格档位（个人）

| 档位 | 工具 |
|------|------|
| **完全免费 + 自托管** | Aider、Cline、Roo Code、opencode、Crush、Continue、OpenHands、SWE-agent、CodeGeeX |
| **免费 + 自家 API 计费** | Gemini CLI、Codex CLI（订阅）、通义灵码、CodeBuddy、Comate、Trae、MarsCode |
| **$10–20/月** | Cursor、Windsurf、GitHub Copilot、CodeRabbit |
| **$20+/月（高级）** | Claude Code Max、Windsurf Ultra ($200) |
| **$500+/月（企业）** | Devin、Factory |
| **企业议价** | Tabnine、JetBrains AI Enterprise、Codeium Enterprise |

---

下一章：[`07-selection-guide.md`](./07-selection-guide.md)
