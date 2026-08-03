# Harness V2 多 Agent 适配 · 可行性报告与方案

> **生成日期**：2026-07-20
> **目标**：让 Harness V2 基础设施 + 智能体模式（已用 Claude Code 完成适配）扩展到第二/三梯队工具。
> **覆盖范围**：
> - **CLI 三梯队**：① Claude Code（已完成基准） ② opencode ③ Qwen Code / Kimi Code
> - **IDE 适配**：Trae（普通模式 vs SOLO 模式深度分析）

---

## 一、TL;DR · 三句话结论

1. **opencode 适配最简单**——它的 Plugin/Hook 系统几乎是 Claude Code 的"开源克隆版"，**70% 的脚本可零改动迁移**，是第二梯队的首选。
2. **Qwen Code（基于 Gemini CLI）适配中等**——它复用 Gemini CLI 的 hooks/extensions 机制，但**配置文件名不同**（`GEMINI.md` 而非 `AGENTS.md`）、hook 签名略不同，需要**改文件名 + 适配 hook 入参格式**。
3. **Trae 必须用普通模式，不能用 SOLO 模式**——SOLO 模式**当前不支持 Hooks**（社区已开 issue 反馈），而 Harness 的 4 大 hook（apply-role / guard_write / ensure_change_context / run_checks）必须依赖 hooks。详见第三章。

---

## 二、Harness 对 Agent 工具的"硬依赖"清单

适配任何工具前，必须先搞清楚 Harness **依赖哪些能力**。下表是 Claude Code 当前适配用到的能力：

| 能力 | Harness 用途 | Claude Code 实现位置 |
|------|------------|-------------------|
| **SessionStart Hook** | 检查 `.hyperspec-state.yaml`，注入当前 checkpoint 对应的角色 prompt | `hooks/apply-role.sh` |
| **PreWrite Hook** | 拦截对 `application.yml / db/ / sql/ / .env` 的写入 | `hooks/guard_write.py` |
| **PreBash / PreToolUse Hook** | 危险命令（`git push`、`drop table`）必须有 openspec 工单 | `hooks/ensure_change_context.py` |
| **PostWrite Hook** | `.java` 文件保存后自动跑 `mvn compile` 检查 | `hooks/run_checks.sh` |
| **MCP 客户端** | 调用 OMC（Obsidian Memory Center）、guard 等 MCP 服务 | 通过 `.mcp.json` 注册 |
| **角色配置注入** | 7 个角色（PM/Architect/TechLead/Developer/Reviewer/Tester/DevOps）的权限矩阵 | `team-roles/permissions.json` |
| **Slash Commands / Skills** | `/openspec`、`/openspec-proposal` 等命令 | `.claude/skills/` |
| **AGENTS.md 自动加载** | 项目级规范文件，会话启动时自动注入上下文 | 根目录 `AGENTS.md` |

**核心结论**：**任何一个新 Agent 工具要适配 Harness，必须能跑上述 8 项中的至少前 4 项（4 类 hooks）**。否则 HyperSpec 状态机就不通。

---

## 三、Trae 普通模式 vs SOLO 模式 · 深度对比

### 3.1 两种模式的本质差异

| 维度 | 普通模式（Builder / AI 对话） | SOLO 模式 |
|------|----------------------------|-----------|
| **形态** | 集成在 Trae IDE 内 | **独立客户端**（从 IDE 剥离） |
| **定位** | 开发者辅助 | "AI 主导、人类旁看"的自主 Agent |
| **Agent 架构** | 单一 Builder | **Subagent 多代理**（可针对不同任务用不同模型） |
| **核心场景** | 写代码 + 调试 + 问答 | 全流程：需求理解 → 写码 → 测试 → 预览 → 部署 |
| **配置入口** | 设置图标 | 聊天面板右上角设置 |

### 3.2 对 Harness 适配至关重要的能力对比

| 能力 | 普通模式 | SOLO 模式 | Harness 是否必需 |
|------|---------|----------|---------------|
| **SessionStart Hook** | ✅ 支持 | ❌ **不支持** | ⭐⭐⭐⭐⭐ 必需（apply-role.sh） |
| **PreToolUse Hook** | ✅ 支持 | ❌ **不支持** | ⭐⭐⭐⭐⭐ 必需（guard_write / ensure_change_context） |
| **PostToolUse Hook** | ✅ 支持 | ❌ **不支持** | ⭐⭐⭐⭐ 必需（run_checks.sh） |
| **UserPromptSubmit Hook** | ✅ 支持 | ❌ **不支持** | ⭐⭐⭐ 可选 |
| **MCP Server** | ✅ 支持 | ✅ 支持 | ⭐⭐⭐⭐ 必需 |
| **自定义智能体 / 角色** | ✅ 支持 | ✅ 支持 | ⭐⭐⭐⭐ 必需 |
| **Slash Commands** | ✅ 支持 | ⚠️ 部分 | ⭐⭐⭐ 必需 |
| **从外部 IDE 导入配置** | 手动 | ✅ **默认开启** | ⭐⭐ 加分项 |

### 3.3 关键事实（来自官方 + 社区）

- **官方 Hook 文档明确**：Trae 支持 `SessionStart / UserPromptSubmit / PreToolUse / PostToolUse / Notification` 等 6 类 Hook，且支持**全局 Hook + 项目 Hook**。
  - 来源：[docs.trae.cn/ide_automate-actions-with-hooks](https://docs.trae.cn/ide_automate-actions-with-hooks)
- **SOLO 模式 Hooks 缺失**已有社区 issue 反馈：
  - [希望 TRAE SOLO 模式支持 hooks 机制（Trae 论坛）](https://forum.trae.cn/t/topic/15891)
  - [Builder/Agent 模式的生命周期 Hooks（GitHub Issue #2436）](https://github.com/Trae-AI/TRAE/issues/2436)
- **Trae Work** 是 SOLO 的升级形态，但截至 2026 年 7 月，Hooks 仍未原生支持。

### 3.4 ⚠️ 给 Harness 适配的硬性结论

> **Trae 必须用"普通模式（Builder）"适配 Harness。SOLO 模式不行。**

**理由**：Harness 的 4 大 hook 是 HyperSpec 状态机的"血管"。没有 SessionStart Hook，apply-role.sh 跑不起来，角色 prompt 注入失败，整条工作流就断了。

**SOLO 模式的折中方案**（不推荐，仅供评估）：
- 把 4 个 hook 的逻辑封装成 **MCP Server**（如 `harness-guard-mcp`），让 SOLO Agent 主动调用
- 但这是**自律型**（Agent 决定调不调），不是**强制型**（hook 强制拦截）——失去了 Harness "guard rail" 的意义
- 等同于回到 "Vibe Coding" 而非 "Spec-Driven Development"

**建议**：
- 短期：Trae 适配只做**普通模式**
- 长期：持续关注 Trae Work / SOLO 模式的 Hook 支持进展，等官方补齐再升级

---

## 四、三梯队 CLI 适配可行性矩阵

### 4.1 能力对照表

| 能力 | Claude Code（基准） | opencode | Qwen Code | Kimi Code |
|------|-------------------|----------|-----------|----------|
| **SessionStart Hook** | ✅ settings.json | ✅ Plugin `event.session.start` | ✅ Gemini CLI hooks | ⚠️ TS 重写后应支持，待官方确认 |
| **PreToolUse Hook** | ✅ | ✅ `event.tool.pre` | ✅ | ⚠️ |
| **PostToolUse Hook** | ✅ | ✅ `event.tool.post` | ✅ | ⚠️ |
| **MCP 客户端** | ✅ 原生 | ✅ 原生 | ✅ 原生 | ✅ |
| **角色配置文件** | `team-roles/permissions.json` | `agents/*.md`（YAML frontmatter） | `GEMINI.md` + extensions | `AGENTS.md` 推测 |
| **Slash Commands** | `.claude/commands/` | `.opencode/commands/` | Gemini CLI slash | 待确认 |
| **Skills 系统** | `.claude/skills/` | ✅ `.opencode/skills/`（同形态） | 通过 extensions | 待确认 |
| **BYOK** | ❌ | ✅ | ✅ | ✅ |
| **开源** | ❌ | ✅ MIT | ✅ | ✅ 部分 |
| **模型成本** | 高（Anthropic 订阅） | BYOK 任意 | 极低（Qwen3-Coder） | 极低（Kimi K3） |
| **文档完善度** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐（继承 Gemini CLI） | ⭐⭐（新，资料少） |

### 4.2 适配工作量评估（相对 Claude Code 基准）

| 工具 | 工作量 | 理由 |
|------|-------|------|
| **opencode** | **30%**（基本是平移） | Plugin 系统设计几乎一致，hooks API 名称略有不同（`event.session.start` vs Claude Code 的 `SessionStart`），改个事件名即可 |
| **Qwen Code** | **60%**（要改文件名 + 适配入参） | Hook 文件名要从 `.claude/settings.json` 改成 Gemini CLI 风格；`AGENTS.md` → `GEMINI.md`；hook 入参 JSON schema 略不同 |
| **Kimi Code** | **80%**（资料少、要踩坑） | TS 重写后 hook 能力需实测，文档稀缺，要做 spike |

### 4.3 推荐排序

1. **首选第二梯队**：opencode —— 几乎 1:1 平移 Claude Code 的适配
2. **第三梯队推荐 Qwen Code 而非 Kimi Code**：
   - Qwen Code 基于 Gemini CLI，hooks/extensions 文档完整（继承自 Gemini CLI）
   - Kimi Code 是 TS 重写的，hook 能力需要实测；K3 模型虽强，但适配成本高
   - **建议**：先把 Qwen Code 适配跑通，Kimi Code 作为后续可选

---

## 五、具体适配方案

### 5.1 opencode 适配方案（推荐先做）

#### 5.1.1 目录结构映射

| Claude Code（基准） | opencode 对应 |
|-------------------|--------------|
| `.claude/settings.json` | `opencode.json` 或 `OPENCODE_CONFIG_DIR` 指定目录 |
| `.claude/hooks/apply-role.sh` | `opencode/plugins/harness-role/index.ts` |
| `.claude/hooks/guard_write.py` | `opencode/plugins/harness-guard/index.ts`（订阅 `event.tool.pre`） |
| `.claude/skills/` | `.opencode/skills/`（**结构完全相同**） |
| `team-roles/permissions.json` | `opencode/agents/*.md`（YAML frontmatter 写权限） |
| `AGENTS.md` | `AGENTS.md`（**opencode 也用同名文件**） |

#### 5.1.2 Hook 改写示例

Claude Code 的 `apply-role.sh` 是 shell + YAML；opencode 推荐 TS 插件：

```typescript
// opencode/plugins/harness-role/index.ts
import { plugin } from "@opencode/plugin-sdk";

plugin("harness-role", {
  event: {
    "session.start": async (event) => {
      const checkpoint = await readYaml(".hyperspec-state.yaml");
      const role = mapCheckpointToRole(checkpoint);
      const prompt = await readFile(`agents/${role}.md`);
      return { system: prompt }; // 注入到 session
    },
  },
});
```

#### 5.1.3 关键收益

- **Skills 可零改动复用**（opencode 也用 SKILL.md 格式）
- **AGENTS.md 同名自动加载**
- **权限矩阵通过 agents/*.md 的 YAML frontmatter 实现**，逻辑一致

#### 5.1.4 风险

- opencode 版本迭代快（2026 年周级更新），Plugin API 可能变更
- TUI 体验与 Claude Code 略不同，但功能层一致

### 5.2 Qwen Code 适配方案

#### 5.2.1 关键差异

- 基于 Gemini CLI → 复用 Gemini CLI 的 hooks/extensions 机制
- 默认配置文件 `GEMINI.md`（**需要软链或符号链接到 `AGENTS.md`**）
- Hook 事件命名与 Gemini CLI 一致

#### 5.2.2 改动清单

1. **`AGENTS.md` 双写**：保留根目录的 `AGENTS.md`，同时创建 `GEMINI.md` 软链或副本
2. **Hook 配置路径**：从 `.claude/settings.json` 改到 Gemini CLI 的 hooks 配置（通常在 `~/.gemini/settings.json` 或项目 `.gemini/settings.json`）
3. **Hook 入参格式适配**：Gemini CLI 的 hook 入参 JSON 与 Claude Code 略有差异（字段名不同），需要写适配层
4. **角色注入**：Gemini CLI 用 extensions 而非 SessionStart hook 注入角色 prompt——可以**把 7 个角色 prompt 做成 7 个 extension**

#### 5.2.3 风险

- Qwen Code 是 Gemini CLI 的 fork，**未来可能随上游漂移**
- 文档主要在 Gemini CLI 官网，Qwen Code 自己的适配文档少
- Hook API 受 Gemini CLI 上游决定

### 5.3 Kimi Code 适配方案（备选）

#### 5.3.1 已知信息

- 0.4.0 版本用 TypeScript 重写
- 支持 MCP
- Hook 能力**官方文档未明确**，需要实测

#### 5.3.2 Spike 计划

在主适配前，先做一个 1–2 天的 spike：
1. 安装 Kimi Code 0.4.0
2. 测试 SessionStart / PreToolUse / PostToolUse 是否可用
3. 如可用 → 按 opencode 路径适配（同为 TS 架构）
4. 如不可用 → 降级为"MCP Server 模式"（封装 guard 逻辑为 MCP，让 Agent 自律调用，**但要明确告诉用户这是降级方案**）

#### 5.3.3 风险

- **资料稀缺**：中文社区讨论少，国际社区几乎无评测
- **维护节奏**：月之暗面产品线广（Kimi 助手、K2/K3 模型、Code CLI），Code CLI 可能不是最高优先级

### 5.4 Trae 适配方案（普通模式）

#### 5.4.1 配置入口

- 普通 Builder 模式：设置图标 → Hooks 配置 → 全局 / 项目级

#### 5.4.2 Hook 映射

| Harness Hook | Trae Hook 事件 | 配置位置 |
|------------|---------------|--------|
| `apply-role.sh` | `SessionStart` | 项目 `.trae/hooks/` |
| `guard_write.py` | `PreToolUse`（拦截 Write） | 项目 `.trae/hooks/` |
| `ensure_change_context.py` | `PreToolUse`（拦截 Bash） | 项目 `.trae/hooks/` |
| `run_checks.sh` | `PostToolUse`（Write 后触发） | 项目 `.trae/hooks/` |

#### 5.4.3 关键差异

- Trae 的 Hook 是 **Shell 命令**（和 Claude Code 一致），**shell 脚本可零改动复用**
- 角色注入：Trae 通过 "自定义智能体" 配置，把 7 个角色 prompt 注册为 7 个智能体
- MCP 配置：通过 Trae 设置面板的 JSON 配置（**与 Claude Code 的 `.mcp.json` 结构兼容**）

#### 5.4.4 工作量

**约 40%**——shell 脚本零改动，主要工作在：
- 配置文件格式转换（`.claude/settings.json` → `.trae/hooks/config.json`）
- 角色智能体的 YAML frontmatter 重写
- MCP 配置从文件迁移到 Trae 设置面板

#### 5.4.5 风险

- Trae **普通模式与 SOLO 模式分裂**——用户切换模式会失效，**必须在文档里强调"仅支持普通模式"**
- Trae 国际版 / 国内版的配置可能不互通
- Trae 是闭源 IDE，未来 hook API 可能变更

---

## 六、整体路线图建议

### Phase 1（1–2 周）：opencode 适配 ⭐ 第二梯队

- 优先级最高、工作量最小
- 验证 "Harness 是 Agent-agnostic" 这个核心假设
- 产出：`harness-packages/harness-infra/init-for-opencode.sh`
- **预期收益**：解锁 BYOK 能力（任意 OpenAI-compatible 端点都可用）

### Phase 2（2 周）：Qwen Code 适配 ⭐ 第三梯队主选

- 国产 BYOK 阵营的代表
- 产出：`harness-packages/harness-infra/init-for-qwen.sh`
- **预期收益**：阿里云生态 + Qwen3-Coder 1M 上下文 + 极低 token 成本

### Phase 3（1 周）：Trae 普通模式适配 ⭐ IDE 阵营

- 解决 IDE 阵营的覆盖问题
- 产出：`harness-packages/harness-infra/init-for-trae.sh`
- **关键约束**：文档明确"仅支持普通模式，不支持 SOLO 模式"
- **预期收益**：国内开发者最常用的 AI IDE 适配

### Phase 4（备选，3–5 天）：Kimi Code Spike

- **触发条件**：Phase 2 完成后，或用户主动要求
- 先做 spike 评估 hook 能力
- 视结果决定是否做完整适配
- **预期收益**：备选国产方案，200 万汉字上下文 + K3 模型

---

## 七、关键风险与依赖

### 7.1 单点风险

| 风险 | 影响 | 缓解措施 |
|------|------|--------|
| opencode Plugin API 破坏性变更 | 第二梯队失效 | 锁定 opencode 版本，季度评估升级 |
| Trae 普通模式被弃（全面转 SOLO） | IDE 适配失效 | 持续监控官方公告；准备 MCP 模式降级方案 |
| Qwen Code 与 Gemini CLI 上游漂移 | Hook 配置失效 | 在 harness-infra 里维护 Qwen Code 专用 hook 适配层 |
| Kimi Code Hook 能力不足 | 第三梯队降级 | Spike 验证；必要时降级为 MCP 自律模式 |

### 7.2 共性依赖

所有 4 个适配都依赖以下基础（已在 Claude Code 适配中沉淀）：

- ✅ `.hyperspec-state.yaml` 状态机文件格式
- ✅ `openspec/changes/<id>/` 工件目录结构
- ✅ `team-roles/permissions.json` 角色权限矩阵
- ✅ HyperSpec 12 检查点定义
- ✅ `AGENTS.md / CLAUDE.md / REVIEW.md` 三件套模板

这些**不动**，只改 hook 接入层。

---

## 八、决策（已确认 · 2026-07-20）

| 决策项 | 确认结果 |
|-------|---------|
| 第一梯队 CLI | ✅ **Claude Code**（已完成，作为基准） |
| 第二梯队 CLI | ✅ **opencode** |
| 第三梯队 CLI 主选 | ✅ **Qwen Code** |
| 第三梯队备选 | ✅ **Kimi Code**（按 spike 结果决定是否做完整适配） |
| IDE 适配 | ✅ **Trae 普通模式**（不接受 SOLO 模式，理由见第三章） |
| **工具混用策略** | ❌ **不混用**——每个项目每次只选一个工具 |

### 8.1 "不混用"对设计的影响（重要简化）

"不混用"这个约束让适配工作**大幅简化**：

| 原本要考虑的复杂度 | 现在的处理 |
|-----------------|---------|
| 多工具配置文件并存（`.claude/` + `opencode/` + `.gemini/` + `.trae/`） | ❌ 不需要——每个工具独占 |
| 跨工具的 `AGENTS.md` ↔ `GEMINI.md` 软链 | ❌ 不需要 |
| `.hyperspec-state.yaml` 在不同工具间的读写差异 | ❌ 不需要——同一时刻只一个工具写 |
| 共享 MCP 配置（`.mcp.json`）的格式冲突 | ❌ 不需要——每个工具用自己的 mcp 配置入口 |
| 角色 prompt 在不同工具的"共享注入点" | ❌ 不需要——每个工具独立注入 |

**直接结论**：每个工具的 `init-for-<tool>.sh` 脚本可以**独占式、覆盖式**安装自己的配置，不需要做"幂等性深度合并"——只需保留 HyperSpec 状态机和 openspec 工件（这些是工具无关的）。

### 8.2 设计约束（针对"不混用"）

1. 每个 init 脚本**只装自己工具的配置**——不写其他工具的目录
2. uninstall 脚本**只删自己工具的痕迹**——不动 HyperSpec 状态机、openspec/、AGENTS.md/CLAUDE.md/REVIEW.md
3. 用户切换工具时，**手动跑** `uninstall-for-X.sh && init-for-Y.sh`——不需要自动切换
4. 文档明确："**同一项目同一时刻只装一个 Agent 工具的适配**"，避免误装两个导致 hook 冲突

---

## 九、下一步

决策已确认。可以选择以下任一路径推进：

### 路径 A：先做 Phase 1 详细设计（推荐）

输出 `harness-packages/multi-agent-adaptation/phase1-opencode-design.md`，内容包括：
- opencode Plugin 项目结构（`opencode/plugins/harness-*`）
- 4 个 hook（apply-role / guard-write / ensure-change-context / run-checks）的 TS 实现伪代码
- 与 Claude Code 适配的逐文件映射表
- 测试用例清单

### 路径 B：先写 4 个工具的"统一适配模板"

提取 Claude Code 适配中的可复用部分（hook 逻辑、角色映射、guard 规则），做成工具无关的 `harness-core/` 包，再让 4 个工具的 init 脚本各自引用——避免重复实现 4 遍。

### 路径 C：先做 Kimi Code 的 spike（前置评估）

花半天到一天实测 Kimi Code 0.4.0 的 hook 能力，确定 Phase 4 是否值得做。

---

**建议**：走路径 A——Phase 1 的工作量最小，先把它跑通可以验证"Harness 是 Agent-agnostic"的核心假设，后续 3 个工具的适配会因此更顺。

---

## 参考来源

| 主题 | 链接 |
|------|------|
| Trae 普通 vs SOLO 模式 | [阮一峰博客：Trae Solo](https://www.ruanyifeng.com/blog/2025/11/trae-solo.html) |
| Trae 官方 Hook 文档 | [docs.trae.cn/ide_automate-actions-with-hooks](https://docs.trae.cn/ide_automate-actions-with-hooks) |
| Trae SOLO Hooks 请求 issue | [forum.trae.cn/t/topic/15891](https://forum.trae.cn/t/topic/15891) |
| Trae GitHub Hooks issue | [github.com/Trae-AI/TRAE/issues/2436](https://github.com/Trae-AI/TRAE/issues/2436) |
| Trae MCP 配置 | [docs.trae.ai/ide/add-mcp-servers](https://docs.trae.ai/ide/add-mcp-servers) |
| opencode Plugins 文档 | [opencode.ai/docs/plugins](https://opencode.ai/docs/plugins/) |
| opencode Hooks 实现方式 | [dev.to: Does OpenCode Support Hooks](https://dev.to/einarcesar/does-opencode-support-hooks-a-complete-guide-to-extensibility-k3p) |
| opencode Plugin 开发指南 | [gist.github.com/rstacruz/946d02757525c9a0f49b25e316fbe715](https://gist.github.com/rstacruz/946d02757525c9a0f49b25e316fbe715) |
| Qwen Code GitHub | [github.com/QwenLM/qwen-code](https://github.com/QwenLM/qwen-code) |
| Gemini CLI Hooks 官方 | [geminicli.com/docs/hooks](https://geminicli.com/docs/hooks/) |
| Gemini CLI Extensions | [blog.google: Introducing Gemini CLI extensions](https://blog.google/innovation-and-ai/technology/developers-tools/gemini-cli-extensions/) |
| Kimi Code 百科 | [baike.baidu.com/item/Kimi Code CLI](https://baike.baidu.com/item/Kimi%20Code%20CLI/67975444) |
| Trae Agent 开源（旁参考） | [github.com/bytedance/trae-agent](https://github.com/bytedance/trae-agent) |
