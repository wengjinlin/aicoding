# Harness Agent Team — 多 Agent + A2A 架构设计

> 版本：2.0 | 更新日期：2026-06-17
> 定位：在 7 层 Harness 基础架构之上，构建真并行多 Agent 团队
> 与单实例方案的关系：本文档替代原"角色编排层"轻量方案，作为并行开发的基础

---

## 〇、实现真相（必读，避免概念混淆）

> 这一章解决一个核心误解：**"开一个 Claude Code 会话 + 多份 agent 提示词" ≠ "多 agent 并行"**。

### 0.1 三种运行模型的本质差异

| 运行模型 | Claude 进程数 | 谁是协调者 | 是否真并行 | 实际收益 |
|---------|------------|----------|---------|---------|
| **单实例** | 1 | 主会话自身 | 否 | 串行流转，单需求够用 |
| **伪多 agent**（一个会话内 Task 工具切角色） | 1 | 主会话自身 | **否** | 仅 context 隔离，仍串行 |
| **真多 agent**（本文档目标） | **N** | **外部 Python/Node 编排器** | **是** | 流水线 + 任务级并行 |

### 0.2 Claude Code 的能力边界（写在这里防止自欺）

Claude Code 的 subagent 机制（Task/Agent 工具）有以下硬限制：

1. **同步阻塞**：主会话调用 Task 工具启动 subagent 时，主会话**阻塞等待** subagent 返回。即使 `run_in_background=true`，subagent 也是单会话内的子任务，不能跨会话并行。
2. **无常驻循环**：subagent 完成任务后即退出，不能像守护进程那样循环 sleep + 检查消息总线。"Team Lead 常驻 agent"在单会话内**不存在**——主会话要响应用户输入，无法专职调度。
3. **无 IPC**：subagent 之间没有内存共享，也没有内建消息传递。只能通过文件系统交换数据。
4. **单会话语境**：所有 subagent 共享同一个主会话的"上层意识"，并不是真正的独立进程。

**结论**：在**单个 Claude Code 会话**内，无论写多少 agent 提示词、多少 A2A 消息文件，本质都是**单实例 + context 隔离**，**无法实现真并行**。

### 0.3 真并行的唯一路径：外部编排器

要实现真正的多 agent 并行，**Team Lead 不能是 Claude**，必须是**外部 Python/Node 脚本**。架构如下：

```
用户终端（只开一个）:
  $ python team_lead.py                ← 这是 Python，不是 Claude
       │
       │  Team Lead 是 Python 主循环（schedule + 锁管理 + 心跳监控）
       │
       ├─ subprocess.Popen(["claude", "-p", "--agent=pm",          "--input",  ".workspace/inbox/pm-01.json"])  ← Claude 进程 #1
       ├─ subprocess.Popen(["claude", "-p", "--agent=architect",   "--input",  ".workspace/inbox/arch-01.json"]) ← Claude 进程 #2
       ├─ subprocess.Popen(["claude", "-p", "--agent=developer",   "--input",  ".workspace/inbox/dev-01.json"])  ← Claude 进程 #3
       └─ subprocess.Popen(["claude", "-p", "--agent=developer",   "--input",  ".workspace/inbox/dev-02.json"])  ← Claude 进程 #4
                                                                                                                  （真并行）
       Python 主循环:
         while True:
             scan .workspace/bus/             # 拉新消息
             scan subprocess status           # 检查 agent 心跳/退出
             reconcile .workspace/registry/   # 更新需求状态机
             dispatch new agents as needed    # fork 新 claude 进程
             handle lock conflicts            # 死锁检测
             sleep(30s)
```

**关键点**：

| 组件 | 实际实现 |
|------|---------|
| Team Lead | **Python 脚本**（`team_lead.py`），不是 Claude |
| 角色 Agent | 通过 `subprocess.Popen` 启动的**独立 Claude Code 进程**，用 `-p`（print/headless 模式）+ `--agent={role}` 加载角色提示词 |
| 通信 | 各 Claude 进程的 stdin/stdout + `.workspace/bus/` JSON 文件（双向） |
| 状态 | 全部外置于 `.workspace/`（Claude 进程无状态，崩溃可重启） |

### 0.4 三种实现路径对比

| 路径 | 描述 | 真并行 | 复杂度 | 推荐场景 |
|------|------|-------|-------|---------|
| **A. 单 Claude 会话** | `/hyperspec` 流转，Task 工具切角色 | 否 | 低 | 单需求，task ≤ 5 |
| **B. 外部编排 + N 个 `claude -p`** | Python Team Lead fork 多个 Claude 进程 | **是** | 高 | 多需求并行、task ≥ 6 |
| **C. 手动多终端** | 用户开多个 claude 终端，人工协调 | 是（粗糙） | 中 | 实验/演示 |

本文档描述的是 **路径 B**。如果只看"agent 定义"和"A2A 协议"，它和路径 A 长得很像——**差异只在 Team Lead 是不是 Python**。

### 0.5 一句话总结

> 没有 `team_lead.py` 这个外部编排器，本文档描述的"多 agent 并行"就只是 PPT。`team_lead.py` 是落地的**必要前提**，不是"未来实现"。

---

## 一、为什么需要重新设计

### 1.1 单实例方案的天花板

前一版 Agent Team（单实例角色切换）的并行能力受三个根本性约束：

| 约束 | 表现 |
|------|------|
| 单实例串行 | 一个 Claude Code 会话同时只能扮演一个角色、跑一个 checkpoint |
| 共享上下文 | 角色切换时上下文清空不彻底，导致视角污染 |
| 文件竞争无机制 | 多需求并发时无锁，必然引发 git 冲突 |

实测下，单实例方案即使在理想流水线下也只能榨出 **1.5-2x 加速**，且任务级并行几乎不可行。

### 1.2 真并行的必要条件

要让多个需求真正同时推进、让一个需求的多个 task 同时跑，需要：

1. **每个角色是独立 Claude 进程**（独立 `claude -p` 子进程，独立上下文窗口、独立模型实例）
2. **外部编排器（非 Claude）负责调度**（Python 脚本 fork/监控子进程，单 Claude 会话做不到）
3. **agent 之间通过文件消息通信**（不靠共享上下文传递状态）
4. **共享工作区**（artifact 仓库 + 文件锁 + 消息总线）
5. **路由协调者**（Team Lead = Python 主循环，负责任务分派与冲突裁决）

这就是 ECC 多 agent + A2A（Agent-to-Agent）通信架构的核心。**第 2 条是关键**——没有外部 Python 编排器，再多 agent 提示词也只是 PPT。

### 1.3 设计目标

| 目标 | 量化指标 |
|------|---------|
| 流水线并行 | N 个需求同时在不同 checkpoint 推进，互不阻塞 |
| 任务级并行 | 单需求内 N 个无依赖 task 同时执行 |
| 上下文隔离 | 每个 agent 独立上下文，无视角污染 |
| 冲突可控 | 文件锁 + 预检测，冲突率 < 5% |
| 可扩展 | Developer / Reviewer 等角色可按需扩容 |

---

## 二、与单实例方案的核心差异

| 维度 | 单实例方案 | 多 agent + A2A 方案 |
|------|-----------|------------------|
| **Claude 会话数** | **1** | **N**（每 agent 一个 `claude -p` 进程） |
| **协调者** | 主会话自身 | **★ Python 编排器（非 Claude）★** |
| **真并行能力** | 否 | 是（OS 进程级） |
| 通信方式 | 共享上下文 + 文件 | A2A 消息文件（无共享上下文） |
| 上下文 | 切换有残留 | 完全隔离（独立进程） |
| 并行度 | 串行 | 流水线 + 任务级 |
| Token 成本 | 1x | 3-5x（多 Claude 进程并行消耗） |
| 调试难度 | 简单 | 复杂（需 trace_id 追踪 + 进程日志） |
| 冲突风险 | 无 | 需锁机制管理 |
| 适用场景 | 单需求、轻量任务 | 多需求并行、大型特性 |
| **实现成本** | 低（复用 `/hyperspec`） | **高（需写 Python 编排器 + 7 份角色提示词 + Workspace 运行时）** |

**何时选哪个**：
- 团队只有 1-2 个并发育求、单需求 task ≤ 5 → **单实例够用**
- 并发育求 ≥ 3、单需求 task ≥ 8、或需跨模块大重构 → **多 agent**（且愿意承担 Python 编排器的开发成本）

---

## 三、架构总览

### 3.1 三层结构

```
┌─────────────────────────────────────────────────────────────┐
│                    用户需求入口（多个并发）                    │
│        req-A: 财务月报    req-B: 库存预警    req-C: ...        │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│   Team Lead（★ Python 编排器，不是 Claude ★）                  │
│   team_lead.py：路由 + 协调 + 冲突裁决 + 心跳监控               │
│   接收需求 → fork PM → 推进 checkpoint → fork Developer → 解锁  │
└──────────────────────────┬──────────────────────────────────┘
                           │ subprocess.Popen(["claude","-p",...])
                           │ （每个箭头 = 一个独立 Claude 进程）
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐        ┌────▼────┐        ┌────▼────┐
   │ Claude  │        │ Claude  │        │ Claude  │
   │  pm.md  │        │architect│        │tech-lead│  ← 角色层
   │ 进程#1  │        │进程#2   │        │进程#3   │   （每进程独立 context）
   └────┬────┘        └────┬────┘        └────┬────┘
        │                  │                  │
   ┌────▼────┐        ┌────▼────┐        ┌────▼────┐
   │ Claude  │        │ Claude  │        │ Claude  │
   │developer│        │developer│        │reviewer │
   │进程#4   │        │进程#5   │        │进程#6   │
   └────┬────┘        └────┬────┘        └────┬────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │ 读写文件（唯一的 IPC 通道）
┌──────────────────────────▼──────────────────────────────────┐
│                     Workspace（共享工作区）                    │
│  ┌─────────────┬──────────────┬──────────────┬────────────┐ │
│  │ 消息总线     │ Artifact 仓库 │ 锁管理器      │ 状态注册表  │ │
│  │ (A2A Bus)   │ (Git-based)  │ (File Lock)  │ (Registry) │ │
│  └─────────────┴──────────────┴──────────────┴────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│        7 层 Harness 基础架构（每个 Claude 进程各自加载）        │
│   L1 OpenSpec | L2 Superpowers | L3 审查 | L4-L6 增强          │
│   安全保护层 | 模型路由层 | L7 HyperSpec                       │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 核心组件（实现真相）

| 组件 | 职责 | 实现 |
|------|------|------|
| **Team Lead** | 总协调：路由需求、fork agent 进程、裁决冲突、扩容 | **★ Python 脚本 `team_lead.py`（不是 Claude）★** |
| **角色 Agent x N** | 8 个角色，每个可扩展为多实例 | **独立 Claude Code 进程**：`subprocess.Popen(["claude","-p","--agent={role}"])` |
| **A2A 消息总线** | agent 间结构化消息传递 | JSON 文件队列（`.workspace/bus/`，简单可靠） |
| **Artifact 仓库** | proposal/specs/design/tasks/code 的版本化存储 | Git 分支 + 语义化路径 |
| **锁管理器** | 文件级锁，防并行写冲突 | `.workspace/locks/` 目录 + JSON 状态 |
| **状态注册表** | 每个需求的状态机实例 | `.workspace/registry/{req-id}.yaml` |
| **stdin/stdout 桥** | Python 与 Claude 进程的双向数据通道 | `--input`/`--output` JSON 文件，或直接 stdin/stdout pipe |

---

## 四、A2A 通信协议

### 4.1 消息结构

每条 A2A 消息是一个 JSON 对象，通过文件或 WebSocket 传递：

```json
{
  "msg_id": "msg-20260617-001",
  "from": "pm-01",
  "to": "architect-pool",
  "type": "task-assign",
  "requirement_id": "req-2026-financial-report",
  "checkpoint": "specs-draft",
  "payload": {
    "input_artifact": "proposal.md@v3",
    "expected_output": "specs.md",
    "deadline": "2026-06-17T15:00:00Z"
  },
  "priority": "normal",
  "requires_reply": true,
  "trace_id": "trace-req-2026-financial-report"
}
```

### 4.2 消息类型

| Type | 用途 | 触发者 → 接收者 |
|------|------|---------------|
| `task-assign` | 分派任务 | Team Lead → 角色 Agent |
| `task-done` | 任务完成通知 | Agent → Team Lead |
| `handoff` | 工件交接 | 上游 Agent → 下游 Agent |
| `review-request` | 请求审查 | Developer → Reviewer Pool |
| `review-result` | 审查结果 | Reviewer → Developer + Team Lead |
| `query` | 上下文查询 | Agent → 其他 Agent |
| `lock-request` | 请求文件锁 | Developer → Lock Manager |
| `lock-granted` | 锁授予通知 | Lock Manager → Developer |
| `conflict-alert` | 冲突告警 | Lock Manager → Team Lead |
| `status` | 状态广播 | 任意 Agent → Team Lead |
| `escalate` | 升级到人类 | Team Lead → 人类通道 |

### 4.3 通信模式

**点对点**（task-assign、handoff）：from → to，要求 reply
**广播**（status、conflict-alert）：from → 所有 agent
**队列**（review-request）：from → pool，任意空闲 agent 接单
**请求-响应**（query、lock-request）：同步等待响应

### 4.4 消息持久化与追踪

每条消息写入 `.workspace/bus/{date}/{msg-id}.json`，支持：
- **trace_id 贯穿**：一个需求的所有消息共享 trace_id
- **重放**：崩溃后可从消息日志恢复状态
- **审计**：谁在什么时间做了什么决策

---

## 五、8 个 Agent 详细定义

每个 Agent 是独立的 Claude Code subagent，有专属 system prompt、技能、工具权限、模型。

### 5.1 PM Agent（产品经理）

| 维度 | 配置 |
|------|------|
| 实例数 | 按需求扩容（每需求 1 个） |
| 触发 | Team Lead 收到新需求后启动 |
| system prompt | `.claude/agents/pm.md`（业务视角、不写代码、只产 proposal） |
| 技能 | requirements-analysis、business-domain、stakeholder-interview |
| 工具 | Read、Grep、Glob、WebFetch（查业务文档） |
| 模型 | opus |
| 输出 | `proposal.md` 提交到 Artifact 仓库 |
| A2A 通信 | 完成 → 发 `task-done` 给 Team Lead；阻塞 → 发 `query` 给 Team Lead |

### 5.2 Architect Agent（架构师）

| 维度 | 配置 |
|------|------|
| 实例数 | 1-3（按并发需求扩容） |
| 触发 | proposal 审核通过后，Team Lead 启动 |
| system prompt | `.claude/agents/architect.md`（技术视角、不写业务代码、产 specs/design） |
| 技能 | springboot、jpa、api-design、ddd、architecture-patterns |
| 工具 | Read、Grep、Glob、LSP goto_def、AST 搜索 |
| 模型 | opus |
| 输出 | `specs.md`、`design.md` |
| A2A 通信 | 接收 PM 的 handoff；产出后 handoff 给 Tech Lead |

### 5.3 Tech Lead Agent（技术负责人）

| 维度 | 配置 |
|------|------|
| 实例数 | 1-2 |
| 触发 | design 完成后由 Team Lead 启动 |
| system prompt | `.claude/agents/tech-lead.md`（拆任务视角、标注依赖关系） |
| 技能 | task-decomposition、dependency-graph、estimation、risk-analysis |
| 工具 | Read、Grep、Glob、LSP |
| 模型 | sonnet |
| 输出 | `tasks.md`（含每个 task 的依赖标记 + 可并行标记 + 文件清单） |
| 关键能力 | **依赖图构建**：分析 task 之间的顺序与并行关系，输出 DAG |

### 5.4 Developer Agent（开发，可多实例并行）

| 维度 | 配置 |
|------|------|
| 实例数 | **1-N**（按可并行 task 数扩容，核心扩容点） |
| 触发 | Team Lead 根据 Tech Lead 的依赖图，对每个 ready task 启动 Developer |
| system prompt | `.claude/agents/developer.md`（TDD 红绿循环、不跨 task 改代码） |
| 技能 | springboot、jpa、mybatis、vue（按文件类型自动激活） |
| 工具 | Edit/Write（受 guard_write 保护）、Bash（run_tests）、LSP、AST |
| 模型 | sonnet（标准）/ opus（复杂 task） |
| **关键流程** | 1. 启动时向 Lock Manager 请求 task 文件锁；2. 拿到锁后开始 TDD；3. 完成后发 `task-done` + 释放锁 |
| 输出 | 生产代码 + 测试代码 + `task-{N}-report.md` |

### 5.5 Reviewer Agent（代码审查员，可多实例）

| 维度 | 配置 |
|------|------|
| 实例数 | 1-3（队列模式，从 pool 取任务） |
| 触发 | Developer 完成 task 后发 `review-request` 到 Reviewer Pool |
| system prompt | `.claude/agents/reviewer.md`（独立审查视角、不写代码） |
| 技能 | code-review、security-review、simplify、spec-compliance |
| 工具 | **完全只读** — Read、Grep、Glob、LSP |
| 模型 | **opus（与 Developer 不同模型，避免共谋）** |
| 输出 | `review-report-{task-N}.md`（通过/打回 + 理由） |
| 关键约束 | 不能改代码；打回时附明确修改建议 |

### 5.6 Tester Agent（测试）

| 维度 | 配置 |
|------|------|
| 实例数 | 1-2 |
| 触发 | 所有 task 通过 review 后，Team Lead 启动集成测试 |
| system prompt | `.claude/agents/tester.md`（验收视角、不改生产代码） |
| 技能 | integration-test、boundary-test、performance-test |
| 工具 | Bash（运行测试套件）、Read（看测试报告） |
| 模型 | sonnet |
| 输出 | `test-report.md` |

### 5.7 DevOps Agent（发布）

| 维度 | 配置 |
|------|------|
| 实例数 | 1 |
| 触发 | 最终 review 通过后 |
| system prompt | `.claude/agents/devops.md`（发布视角、谨慎操作） |
| 技能 | deployment、changelog、release-management |
| 工具 | Edit（仅 docs）、Bash（git、CI） |
| 模型 | sonnet |
| 输出 | `CHANGELOG.md` 更新、git commit + tag |

### 5.8 Team Lead（★ Python 编排器，不是 Claude ★）

> **这是整个架构最关键的反直觉点**：Team Lead **不是 Claude subagent**，而是一个**外部 Python 脚本** `team_lead.py`。原因见第〇章 0.2 节。

| 维度 | 配置 |
|------|------|
| 实现语言 | **Python**（备选 Node.js） |
| 实例数 | **1**（单点协调，避免脑裂） |
| 触发 | 用户在终端运行 `python team_lead.py` |
| 是否是 Claude | **否**。它是 Claude 进程的**父进程**，不调用 LLM 做决策 |
| 决策来源 | **纯规则**（依赖图、容量上限、锁状态），不需要 LLM 推理 |
| 核心循环 | `while True: scan_bus() → scan_processes() → dispatch() → handle_conflicts() → sleep(30s)` |
| 启动 agent 的方式 | `subprocess.Popen(["claude", "-p", "--agent={role}", "--input", "{inbox}.json", "--output", "{outbox}.json"])` |
| 监控 agent 的方式 | `subprocess.poll()` 检查进程退出码 + 心跳文件 mtime |
| 核心职责 | 1. 接收新需求 → fork PM 进程；2. 推进 checkpoint → fork 下游 agent；3. 解析依赖图 → 并行 fork 多个 Developer；4. 监听锁冲突 → 串行化或强制释放；5. 容量管理 → 按需 fork/回收 |

**为什么不把 Team Lead 做成 Claude**：

| 假设的方案 | 致命问题 |
|----------|---------|
| Team Lead 是常驻 Claude subagent | Claude Code subagent 完成即退出，无法循环；主会话要响应用户，无法专职调度 |
| Team Lead 是主会话自身 | 主会话同步阻塞，无法同时跑多个 Developer；且 Developer 是它的 subagent，必然串行 |
| Team Lead 用 run_in_background | 仍是单会话子任务，无法 fork 独立 Claude 进程；context 共享污染 |

**Team Lead 的 Python 实现骨架**（核心 < 200 行）：

```python
# team_lead.py（简化骨架）
import subprocess, json, time
from pathlib import Path

WS = Path(".workspace")

def fork_agent(role, inbox, requirements_id):
    outbox = WS / f"bus/outbox/{role}-{time.time_ns()}.json"
    proc = subprocess.Popen([
        "claude", "-p",
        "--agent", role,                # 加载 .claude/agents/{role}.md
        "--input",  str(inbox),         # 任务包（JSON）
        "--output", str(outbox),        # 输出工件路径
    ])
    return proc, outbox

def main():
    while True:
        # 1. 扫消息总线
        for msg in scan_bus_pending():
            route_message(msg)              # 按 type 分派
        # 2. 扫进程状态
        for proc_id, proc in active_procs.items():
            if proc.poll() is not None:     # 进程退出
                handle_exit(proc_id, proc.returncode)
            elif heartbeat_stale(proc_id):  # 30min 无心跳
                proc.kill()
                restart_task(proc_id)
        # 3. 按依赖图调度
        for req in scan_registry():
            for task in ready_tasks(req):   # 依赖已满足
                if capacity_available("developer"):
                    fork_agent("developer", build_inbox(req, task), req["id"])
        # 4. 死锁检测
        detect_and_break_deadlocks()
        time.sleep(30)

if __name__ == "__main__":
    main()
```

---

## 六、Workspace（共享工作区）

### 6.1 目录结构

```
.workspace/
├── bus/                              # A2A 消息总线
│   ├── 2026-06-17/
│   │   ├── msg-001.json
│   │   ├── msg-002.json
│   │   └── ...
│   └── pending/                      # 待消费的消息（队列）
│       ├── review-requests/
│       └── queries/
│
├── registry/                         # 需求状态注册表
│   ├── req-2026-financial-report.yaml
│   ├── req-2026-inventory-alert.yaml
│   └── req-2026-...yaml
│
├── artifacts/                        # Artifact 仓库（按需求组织）
│   ├── req-2026-financial-report/
│   │   ├── proposal.md
│   │   ├── specs.md
│   │   ├── design.md
│   │   ├── tasks.md
│   │   ├── task-01-report.md
│   │   └── review-reports/
│   └── ...
│
├── locks/                            # 文件锁管理
│   ├── lock-state.json               # 当前活跃锁
│   └── history/                      # 锁历史（审计）
│
├── agents/                           # agent 实例注册
│   ├── active.json                   # 当前活跃 agent 列表
│   └── capacity.json                 # 容量配置（每角色上限）
│
└── logs/                             # 执行日志
    ├── team-lead.log
    └── trace-{req-id}/               # 单需求的完整消息轨迹
```

### 6.2 Artifact 仓库（Git-based）

每个需求的工件存于独立目录，**版本化通过 git tag** 而非文件副本：

```
git tag req-2026-financial-report/proposal@v1
git tag req-2026-financial-report/specs@v3
```

这样：
- 工件交接时引用 tag（如 `proposal.md@v3`），接收方明确版本
- 回退方便（checkout 旧 tag）
- 审计天然支持（git log）

### 6.3 锁管理器

**锁粒度**：文件级（不是行级，避免过度复杂）

**锁协议**：

```json
// Developer #2 请求锁
{
  "type": "lock-request",
  "from": "developer-02",
  "files": ["src/finance/ReportService.java", "src/finance/ReportMapper.java"]
}

// Lock Manager 授予
{
  "type": "lock-granted",
  "to": "developer-02",
  "locks": {
    "src/finance/ReportService.java": {"owner": "developer-02", "expires": "2026-06-17T15:00:00Z"},
    "src/finance/ReportMapper.java": {"owner": "developer-02", "expires": "2026-06-17T15:00:00Z"}
  }
}

// 若文件已被占
{
  "type": "conflict-alert",
  "to": "developer-02",
  "conflicts": [
    {"file": "src/finance/ReportService.java", "current_owner": "developer-01", "release_expected": "2026-06-17T14:30:00Z"}
  ]
}
```

**锁过期机制**：默认 30 分钟，超时自动释放（避免 agent 崩溃后死锁）。

### 6.4 状态注册表

每个需求独立状态文件，并行不冲突：

```yaml
# .workspace/registry/req-2026-financial-report.yaml
requirement_id: req-2026-financial-report
title: 财务月报按部门统计
created: 2026-06-17T10:00:00Z
current_checkpoint: apply/task-execute
current_phase: apply
parallel_tasks:
  - task_id: task-01
    status: in_progress
    assigned_to: developer-01
    files_locked: [src/finance/ReportDTO.java]
  - task_id: task-02
    status: in_progress
    assigned_to: developer-02
    files_locked: [src/finance/ReportService.java, src/finance/ReportMapper.java]
  - task_id: task-03
    status: blocked
    blocked_by: [task-01, task-02]   # 依赖前两个 task
history:
  - {checkpoint: propose/draft, agent: pm-01, completed: 2026-06-17T10:30:00Z}
  - {checkpoint: apply/specs-draft, agent: architect-01, completed: 2026-06-17T11:15:00Z}
  - {checkpoint: apply/tasks-draft, agent: tech-lead-01, completed: 2026-06-17T11:45:00Z}
```

---

## 七、并行执行模型

### 7.1 流水线并行（需求间）

不同需求处于不同 checkpoint，互不阻塞：

```
时间 →  10:00   11:00   12:00   13:00   14:00   15:00
Req A: [PM A]→[Arch A]→[TL A]→[Dev A1│A2│A3]→[Rev A]→[Test]→[DO]
Req B:        [PM B]→[Arch B]→[TL B]→[Dev B1│B2]→[Rev B]→...
Req C:                [PM C]→[Arch C]→[TL C]→...
```

每个需求独立 registry 文件、独立 artifact 目录、独立 trace_id，完全隔离。

### 7.2 任务级并行（需求内）

一个需求拆出 N 个 task 后，Tech Lead 标注依赖关系，Team Lead 按依赖图调度：

**依赖图示例（DAG）**：

```
task-01 (DTO 定义)     ──┐
                          ├──→ task-04 (Controller)  ──→ task-05 (前端)
task-02 (Service 实现) ──┤
                          ├──→ task-06 (集成测试)
task-03 (Mapper SQL)   ──┘
```

调度逻辑：

| Task | 依赖 | 可并行？ | 调度 |
|------|------|---------|------|
| task-01 | 无 | ✓ | 立即启动 developer-01 |
| task-02 | 无 | ✓ | 立即启动 developer-02（与 01 并行） |
| task-03 | 无 | ✓ | 立即启动 developer-03（与 01/02 并行） |
| task-04 | task-01/02/03 | ✗ | 等待前三个完成 |
| task-05 | task-04 | ✗ | 等待 04 |
| task-06 | 所有 | ✗ | 最后由 Tester 跑 |

### 7.3 Reviewer 队列（共享资源）

Reviewer 是共享资源（多需求共用），采用队列模式：

```
[Req A task-01 done]──┐
[Req A task-02 done]──┼──→ review-requests queue ──→ [Reviewer #1][Reviewer #2][Reviewer #3]
[Req B task-01 done]──┘                                   ↓
                                                    review-result 回传
```

3 个 Reviewer 实例可并行处理来自不同需求的审查请求。

### 7.4 容量管理

每角色有容量上限（避免无限制扩容导致 token 爆炸）：

| 角色 | 默认容量 | 扩容触发条件 |
|------|---------|------------|
| PM | 5（每需求 1 个） | 新需求到达 |
| Architect | 2 | 多需求 specs 同期推进 |
| Tech Lead | 1 | 单点（避免拆任务不一致） |
| Developer | 5 | 可并行 task 增多 |
| Reviewer | 3 | 队列堆积 > 5 |
| Tester | 2 | 多需求集成测试重叠 |
| DevOps | 1 | 单点（避免发布冲突） |
| Team Lead | 1 | **永不扩容**（避免脑裂） |

总 agent 数上限：~20（防止 token 失控）。

---

## 八、冲突检测与解决

### 8.1 冲突场景

| 场景 | 触发条件 | 后果 |
|------|---------|------|
| 文件锁冲突 | 两个 Developer 想改同一文件 | 后者必须等待 |
| 跨需求依赖 | Req A 改了 BaseEntity，Req B 依赖 BaseEntity | B 必须重测 |
| 语义冲突 | 两个 Developer 改不同文件，但语义互相影响（如改同一接口的调用方与实现方） | 编译/测试失败 |
| 资源死锁 | Agent A 锁 X 等 Y，Agent B 锁 Y 等 X | 流程僵死 |

### 8.2 检测机制

**静态检测**（启动 task 前）：
- Tech Lead 在拆任务时，明确列出每个 task 的"文件清单"
- Team Lead 启动 Developer 前，向 Lock Manager 提交文件清单
- 重叠文件 → 自动串行化

**动态检测**（运行中）：
- Developer 编辑文件时，guard_write hook 检查是否有其他 agent 正在改相关文件
- Tester 跑集成测试时，若失败，扫描是否是跨需求影响

**死锁检测**：
- Lock Manager 周期性扫描锁等待图
- 检测到环 → 升级到 Team Lead → 强制释放某个锁 + 通知 agent 重做

### 8.3 解决策略

| 冲突类型 | 自动解决 | 升级到 Team Lead | 升级到人类 |
|---------|---------|---------------|----------|
| 文件锁冲突 | 串行化（后者排队） | 排队 > 1h | — |
| 死锁 | — | 强制释放 + 重做 | 重做 > 2 次 |
| 语义冲突 | — | 通知 Tester 加测 | 测试持续失败 |
| 跨需求依赖 | — | 协调发布顺序 | 业务影响大 |

---

## 九、Team Lead 路由逻辑（Python 主循环）

> **重申**：Team Lead 是 `team_lead.py` 的 Python 主循环，**不调用 LLM**，纯规则驱动。

```
team_lead.py 主循环:
  while True:
    1. 扫 .workspace/bus/pending/ 目录
       - 有 new-requirement 消息？→ fork pm 进程
       - 有 task-done 消息？→ 更新 registry，推进该需求 checkpoint
       - 有 review-result 消息？→ 写回 registry（通过/打回）
       - 有 conflict-alert 消息？→ 进入冲突解决流程
    
    2. 扫 .workspace/registry/，按依赖图调度
       - 解析每个需求的 tasks.md 依赖图（YAML/JSON）
       - 找出 ready task（依赖已完成）
       - 检查 .workspace/locks/ 是否冲突
       - 检查 .workspace/agents/capacity.json 容量上限
       - 容量充足 + 无锁冲突 → fork developer 进程
    
    3. 扫活跃 Claude 进程
       - subprocess.poll() 检查退出码
       - 心跳文件 mtime > 30min → kill + 重启
       - 退出码非 0 → 记录 + 重试
    
    4. 死锁检测
       - 构建锁等待图（wait-for graph）
       - 检测到环 → 选一个 victim 强制释放 + 重做
    
    5. 容量回收
       - 空闲 developer 进程 > 10min → terminate
    
    sleep(30s)
```

**Team Lead 不直接产出业务工件**，只做调度决策。它**不需要 LLM 智能**——所有决策都是规则匹配（依赖满足？锁空闲？容量够？），普通 Python 逻辑就够。

**何时需要 LLM 介入**（少数复杂场景，可选）：

| 场景 | 谁来决策 | 实现 |
|------|---------|------|
| 死锁 victim 选择 | 规则（释放代价最小） | Python |
| 跨需求语义冲突（A 改了 B 依赖的接口） | LLM 推理（罕见） | Team Lead fork 一个临时 `claude -p --agent=mediator` 进程裁决 |
| 容量扩容策略 | 规则（队列长度阈值） | Python |

99% 的调度决策由 Python 完成，LLM 仅作为"复杂冲突仲裁员"按需调用。

---

## 十、状态机与断点恢复

### 10.1 单需求状态机（与 HyperSpec 兼容）

每个需求的状态机与原 HyperSpec 12 checkpoint 一致，但状态存于独立 registry 文件。

### 10.2 断点恢复

任意 agent 崩溃后：

1. Team Lead 通过心跳检测到 agent 失联
2. 释放该 agent 持有的文件锁（过期机制兜底）
3. 重新分派任务给新 agent（或等待同角色空闲 agent）
4. 新 agent 从 registry 读取上次 checkpoint + 输入 artifact，从断点继续

**关键**：所有状态外置于 Workspace 文件，agent 本身无状态，崩溃不影响整体流程。

---

## 十一、与现有 7 层架构的集成

### 11.1 每个 agent 各自加载 7 层能力

| Agent | L1 OpenSpec | L2 Superpowers | L3 审查 | L4 技能 | L5 工具 | L6 本能 |
|-------|------------|--------------|--------|--------|--------|--------|
| PM | 读 proposal | — | — | 业务分析 | Read only | 业务经验 |
| Architect | 产 specs/design | — | — | springboot/ddd | LSP/AST | 架构经验 |
| Developer | 读 tasks | **TDD 强制** | — | 编码技能 | Edit/Bash | 编码经验 |
| Reviewer | 读 specs 对照 | — | **9 关/3 关** | 审查技能 | Read only | 历史问题 |
| Tester | 读 specs | — | — | 测试技能 | Bash | 边界用例 |

### 11.2 HyperSpec 升级为 Multi-HyperSpec

原 HyperSpec 是单状态机；新方案下，HyperSpec 变成"状态机管理器"，每个需求一个子状态机实例。Team Lead 是 Multi-HyperSpec 的运行时。

### 11.3 安全保护层升级

原 Hooks（guard_write、run_checks、ensure_change_context）保留，并新增：
- `lock_check.py`：写文件前检查是否持有锁
- `workspace_sync.py`：每次 commit 后同步 registry 状态

---

## 十二、实现路径

### 12.1 技术栈选型（关键：Team Lead 必须是 Python）

| 组件 | 选型 | 备选 | 备注 |
|------|------|------|------|
| **Team Lead 编排器** | **Python 脚本** | Node.js | ★ 非 Claude，落地的必要前提 |
| 角色 Agent runtime | **Claude Code CLI (`claude -p`)** | Claude Agent SDK | 每 agent 一个独立进程 |
| A2A 消息总线 | 文件队列（`.workspace/bus/`） | Redis / RabbitMQ | 首选文件——无依赖、易调试 |
| Artifact 仓库 | Git + 语义 tag | 自建版本化存储 | 与现有 git 工作流契合 |
| 锁管理器 | 文件 + flock | Redis SETNX | 文件级即可 |
| 状态注册表 | YAML 文件 | SQLite | 人可读、易调试 |
| 进程管理 | `subprocess.Popen` + `poll()` | systemd / supervisord | Python 标准库够用 |
| 监控 | 日志 + Grafana | LangSmith | 后期再加 |

### 12.2 Team Lead 的核心代码结构

```
team_lead/                            # Python 包（不是 Claude agents 目录）
├── __init__.py
├── main.py                           # 入口：python -m team_lead
├── bus.py                            # A2A 文件总线扫描与派发
├── dispatcher.py                     # fork claude -p 子进程的核心逻辑
├── scheduler.py                      # 依赖图调度算法
├── lock_manager.py                   # 锁管理器（含死锁检测）
├── registry.py                       # 状态注册表读写
├── heartbeat.py                      # 子进程心跳监控
└── config.py                         # 容量上限、超时阈值
```

### 12.3 Claude agents 目录（被 Python fork 加载）

```
.claude/
├── agents/                           # 7 个角色 agent（不含 team-lead）
│   ├── pm.md                         # 接收 inbox.json → 产 proposal.md + outbox.json
│   ├── architect.md
│   ├── tech-lead.md
│   ├── developer.md
│   ├── reviewer.md
│   ├── tester.md
│   └── devops.md
├── workspace/                        # 运行时（git ignored）
│   ├── bus/
│   │   ├── pending/                  # 待消费消息（按 type 分目录）
│   │   │   ├── new-requirements/
│   │   │   ├── task-done/
│   │   │   ├── review-requests/
│   │   │   └── conflict-alerts/
│   │   ├── outbox/                   # 各 Claude 进程的输出
│   │   └── archive/{date}/           # 已归档的消息（审计/重放）
│   ├── registry/
│   │   └── {req-id}.yaml
│   ├── artifacts/{req-id}/
│   ├── locks/
│   │   ├── lock-state.json
│   │   └── history/
│   ├── agents/
│   │   ├── active.json               # 当前活跃 Claude 进程列表（PID + 角色）
│   │   └── capacity.json             # 每角色容量上限
│   └── logs/
│       ├── team_lead.log
│       └── trace-{req-id}/
├── hooks/                            # 安全保护脚本（Claude 进程内执行）
│   ├── guard_write.py                # 原有
│   ├── run_checks.sh                 # 原有
│   ├── lock_check.py                 # 新增：写文件前查锁
│   └── workspace_sync.py             # 新增：commit 后同步 registry
└── commands/
    ├── team-start.md                 # 启动：python -m team_lead
    ├── team-status.md                # 查看状态：python -m team_lead.status
    └── team-stop.md                  # 优雅停止
```

### 12.4 单个 Claude 进程的输入/输出契约

每个 Claude 子进程接收一个 `inbox.json` 任务包，输出 `outbox.json` 结果：

```json
// inbox.json（Python 写入，Claude 读取）
{
  "agent_role": "developer",
  "agent_instance_id": "developer-02",
  "requirement_id": "req-2026-financial-report",
  "task_id": "task-02",
  "checkpoint": "apply/task-execute",
  "input_artifacts": [
    ".workspace/artifacts/req-2026-financial-report/tasks.md@v3",
    ".workspace/artifacts/req-2026-financial-report/design.md@v2"
  ],
  "files_locked": [
    "src/finance/ReportService.java",
    "src/finance/ReportMapper.java"
  ],
  "expected_output": ".workspace/artifacts/req-2026-financial-report/task-02-report.md",
  "deadline": "2026-06-17T15:00:00Z",
  "trace_id": "trace-req-2026-financial-report"
}
```

```json
// outbox.json（Claude 写入，Python 读取）
{
  "agent_instance_id": "developer-02",
  "status": "done",                    // done | failed | blocked
  "output_artifacts": ["...task-02-report.md"],
  "files_modified": ["src/finance/ReportService.java"],
  "commits": ["a1b2c3d"],
  "next_message": {                    // Python 转发到 bus/pending/
    "type": "review-request",
    "to": "reviewer-pool",
    "payload": { ... }
  },
  "error": null
```

Claude 进程退出后，Python 读取 `outbox.json` → 把 `next_message` 转发到 bus → 进入下一轮调度。

### 12.5 落地阶段（重新排期：先 Python 编排器，再扩并行）

**阶段 1：Python 编排器 + 单 agent 跑通**（2 周）
- 实现 `team_lead/` Python 包
- Workspace 目录结构与 A2A 协议
- 单需求 fork PM → Architect → Tech Lead → Developer → Reviewer 串行跑通
- **验证里程碑**：`python -m team_lead` 启动后，单需求能完整跑完 7 个角色

**阶段 2：任务级并行**（2 周）
- Tech Lead 输出依赖图（DAG）
- Scheduler 按依赖图并行 fork 多 Developer
- Lock Manager 实现文件锁
- **验证里程碑**：单需求内 ≥ 3 个 Developer 真并行（用 `ps -ef | grep claude` 验证）

**阶段 3：流水线并行 + 冲突解决**（2 周）
- 多需求并发调度
- 死锁检测
- Reviewer/Tester 队列模式
- **验证里程碑**：3 个需求并发跑完，加速比 ≥ 2.5x

**阶段 4：监控与容错**（1 周）
- 心跳/超时重启
- 日志聚合
- 容量动态调整

---

## 十三、典型场景：3 个需求并行

**需求 A**：财务月报按部门统计（5 task）
**需求 B**：库存预警阈值可配置（3 task）
**需求 C**：生产工单批量审核（6 task）

### 13.1 时间线

```
10:00  用户连续提交 A、B、C 三个需求
10:01  Team Lead 启动 PM-A、PM-B、PM-C（3 个 PM agent 并行）
10:30  PM-A 完成 proposal-A，启动 Architect-A
       PM-B 完成 proposal-B，启动 Architect-B
       PM-C 还在与用户澄清边界
10:45  PM-C 完成，启动 Architect-C
11:00  Architect-A 完成 specs/design-A，启动 Tech Lead-A
11:15  Architect-B 完成，启动 Tech Lead-B
11:30  Architect-C 完成，启动 Tech Lead-C
11:30  Tech Lead-A 完成，输出 5 个 task（其中 3 个可并行）
       Team Lead 启动 Developer-A1、A2、A3（3 个并行）
       Lock Manager 授予 A1/A2/A3 各自的文件锁
11:45  Tech Lead-B 完成，输出 3 个 task（全部可并行）
       启动 Developer-B1、B2、B3
       Lock Manager 检测：B2 与 A1 都想改 ReportService.java → B2 排队
12:00  Tech Lead-C 完成，输出 6 个 task（部分可并行）
       启动 Developer-C1、C2
       
       此时活跃 agent：3 PM(完成)、3 Arch(完成)、3 TechLead(完成)
                     3 Dev-A、3 Dev-B、2 Dev-C = 8 Developer
                     总活跃：8 + Team Lead = 9 agent
       
12:30  Developer-A1 完成 task-A1，发 review-request
       Reviewer Pool 接单 → Reviewer-01 审查
12:35  Reviewer-01 通过 task-A1
12:40  Developer-A2、A3 也完成 → 加入 review 队列
12:50  Developer-B2 的锁等待超时，Team Lead 介入调度
       发现 A1 已完成释放 ReportService.java → 授予 B2

13:30  所有 A 的 task 通过 review → 启动 Tester-A
14:00  Tester-A 集成测试通过
14:15  Reviewer + Architect 最终批准 A
14:30  DevOps-A 发布 A（git tag req-A@v1）

14:30  B、C 继续推进...
```

### 13.2 性能对比

| 方案 | 总耗时（A/B/C 全部完成） | 加速比 |
|------|-----------------------|-------|
| 单实例串行 | ~6 小时（A→B→C 顺序） | 1x |
| 单实例流水线 | ~3.5 小时 | 1.7x |
| 多 agent + A2A | ~2 小时 | 3x |

**核心收益**：多 agent 把"等待时间"转化为"并行产出"。

---

## 十四、风险与对策

| 风险 | 概率 | 影响 | 对策 |
|------|-----|------|------|
| Token 成本爆炸 | 高 | 月费 5-10x | 容量上限 + 模型路由（haiku 优先） |
| 死锁 | 中 | 流程僵死 | 锁过期 + 周期检测 |
| 消息丢失 | 低 | 状态不一致 | 文件持久化 + 重放 |
| Agent 失联 | 中 | 任务停滞 | 心跳 + 超时重启 |
| 跨需求语义冲突 | 中 | 测试失败 | Tester 加跨需求回归 |
| 调试困难 | 高 | 排查慢 | trace_id + 日志聚合 |

---

## 十五、与单实例方案的切换策略

两套方案**共存**，按需切换。**关键区别：是否启动 `team_lead.py`**。

| 触发条件 | 启用方案 | 启动命令 |
|---------|---------|---------|
| 单需求、task ≤ 5 | 单实例 | `/hyperspec`（一个 Claude 会话内） |
| 单需求、task ≥ 6 或跨模块 | 多 agent | `python -m team_lead`（fork 多个 claude -p） |
| 多需求并发（≥ 2） | 多 agent | `python -m team_lead` |
| 大型重构 | 多 agent + 严格锁管理 | `python -m team_lead` |

**切换的本质**：

| | 单实例 | 多 agent |
|---|---|---|
| 用户终端数 | 1 | 1（只多了一个 Python 进程） |
| Claude 会话数 | 1 | N（被 Python fork 出来） |
| 启动命令 | `/hyperspec` | `python -m team_lead` |
| 协调者 | 主会话自身 | Python 主循环 |
| 真并行 | 否 | 是 |

`AGENTS.md` 顶部声明（由 Python 编排器读取）：

```yaml
mode: auto  # auto | single | multi
auto_rules:
  - if: concurrent_requirements >= 2
    then: multi
  - if: task_count >= 6
    then: multi
  - default: single
mode_switch:
  single: "/hyperspec"                      # Claude 会话内 slash command
  multi:  "python -m team_lead"             # 外部 Python 进程
```

**重要提醒**：在单个 Claude 会话内运行 `/hyperspec` 时，**不要假装在跑多 agent**——即使加载了 8 份 agent 提示词，本质仍是单实例。真多 agent 必须启动 `team_lead.py`。

---

## 十六、下一步：并行开发讨论

本文档完成了多 agent + A2A 架构的设计。接下来需要讨论的并行开发议题：

1. **容量规划**：每个角色多少 agent 合适？如何动态调整？
2. **锁粒度**：文件级 vs 模块级？行级是否值得？
3. **跨需求优先级**：3 个需求同时到达，谁先？
4. **资源抢占**：Reviewer 是稀缺资源，如何公平调度？
5. **回滚策略**：并行发布后某个需求出问题，如何安全回滚？
6. **可观测性**：如何在 UI 上展示 8+ agent 的实时状态？

这些问题在架构落地后逐一讨论。
