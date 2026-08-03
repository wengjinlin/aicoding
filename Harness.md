# Harness 最佳实践：OpenSpec + Claude Code 实战方法手册

> 项目：sunny-mdm（Sunny MDM 主数据管理服务）
> 定位：基于 Spring Cloud 的主数据管理微服务，提供物料主数据、视图、变体等管理能力
>
> **本项目特有的入口与反直觉点**（与本手册通用规则不冲突，但项目级约定优先）：
>
> - 📖 项目文档总入口：[`docs/index.md`](docs/index.md)（5 分钟看完，再开始任何变更）
> - ⚠️ 隐性业务约定（必看）：[`docs/architecture/implicit-contracts.md`](docs/architecture/implicit-contracts.md) —— `cStaff` ≠ `cCreateUser`、`@Authignore` 注释放行、DTO 单一类模式、**项目当前无单元测试** 等 10+ 个反直觉点
> - 🔧 项目特有技术事实：[`docs/architecture/index.md`](docs/architecture/index.md) —— 25 个业务模块、5 个 ADR、Nacos/Redis 集群、已知技术债

核心理念：不是"让 AI 多写代码"，而是"把 AI 放进可控、可审计、可复用的工程流程里"

适合项目：有历史包袱的业务系统、增量改造需求、口头约定多、想把 AI 编码变成流程能力

---

## 一、核心原则（4条）

| 原则 | 说明 | 举例 |
|------|------|------|
| OpenSpec 管变更生命周期 | 用 /opsx:propose → /opsx:apply → /opsx:verify → /opsx:archive 管住需求从提出到归档的全过程 | 没有 change 就不允许开始开发 |
| AGENTS.md 只当地图，不当百科全书 | 告诉 AI"先看什么、按什么流程做"；真正的项目知识放 docs/ | AGENTS.md 越来越长 = 知识没有被正确拆分到 docs |
| 硬约束靠 permissions + hooks | 规则写文档只是"软约束"；真正能拦住危险动作的，是权限和 hook | 高风险目录直接 deny，不只靠提示词 |
| 团队专用动作放 skills 和 subagents | review 摘要、Spring 分层审查、SQL 风险审查 → 变成可重复调用的能力 | 每个 change 都可以重复调用 |

一句话总结：需求先工件化，知识先显性化，执行先加护栏，评审与验证必须分离。

---

## 二、仓库组织结构

```
sunny-mdm/
├─ Harness.md                    # 通用规则（导航入口）
├─ AGENTS.md                     # AI 协作入口
├─ CLAUDE.md                     # Claude 系统提示词
├─ REVIEW.md                     # 只读评审标准
│
├─ docs/                         # 🔥 项目知识库（真正的知识放这里）
│   ├─ index.md                  # 🔥 项目文档总入口（必读）
│   ├─ architecture/
│   │   ├─ index.md              # 项目架构总览（25 业务模块 + 5 ADR + 已知技术债）
│   │   └─ implicit-contracts.md # 🔥 隐性业务约定 / 项目坑点（10+ 反直觉点）
│   ├─ product/
│   │   └─ index.md              # 产品规则（业务域、术语表、状态机）
│   ├─ standards/
│   │   ├─ testing.md            # 测试规范（项目当前无 src/test/）
│   │   ├─ database.md           # 数据库与 SQL 规范
│   │   └─ api.md                # API 设计规范（XxxDTO 单一类模式）
│   ├─ database/                 # 🔥 由 db-schema-export 自动生成
│   │   ├─ index.md              # 表结构总览
│   │   └─ tables/<域>.md        # 字段详情
│   └─ help/                     # 平台能力使用指南（PO / S3 / Kafka / 锁 / OA / 导入导出）
│
├─ openspec/                     # OpenSpec 执行目录
│   ├─ changes/                  # 当前正在执行的 change
│   │   ├─ proposal.md           # 需求实现提案
│   │   ├─ design.md             # 执行方案
│   │   └─ tasks.md              # 拆解的执行步骤
│   └─ archive/                  # 归档文件
│
└─ .claude/                      # Claude 项目级配置
    ├─ settings.local.json       # 🔥 项目级权限设置
    ├─ skills/                   # 🔥 项目级 Skills（db-schema-export 等）
    ├─ agents/                   # 只读评审代理（reviewer）
    └─ hooks/                    # 🔥 Hook（guard_write / ensure_change_context / run_checks）
```

职责分层：
- **openspec/**：管理"这次改什么"
- **docs/**：管理"这个项目本来是怎么工作的"
- **AGENTS.md / CLAUDE.md / REVIEW.md**：管理"AI 进入仓库后应该怎么做"
- **.claude/settings.json + hooks**：管理"哪些事不能做、哪些检查必须跑"
- **skills / agents**：管理"团队专用的审查动作"

---

## 三、标准工作流（8步）

### 第0步：初始化仓库

通过 `openspec init --tools claude` 生成基础目录，再补齐：
- AGENTS.md、CLAUDE.md、REVIEW.md
- docs/
- .claude/settings.local.json
- .claude/hooks/
- .claude/skills/
- .claude/agents/

目标：先把 change 生命周期、项目知识入口、权限和 hook 的承载位置搭好

### 第1步：创建 change

执行 `/opsx:propose`，让需求先变成工件

### 第2步：人工审 proposal / design / tasks

重点检查：
- 边界是不是对的
- 是否遗漏隐性约定
- 是否把多个问题错误混成一个 change
- tasks.md 是否足够可执行

### 第3步：必要时废弃 change 重来

如果 proposal 拆错，不要勉强修补。直接重开新的 change 往往更省成本。

经验：第一版 proposal 往往只是草案，不能盲目执行

### 第4步：执行 /opsx:apply

基于已确认的工件实施代码变更

重点：
- 只做 tasks.md 范围内的事
- 不允许自行扩需求
- 每完成一个里程碑就跑检查

### 第5步：跑专项审查（分开执行）

依次执行：
- `/prepare-review` — 生成 PR 前摘要
- `spring-architecture-review` — Spring 分层架构审计（Java 项目）
- `sql-risk-review` — 数据层和 SQL 风险审计
- `python-fastapi-review` — Python 项目架构审查
- `reviewer (agent)` — 只读审计

关键：verify、review、架构审查、SQL 审查不是一回事，分开编排更清晰、更可控

### 第6步：执行 /opsx:verify

确认实现是否和 OpenSpec change 对齐

注意：verify 不是代码评审，也不是架构评审，它只负责检查实现与 change 工件是否一致

### 第7步：归档

执行 `/opsx:archive`，结束当前 change

---

## 四、OpenSpec 各阶段职责

| 阶段 | 职责 | 产出 |
|------|------|------|
| /opsx:propose | 把需求拆成一个 change | proposal.md、design.md、tasks.md |
| /opsx:apply | 根据 design 和 tasks 实施代码改动 | 代码变更 |
| /opsx:verify | 核对实现有没有和 OpenSpec 工件对上 | 验证报告 |
| /opsx:archive | 把当前 change 归档 | 归档文件 |

重要经验：
- 第一版 proposal 往往不靠谱，不要急着执行
- 如果 proposal 拆错了，宁可废弃当前 change，重新生成新的，也不要硬着头皮继续做

---

## 五、评审与验证必须分离

| 动作 | 职责 | 不是 |
|------|------|------|
| /opsx:verify | 检查"实现有没有和 OpenSpec 工件对上" | 不是代码评审，不是架构评审 |
| /prepare-review | 整理"这次到底改了什么，方便人 review" | 不是实现检查 |
| spring-architecture-review | 检查"Spring 分层有没有乱" | 不是业务逻辑评审 |
| sql-risk-review | 检查"SQL 有没有事故味" | 不是功能验证 |
| reviewer 子代理 | 做一轮独立、只读、偏代码审查视角的检查 | 不是 verify |

分开的好处：
1. 每种审查都有明确目标，不会互相覆盖又互相遗漏
2. 出问题时更容易定位，到底是 proposal 有问题、实现有问题，还是架构/SQL 有风险

---

## 六、硬护栏配置

### 高风险目录（默认禁止修改）

| 目录 | 风险 |
|------|------|
| `src/main/resources/application*.yml` | 配置错误影响全局 |
| `src/main/resources/bootstrap*.yml` | 启动配置 |
| `src/main/resources/db/` | 数据库脚本 |
| `sql/` | SQL 脚本 |
| `deploy/` | 部署配置 |
| `infra/` | 基础设施 |
| `secrets/` | 敏感信息 |
|  | 用户补充 |

保护方式：
- `permissions.deny` 直接禁止
- `guard_write.py` 再做一层路径校验

### Bash 命令分层控制

**允许**：`mvn test`、`mvn -q -DskipTests compile`、`mvn -DskipTests package`、`git status`、`git diff`、构建工具路径相关命令

**禁止**：`git push`、`kubectl`、`terraform`、`helm`、`rm -rf`

---

## 七、Hooks 不只做拦截，还要做自动检查

| 时机 | Hook | 动作 |
|------|------|------|
| 写入前 | guard_write.py | 拦截受保护路径写入 |
| 命令前 | ensure_change_context.py | 检查当前是否存在 OpenSpec change；没有 change 时对高风险 Bash 动作直接 ask |
| 写入后 | run_checks.sh | 自动执行编译/单元测试/打包检查；文档类变更可跳过重检查 |

关键点：让"检查会不会跑"不再依赖模型自觉，而变成流程自动发生

---

## 八、高风险坑点

| 坑点 | 描述 | 保护措施 |
|------|------|----------|
| Controller 写业务逻辑 | 最常见的脏问题 | 在 CLAUDE.md、REVIEW.md、reviewer、spring-architecture-review 里同时卡住 |
| 直接改 SQL/配置/数据库脚本 | 这种改动往往"本地能跑，线上出事" | permissions.deny + guard_write.py + database.md + sql-risk-review 多层保护 |
| Service 过胖，职责混乱 | 很容易在 AI 连续补代码时越滚越大 | reviewer 和架构审查能力持续盯住 |
| 测试只跑 happy path | 很多项目的通病 | testing.md 和 review 摘要里明确说明跑了哪些测试、哪些没测 |
| 批量更新没有 where 限制 | 这类问题不是 bug，而是事故预告 | 数据库规范和 SQL 风险审查里必须作为显式检查项 |

---

## 九、把"隐性约定"单独文档化

对真实业务项目来说，最危险的通常不是显式规则，而是那些"大家都知道，但没人写下来"的东西。

典型隐性约定举例：
- status = null 和 status = 0 在历史语义上并不等价
- 单元详情接口里，前端依赖 contentResponse 做回显

最佳实践：
1. 所有容易导致"改完能跑、联调出错"的口头约定，单独沉淀到 `docs/architecture/implicit-contracts.md`
2. OpenSpec 在 design.md 阶段就显式检查这些约定
3. reviewer / verify 阶段也把这些约定作为对齐依据

经验：这一步做得好不好，几乎直接决定 AI 产出的可落地程度

---

## 十、Skill 和 Subagent 只做团队专用能力

不适合硬塞进主提示词的能力：
- 生成 PR 前的 review 摘要
- 检查 Spring Boot 分层架构
- 检查 SQL 风险
- 做一轮只读视角的 reviewer 审计

适合沉淀为：
- `.claude/skills/`
- `.claude/agents/`

好处：
1. 可复用：以后每个 change 都可以重复调用
2. 可组合：不同类型的需求可以只调用需要的能力
3. 可演进：团队后续可以持续补充自己的审查能力，而不必频繁改系统提示词

总结：主流程负责通用约束，skills / agents 负责团队私有经验

---

## 十一、分阶段落地路径

### 第一阶段：最小可用版

先上这几个：
- OpenSpec
- AGENTS.md + CLAUDE.md + REVIEW.md
- docs/architecture/implicit-contracts.md
- reviewer 子代理

目标：先把"变更工件化"和"隐性约定显性化"跑通

### 第二阶段：补硬护栏

再加：
- permissions 权限配置
- guard_write.py + ensure_change_context.py
- 自动编译/测试/打包检查

目标：让高风险动作可控

### 第三阶段：补团队专用能力

最后再加：
- prepare-review
- spring-architecture-review / python-fastapi-review
- sql-risk-review
- 更多团队私有 skills / agents

目标：让流程真正变成可复用的工程能力

---

## 十二、实战经验（3条血泪教训）

1. **第一版 proposal 通常只是草案**
   AI 很容易先产出一个"结构看起来合理、业务边界其实不对"的 proposal
   教训：proposal 阶段的人审，绝对不能省

2. **design 阶段修正比 apply 后返工便宜得多**
   一旦进了 apply，错误就开始变成代码、测试和联调成本
   教训：最值得花时间的地方，其实是 design 阶段

3. **change 边界不清时，宁可拆成多个 change**
   如果模型始终无法稳定理解某块逻辑，通常不是因为它"再多想一轮就会懂"，而是因为当前 change 边界定义得不够好
   教训：把复杂问题拆开，先让 change 边界变清晰

---

## 十三、检查清单

### 仓库层
- ☐ 有 AGENTS.md
- ☐ 有 CLAUDE.md
- ☐ 有 REVIEW.md
- ☐ 有 docs/architecture/implicit-contracts.md
- ☐ 有 openspec/changes/ 目录
- ☐ 有 .claude/settings.json
- ☐ 有 hooks / skills / agents

### 流程层
- ☐ 没有 change 时，不允许直接开始开发
- ☐ proposal / design / tasks 经人工审计
- ☐ apply 后自动跑检查
- ☐ verify 独立执行
- ☐ change 完成后 archive

### 风险层
- ☐ 高风险目录已 deny
- ☐ SQL / Mapper 有专项风险检查
- ☐ 测试缺口被显式说明
- ☐ Spring 分层有独立审查
- ☐ 隐性约定在 docs 中显性记录
