# 05 · 权威基准测试与排行

> **重要前提**：所有基准测试都有"刷分"嫌疑。本章节列出**多个独立来源**，交叉对比后才能看出真实水平。

---

## 一、主流基准测试简介

| 基准 | 测试什么 | 数据规模 | 权威性 | 备注 |
|------|---------|---------|--------|------|
| **SWE-bench** | 真实 GitHub issue 修复（端到端） | ~2,294（Verified 子集 500） | ⭐⭐⭐⭐⭐ | 学术 + 工业公认 |
| **SWE-bench Verified** | 人工验证子集，质量更高 | 500 | ⭐⭐⭐⭐⭐ | 最常被引用 |
| **SWE-bench Pro** | 更难、更多语言 |  mini/regular | ⭐⭐⭐⭐ | 2025 年起新增 |
| **Terminal-Bench** | 终端任务（部署/运维/CLI） | — | ⭐⭐⭐⭐ | 2025 年起流行 |
| **LiveCodeBench** | 实时编程题（防数据污染） | — | ⭐⭐⭐⭐ | 反 overfit |
| **HumanEval / MBPP** | 函数级补全 | ~500 | ⭐⭐⭐ | 已被刷穿，区分度低 |
| **BigCodeBench** | 复杂多文件任务 | — | ⭐⭐⭐ | 偏库使用 |
| **Aider Leaderboard** | 编辑成功率（自带） | ~89 题 | ⭐⭐⭐ | 工程实践向 |
| **MorphLLM Index** | 综合分数（多基准加权） | — | ⭐⭐⭐ | 第三方 |

---

## 二、SWE-bench Verified Top 模型（截至 2026 年 7 月）

> **数据来源**：[swebench.com 官方榜](https://www.swebench.com/) + 第三方报道。第三方数字可能高于官方，因部分采用更激进的 harness 配置。

### 官方榜单

| 模型 | 分数 | 提交方 |
|------|------|--------|
| Claude Opus 4.6 | **75.60%** | Anthropic |
| GPT-5-2 Codex | 72.80% | OpenAI |
| GLM-5 (high reasoning) | 72.80% | 智谱 AI |
| GPT-5-2 (high reasoning) | 72.80% | OpenAI |

### 第三方报告（不同 harness / 不同评测口径）

| 模型 / 工具 | 分数 | 来源 |
|------------|------|------|
| Claude Fable 5 | ~95.0% | MorphLLM |
| GPT-5.5 (OpenAI 自报) | 88.7% | OpenAI |
| Claude Opus 4.8 | 88.6% | 第三方跟踪 |
| Claude Opus 4.7 | 87.6% | Codesoto / Birjob |
| GPT-5.3 Codex | 85.0% | Birjob |
| Claude Code (Opus 4.6 harness) | 80.8% | NXCode |

### ⚠️ 数据真实性警示

部分第三方榜单引用的模型版本（Fable 5、Opus 4.8、Mythos Preview）**官方未确认**。这些可能是：
- 真实新版本（领先于官方公告）
- 第三方自报数字（不可复现）
- 纯属推测的未来内容

**保守结论**：截至 2026 年 7 月，**Anthropic Claude Opus 4.x 系列**在 SWE-bench Verified 上处于第一梯队，**OpenAI GPT-5 Codex** 紧随其后，**智谱 GLM-5** 已进入国际第一梯队（这是国产模型的历史性突破）。

---

## 三、Terminal-Bench 2.1（截至 2026 年）

测试 Agent 在真实终端任务（部署、运维、CI/CD）的能力。

| 工具 / 模型 | 分数 | 备注 |
|------------|------|------|
| **Droid（Factory AI）** | **58.75%（#1）** | ⭐ Terminal-Bench 冠军，靠 agent design 而非模型；可调智谱 GLM-4.6 |
| Claude Code + Opus 4.x | 高 | 工程实践强，社区稳定口碑 |
| Codex CLI + GPT-5 | 高 | OpenAI 官方 |
| OpenHands + Opus | 高 | 开源阵营最强 |
| opencode | 中高 | 开源 CLI 新秀 |
| Goose / Amp | 中高 | 企业向 |
| Cursor + Opus | 中高 | IDE harness |
| Cline + Sonnet | 中 | 开源 + 模型成本平衡 |
| Aider | 中 | Git-first，Agent 弱 |

**关键洞察**：Droid 在 Terminal-Bench 上超越 Claude Code 与 Codex CLI 的事实，证明**Agent 架构设计有时比底层模型更重要**——这是 2026 年最重要的范式转移信号之一。

---

## 四、MorphLLM AI Coding Agent Index（2026）

第三方综合榜（基于 GitHub stars + benchmark + 社区活跃度）：

| 工具 | Stars（约） | 综合排名 |
|------|-----------|---------|
| opencode | 180,000+ | #1 |
| Claude Code | 135,000+ | #2 |
| Gemini CLI | 105,000+ | #3 |
| OpenAI Codex | 94,000+ | #4 |
| Aider | 30,000+ | 高位 |
| OpenHands | 50,000+ | 高位（自主 Agent 类 #1） |
| Cline | 50,000+ | 高位 |
| Continue | 25,000+ | 中 |
| Roo Code | 15,000+ | 中 |

> ⚠️ Stars 数是**流行度**指标，不是**能力**指标。opencode 的高分主要来自社区热度而非 SWE-bench。

---

## 五、Aider Leaderboard（编辑成功率）

Aider 自维护的"模型在真实编辑任务上的成功率"榜单，按 architecture 分组：

### Whole Edit（整体编辑）组

| 模型 | 成功率 |
|------|--------|
| Claude Opus 4.x | 高 |
| GPT-5 Codex | 高 |
| DeepSeek-V3 / Coder-V2 | 中高（开源最强） |
| Qwen3-Coder | 中高 |
| Gemini 2.5 Pro | 中高 |

### Diff / UDiff 组（差分编辑）

| 模型 | 成功率 |
|------|--------|
| Claude Sonnet 4.x | 高 |
| GPT-5 mini | 中高 |

---

## 六、OpenHands Index（自主 Agent 类）

| Agent | SWE-bench Verified | 备注 |
|-------|-------------------|------|
| OpenHands + Opus 4.6 | 高（开源最强） | 自托管 |
| Devin（Cognition） | 高 | 商业，分数有争议 |
| Factory | 中高 | 企业向 |
| SWE-agent | 中 | 学术 baseline |

---

## 七、基准的局限

阅读这些数字时请记住：

1. **harness 影响 > 模型影响**
   同一个模型用 Claude Code harness 和用 SWE-agent harness 跑出来的分数可能差 20 个百分点。"工具"和"模型"要分开看。

2. **数据污染**
   部分模型可能在训练数据中见过 SWE-bench 测试集。LiveCodeBench 是反污染的尝试。

3. **"提交方"决定分数**
   Anthropic 自报 vs OpenAI 自报 vs 第三方测，数字差异大。**官方 swebench.com 才是最可信的**。

4. **基准 ≠ 真实工作**
   SWE-bench 都是修 bug 的任务；真实工作是"从需求到上线"，包含沟通、设计、文档——基准测不到。

---

## 八、对选型的启示

- **看重 SWE-bench Verified** → 选 Claude Opus 4.x 系模型 + Claude Code 或 Cursor
- **看重成本** → 选 DeepSeek-Coder-V2 + Aider/Cline
- **看重自主度** → 选 OpenHands + Claude Opus
- **看重中文场景** → 选 Qwen3-Coder（BYOK）或通义灵码（端到端）

---

下一章：[`06-comparison-matrix.md`](./06-comparison-matrix.md)
