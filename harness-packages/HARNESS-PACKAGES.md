# Harness V2 包总览

> 版本：1.0 | 更新日期：2026-07-17
> 定位：团队成员的"快速入口"——告诉你在新项目里怎么快速装上 Harness

---

## 一、两个包，一张图看懂

```
┌──────────────────────────────────────────────────────────────┐
│                    Harness V2 完整架构                         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  包 A: harness-infra (必装)                              │  │
│  │  ─────────────────────────────                          │  │
│  │  • L1 OpenSpec     规范驱动 (proposal→specs→design→tasks)│  │
│  │  • L2 Superpowers  TDD 纪律 (红绿重构)                   │  │
│  │  • L3 双轨审查     quick-review / gstack 9 关            │  │
│  │  • L4 ECC 领域技能 Spring/JPA/API 等                     │  │
│  │  • L5 OMC MCP      LSP/AST 工具精度                      │  │
│  │  • L6 ECC 本能     跨会话学习                            │  │
│  │  • L7 HyperSpec    ★ 全自动编排 (12 checkpoint)          │  │
│  │  • 安全保护层      Hooks (guard_write / run_checks)      │  │
│  │  • 模型路由层      haiku/sonnet/opus 自动选择            │  │
│  └────────────────────────────────────────────────────────┘  │
│                            ▲                                 │
│                            │ 装在 infra 之上                  │
│                            ▼                                 │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  包 B: harness-agents (可选)                             │  │
│  │  ─────────────────────────────                          │  │
│  │  • PM Agent         业务需求分析                         │  │
│  │  • Architect Agent  技术方案设计                         │  │
│  │  • Tech Lead Agent  任务拆解                             │  │
│  │  • Developer Agent  TDD 编码                             │  │
│  │  • Reviewer Agent   独立审查（严格只读）                 │  │
│  │  • Tester Agent     集成 / 验收测试                      │  │
│  │  • DevOps Agent     发布归档                             │  │
│  │  • 角色切换 Hook    apply-role.sh                        │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

---

## 二、核心结论

### Q：HyperSpec 全自动能力是哪个包提供的？

**A：包 A（harness-infra）**。装完包 A，`/hyperspec` 命令立即可用。

### Q：不装包 B 能用吗？

**A：能**。包 A 自带 HyperSpec 全自动编排。包 B 只是让流程更"角色化"分工（PM/Architect/Developer 各司其职）。

### Q：装了包 B 之后还能 `/hyperspec` 吗？

**A：能，而且更强**。包 B 的角色 prompt 被 HyperSpec 自动加载，每个 checkpoint 切换到对应角色。

---

## 三、团队成员快速开始

### 场景 1：我是新成员，第一次在项目里用 Harness

```bash
# 1. 克隆项目
git clone your-project.git
cd your-project

# 2. 装基础建设（必装）
bash harness-infra/init-harness-infra.sh

# 3. 装 Agent 角色（推荐装，但可选）
bash harness-agents/install-harness-agents.sh

# 4. 验证
claude
> /hyperspec --help

# 5. 试跑
> /hyperspec propose "你的第一个需求"
```

**预计耗时**：基础建设 15-30 分钟，Agent 角色 5 分钟。

### 场景 2：我只想用 HyperSpec 全自动，不需要角色分工

```bash
bash harness-infra/init-harness-infra.sh
# 跳过 harness-agents
```

**适合**：小项目、个人开发、快速验证。

### 场景 3：我已经在用 harness-infra，现在想加上角色分工

```bash
bash harness-agents/install-harness-agents.sh
# 立即生效，下次 /hyperspec 会启用角色切换
```

**适合**：团队规模扩大、需要分工、对审查独立性有要求。

### 场景 4：我想卸载角色包，但保留基础设施

```bash
bash harness-agents/uninstall-harness-agents.sh
# HyperSpec 仍可运行（退化为无角色模式）
```

### 场景 5：我想完全移除 Harness

```bash
bash harness-infra/uninstall-harness-infra.sh
# 移除所有 Harness 痕迹（业务文档保留）
```

---

## 四、包之间的依赖关系

```
harness-infra (独立可运行)
       ▲
       │ 依赖
       │
harness-agents (依赖 infra，不可独立运行)
```

**强制约束**：
- ❌ 不能未装 infra 就装 agents（脚本会检测并退出）
- ❌ 不能先卸 infra 再留 agents（agents 会失效）
- ✅ 可以只装 infra 不装 agents
- ✅ 可以先装 infra，后装 agents
- ✅ 可以随时卸载 agents，infra 不受影响

---

## 五、能力对照表

| 能力 | 裸 Claude Code | + infra | + infra + agents |
|------|:------------:|:------:|:----------------:|
| 规范驱动（OpenSpec） | ❌ | ✅ | ✅ |
| TDD 强约束 | ❌ | ✅ | ✅ |
| 双轨审查 | ❌ | ✅ | ✅ |
| 领域知识激活 | ❌ | ✅ | ✅ |
| LSP/AST 工具精度 | ❌ | ✅ | ✅ |
| 跨会话学习 | ❌ | ✅ | ✅ |
| **HyperSpec 全自动** | ❌ | **✅** | **✅** |
| 安全保护 Hooks | ❌ | ✅ | ✅ |
| **7 角色分工** | ❌ | ❌ | **✅** |
| **Reviewer 独立审查** | ❌ | ❌ | **✅** |
| **上下文隔离** | ❌ | ❌ | **✅** |

---

## 六、目录结构总览

```
your-project/
├── harness-infra/                    # 包 A 源码（可 git submodule 引入）
│   ├── README.md
│   ├── init-harness-infra.sh         # ★ 一键安装脚本
│   ├── uninstall-harness-infra.sh
│   ├── hooks/                        # Hooks 脚本源
│   │   ├── guard_write.py
│   │   ├── ensure_change_context.py
│   │   └── run_checks.sh
│   ├── skills/                       # 自建 skill 源
│   │   └── quick-review/
│   ├── templates/                    # AGENTS.md / CLAUDE.md 模板
│   └── config/                       # openspec/config.yaml 模板
│
├── harness-agents/                   # 包 B 源码（可 git submodule 引入）
│   ├── README.md
│   ├── install-harness-agents.sh     # ★ 一键安装脚本
│   ├── uninstall-harness-agents.sh
│   ├── agents/                       # 7 个角色 prompt 源
│   │   ├── pm.md
│   │   ├── architect.md
│   │   ├── tech-lead.md
│   │   ├── developer.md
│   │   ├── reviewer.md
│   │   ├── tester.md
│   │   └── devops.md
│   ├── team-roles/                   # 配置源
│   │   ├── permissions.json
│   │   ├── checkpoint-map.yaml
│   │   └── hyperspec-extend.yaml
│   └── hooks/
│       └── apply-role.sh
│
├── HARNESS-PACKAGES.md               # 本文档
│
# 以下是 init 脚本运行后生成的目录
├── .claude/
├── openspec/
├── superpowers/
├── docs/
├── AGENTS.md
├── CLAUDE.md
├── REVIEW.md
└── .hyperspec-state.yaml
```

---

## 七、版本与升级策略

| 升级对象 | 命令 | 影响 |
|---------|------|------|
| 包 A 脚本 | 替换 `harness-infra/` 目录，重跑 init | 备份现有配置，增量合并 |
| 包 B 脚本 | 替换 `harness-agents/` 目录，重跑 install | 备份角色 prompt，提示 diff |
| npm 全局工具 | `npm update -g` | 不影响项目配置 |
| 项目级 skills | `npx skills update` | 仅更新 skill 内容 |
| HyperSpec 状态 | 自动迁移 | `.hyperspec-state.yaml` 升级时自动转换 |

**升级原则**：
- ✅ 团队积累的本能知识（`.claude/instincts/`）永不丢失
- ✅ 历史变更记录（`openspec/archive/`）永不丢失
- ✅ 业务文档（`docs/architecture`、`docs/database`）永不丢失
- ⚠️ 自定义角色 prompt 升级时会 diff，由人工审核合并

---

## 八、求助与反馈

| 问题类型 | 联系方式 |
|---------|---------|
| 安装失败 | 附上 `init-*.sh --verbose` 输出 |
| 角色切换异常 | 附上 `.claude/logs/role-switch.log` |
| HyperSpec 状态错乱 | 附上 `.hyperspec-state.yaml` |
| 改进建议 | 提 issue 到 harness 仓库 |

---

## 九、相关文档

| 文档 | 作用 |
|------|------|
| `../Harness V2 架构设计文档2.md` | 完整架构总览 |
| `../Harness V2 落地实操手册2-1.md` | 基础设施层落地（对应包 A） |
| `../Harness V2 落地实操手册2-2.md` | Agent 角色层落地（对应包 B） |
| `harness-infra/README.md` | 包 A 详细说明 |
| `harness-agents/README.md` | 包 B 详细说明 |
