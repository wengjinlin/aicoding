# AI 编码工具全景对比报告

> **生成日期**：2026-07-17
> **覆盖范围**：截至 2026 年中期的主流 AI 编码工具（CLI / IDE / 自主智能体 / 国产）
> **本报告定位**：选型参考——不是排行榜，而是"在什么场景下用什么工具"的决策依据。

---

## 一、为什么要做这份对比

Harness V2 的基础设施层是**模型无关、工具无关**的——它只假设你有一个能跑 MCP、能加载技能、能读 `openspec/` 工单的 Agent 容器。但团队成员问得最多的仍然是：

> "我应该用 Claude Code 还是 Cursor？还是直接用 Cline？"

这份报告试图一次性回答这个问题，并给出**可复用的对比维度**。

---

## 〇、修订记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-17 | 首版：CLI / IDE / 自主 Agent / 国产 / 基准 / 矩阵 / 选型 / 来源 共 9 文件 |
| **v1.1** | 2026-07-17 | **用户反馈遗漏后补全**：新增 8 款 CLI（**Droid**（Terminal-Bench #1 58.75%）、**Amp**、**Goose**、**CodeBuff**、**IBM Granitic**、**GitHub Copilot CLI**、**Kimi Code**（月之暗面）、**Qwen Code**（阿里））；更新 01/04/05/06 章节 |

### ⚠️ 关于"还可能漏了什么"

AI 编码工具领域**周级迭代**，任何"全景"报告都注定不完整。本报告仍可能遗漏：

- **新发布的工具**（v1.1 之后才出现的）
- **小众但活跃的工具**（如 Termtop 排行榜上的 [Antigravity CLI](https://terminaltrove.com/)、[Codebuff](https://www.codebuff.com/) 等）
- **特定语言/平台的专用 Agent**（如 Rust 专用、Solidity 专用）
- **企业内部闭源 Agent**（如摩根士丹利 GPT、JPMorgan IndexGPT 等）

建议读者把本报告当**起点**而非**终点**，配合 [awesome-cli-coding-agents](https://github.com/bradagi/awesome-cli-coding-agents) 等社区清单交叉使用。

---

## 二、分类框架

AI 编码工具按"工作形态"分三大类，每类的产品定位、使用方式、协议适配完全不同：

| 类别 | 形态 | 典型产品 | 谁在用 |
|------|------|---------|--------|
| **A. CLI / 终端原生** | 终端命令行、Agent 会话 | Claude Code、Aider、Cline、opencode、Gemini CLI、OpenAI Codex CLI | 重度命令行用户、CI/CD 集成、脚本化场景 |
| **B. IDE / 编辑器扩展** | VS Code fork / JetBrains / Vim 插件 | Cursor、Windsurf、Trae、Continue、Roo Code、Copilot、JetBrains AI | 日常开发、可视化交互、团队协作 |
| **C. 自主智能体（Autonomous Agent）** | 云端 Agent 异步处理整个任务 | Devin、OpenHands、Devika、SWE-agent、Factory、CodeRabbit | 整需求外包、批量化处理、PR 自动生成 |

> 还有一类"代码补全模型"（Codestral、DeepSeek-Coder、StarCoder2、CodeLlama），它们是**底座**而非**产品**，本报告只附带提及。

---

## 三、文件结构

| 文件 | 内容 |
|------|------|
| `01-cli-tools.md` | CLI 类工具逐项分析 |
| `02-ide-tools.md` | IDE/编辑器类工具逐项分析 |
| `03-autonomous-agents.md` | 自主智能体类工具逐项分析 |
| `04-china-tools.md` | 国产工具专题（通义灵码、CodeBuddy、Comate、Trae 等） |
| `05-benchmarks.md` | SWE-bench / Terminal-Bench / MorphLLM 等权威排行 |
| `06-comparison-matrix.md` | 横向对比矩阵（一张表看全部工具） |
| `07-selection-guide.md` | 基于场景的选型建议 |
| `SOURCES.md` | 全部参考来源与数据时效性说明 |

---

## 四、TL;DR（三十秒看完）

### 如果你只想知道三件事

1. **SWE-bench Verified 最强模型**：Claude Opus 4.x 系列长期占据前列（官方榜 75.6%，第三方榜有 87–95% 的报告），GPT-5 Codex、GLM-5 紧追。
2. **Terminal-Bench 最强 Agent**：**Droid（Factory AI）58.75%**——这是 v1.1 才补上的重要事实，证明 Agent 架构有时比模型更重要。
3. **MCP 协议**已经成为事实标准——Cursor、Windsurf、Claude Code、Cline、Roo Code、通义灵码、Kimi Code、Qwen Code 等**全部支持**。如果不支持 MCP，基本可以判定为"上一代工具"。

### 三句话选型

- 想要**最强模型 + 最深 Agent 能力** → **Claude Code**（CLI）或 **Cursor**（IDE）
- 想要**完全自主可控 + 开源** → **Cline / Roo Code**（IDE）或 **Aider / opencode**（CLI）
- 想要**云端外包整需求** → **Devin**（商业）或 **OpenHands**（开源）

### 三句话"国产 + BYOK"补充（v1.1 新增）

- 想要**国产 CLI + 长上下文** → **Kimi Code**（200 万汉字）或 **Qwen Code**（1M token）
- 想要**国产 IDE 插件** → **通义灵码**（MCP 生态最完善）
- 想要**国产模型 + 任意工具 BYOK** → **DeepSeek-Coder** 或 **Qwen3-Coder** API

---

## 五、核心结论（在阅读详细章节之前）

### 1. 模型 vs 工具：别混淆

> "Cursor 比 Claude Code 强" 是无意义的陈述——Cursor 可以调用 Claude 模型。

工具提供的是**交互形态、上下文管理、工具调用能力**；模型提供的是**推理与代码生成能力**。本报告把两者分开看。

### 2. 三条不可逆趋势

- **MCP 胜出**：Anthropic 的 Model Context Protocol 已经成为 Agent ↔ 外部系统的标准接口，2025 年起所有主流工具都已支持。
- **BYOK 与商业计费二选一**：开源工具以 BYOK 为荣，商业工具以"按月订阅"锁定用户。
- **Agent 能力下沉**：去年还要 Devin 才有的"多步规划 + 自主执行"，现在 Claude Code、Cursor、Cline 都能做到。

### 3. 中国市场的特殊情况

国产工具（通义灵码、CodeBuddy、Comate、Trae、CodeGeeX）在**中文场景、本地化、价格**上有显著优势，但：
- 大部分默认绑定自家模型（Qwen、混元、文心）
- MCP 支持深度参差（通义灵码最完善）
- 国际社区影响力弱

详见 `04-china-tools.md`。

---

## 六、数据时效性声明

本报告所有数据来自 2026 年 7 月之前的公开资料。AI 编码领域演化极快，**任何"截至 X 月"的陈述在 3 个月后都可能失效**。建议将本报告视为**2026 年中期的快照**，并参考 `SOURCES.md` 中的链接自行交叉验证。

特别是：
- SWE-bench 分数存在"官方提交"和"第三方自报"两个口径，差异较大
- 模型版本号（Opus 4.7、GPT-5.6、Fable 5 等）来自第三方报道，**未经官方确认的版本不在本报告核心结论中**
- 工具的 MCP/BYOK 支持情况以**官方文档**为准，第三方测评仅供参考

---

下一站：[`01-cli-tools.md`](./01-cli-tools.md) 开始看 CLI 类工具。
