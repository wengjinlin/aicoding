# Phase 1 · opencode 适配详细设计（v2，基于真实机制）

> **生成日期**：2026-07-21
> **版本**：v2（v1 基于错误推断，已废弃）
> **核心修正**：通过阅读 `HyperSpec/SKILL.md` 实际内容，确认 HyperSpec 是**纯工具无关编排 skill**——运行时角色切换由 SKILL.md 在会话内指挥 Agent 完成，**不需要 plugin 介入**。本设计因此大幅简化。

---

## 一、v2 与 v1 的核心差异

| 维度 | v1（错误推断） | v2（基于事实） |
|------|-------------|--------------|
| plugin 数量 | 4 个（含运行时切换） | **3 个**（只做 session.start / tool.pre / tool.post） |
| harness-role 复杂度 | 监听 chat.message.pre / 文件变化 | **只在 session.start 跑一次** |
| HyperSpec 复用度 | 需要写"opencode 适配补丁" | **100% 原样复用** |
| 总代码量 | ~2000 行 | **~700 行** |
| 已知限制 | 5 条（含"运行时不能切换角色"） | **2 条** |

**修正依据**：`HyperSpec/SKILL.md` 第 14-27 行明确"HyperSpec 是纯编排层"，第 192-200 行明确"用 Read 工具加载子文件"——所有运行时逻辑由 Agent 在会话内执行，工具无关。

---

## 二、HyperSpec 真实工作机制（已从 SKILL.md 确认）

### 2.1 HyperSpec 只做 4 件事

```
┌─────────────────────────────────────────────────────┐
│  HyperSpec SKILL.md 的 4 项职责                       │
│                                                      │
│  1. 项目感知     探测语言/框架/构建工具                │
│  2. 状态检测     读 .hyperspec-state.yaml + 验证文件  │
│  3. 阶段路由     Read propose.md / apply.md /         │
│                  archive.md 执行                      │
│  4. Commit 纪律  每 task 自动 commit                  │
└─────────────────────────────────────────────────────┘
```

### 2.2 HyperSpec 显式"不做"的事

| 不做 | 委托给 |
|------|-------|
| 创建 openspec artifacts | `openspec-propose` skill |
| 转 tasks → plan | `superpowers:writing-plans` skill |
| TDD 编码 | `superpowers:subagent-driven-development` |
| 代码审查 | `superpowers:requesting-code-review` |
| 归档 | `openspec-archive-change` |

### 2.3 运行时角色切换的真实路径

```
用户：/hyperspec propose "新增用户认证"
         │
         ▼
opencode 读 HyperSpec/SKILL.md
         │
         ▼  按 SKILL 指令：
Agent 读 .hyperspec-state.yaml
         │
         ▼  状态检测 + 验证文件一致性
Agent 路由到 propose 阶段
         │
         ▼  按 SKILL 指令：用 Read 工具加载
Agent Read skill/propose.md
         │
         ▼  按 propose.md 流程
Agent 委托 openspec-propose 生成 artifacts
         │
         ▼  按 propose.md 流程
Agent 委托 superpowers:writing-plans 转 plan
         │
         ▼  按 propose.md 流程
Agent 写 .hyperspec-state.yaml → checkpoint: plan-generated
         │
         ▼  按 propose.md 出口条件
Agent Read skill/apply.md
         │
         ▼  按 apply.md 流程
Agent 委托 superpowers:subagent-driven-development 编码
         │
         ▼  ...继续推进 checkpoint...
```

**关键**：所有"角色切换"实质是 Agent 读取了不同的 SKILL 子文件 + 不同的 `team-roles/*.md` prompt——这是**纯文本驱动**，与 Claude Code 还是 opencode 无关。

### 2.4 SKILL.md 用到的全部"工具"

通读 SKILL.md 全文，它只依赖：
- ✅ **Read**（读子流程文件、读 artifacts）
- ✅ **Write / Edit**（更新 `.hyperspec-state.yaml`）
- ✅ **Bash**（项目分析器跑编译命令、commit）
- ✅ **skill 委托**（通过 prompt 让 Agent 调用其他 skill）

**没有任何 Claude Code 特有的 slash command、hook、MCP 工具依赖**。

---

## 三、opencode 适配的真实工作量

只需要 3 类工作：

### 工作 1：把工具无关的资产原样搬到 opencode

| 资产 | 来源 | opencode 目标位置 | 是否改动 |
|------|------|-----------------|---------|
| HyperSpec SKILL.md + 子文件 | `.claude/skills/HyperSpec/` | `.opencode/skills/HyperSpec/` | ❌ 零改动 |
| Superpowers skills | `.claude/skills/superpowers/` | `.opencode/skills/superpowers/` | ❌ 零改动 |
| OpenSpec skills | `.claude/skills/openspec/` | `.opencode/skills/openspec/` | ❌ 零改动 |
| 团队角色 prompt | `.claude/agents/*.md` | `.opencode/agents/*.md`（需加 frontmatter） | ⚠️ 加 frontmatter |
| 角色权限矩阵 | `.claude/team-roles/permissions.json` | `.opencode/team-roles/permissions.json` | ❌ 零改动 |
| Checkpoint 映射 | `.claude/team-roles/checkpoint-map.yaml` | `.opencode/team-roles/checkpoint-map.yaml` | ❌ 零改动 |
| HyperSpec 扩展 | `.claude/team-roles/hyperspec-extend.yaml` | `.opencode/team-roles/hyperspec-extend.yaml` | ❌ 零改动 |
| AGENTS.md | 项目根 | 项目根（同名同址） | ❌ 零改动 |
| `.hyperspec-state.yaml` | 项目根 | 项目根（同名同址） | ❌ 零改动 |
| `openspec/` 工件目录 | 项目根 | 项目根（同名同址） | ❌ 零改动 |

### 工作 2：写 3 个 TS plugin（替换原 4 个 bash/python hook）

| Plugin | 触发事件 | 替换的原 hook |
|--------|---------|-------------|
| `harness-role` | `session.start` | `apply-role.sh`（精简版） |
| `harness-guard` | `tool.pre` | `guard_write.py` + `ensure_change_context.py`（合并） |
| `harness-checks` | `tool.post` | `run_checks.sh` |

### 工作 3：写 init / uninstall 脚本

| 脚本 | 作用 |
|------|------|
| `init-for-opencode.sh` | 安装资产 + 编译 plugin + 生成 opencode.json |
| `uninstall-for-opencode.sh` | 仅清理 `.opencode/`，保留 `openspec/` 和 `.hyperspec-state.yaml` |
| `verify-opencode-adapter.sh` | 跑 10 个端到端测试用例 |

---

## 四、整体架构

```
harness-packages/
├── harness-infra/                        # 已有，不动
├── harness-agents/                       # 已有，不动
└── harness-opencode/                     # ⭐ 新增包（约 700 行）
    ├── README.md
    ├── init-for-opencode.sh              # 主安装脚本
    ├── uninstall-for-opencode.sh
    ├── verify-opencode-adapter.sh
    │
    ├── plugins/                          # 3 个 TS plugin
    │   ├── harness-role/
    │   │   ├── package.json
    │   │   ├── tsconfig.json
    │   │   └── src/index.ts              # ~80 行
    │   ├── harness-guard/
    │   │   ├── package.json
    │   │   ├── tsconfig.json
    │   │   └── src/index.ts              # ~150 行（含按角色保护清单）
    │   └── harness-checks/
    │       ├── package.json
    │       ├── tsconfig.json
    │       └── src/index.ts              # ~60 行
    │
    ├── agents-frontmatter/               # 7 个 opencode agent 头部
    │   ├── pm.md
    │   ├── architect.md
    │   ├── tech-lead.md
    │   ├── developer.md
    │   ├── reviewer.md
    │   ├── tester.md
    │   └── devops.md
    │
    └── config/
        └── opencode.json.template        # 项目根 opencode.json 模板
```

**关键设计**：assets（skills、team-roles）**不在 harness-opencode/ 内**——它们已在 harness-infra 和 harness-agents 里。init 脚本负责把它们**符号链接或复制**到 `.opencode/` 下。

---

## 五、Plugin 1：harness-role（session.start）

### 5.1 目标

会话启动时，读 `.hyperspec-state.yaml`，注入当前 checkpoint 对应的角色 prompt 到 system context。

### 5.2 TS 实现

```typescript
// plugins/harness-role/src/index.ts
import { plugin } from "@opencode/plugin-sdk";
import yaml from "js-yaml";
import { readFileSync, existsSync } from "fs";
import { join } from "path";

const PROJECT_ROOT = process.cwd();

function readYaml<T>(path: string): T | null {
  if (!existsSync(path)) return null;
  try {
    return yaml.load(readFileSync(path, "utf8")) as T;
  } catch {
    return null;
  }
}

function resolveRole(checkpoint: string, map: any): string {
  if (!checkpoint || checkpoint === "done") return "";
  const entry = map.checkpoints[checkpoint];
  if (entry?.role) return entry.role;
  // task-N-complete 模式匹配
  if (/^task-\d+-complete$/.test(checkpoint)) {
    return map.checkpoints["task-N-complete"]?.role ?? "developer";
  }
  return map.default_role ?? "developer";
}

export default plugin({
  name: "harness-role",
  event: {
    "session.start": async () => {
      const stateFile = join(PROJECT_ROOT, ".hyperspec-state.yaml");
      const mapFile = join(PROJECT_ROOT, ".opencode/team-roles/checkpoint-map.yaml");
      const promptDir = join(PROJECT_ROOT, ".opencode/agents");

      const state = readYaml<any>(stateFile);
      const checkpoint = state?.checkpoint ?? state?.current_checkpoint;
      if (!checkpoint || checkpoint === "done") return {};

      const map = readYaml<any>(mapFile);
      if (!map) return {};

      const role = resolveRole(checkpoint, map);
      const promptPath = join(promptDir, `${role}.md`);
      if (!existsSync(promptPath)) return {};

      // 限制 6KB，与 Claude Code 适配一致
      const prompt = readFileSync(promptPath, "utf8").slice(0, 6144);

      return {
        system: `
============================================================
🎭 Harness 角色：${role}    checkpoint：${checkpoint}
============================================================

${prompt}

------------------------------------------------------------
注意：
- 你现在以「${role}」视角工作
- 推进 checkpoint 时按 HyperSpec/SKILL.md 的指令执行
- 工件通过 openspec/changes/<id>/ 传递
------------------------------------------------------------
`,
      };
    },
  },
});
```

### 5.3 与 v1 的差异

- 删除所有"运行时切换"逻辑（chat.message.pre / 文件监听）
- 删除三级 YAML 解析兜底（TS 直接用 js-yaml）
- 字段名兼容：`checkpoint` 或 `current_checkpoint`（前者是真实 SKILL.md 用的字段）

---

## 六、Plugin 2：harness-guard（tool.pre）

### 6.1 目标

合并 v1 的 `guard_write.py` + `ensure_change_context.py` 两个 hook：
- 拦截对保护文件的写入（按角色）
- 拦截无 openspec 工单的危险 Bash 命令

### 6.2 关键设计：按角色保护清单

由于 opencode 权限是粗粒度（read/edit/bash/mcp × allow/ask/deny），所有细粒度限制必须靠本 plugin 实现。设计一个**工具无关的 permissions.yaml**：

```yaml
# config/permissions.yaml（被 plugin 读取，工具无关）
protected_paths_global:          # 所有角色都不能改
  - application*.yml
  - application-*.yml
  - application*.properties
  - db/**
  - sql/**
  - *.env
  - *.env.local
  - *credentials*
  - *secrets*
  - *.pem
  - id_rsa*

risky_bash_patterns:             # 没有 active change 时拦截
  - ^git\s+push
  - ^git\s+reset\s+--hard
  - ^mvn\s+deploy
  - (?i)drop\s+table
  - (?i)truncate\s+table
  - (?i)delete\s+from

role_specific_deny:              # 角色额外禁止写的路径
  tester:
    - src/main/**
  devops:
    - src/**
```

plugin 读取此文件 + 当前角色 → 决定拦截策略。

### 6.3 TS 实现

```typescript
// plugins/harness-guard/src/index.ts
import { plugin } from "@opencode/plugin-sdk";
import yaml from "js-yaml";
import { readFileSync, existsSync, readdirSync } from "fs";
import { join, resolve, relative } from "path";
import { minimatch } from "minimatch";

const PROJECT_ROOT = process.cwd();

function loadPermissions(): any {
  const path = join(PROJECT_ROOT, ".opencode/team-roles/permissions.yaml");
  if (!existsSync(path)) return null;
  try {
    return yaml.load(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

function getCurrentRole(): string {
  // 读 .hyperspec-state.yaml + checkpoint-map 推断当前角色
  const stateFile = join(PROJECT_ROOT, ".hyperspec-state.yaml");
  const mapFile = join(PROJECT_ROOT, ".opencode/team-roles/checkpoint-map.yaml");
  if (!existsSync(stateFile) || !existsSync(mapFile)) return "developer";
  try {
    const state = yaml.load(readFileSync(stateFile, "utf8")) as any;
    const map = yaml.load(readFileSync(mapFile, "utf8")) as any;
    const cp = state?.checkpoint ?? state?.current_checkpoint;
    if (!cp) return "developer";
    return map.checkpoints[cp]?.role
      ?? (/^task-\d+-complete$/.test(cp)
          ? (map.checkpoints["task-N-complete"]?.role ?? "developer")
          : "developer");
  } catch {
    return "developer";
  }
}

function hasActiveChange(): boolean {
  const dir = join(PROJECT_ROOT, "openspec/changes");
  if (!existsSync(dir)) return false;
  try {
    const entries = readdirSync(dir).filter(e => e !== "archive");
    return entries.length > 0;
  } catch {
    return false;
  }
}

function normalize(p: string): string {
  return relative(PROJECT_ROOT, resolve(PROJECT_ROOT, p)).replace(/\\/g, "/");
}

function matchesAny(path: string, patterns: string[]): boolean {
  return patterns.some(p => minimatch(path, p, { dot: true }));
}

export default plugin({
  name: "harness-guard",
  event: {
    "tool.pre": async (ctx: any) => {
      const perms = loadPermissions();
      if (!perms) return {}; // 无配置则放行

      const role = getCurrentRole();

      // —— 分支 A：写文件拦截（write / edit）——
      if (ctx.tool === "write" || ctx.tool === "edit") {
        const filePath = ctx.input.file_path ?? ctx.input.path;
        if (!filePath) return {};
        const rel = normalize(filePath);

        const globalBlock = matchesAny(rel, perms.protected_paths_global ?? []);
        const roleBlock = matchesAny(
          rel,
          perms.role_specific_deny?.[role] ?? []
        );

        if (globalBlock || roleBlock) {
          return {
            status: "deny" as const,
            error: `🛡️ harness-guard 拦截：${rel}
    角色：${role}
    此路径受 Harness 安全保护层保护。如需修改：
      1. 在 openspec/changes/ 下创建变更工单
      2. 显式声明修改此文件的理由
      3. 由人类审核后执行
    （如需绕过，设置环境变量 HARNESS_BYPASS=1）`,
          };
        }
      }

      // —— 分支 B：危险 Bash 命令拦截 ——
      if (ctx.tool === "bash") {
        const cmd: string = ctx.input.command ?? "";
        const risky = (perms.risky_bash_patterns ?? []).some(
          (p: string) => new RegExp(p).test(cmd)
        );
        if (risky && !hasActiveChange() && !process.env.HARNESS_BYPASS) {
          return {
            status: "deny" as const,
            error: `⚠️ harness-guard 拦截：危险命令无活跃 openspec 工单
    命令：${cmd}
    请先在 openspec/changes/ 下创建工单，或设置 HARNESS_BYPASS=1`,
          };
        }
      }

      return {}; // 放行
    },
  },
});
```

### 6.4 与 v1 的差异

- 合并了 `guard_write.py` + `ensure_change_context.py`
- 引入 minimatch（glob 匹配，比正则更准）
- 加 `HARNESS_BYPASS=1` 逃生舱
- 新增"角色额外禁止路径"（补偿 opencode 粗粒度权限）

---

## 七、Plugin 3：harness-checks（tool.post）

### 7.1 目标

`.java` 文件保存后自动跑 `mvn compile`，失败输出 stderr，**不阻塞会话**（与 Claude Code 适配一致）。

### 7.2 TS 实现

```typescript
// plugins/harness-checks/src/index.ts
import { plugin } from "@opencode/plugin-sdk";
import { existsSync } from "fs";
import { join } from "path";
import { spawn } from "child_process";

const PROJECT_ROOT = process.cwd();

function findMaven(): string | null {
  if (existsSync(join(PROJECT_ROOT, "mvnw"))) return "./mvnw";
  const intellij = "/c/Program Files/JetBrains/IntelliJ IDEA 2025.3/plugins/maven/lib/maven3/bin/mvn.cmd";
  if (existsSync(intellij)) return intellij;
  return "mvn";
}

export default plugin({
  name: "harness-checks",
  event: {
    "tool.post": async (ctx: any) => {
      if (ctx.tool !== "write" && ctx.tool !== "edit") return {};
      const filePath: string = ctx.input.file_path ?? "";
      if (!filePath.endsWith(".java")) return {};

      const mvn = findMaven();
      const env = { ...process.env, JAVA_HOME: "/d/jdk1.8.0_171" };

      // 异步跑，不阻塞会话
      const child = spawn(mvn, ["compile", "-q"], {
        cwd: PROJECT_ROOT,
        env,
        stdio: ["ignore", "pipe", "pipe"],
        shell: true,
      });

      let stderr = "";
      child.stderr.on("data", (d) => (stderr += d.toString()));

      child.on("close", (code) => {
        if (code !== 0) {
          console.error(
            `\n⚠️  mvn compile 失败（exit ${code}）\n${stderr.slice(-2000)}\n`
          );
        }
      });

      return {}; // 不阻塞
    },
  },
});
```

### 7.3 与 v1 的差异

- 与 v1 几乎一致（这部分本来就工具无关）
- Maven 路径写死 IntelliJ 路径（用户 CLAUDE.md 已规定）

---

## 八、opencode agents frontmatter（7 个）

### 8.1 模板

每个 agent 文件 = frontmatter（opencode 权限） + 现有 `agents/*.md` 内容。

以 `reviewer.md` 为例：

```markdown
---
description: 代码审查员 — 严格只读，独立审查视角
model: opus
permissions:
  read: allow
  edit: deny
  bash: deny
  webfetch: allow
  mcp: allow
---

（这里嵌入 harness-agents/agents/reviewer.md 的全部内容，零修改）
```

### 8.2 7 个角色的 frontmatter 配置

| 角色 | model | read | edit | bash | 备注 |
|------|-------|------|------|------|------|
| pm | opus | allow | deny | deny | 加 webfetch: allow |
| architect | opus | allow | deny | deny | mcp: allow（LSP/AST） |
| tech-lead | sonnet | allow | deny | deny | mcp: allow |
| developer | sonnet | allow | allow | allow | 细粒度靠 harness-guard |
| reviewer | opus | allow | deny | deny | 严格只读 |
| tester | sonnet | allow | allow | allow | 细粒度靠 harness-guard（src/main/**） |
| devops | sonnet | allow | allow | allow | 细粒度靠 harness-guard（src/**） |

### 8.3 复用策略

agent 文件分两部分：
- **frontmatter**：opencode 专属（init 脚本生成）
- **正文**：直接 `cat harness-agents/agents/{role}.md >>`（零改动）

init 脚本的拼装逻辑：

```bash
assemble_agent_files() {
    for role in pm architect tech-lead developer reviewer tester devops; do
        local frontmatter="agents-frontmatter/${role}.md"
        local source="$HARNESS_AGENTS_DIR/agents/${role}.md"
        local target=".opencode/agents/${role}.md"

        cat "$frontmatter" > "$target"
        echo "" >> "$target"
        cat "$source" >> "$target"
    done
}
```

---

## 九、init-for-opencode.sh 结构

```bash
#!/usr/bin/env bash
# init-for-opencode.sh — 把 Harness V2 适配到 opencode

set -uo pipefail

# === 阶段 1：前置检查 ===
preflight_check() {
  # 必需：harness-infra 已初始化（openspec/ 等存在）
  # 必需：harness-agents 已初始化（agents/*.md 存在）
  # 必需：opencode 在 PATH
  # 必需：node ≥ 20
  # 警告：若 .claude/ 存在，提示"你已装 Claude Code 适配，建议二选一"
}

# === 阶段 2：编译 3 个 plugin ===
build_plugins() {
  for plugin in harness-role harness-guard harness-checks; do
    ( cd "plugins/$plugin" && npm install && npm run build )
  done
}

# === 阶段 3：装 skills（符号链接到 harness-infra 已装的） ===
install_skills() {
  mkdir -p .opencode/skills
  # HyperSpec、superpowers、openspec 等符号链接到 .claude/skills/
  # 或者从 harness-infra 的源目录链接
  ln -sf ../../.claude/skills/HyperSpec .opencode/skills/HyperSpec
  ln -sf ../../.claude/skills/superpowers .opencode/skills/superpowers
  # ...
}

# === 阶段 4：装 team-roles（符号链接） ===
install_team_roles() {
  mkdir -p .opencode/team-roles
  ln -sf ../../.claude/team-roles/checkpoint-map.yaml .opencode/team-roles/
  ln -sf ../../.claude/team-roles/hyperspec-extend.yaml .opencode/team-roles/
  ln -sf ../../.claude/team-roles/permissions.json .opencode/team-roles/
  # permissions.yaml 是 opencode 新增的，单独装
  cp "$SRC/config/permissions.yaml" .opencode/team-roles/
}

# === 阶段 5：装 agents（拼装 frontmatter + 现有正文） ===
assemble_agent_files() {
  mkdir -p .opencode/agents
  for role in pm architect tech-lead developer reviewer tester devops; do
    cat "agents-frontmatter/${role}.md" > ".opencode/agents/${role}.md"
    echo "" >> ".opencode/agents/${role}.md"
    cat ".claude/agents/${role}.md" >> ".opencode/agents/${role}.md"
  done
}

# === 阶段 6：生成 opencode.json ===
generate_opencode_json() {
  # 读 .mcp.json（若存在）转换为 opencode 格式
  # 注册 3 个 plugin
  # 设置默认模型路由
}

# === 阶段 7：写报告 ===
print_report() {
  # 已安装组件
  # 下一步：opencode，跑 /hyperspec ...
}

preflight_check
build_plugins
install_skills
install_team_roles
assemble_agent_files
generate_opencode_json
print_report
```

### 9.1 与 v1 的差异

- 大量使用**符号链接**（skills、team-roles）——避免数据重复
- agents 是**拼装**而非纯复制（frontmatter + 现有正文）
- 不需要"幂等性深度合并"（用户决策：不混用，独占安装）

---

## 十、uninstall-for-opencode.sh

```bash
#!/usr/bin/env bash
# 仅清理 .opencode/，保留：
#   - openspec/
#   - .hyperspec-state.yaml
#   - AGENTS.md
#   - .claude/（若有）
#   - git 历史

set -uo pipefail

# 阶段 1：列出将删除的内容（dry-run 默认）
# 阶段 2：备份 .opencode/ 到 .harness-opencode-uninstall-backup-{date}/
# 阶段 3：删除 .opencode/
# 阶段 4：可选 --purge，同时删除 .hyperspec-state.yaml（默认保留）
```

---

## 十一、端到端测试用例（10 个，精简版）

| # | 场景 | 验证点 | 预期 |
|---|------|-------|------|
| T1 | 全新项目 + init-for-opencode.sh | skills 链接、agents 拼装、plugin 编译、opencode.json 生成 | 全部产物存在 |
| T2 | 启动 opencode（无 `.hyperspec-state.yaml`） | harness-role 不注入角色 | system 无角色内容 |
| T3 | checkpoint=proposal-draft 时启动 opencode | harness-role 注入 PM 角色 | system 含 PM prompt |
| T4 | developer 角色下，尝试 Write `application.yml` | harness-guard 拦截 | deny + 错误消息 |
| T5 | developer 角色下，尝试 Write `src/Foo.java` | 放行 | 正常写入 |
| T6 | tester 角色下，尝试 Edit `src/main/Foo.java` | harness-guard 拦截 | deny |
| T7 | 无 openspec 工单时，尝试 `git push` | harness-guard 拦截 | deny + 提示创建工单 |
| T8 | 有 `openspec/changes/req-001/` 时 `git push` | 放行 | 正常执行 |
| T9 | Write `src/Foo.java` 后 | harness-checks 跑 mvn compile | 编译结果输出 |
| T10 | uninstall 后 | `.opencode/` 清理，`openspec/` 和 `.hyperspec-state.yaml` 保留 | 仅删 opencode 痕迹 |

### 11.1 删除的测试用例（v1 → v2）

- ~~T10 切换 checkpoint（不重启 opencode）角色不变~~（HyperSpec 自己处理，不需要测试 plugin）
- ~~T11 重启 opencode 后角色更新~~（合并到 T3）

---

## 十二、已知风险与边界（v2 只剩 2 条）

### R1：opencode plugin API 稳定性

opencode 周级更新，plugin API 可能变更。

**缓解**：
- init 脚本锁定 opencode 版本范围
- 季度评估升级

### R2：HyperSpec 子文件（`propose.md` 等）的 Claude Code 依赖

SKILL.md 本身 100% 工具无关，但它 Read 的子文件（`propose.md` / `apply.md` / `archive.md`）**还没看**。可能含有 Claude Code 特有的 slash command 引用。

**缓解**：Phase 1 实施前**先快速过一遍子文件**（约 15 分钟），确认无 Claude Code 特有依赖。若发现依赖，写一个补丁文件覆盖。

### v1 中的伪风险（已消除）

- ~~"运行时不能切换角色"~~（HyperSpec 自己干）
- ~~"opencode session.start 长度限制"~~（实测调整即可）
- ~~"重启会话切换 checkpoint"~~（不需要）

---

## 十三、实施清单（10 步，约 700 行）

按顺序产出代码：

1. **`harness-opencode/` 骨架**（README + 目录）
2. **快速 review HyperSpec 子文件**（`propose.md` / `apply.md` / `archive.md`），确认无 Claude Code 特有依赖
3. **`plugins/harness-role/`**（~80 行 TS + package.json）
4. **`plugins/harness-guard/`**（~150 行 TS + permissions.yaml）
5. **`plugins/harness-checks/`**（~60 行 TS）
6. **`agents-frontmatter/*.md`**（7 × ~15 行 frontmatter）
7. **`config/opencode.json.template`**
8. **`init-for-opencode.sh`**（~250 行 bash）
9. **`uninstall-for-opencode.sh`**（~80 行 bash）
10. **`verify-opencode-adapter.sh`**（10 个测试用例，~150 行）

**预计总代码量**：约 700 行（TS ~290 + bash ~480 + yaml ~60）

---

## 十四、参考来源

| 主题 | 链接 |
|------|------|
| HyperSpec SKILL.md（实际样本） | `E:\IdeaProjects\sunny-qms\sunny-qms-service\.claude\skills\hyperspec\SKILL.md` |
| Harness V2 架构文档 | `E:\claude\Harness V2 架构设计文档2.md` |
| opencode Plugins 官方 | [opencode.ai/docs/plugins](https://opencode.ai/docs/plugins/) |
| opencode Permissions | [opencode.ai/docs/permissions](https://opencode.ai/docs/permissions/) |
| opencode Agents | [opencode.ai/docs/agents](https://opencode.ai/docs/agents/) |
| opencode SDK | [opencode.ai/docs/sdk](https://opencode.ai/docs/sdk/) |
| 粒度权限 issue（已知缺陷） | [github.com/anomalyco/opencode/issues/17607](https://github.com/anomalyco/opencode/issues/17607) |

---

## 十五、下一步

设计已基于真实机制。建议：

1. **先做步骤 2**（review HyperSpec 子文件，15 分钟）——这是唯一的不确定点
2. 确认无依赖后，按步骤 3–10 顺序产出代码
3. 代码产出后跑 10 个测试用例验证

确认后我可以开始动手实施。
