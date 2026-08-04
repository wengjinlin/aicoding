# harness-agents — Harness V2 Agent 角色包

> 版本：1.0 | 适用架构：《Harness V2 架构设计文档2.md》第 8 章
> 定位：在 HyperSpec 编排层之上，为每个 checkpoint 加载专属角色（PM / Architect / Tech Lead / Developer / Reviewer / Tester / DevOps / Coordinator）
> 适用对象：已安装 harness-infra 的项目，希望让 AI 流程"角色化分工"

---

## 一、这个包是什么

`harness-agents` 是 Harness V2 的**角色分工增强包**。它本身不是独立可用的——必须基于 `harness-infra`（已含 HyperSpec）。

安装本包后，`/hyperspec` 启动全自动流程时，**每个 checkpoint 会自动切换到对应的角色**：

```
/hyperspec "财务月报按部门统计"
     │
     ▼
HyperSpec 主循环
     │
     ├─[proposal-draft]   → 加载 PM 角色 → 产出 proposal.md
     ├─[specs-draft]      → 加载 Architect 角色 → 产出 specs.md
     ├─[design-draft]     → 加载 Architect 角色 → 产出 design.md
     ├─[tasks-draft]      → 加载 Tech Lead 角色 → 产出 tasks.md
     ├─[task-N-tdd] × N   → 加载 Developer 角色 → 产出代码 + 测试
     ├─[task-N-review] × N→ 加载 Reviewer 角色 → 产出 review-report
     ├─[integration-test] → 加载 Tester 角色 → 产出 test-report
     ├─[final-review]     → 加载 Reviewer + Architect → 最终批准
     └─[archive-apply]    → 加载 DevOps 角色 → CHANGELOG + git commit
```

**关键**：仍然是**单个 Claude Code 会话**，但每个 checkpoint 看到的"自己"不一样——system prompt、工具权限、激活技能、模型路由都按角色定制。

---

## 二、本包的工作机制

本包基于**单实例 + 角色切换**模型——所有角色仍在同一个 Claude Code 会话内串行推进，但每个 checkpoint 看到的"自己"不同：

| 设计点 | 实现方式 |
|-------|---------|
| **上下文隔离** | 每个 checkpoint 清空无关上下文，避免"PM 思维污染 Developer 决策" |
| **工具权限分层** | Reviewer 严格只读，避免"自己写自己审"的共谋问题 |
| **模型独立审查** | Developer 用 sonnet、Reviewer 用 opus，不同模型进一步保证独立性 |
| **工件交接** | 角色之间通过标准工件（proposal/specs/design/tasks）传递，不靠记忆 |

**适用场景**：
- 单需求 task ≤ 5
- 并发需求 ≤ 2
- 团队对 token 成本敏感（本包与原 HyperSpec 同成本，1x）

---

## 三、前置条件

| 检查项 | 命令 | 说明 |
|-------|------|------|
| harness-infra 已装 | `ls .claude/skills/hyperspec` | 必须先装基础包 |
| HyperSpec 可用 | Claude 内 `/hyperspec --help` | 必须正常响应 |
| 项目可正常 `/hyperspec` | 试跑一个小需求 | 跑通后再装本包 |
| **jq 可执行** | `jq --version` | **必需**：注入 SessionStart hook 靠 jq 深度合并，无 jq 会报错退出 |

**未装 harness-infra 直接装本包**：脚本会报错退出，不会污染项目。

**jq 缺失**：脚本会在预检阶段 fail-fast 退出，提示安装方式。

### jq 跨平台安装

| 平台 | 命令 |
|------|------|
| Windows（winget） | `winget install jqlang.jq --source winget` |
| Windows（scoop） | `scoop install jq` |
| Windows（choco） | `choco install jq` |
| macOS | `brew install jq` |
| Ubuntu/Debian | `sudo apt-get install -y jq` |
| Fedora/RHEL | `sudo dnf install -y jq` |

---

## 四、安装方式

```bash
# 前置：harness-infra 已安装完成
cd your-project
bash harness-agents/install-harness-agents.sh
```

### 4.0 Windows 用户必读

Windows 上**必须用 Git Bash 或 MSYS2 bash**（不能用 PowerShell / cmd），原因：
- 安装脚本里大量使用 bash 关联数组、`set -uo pipefail`、heredoc 等 POSIX shell 特性
- jq 在 bash 环境下 path 解析才稳定

| 步骤 | 操作 |
|------|------|
| 1. 打开 Git Bash | 开始菜单搜 "Git Bash"；或在资源管理器目标目录右键 → "Git Bash Here" |
| 2. 切到项目目录 | `cd /e/your-project`（注意是 `/e/` 不是 `E:\`） |
| 3. 跑安装脚本 | `bash harness-agents/install-harness-agents.sh` |

Windows 路径在 bash 中的写法对照：

| Windows 路径 | Bash 路径 |
|--------------|-----------|
| `E:\your-project` | `/e/your-project` |
| `C:\Users\me\code\app` | `/c/Users/me/code/app` |

### 4.1 安装脚本会做的事

1. ✅ 检测 `.claude/skills/hyperspec` 是否存在（验证 infra 已装）
2. ✅ **预检 jq 是否可用**（fail-fast，无 jq 直接退出）
3. ✅ 备份当前 `.claude/settings.local.json` 到 `.harness-backup-{date}/`
4. ✅ 创建 `.claude/agents/` 目录并写入 7 个角色 prompt
5. ✅ 创建 `.claude/team-roles/` 目录并写入权限矩阵 + checkpoint 映射
6. ✅ 添加 `apply-role.sh` + `on-state-change.sh` 到 `.claude/hooks/`
7. ✅ 用 jq 深度合并 `SessionStart` + `PostToolUse(Write|Edit)` hook 到 `settings.local.json`（保持 `{matcher, hooks: [...]}` 嵌套结构）
8. ✅ 验证角色加载正确

> **关于 hooks 嵌套结构**：Claude Code 要求 `hooks.<event>` 必须是数组，每项为 `{matcher, hooks: [{type, command}]}`。本脚本生成的 SessionStart 配置形如：
> ```json
> {"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"bash .claude/hooks/apply-role.sh"}]}]}}
> ```
> 旧的 flat 结构 `{type, command, matcher}` 会被 Claude Code 拒绝（`Settings Error: hooks: Expected array`）。脚本已兼容旧 flat 结构——重跑会自动迁移。

---

## 五、包含的文件清单

### 5.1 角色定义（7 个）

| 文件 | 角色 | 模型 | 工具权限 | 主导 checkpoint |
|------|------|------|---------|----------------|
| `.claude/agents/pm.md` | 产品经理 | opus | 只读 | proposal-draft |
| `.claude/agents/architect.md` | 架构师 | opus | 只读 + LSP/AST | specs-draft, design-draft |
| `.claude/agents/tech-lead.md` | 技术负责人 | sonnet | 只读 + LSP | tasks-draft |
| `.claude/agents/developer.md` | 开发 | sonnet/opus | Edit/Write（受 guard）+ Bash | task-N-tdd |
| `.claude/agents/reviewer.md` | 代码审查员 | **opus**（≠ Developer） | **完全只读** | task-N-review, final-review |
| `.claude/agents/tester.md` | 测试 | sonnet | Bash（run_tests）+ Read | integration-test |
| `.claude/agents/devops.md` | 发布 | sonnet | Edit（仅 docs）+ Bash（git/CI） | archive-apply |

> 第 8 个角色 Coordinator 由 HyperSpec 内置实现（haiku 模型，轻量决策），不需要单独 prompt。

### 5.2 配置文件

| 文件 | 作用 |
|------|------|
| `.claude/team-roles/permissions.json` | 角色 × 工具权限矩阵 |
| `.claude/team-roles/checkpoint-map.yaml` | HyperSpec checkpoint → 角色 映射表 |
| `.claude/team-roles/hyperspec-extend.yaml` | HyperSpec 扩展配置（注入 `current_role` 字段） |

### 5.3 Hook 脚本

| 文件 | 触发时机 | 作用 |
|------|---------|------|
| `.claude/hooks/apply-role.sh` | SessionStart + 每次 HyperSpec 改状态文件 | 读 `.hyperspec-state.yaml` 的 `checkpoint` → 查 checkpoint-map → 加载对应角色 |
| `.claude/hooks/on-state-change.sh` | PostToolUse(Write\|Edit) | basename 过滤 `.hyperspec-state.yaml` 改动 → 调 apply-role.sh |

**为什么需要两个 hook**:Claude Code 没有"checkpoint 推进"粒度的原生事件。HyperSpec skill 推进 checkpoint 时用 Edit 工具改 `.hyperspec-state.yaml`,这会触发 `PostToolUse(Write|Edit)` 事件。`on-state-change.sh` 利用该事件作为 checkpoint 切换信号 — 不依赖 HyperSpec 上游配合,也不依赖 Claude Code 不存在的 PreCheckpointAdvance 事件。

### 5.4 卸载脚本

| 文件 | 作用 |
|------|------|
| `uninstall-harness-agents.sh` | 移除所有角色配置（保留 harness-infra 不动） |

---

## 六、Checkpoint × Role 映射表

| 阶段 | HyperSpec checkpoint | 主导角色 | 输入 → 输出 |
|------|---------------------|---------|-----------|
| Propose | `profiler-done` | Architect（预探测） | 项目结构 → project_profile |
| Propose | `requirements-confirmed` | PM | 业务需求 → clarified-requirements |
| Propose | `openspec-generated`（proposal） | PM | 需求 → proposal.md |
| Apply | `openspec-generated`（specs） | Architect | proposal → specs.md |
| Apply | `openspec-generated`（design） | Architect | specs → design.md |
| Apply | `plan-generated` | Tech Lead | design → tasks.md |
| Apply | `plan-generated-and-confirmed` | Coordinator | （人工审核）→ 确认信号 |
| Apply | `task-N-complete` × N | Developer | task → 代码 + 测试 |
| Apply | `verified` | Tester | 全部 task → test-report |
| Apply | `reviewed` | Reviewer | 代码 → review-report |
| Apply | `apply-done` | Coordinator | （状态推进） |
| Apply | `consistency-verified` | Reviewer | 代码 vs specs → 一致性报告 |
| Archive | `archived` | DevOps | 全部工件 → CHANGELOG + git commit |
| Archive | `done` | — | 流程结束 |

---

## 七、工具权限矩阵（关键设计）

| 角色 | Edit/Write | Bash | Read/Grep | LSP/AST | git commit | CI 触发 |
|------|:---------:|:----:|:---------:|:-------:|:----------:|:-------:|
| PM | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ |
| Architect | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| Tech Lead | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| Developer | ✓（受 guard_write 保护） | ✓（run_tests） | ✓ | ✓ | 仅 task 完成时 | ✗ |
| **Reviewer** | **✗（严格只读）** | **✗** | **✓** | **✓** | **✗** | **✗** |
| Tester | ✗ | ✓（run_tests） | ✓ | ✗ | ✗ | ✗ |
| DevOps | ✓（仅 docs/changelog） | ✓ | ✓ | ✗ | ✓ | ✓ |

**Reviewer 严格只读** 是关键设计——避免"自己写自己审"的共谋问题。Reviewer 用 opus 模型，与 Developer（sonnet）不同模型，进一步保证独立性。

---

## 八、安装后的能力对比

| 能力 | 仅装 harness-infra | 装 infra + agents |
|------|-------------------|------------------|
| `/hyperspec` 全自动 | ✅ | ✅ |
| 12 checkpoint 状态机 | ✅ | ✅ |
| 角色分工 | ❌（一个 Claude 干到底） | ✅ 7 角色各司其职 |
| 上下文隔离 | ❌（共享） | ✅ 每 checkpoint 清空无关上下文 |
| 工具权限分层 | ❌（全权） | ✅ Reviewer 严格只读 |
| 模型独立审查 | ❌（同一模型） | ✅ Developer sonnet / Reviewer opus |
| Token 成本 | 1x | 1x（不变） |

---

## 九、验证安装

```bash
# 1. 文件检查
ls .claude/agents/                              # 应有 7 个 .md 文件
ls .claude/team-roles/                          # 应有 permissions.json 等
ls .claude/hooks/apply-role.sh                  # 应存在

# 2. Claude Code 内验证
claude
> /hyperspec propose "测试需求"
# 预期：会话启动时显示 "Active role: PM"，每个 checkpoint 切换时显示 "Switching to role: XXX"

# 3. 检查角色加载日志
cat .claude/logs/role-switch.log                # 应有完整的角色切换记录
```

---

## 十、卸载方式

```bash
bash harness-agents/uninstall-harness-agents.sh
```

卸载脚本会：
- ✅ 移除 `.claude/agents/`、`.claude/team-roles/`、`.claude/hooks/apply-role.sh`
- ✅ 从 `SessionStart` hook 配置移除 `apply-role.sh` 引用
- ✅ 恢复 `.claude/settings.local.json`（从备份）
- ✅ **保留** `.claude/skills/`、`.claude/hooks/{guard_write.py, ensure_change_context.py, run_checks.sh}`
- ✅ HyperSpec 仍可运行（退化为无角色模式）

**关键**：卸载本包不影响 harness-infra 的任何能力。

---

## 十一、常见问题

### Q1：装了之后，以前的 `/hyperspec` 命令还能用吗？

完全可以。本包**只追加角色配置**，不替换 HyperSpec 本身。命令、checkpoint、状态机全部保留。

### Q2：角色 prompt 可以自定义吗？

可以。`.claude/agents/*.md` 都是普通 markdown 文件，团队可按项目特点调整（如补充业务领域知识、团队编码偏好）。升级本包时建议先 `git diff` 看官方变更，再决定合并策略。

### Q3：Reviewer 真的能"只读"吗？AI 会不会偷偷改代码？

`apply-role.sh` 在加载 Reviewer 角色时，会通过 Claude Code 的 permission 配置**禁用 Edit/Write 工具**。AI 想改也调不到工具。

### Q4：角色切换会不会丢上下文？

会，但是**有意为之**。每次切换会清空无关上下文（PM 切到 Architect 时，业务原始描述清空，只留 proposal.md），避免"PM 思维污染 Architect 决策"。相关上下文通过标准工件（proposal/specs/design/tasks）传递，不靠记忆。

### Q5：能不能跳过某些角色（比如不要 PM，直接 Architect）？

可以。编辑 `.claude/team-roles/checkpoint-map.yaml`，把 `proposal-draft` 的 role 改为 `architect`。但不推荐——每个角色有独立视角，跳过会降低产出质量。

---

## 十二、版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2026-07-17 | 首版，对应《Harness V2 架构设计文档2.md》第 8 章 |

---

## 十三、相关文档

- 总览：`../../Harness V2 架构设计文档2.md`（特别是第 8 章）
- 落地手册：`../../Harness V2 落地实操手册2-2.md`（Agent 角色层落地）
- 基础设施包：`../harness-infra/README.md`
- 安装总览：`../HARNESS-PACKAGES.md`
