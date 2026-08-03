# harness-infra — Harness V2 基础建设包

> 版本：1.0 | 适用架构：《Harness V2 架构设计文档2.md》
> 定位：把 Harness 7 层架构 + HyperSpec 编排层打包成"一键安装"的基础设施
> 适用对象：Spring Boot / Java 后端项目（其他技术栈可参照骨架改造）

---

## 一、这个包是什么

`harness-infra` 是 Harness V2 架构的**基础建设包**，包含除 Agent 角色外的所有 7 层能力。

团队成员只需要在项目根目录执行一条命令，就能把整套 Harness 基础设施搭建好，立即获得：

- ✅ **规范驱动开发**（OpenSpec：proposal → specs → design → tasks 强制顺序）
- ✅ **TDD 纪律**（Superpowers：红绿重构 5 步循环）
- ✅ **双轨审查**（quick-review 3 关 / gstack 9 关自动路由）
- ✅ **领域知识**（Spring Boot / JPA / API 等领域技能自动激活）
- ✅ **工具精度**（LSP / AST 结构化代码分析）
- ✅ **持续学习**（跨会话积累项目本能）
- ✅ **HyperSpec 全自动编排**（12 checkpoint 状态机 + 断点恢复）
- ✅ **安全保护**（Hooks 拦截保护目录、强制变更上下文）

**关键**：本包**已包含 HyperSpec**。安装后 `/hyperspec` 命令立即可用，无需再装任何东西。

---

## 二、与 harness-agents 的关系

| 维度 | harness-infra（本包） | harness-agents（角色包） |
|------|---------------------|------------------------|
| 定位 | 基础设施（必装） | 增强配置（可选） |
| 含 HyperSpec | ✅ 是 | ❌ 否 |
| 含角色 prompt | ❌ 否 | ✅ 7 个角色 |
| 是否独立可用 | ✅ 是 | ❌ 否（依赖本包） |
| 安装顺序 | 第 1 步 | 第 2 步（可选） |
| 卸载影响 | 整套 Harness 失效 | 仅退化为无角色模式 |

**类比**：本包是"操作系统"，harness-agents 是"应用软件"。操作系统必装，应用按需。

---

## 三、前置条件

在安装本包前，请确认项目满足以下条件：

| 检查项 | 命令 | 期望结果 |
|-------|------|---------|
| Git 已初始化 | `git status` | 能输出当前分支 |
| Java 环境 | `java -version` | ≥ 1.8（推荐 JDK 17） |
| Maven 可用 | `mvn -v` | 任意版本 |
| Claude Code CLI | `claude --version` | ≥ 2.0 |
| Node.js | `node --version` | ≥ 18（用于 npm 安装 skills） |
| 项目可编译 | `mvn compile` | BUILD SUCCESS |

任一检查失败，请先解决再装本包。

---

## 四、安装方式

### 方式 1：本地脚本安装（推荐）

```bash
# 1. 把本包目录放到项目根（或 git submodule 引入）
cp -r /path/to/harness-infra ./harness-infra

# 2. 在项目根执行
cd your-project
bash harness-infra/init-harness-infra.sh

# 3. 验证
claude --version    # 启动 Claude Code，输入 /hyperspec 应能看到帮助
```

### 方式 2：远程一键安装

```bash
curl -fsSL https://your-internal-server/harness-infra/init-harness-infra.sh | bash
```

### 方式 3：Docker 化（团队规范统一）

```dockerfile
FROM your-base-image:latest
COPY harness-infra /opt/harness-infra
RUN /opt/harness-infra/init-harness-infra.sh /workspace
```

### 方式 4：命令行选项

```bash
./init-harness-infra.sh                 # 默认：保守模式（不覆盖任何已存在内容）
./init-harness-infra.sh --force         # 强制覆盖（自动备份到 .harness-backup-{date}/）
./init-harness-infra.sh --dry-run       # 预演，只打印决策，不写任何文件
./init-harness-infra.sh --verbose       # 详细日志（显示每步决策）
./init-harness-infra.sh --help          # 帮助
```

---

## 五、幂等性策略（默认保守模式）

脚本设计为**幂等可重入**——团队成员可以多次运行，不会破坏已有配置。这是默认行为；如需强制覆盖，加 `--force` 选项。

### 5.1 预检报告

脚本第一步先扫描系统状态，输出预检报告，让用户看到"会发生什么"再决定：

```
🔍 预检报告（运行模式：保守）
─────────────────────────────────────────────────────
✅ Claude Code CLI      v2.1.0   (≥ 期望 2.0，跳过)
✅ OpenSpec             v1.3.2   (≥ 期望 1.0，跳过)
⚠️ Superpowers skill    已存在   (跳过，--force 可重装)
⚠️ .claude/settings.local.json 已存在，将深度合并
🔴 AGENTS.md            非空     (跳过，请手动 review 模板)
✅ HyperSpec            未安装，将安装
─────────────────────────────────────────────────────
即将执行 4 项操作，跳过 3 项。继续？[y/N]
```

`--dry-run` 模式下只输出此报告，不写任何文件。

### 5.2 各组件已存在时的行为对照表

| 组件 | 默认（保守） | --force |
|------|------------|---------|
| **npm 全局工具** | 检测版本，已 ≥ 期望则跳过；落后则升级 | 强制升级 |
| **Claude Code CLI** | 检测 `claude --version`；**native installer 装的绝不覆盖** | 同左（仍不覆盖 native） |
| **`npx skills add`** | 检测 `.claude/skills/<name>/`，已存在则跳过 + 提示 | 备份后重新 add |
| **目录骨架** (`mkdir -p`) | 创建缺失的，不动已有的 | 同左 |
| **`.claude/settings.local.json`** | **深度合并**（保留用户键，追加脚本键） | 备份后覆盖 |
| **`.claude/hooks/*.sh`** | 直接覆盖（hooks 是标准件，统一版本） | 同左 |
| **`AGENTS.md` / `CLAUDE.md` / `REVIEW.md`** | 已存在且非空 → **跳过 + 提示**；空或不存在 → 写模板 | 备份后覆盖 |
| **`openspec/config.yaml`** | 已存在 → **跳过** + 提示缺失字段 | 备份后覆盖 |
| **`.hyperspec-state.yaml`** | **绝不覆盖**（运行时状态） | 备份后覆盖（极少需要） |
| **`.claude/instincts/`** | 不动（团队积累的本能知识） | 不动 |
| **`openspec/archive/`** | 不动（历史变更记录） | 不动 |

### 5.3 关键设计原则

1. **配置类文件深度合并**：`.claude/settings.local.json` 这类 JSON 配置，用 `jq` 做深合并，**保留用户键，追加脚本键**，冲突时优先用户值
2. **文档类文件尊重用户沉淀**：`AGENTS.md`/`CLAUDE.md`/`REVIEW.md` 一旦非空，绝不覆盖——脚本只生成模板，让用户手动 diff 合并
3. **运行时状态只备份不覆盖**：`.hyperspec-state.yaml`、`.claude/instincts/` 是运行产物，--force 也只备份不删除
4. **标准件统一版本**：`.claude/hooks/*.sh`、`.claude/commands/opsx/*` 这类是脚本包的"标准件"，每次运行都覆盖到统一版本，避免版本漂移
5. **native 安装的 Claude Code 不动**：脚本检测 `/usr/local/bin/claude` vs `~/.local/share/claude/native/`，识别 native 安装路径，绝不覆盖

### 5.4 备份策略（--force 时）

所有被覆盖的文件统一备份到 `.harness-backup-{YYYYMMDD-HHMMSS}/`：

```
.harness-backup-20260717-091500/
├── .claude/
│   ├── settings.local.json
│   └── hooks/
│       └── guard_write.py
├── AGENTS.md
├── openspec/
│   └── config.yaml
└── backup-manifest.json        # 备份清单（含原文件 hash，可用于校验）
```

备份目录保留 30 天，可在脚本配置 `BACKUP_RETENTION_DAYS` 调整。

### 5.5 常见场景

| 场景 | 脚本行为 |
|------|---------|
| 全新项目，从未装过 Harness | 全量安装，无需 --force |
| 装过旧版 Harness，想升级到 1.0 | 直接运行，已存在的组件跳过，缺失组件补齐 |
| 装了一半中断了 | 直接重跑，已成功的步骤跳过，未完成的继续 |
| 团队成员自己改过 `.claude/settings.local.json` | 默认深度合并，团队配置保留 |
| 团队成员自己改过 `AGENTS.md` | 默认跳过，提示"请手动 review 模板" |
| 想强制覆盖某个组件 | `--force` 全量覆盖，或编辑脚本 BACKUP_RETENTION_DAYS |

---

## 六、安装脚本将做的事

`init-harness-infra.sh` 执行时会：

### 步骤 1：全局工具安装（npm 全局）

| 工具 | 用途 |
|------|------|
| `@anthropic-ai/claude-code` | Claude Code CLI |
| `@fission-ai/openspec` | L1 规范层命令 |

### 步骤 2：项目级 skills 安装（写入 `.claude/skills/`）

| Skill | 层级 | 来源 |
|-------|-----|------|
| superpowers | L2 纪律层 | `obra/superpowers` |
| gstack | L3 审查层（9 关） | `garrytan/gstack` |
| HyperSpec | L7 编排层 | `wind7rui/HyperSpec` |
| ECC 领域技能（10+） | L4 领域层 | `affaan-m/ecc` |
| quick-review | L3 审查层（3 关） | 本包内置 |

### 步骤 3：MCP 工具注册

| MCP | 用途 |
|-----|------|
| oh-my-claudecode (OMC) | L5 LSP/AST 工具 |

注册到 `.claude/settings.local.json`。

### 步骤 4：目录骨架创建

```
your-project/
├── .claude/
│   ├── settings.local.json     # 权限 + Hooks + MCP
│   ├── hooks/
│   │   ├── guard_write.py
│   │   ├── ensure_change_context.py
│   │   └── run_checks.sh
│   ├── commands/opsx/          # OpenSpec 命令组
│   ├── skills/                 # L4 领域技能
│   └── instincts/              # L6 本能（运行时生成）
├── openspec/
│   ├── config.yaml             # 模型路由
│   ├── changes/
│   └── archive/
├── superpowers/plans/          # TDD 计划
├── docs/{architecture,database,standards,harness,help}/
├── AGENTS.md
├── CLAUDE.md
├── REVIEW.md
└── .hyperspec-state.yaml       # HyperSpec 运行时状态
```

### 步骤 5：项目文档骨架

生成 `AGENTS.md`、`CLAUDE.md`、`REVIEW.md` 模板，由 Claude Code 在首次会话时根据项目实际情况自动补全。

### 步骤 6：HyperSpec 状态机初始化

写入空的 `.hyperspec-state.yaml`，等待第一次 `/hyperspec` 调用。

---

## 七、安装后的能力清单

安装完成后，开发者可以在 Claude Code 内使用以下命令：

| 命令 | 来源层 | 作用 |
|------|-------|------|
| `/opsx:explore` | L1 | 反问澄清需求 |
| `/opsx:propose` | L1 | 生成 4 工件 |
| `/opsx:apply` | L1 | 按 tasks 逐条执行 |
| `/opsx:archive` | L1 | 归档变更 |
| `/quick-review` | L3 | 轻量 3 关审查 |
| `/full-review` | L3 | 完整 9 关审查 |
| `/superpowers:*` | L2 | TDD / 系统调试等 |
| `/hyperspec` | **L7** | **★ 全自动 12 checkpoint 流程** |
| `/instinct-export` | L6 | 导出项目本能 |

**核心**：`/hyperspec` 一条命令即可启动完整全自动流程（propose → apply → archive），无需人工干预 checkpoint 推进。

---

## 八、验证安装

```bash
# 1. 目录结构检查
ls .claude/{hooks,commands,skills,instincts}     # 应有 4 个子目录
ls openspec/                                       # 应有 config.yaml, changes/, archive/
ls .hyperspec-state.yaml                           # 应存在

# 2. Claude Code 内验证
claude
> /opsx:explore --help                             # 应正常显示
> /hyperspec --help                                # 应正常显示
> /quick-review --help                             # 应正常显示

# 3. 试跑一个小需求
> /hyperspec propose "为物料主数据新增'安全库存'字段"
# 预期：自动跑完 propose → apply → archive，约 5 分钟
```

---

## 九、卸载方式

```bash
bash harness-infra/uninstall-harness-infra.sh
```

卸载脚本会：
- ✅ 移除 `.claude/`、`openspec/`、`superpowers/`、`docs/harness/`、`.hyperspec-state.yaml`
- ✅ 移除项目根的 `AGENTS.md`、`CLAUDE.md`、`REVIEW.md`（备份到 `.harness-backup-{date}/`）
- ⚠️ **保留** `docs/architecture`、`docs/database`、`docs/standards`（业务文档）
- ⚠️ **不卸载** npm 全局工具（避免影响其他项目）

---

## 十、升级策略

| 升级对象 | 方式 | 频率 |
|---------|------|------|
| npm 全局工具 | `npm update -g` | 按需 |
| 项目级 skills | `npx skills update` | 按需 |
| HyperSpec 状态机 | `.hyperspec-state.yaml` 自动迁移 | HyperSpec 启动时 |
| 本包脚本 | 替换 `harness-infra/` 目录后重跑 init | 大版本发布时 |

**关键**：升级不会清除 `.claude/instincts/`（团队积累的本能知识）和 `openspec/archive/`（历史变更记录）。

---

## 十一、常见问题

### Q1：安装失败怎么办？

```bash
# 查看详细日志
bash harness-infra/init-harness-infra.sh --verbose

# 失败后可重跑（脚本幂等，重复执行不会出问题）
bash harness-infra/init-harness-infra.sh --force
```

### Q2：项目不是 Spring Boot 能用吗？

可以，但 L4 领域技能（springboot-patterns、jpa-patterns 等）不会自动激活。其他层（L1/L2/L3/L5/L6/L7）技术栈无关。

### Q3：装完之后，能不能不装 harness-agents 就用？

可以。本包自带 HyperSpec 全自动编排，`/hyperspec` 命令立即可用。装 harness-agents 只是让流程更"角色化"（PM/Architect/Developer 分工），不影响全自动能力。

### Q4：HyperSpec 状态文件丢了怎么办？

HyperSpec 设计原则是"实际文件状态是 ground truth"。删除 `.hyperspec-state.yaml` 后再次运行 `/hyperspec`，它会根据 `openspec/changes/` 下的实际工件重新推断当前 checkpoint。

### Q5：团队成员的 IDE 配置会受影响吗？

不会。本包只影响 Claude Code 行为，不修改 IntelliJ IDEA / VS Code 等任何 IDE 配置。

---

## 十二、版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2026-07-17 | 首版，对应《Harness V2 架构设计文档2.md》 |

---

## 十三、相关文档

- 总览：`../../Harness V2 架构设计文档2.md`
- 落地手册：`../../Harness V2 落地实操手册2-1.md`
- Agent 角色包：`../harness-agents/README.md`
- 安装总览：`../HARNESS-PACKAGES.md`
