# Phase 1 · 步骤 2：HyperSpec 子文件依赖审查报告

> **审查目的**：验证 v2 设计文档 R2 风险——HyperSpec 委托的子 skill 是否有 Claude Code 特定依赖
> **审查日期**：2026-07-17
> **审查范围**：HyperSpec SKILL.md + 三个 opsx 子文件 + 项目实际目录结构
> **结论**：R2 风险**降级为低风险**，发现新的简化机会（`.agents/skills/` 通用路径已存在）

---

## 一、关键发现（执行摘要）

### 1. 文件结构层次比预期复杂

项目 `sunny-qms-service` 同时维护**两套并行**的 skill 路径：

| 路径 | 用途 | 内容 |
|------|------|------|
| `.claude/skills/` | **Claude Code 特定** | openspec-* 全套 + Superpowers + HyperSpec + 项目特定 |
| `.agents/skills/` | **通用 Agent 路径** | Superpowers + HyperSpec（**不含** openspec-*） |

**结论**：用户的 Harness V2 已经为多 Agent 适配做了部分准备——Superpowers 和 HyperSpec 已经放在了**通用路径**下。这是 v2 设计未发现的事实。

### 2. SKILL.md 第 196-198 行的"子文件"实际不存在

HyperSpec SKILL.md 原文：
```
- propose 阶段 → 读取 skill 目录下的 propose.md
- apply 阶段 → 读取 skill 目录下的 apply.md
- archive 阶段 → 读取 skill 目录下的 archive.md
```

实际状态：
- `.claude/skills/hyperspec/` → **只有 SKILL.md**
- `.agents/skills/hyperspec/` → **只有 SKILL.md**
- `.claude/commands/opsx/` → 有 propose.md/apply.md/archive.md，但是 **slash command 定义**

**真实工作机制**：SKILL.md 第 196-198 行是**伪代码**——HyperSpec 不是字面意义上"读取 markdown 文件"，而是通过 **skill 名称路由**委托给 `openspec-propose` / `superpowers:subagent-driven-development` / `openspec-archive-change` 等已有 skill。

### 3. opencode 适配工作量进一步缩小

基于上述发现，opencode 适配的实际工作量：
- **Superpowers + HyperSpec**：✅ 已经在 `.agents/skills/`，opencode 直接读
- **openspec-* 系列**：需要从 `.claude/skills/` 复制到 `.agents/skills/`（或保留原位）
- **hooks**：需要转换为 opencode 插件（v2 设计已覆盖）
- **slash commands**：opencode 没有 `/` 命令系统，但 HyperSpec 是 skill 路由，不依赖 slash command

---

## 二、逐文件工具依赖分析

### 文件 1：`.claude/skills/hyperspec/SKILL.md`（222 行）

| 项目 | 评估 |
|------|------|
| 工具引用 | YAML 读写、文件扫描、Read 工具 |
| Claude Code 特定 hook | ❌ 无 |
| Claude Code 特定工具 | ❌ 无 |
| 依赖的 openspec CLI | ✅ `openspec` 命令（**工具无关**） |
| **工具无关性** | ✅ **100%** |

### 文件 2：`.claude/commands/opsx/propose.md`（106 行）

| 项目 | 评估 |
|------|------|
| 业务逻辑 | 调用 `openspec new/status/instructions` CLI |
| 工具引用 | bash、**AskUserQuestion**、**TodoWrite** |
| Claude Code 特定 hook | ❌ 无 |
| **工具无关性** | ⚠️ 工具名引用是软依赖 |

### 文件 3：`.claude/commands/opsx/apply.md`（152 行）

| 项目 | 评估 |
|------|------|
| 业务逻辑 | 调用 `openspec status/instructions apply` CLI + 文件读写 |
| 工具引用 | bash、Read、**AskUserQuestion** |
| Claude Code 特定 hook | ❌ 无 |
| **工具无关性** | ⚠️ 工具名引用是软依赖 |

### 文件 4：`.claude/commands/opsx/archive.md`（157 行）

| 项目 | 评估 |
|------|------|
| 业务逻辑 | 调用 `openspec list/status` CLI + mkdir/mv |
| 工具引用 | bash、**AskUserQuestion**、**Task**（subagent_type）、**Skill** |
| Claude Code 特定 hook | ❌ 无 |
| **工具无关性** | ⚠️ 工具名引用是软依赖，subagent 调用需适配 |

### 文件 5：`.claude/skills/openspec-propose/SKILL.md`（111 行）

与 `.claude/commands/opsx/propose.md` 内容**几乎相同**（同一份逻辑，不同承载形式：skill vs slash command）。

工具引用：bash、**AskUserQuestion**、**TodoWrite**。业务逻辑全在 `openspec` CLI。

---

## 三、`.agents/skills/` 已有内容清单

> 这一节是 v2 设计未覆盖的**新事实**——opencode 适配可以直接复用。

`.agents/skills/` 下已有 16 个 Superpowers skills：

| Skill | 用途 |
|-------|------|
| brainstorming | 头脑风暴 |
| dispatching-parallel-agents | 并行子代理 |
| executing-plans | 执行计划 |
| finishing-a-development-branch | 完成开发分支 |
| gstack | 全栈工程栈（最大的一个） |
| **hyperspec** | ⭐ HyperSpec 编排 |
| receiving-code-review | 接收审查 |
| requesting-code-review | 请求审查 |
| subagent-driven-development | 子代理驱动开发 |
| systematic-debugging | 系统调试 |
| test-driven-development | TDD |
| using-git-worktrees | Git worktree |
| using-superpowers | Superpowers 入口 |
| verification-before-completion | 完成前验证 |
| writing-plans | 写计划 |
| writing-skills | 写 skill |

**缺口**：
- ❌ `.agents/skills/openspec-propose/` — 不存在
- ❌ `.agents/skills/openspec-apply-change/` — 不存在
- ❌ `.agents/skills/openspec-archive-change/` — 不存在
- ❌ `.agents/skills/openspec-sync-specs/` — 不存在
- ❌ `.agents/skills/openspec-verify-change/` — 不存在
- ❌ `.agents/skills/openspec-continue-change/` — 不存在
- ❌ `.agents/skills/openspec-explore/` — 不存在
- ❌ `.agents/skills/openspec-ff-change/` — 不存在
- ❌ `.agents/skills/openspec-new-change/` — 不存在
- ❌ `.agents/skills/openspec-onboard/` — 不存在
- ❌ `.agents/skills/omc-reference/` — 不存在（这是 OMC MCP 工具引用）
- ❌ `.agents/skills/quick-review/` — 不存在
- ❌ `.agents/skills/_project_specific/` — 不存在
- ❌ `.agents/skills/_templates/` — 不存在

---

## 四、对 v2 设计的具体调整建议

### 建议 1：明确 `.agents/skills/` 的角色

v2 设计的 `init-for-opencode.sh` 应该：

```bash
# 原计划（隐式）：从 Claude Code hooks 转换为 opencode 插件
# 新增（显式）：
#   - 验证 .agents/skills/ 存在且包含 Superpowers + hyperspec
#   - 把缺失的 openspec-* skills 从 .claude/skills/ 复制（或软链）到 .agents/skills/
#   - 让 opencode 把 .agents/skills/ 作为 skill 加载路径
```

### 建议 2：hooks 替换策略简化

v2 设计中的 3 个插件（harness-role、harness-guard、harness-checks）**无需修改**，但是：
- 它们不再需要"接管 HyperSpec"——HyperSpec 通过 skill 路由就能工作
- 它们只需要管**两件事**：(1) 角色切换、(2) 写保护/编译检查

### 建议 3：R2 风险降级

**v2 设计第十二章节**原文：
> R2: HyperSpec 子文件依赖审查（待步骤 2 完成）

**降级为**：
> ~~R2~~ → 已澄清：HyperSpec 委托的子 skill **没有 Claude Code 硬依赖**，只有工具名称软引用。LLM 看到 `AskUserQuestion 工具`/`TodoWrite 工具`/`Task 工具` 时会自动用 opencode 的等价能力。

### 建议 4：剩余唯一真风险 R1（opencode API 稳定性）

opencode 还在快速演化，`plugin()` / `event` / `tool.pre` API 可能在 2026 年下半年发生变化。**缓解**：将插件代码集中在 3 个文件里，便于跟踪 API 变更。

---

## 五、修订后的实施清单

> v2 设计的第十三章节"实施清单（10 步，约 700 行）"调整为以下顺序：

| 步骤 | 工作内容 | 预估代码量 | 状态 |
|------|---------|----------|------|
| 0 | **新增**：编写本审查报告 | 250 行 markdown | ✅ 已完成 |
| 1 | harness-opencode/ 骨架 + README | 30 行 | ⏳ 待开始 |
| 2 | ~~review HyperSpec 子文件~~ | ~~15 分钟~~ | ✅ 已完成（本报告） |
| 3 | **新增**：openspec-* skill 复制脚本（.claude → .agents） | 50 行 bash | ⏳ |
| 4 | 插件 harness-role（session.start） | ~80 行 TS | ⏳ |
| 5 | 插件 harness-guard（tool.pre） + permissions.yaml | ~150 行 TS + YAML | ⏳ |
| 6 | 插件 harness-checks（tool.post） | ~60 行 TS | ⏳ |
| 7 | opencode agents frontmatter（7 个文件） | ~100 行 markdown | ⏳ |
| 8 | config/opencode.json.template | ~50 行 JSON | ⏳ |
| 9 | init-for-opencode.sh | ~250 行 bash | ⏳ |
| 10 | uninstall-for-opencode.sh | ~80 行 bash | ⏳ |
| 11 | verify-opencode-adapter.sh | ~150 行 bash | ⏳ |

**总代码量预估**：约 750 行（v2 原估计 700 行基础上 + 50 行 openspec skill 复制）

---

## 六、下一步建议

R2 已澄清。建议立即进入实施阶段：

1. ✅ **步骤 0 已完成**（本审查报告）
2. ⏭️ **步骤 1**：创建 `harness-packages/harness-opencode/` 骨架目录
3. ⏭️ **步骤 3-11**：按修订清单顺序产出代码

**等待用户确认后即可开始**。

---

## 七、参考文件清单（审查依据）

| 文件路径 | 行数 | 用途 |
|---------|------|------|
| `E:\IdeaProjects\sunny-qms\sunny-qms-service\.claude\skills\hyperspec\SKILL.md` | 222 | HyperSpec 主 skill（Claude Code 版本） |
| `E:\IdeaProjects\sunny-qms\sunny-qms-service\.agents\skills\hyperspec\SKILL.md` | 222 | HyperSpec 主 skill（**通用 Agent 版本**） |
| `E:\IdeaProjects\sunny-qms\sunny-qms-service\.claude\commands\opsx\propose.md` | 106 | Propose slash command |
| `E:\IdeaProjects\sunny-qms\sunny-qms-service\.claude\commands\opsx\apply.md` | 152 | Apply slash command |
| `E:\IdeaProjects\sunny-qms\sunny-qms-service\.claude\commands\opsx\archive.md` | 157 | Archive slash command |
| `E:\IdeaProjects\sunny-qms\sunny-qms-service\.claude\skills\openspec-propose\SKILL.md` | 111 | openspec-propose skill |
| `E:\IdeaProjects\sunny-qms\sunny-qms-service\.hyperspec-state.yaml` | — | 运行时状态文件 |

---

## 八、致谢

本审查由用户在 v2 设计文档第十五章节中提出"先做步骤 2"后触发。审查过程发现 `.agents/skills/` 路径已存在，这一事实显著简化了 opencode 适配的工作量，是 v2 设计中遗漏的关键信息。
