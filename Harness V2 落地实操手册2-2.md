## 章二十三：进阶 — 单实例多角色编排深度用法

> 本项目采用**单实例多角色**方案（不引入外部 Python 编排器）。一个 Claude Code 会话通过 **checkpoint × 角色**映射，按需切换视角完成 PM → Architect → Developer → Reviewer 全流程。
> 这一章把 Harness V2 架构文档第 8 章（Agent Team 角色编排层）翻译成可执行操作。

### 23.1 为什么是单实例多角色（不是多 agent）

| 维度 | 单实例多角色（本项目采用） | 多 agent + A2A（不采用） |
|------|-------------------------|------------------------|
| Claude 会话数 | **1** | N（每角色独立 `claude -p` 子进程） |
| 协调者 | 主会话自身 + checkpoint 状态机 | 外部 Python 编排器 |
| 角色切换 | 加载新 system prompt + 清理上下文 | fork 新进程 |
| 真并行 | 否（串行切换） | 是 |
| 复杂度 | 低（复用 HyperSpec） | 高（需 Python 编排器 + Workspace + 锁） |
| 适用场景 | **绝大多数项目** | ≥ 3 并发育求 + 单需求 ≥ 8 task |

**单实例的核心收益**（也是它够用的原因）：
- **上下文隔离**：每次切换角色清空上一角色的视角，避免"Developer 视角污染 Reviewer 判断"
- **工具权限分明**：Reviewer 只读、Developer 可写、DevOps 可发布
- **工件驱动交接**：角色间通过 `proposal.md → specs.md → design.md → tasks.md` 流转，不靠口头沟通

### 23.2 8 个角色定义

| 角色 | 视角 | 主要产出 | 模型 | 工具权限 |
|------|------|---------|------|---------|
| **PM**（产品经理） | 业务 / 用户 | proposal.md | opus | 只读 + WebFetch |
| **Architect**（架构师） | 技术 / 全局 | specs.md + design.md | opus | 只读 + LSP/AST |
| **Tech Lead**（技术负责人） | 拆解 / 依赖 | tasks.md（含依赖图） | sonnet | 只读 + LSP |
| **Developer**（开发） | 实现 / TDD | 生产代码 + 测试代码 | sonnet/opus | 可写（受 guard_write 保护）+ Bash |
| **Reviewer**（审查员） | 独立 / 挑刺 | review-report.md | **opus**（与 Developer 不同模型） | **完全只读** |
| **Tester**（测试） | 验收 / 边界 | test-report.md | sonnet | 只读 + Bash（运行测试） |
| **DevOps**（发布） | 部署 / 收尾 | CHANGELOG + git tag | sonnet | 可写（仅 docs）+ Bash（git/CI） |
| **Coordinator**（协调员） | 调度 / 路由 | （无业务产出，只推进 checkpoint） | **haiku** | 读写 `.hyperspec-state.yaml` |

**关键设计**：
- **Reviewer 用 opus**（vs Developer 用 sonnet）→ 避免"自我审查"的共谋
- **Coordinator 用 haiku**（决策简单，省 token）
- **Tech Lead 单点**（避免拆任务不一致）
- **DevOps 单点**（避免发布冲突）

### 23.3 Checkpoint × 角色映射表

每个 checkpoint 由特定角色主导：

| Checkpoint | 主导角色 | 输入 | 输出 |
|-----------|---------|------|------|
| profiler-done | Coordinator | 项目根目录 | `.hyperspec-state.yaml.project_profile` |
| requirements-confirmed | PM | 用户对话 | 用户澄清纪要 |
| openspec-generated | Architect | proposal 输入 | proposal.md + specs.md + design.md + tasks.md |
| plan-generated | Tech Lead | design.md | TDD 计划（依赖图 + 验收标准） |
| plan-generated-and-confirmed | Coordinator | TDD 计划 | 确认信号 |
| task-N-complete | Developer | 单个 task | 生产代码 + 测试代码 + commit |
| verified | Tester | 所有 task 完成 | test-report.md |
| reviewed | Reviewer | 测试报告 + 代码 | review-report.md |
| apply-done | DevOps | 审查通过 | git tag + CHANGELOG |
| consistency-verified | Coordinator | archive 前 | 一致性检查报告 |
| archived | DevOps | 一致性通过 | openspec/archive/ 归档 |
| done | Coordinator | 归档完成 | 终态通知 |

**回溯规则**：
- Reviewer 打回 → 回到 `task-N-complete`（Developer 修复）
- Tester 失败 → 回到 `task-N-complete`
- 一致性检查失败 → 回到 `apply-done`

### 23.4 角色配置文件结构

每个角色对应一个配置文件 `.claude/team-roles/{role}.md`，结构如下：

```markdown
---
role: developer
model: sonnet
checkpoint_ownership:
  - task-N-complete
allowed_tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write            # 受 guard_write 保护
  - Bash             # 仅 mvn / git
denied_tools:
  - WebFetch         # Developer 不联网
  - dispatch_agent   # 不二次分派
active_skills:
  - springboot-tdd
  - jpa-patterns
  - verification-before-completion
context_cleanup_on_enter: true   # 进入此角色时清空上一角色上下文
---

# Developer 角色指令

## 你的视角
你是 TDD 开发者，专注于把单个 task 实现为干净、有测试覆盖的代码。

## 红线
- 不跨 task 改代码（即使你看到可优化的地方）
- 不修改其他 task 的文件
- 不跳过测试（必须红 → 绿 → 重构）
- 不写无意义注释

## 标准流程
1. 读 tasks.md 中你负责的 task
2. 检查依赖 task 是否已完成
3. 写测试（红）
4. 写实现（绿）
5. 重构（保持测试绿）
6. 跑 mvn test 验证
7. auto commit
8. 发出 task-done 信号

## 输出
- 生产代码（按 AGENTS.md 规范）
- 测试代码（命名 should_xxx_when_yyy）
- task-{N}-report.md（200 字以内）
```

### 23.5 角色激活与切换机制

**机制**：HyperSpec 在推进每个 checkpoint 时，根据 23.3 映射表自动切换角色。

**切换动作**（由 Coordinator 角色 + HyperSpec 协作完成）：

1. 写 `.hyperspec-state.yaml`：
   ```yaml
   current_role: developer
   current_checkpoint: task-3-complete
   role_context:
     loaded_skills: [springboot-tdd, jpa-patterns]
     allowed_tools: [Read, Grep, Edit, Write, Bash]
     model: sonnet
   ```yaml

2. SessionStart hook（`apply-role.sh`）读取 `current_role`，注入对应 `.claude/team-roles/{role}.md` 的指令到当前会话

3. 若 `context_cleanup_on_enter: true`：
   - Coordinator 角色发出 `/compact` 信号
   - 把上一角色的中间结论压缩为简短摘要
   - 加载新角色 system prompt

4. HyperSpec 推进到下一 checkpoint 时，重复 1-3

### 23.6 工作交接流水线（Artifact 驱动）

角色间不直接对话，通过工件交接：

```
PM                Architect          Tech Lead         Developer         Reviewer
 │                   │                  │                  │                │
 ├─ proposal.md ─────▶                  │                  │                │
 │                   ├─ specs.md ───────▶                  │                │
 │                   ├─ design.md ──────▶                  │                │
 │                   │                  ├─ tasks.md ───────▶                │
 │                   │                  │                  ├─ 生产代码 ──────▶
 │                   │                  │                  ├─ 测试代码 ──────▶
 │                   │                  │                  │                ├─ review-report.md
 │                   │                  │                  │ ◀── 打回/通过 ──┤
 │                   │                  │                  │                │
```

**交接规则**：
- 下游只读上游产物，**不修改**
- 下游引用上游时必须带版本（`proposal.md@v3`，靠 git tag）
- 上游产物变更 → Coordinator 自动通知下游重做

### 23.7 工具权限矩阵

权限由 `.claude/team-roles/permissions.json` 统一管理：

```json
{
  "pm": {
    "read": ["**/*", "docs/**"],
    "write": ["openspec/changes/**/proposal.md"],
    "bash": [],
    "denied": ["src/main/java/**", "src/main/resources/db/**"]
  },
  "architect": {
    "read": ["**/*"],
    "write": ["openspec/changes/**/specs.md", "openspec/changes/**/design.md"],
    "bash": ["mvn compile", "git log", "git diff"],
    "denied": ["src/main/java/**"]
  },
  "tech-lead": {
    "read": ["**/*"],
    "write": ["openspec/changes/**/tasks.md"],
    "bash": [],
    "denied": ["src/main/java/**"]
  },
  "developer": {
    "read": ["**/*"],
    "write": ["src/main/java/**", "src/test/java/**"],
    "bash": ["mvn compile", "mvn test", "git add", "git commit"],
    "denied": ["src/main/resources/application.yml", "src/main/resources/db/migration/**"]
  },
  "reviewer": {
    "read": ["**/*"],
    "write": ["openspec/changes/**/review-report.md"],
    "bash": ["mvn test", "git log", "git diff"],
    "denied": ["src/main/java/**", "src/test/java/**"]
  },
  "tester": {
    "read": ["**/*"],
    "write": ["openspec/changes/**/test-report.md"],
    "bash": ["mvn test", "mvn verify", "mvn integration-test"],
    "denied": ["src/main/java/**"]
  },
  "devops": {
    "read": ["**/*"],
    "write": ["CHANGELOG.md", "docs/**"],
    "bash": ["git *", "mvn package", "mvn deploy"],
    "denied": ["src/main/java/**"]
  },
  "coordinator": {
    "read": ["**/*"],
    "write": [".hyperspec-state.yaml", "openspec/changes/**/coordinator-log.md"],
    "bash": [],
    "denied": ["src/main/java/**"]
  }
}
```

**强制点**：`guard_write.py`（章十一）在每次 Edit/Write 时读 `current_role`，按此矩阵拦截越权操作。

### 23.8 上下文隔离与切换冲突

**典型冲突**：Developer 阶段遗留的"实现细节"污染 Reviewer 阶段的"挑刺视角"。

**解决机制**：

| 触发点 | 动作 |
|-------|------|
| 进入 Reviewer 角色 | 强制 `context_cleanup_on_enter: true`，压缩 Developer 阶段为 200 字摘要 |
| 进入 Tester 角色 | 只加载 specs.md + 测试代码，不加载实现细节 |
| 进入 Architect 角色 | 清空 Developer 阶段的实现思路，从 specs 重新设计 |
| 角色切换超时（> 5 分钟无产出） | Coordinator 介入，发出 `/clear` 后重新加载 |

**手动触发清理**：
```
/coordinator switch-to reviewer
# Coordinator 会先 /compact 当前上下文，再加载 reviewer.md
```

### 23.9 回滚机制

任意 checkpoint 失败或角色判断错误，可回滚：

```bash
# 回到上一 checkpoint
/coordinator rollback

# 回到指定 checkpoint
/coordinator rollback-to task-2-complete

# 紧急重置（保留 artifacts，清空状态）
/coordinator reset
```

**回滚安全性**：
- artifacts 是 git 提交的，回滚状态机不丢工件
- 已发布的 git tag 不会被回滚覆盖（DevOps 重做时强制 bump 版本）

### 23.10 创建 8 角色配置（AI 自动补全）

### AI 自动补全提示词

```
请基于本项目实际情况生成单实例多角色编排所需的全部配置文件。要求：

1. 在 `.claude/team-roles/` 下创建 8 个角色文件（参考 23.4 模板）：
   - pm.md
   - architect.md
   - tech-lead.md
   - developer.md
   - reviewer.md
   - tester.md
   - devops.md
   - coordinator.md

   每个文件必须包含：
   - frontmatter（role / model / checkpoint_ownership / allowed_tools / denied_tools / active_skills / context_cleanup_on_enter）
   - 你的视角（一句话）
   - 红线（3-5 条）
   - 标准流程（按步骤）
   - 输出（产物清单）

2. 创建 `.claude/team-roles/permissions.json`（按 23.7 矩阵）：
   - 基于 AGENTS.md 的"模块边界"调整每个角色的 denied
   - 财务模块等红线对 Architect / Developer / Reviewer 全部 denied
   - 对 DevOps 添加 deploy 命令白名单

3. 探测项目实际，调整角色定义：
   - 如果是 Spring Boot + JPA → Developer 的 active_skills 加 jpa-patterns
   - 如果是 Spring Boot + MyBatis → Developer 的 active_skills 加 mybatis-patterns（如果没有此 skill，跳过）
   - 如果有 Spring Security → Architect 的 active_skills 加 springboot-security
   - 如果项目用 Maven → 所有 bash 权限中的 npm 改为 mvn

4. 修改 `.claude/hooks/apply-role.sh`（若章十一已创建）：
   - SessionStart 时读取 .hyperspec-state.yaml 的 current_role
   - 把 .claude/team-roles/{current_role}.md 的内容追加到 system prompt
   - 如果 current_role 为空，加载 coordinator.md 作为默认

5. 修改 `.claude/hooks/guard_write.py`：
   - 写入前先读 current_role
   - 加载 .claude/team-roles/permissions.json
   - 检查目标 path 是否在当前角色的 write 权限内
   - 不在则拦截 + 提示当前角色应使用哪个角色

6. 在 `.claude/commands/coordinator.md` 创建 Coordinator 命令：
   - 子命令：switch-to {role} / rollback / rollback-to {checkpoint} / reset / status
   - 每个子命令详细说明

7. 在 docs/harness/role-orchestration.md 写完整说明：
   - 8 角色定义表
   - checkpoint × 角色映射表
   - 工作交接流水线图（ASCII）
   - 工具权限矩阵
   - 上下文隔离规则
   - 回滚机制

8. commit: "feat(harness): 单实例多角色编排层（8 角色 + 权限矩阵）"

注意：
- 角色定义要具体（基于项目实际技术栈），不要泛泛
- permissions.json 的路径必须和 AGENTS.md 模块边界一致
- 不要凭空造项目没有的 skill
```

### 23.11 验收

- [ ] `.claude/team-roles/` 下有 8 个 .md 文件
- [ ] `.claude/team-roles/permissions.json` 路径与 AGENTS.md 模块边界一致
- [ ] `.claude/commands/coordinator.md` 子命令可用
- [ ] apply-role.sh SessionStart 时能加载角色配置
- [ ] guard_write.py 按 current_role 拦截越权（手动测试：Coordinator 角色试图改 src/main/java 应被拦）
- [ ] docs/harness/role-orchestration.md 完整记录设计

### 23.12 使用示例

```bash
# 1. 启动新需求
/hyperspec "添加用户登录功能"

# HyperSpec 自动：
#   - Coordinator 启动，写 current_role=coordinator
#   - 推进到 requirements-confirmed → 切换到 PM
#   - PM 与用户对话完成后 → 切换到 Architect
#   - ...

# 2. 手动切换角色（调试用）
/coordinator switch-to reviewer

# 3. 查看当前状态
/coordinator status
# 输出：
#   current_role: developer
#   current_checkpoint: task-3-complete
#   active_skills: springboot-tdd, jpa-patterns
#   artifacts: tasks.md@v1, design.md@v2

# 4. 回滚
/coordinator rollback

# 5. 紧急重置
/coordinator reset
```

### 23.13 与多 agent 方案的关系（仅供了解）

如果未来确实出现以下场景，可参考 `Harness Agent Team 多agent架构设计.md` 升级到多 agent：
- 同时 ≥ 3 个并发需求
- 单需求 task ≥ 8 个且无依赖、可真并行
- 跨模块大型重构

**升级前提**：单实例方案已稳定运行 ≥ 2 个月，且团队能投入 2-3 周开发 Python 编排器。

**绝大多数项目永远不需要升级**——单实例多角色已覆盖 95%+ 场景。
