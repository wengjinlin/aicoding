Harness 使用指南
本文档面向项目成员，介绍如何使用当前 harness 架构完成日常开发工作。 AI 协作入口参见 AGENTS.md，完整工具链集成参见 integration.md。

一、架构总览
当前 harness 由 4 层工具组成，各司其职：

┌──────────────────────────────────────────────────────────┐
│                    你的日常工作流                           │
└────┬──────────────────────────────────────────────────┬───┘
     │                                                  │
     ▼                                                  ▼
┌──────────────┐                              ┌─────────────────┐
│  OpenSpec    │                              │  增强层          │
│  规范层       │◄──── HyperSpec 编排  ────────►│  Superpowers    │
│              │      (12 checkpoint)         │  (TDD/子代理)    │
│ /opsx:*      │                              │  gstack         │
│ proposal →   │                              │  (多角色审查)     │
│ specs →      │                              │                 │
│ design →     │                              │                 │
│ tasks        │                              │                 │
└──────────────┘                              └─────────────────┘
层	工具	作用	必装？
规范层	OpenSpec	工件化需求管理（proposal / specs / design / tasks）	必装
纪律层	Superpowers	TDD 红绿重构、子代理自动开发、验证	必装
审查层	gstack	CEO / Eng / Design / QA 多角色代码审查	必装
编排层	HyperSpec	衔接上述三层，维护 12 步 checkpoint 状态机	推荐
项目核心约定
开始工作前必须了解：

约定	说明	详见
DTO 单一类	不分 Param/Query/VO，用 XxxDTO 统一承担	docs/standards/api.md
Entity 禁用 Lombok	手写 getter/setter	CLAUDE.md
Service 必须继承 BaseServiceManager	extends BaseServiceManager	CLAUDE.md
平台包优先	用 sunny-base-*，不引重叠依赖	docs/help/index.md
无 src/test/	历史代码无测试；新代码（通过 harness 开发）必须测试	docs/standards/testing.md
隐性约定	修改状态字段/接口返回前必查	docs/architecture/implicit-contracts.md
二、工具安装状态检查
当前项目已安装的工具：

工具	安装位置	类型
OpenSpec	npm 全局	CLI 工具
Superpowers	~/.claude/plugins/ (user scope)	Claude Code 插件
gstack	.claude/skills/gstack/	项目级 skill
HyperSpec	.claude/skills/hyperspec/	项目级 skill
快速验证
# 1. OpenSpec
openspec list

# 2. Superpowers（在 Claude Code 对话中）
/superpowers:using-superpowers

# 3. gstack / HyperSpec（在 Claude Code 对话中）
# 这两个会自动作为 skill 被识别，出现在可用 skills 列表中
三、两条开发路径
harness 提供两条互斥的开发路径，根据需求复杂度和个人偏好选择：

3.0 路径选择
手动路径	HyperSpec 路径
入口	逐个调用 /opsx:* 命令	一条 /hyperspec 命令
谁编排流程	你自己	HyperSpec 自动编排
Superpowers 怎么用	隐式生效 + 按需显式调用	HyperSpec 自动调用
自动 commit	无（你手动 commit）	有（每完成一个 task 自动 commit）
断点恢复	无	有（12 checkpoint 状态机）
适合	小改动、需要精细控制每一步	中大需求、希望全自动
选择建议：

需求复杂度	推荐路径	理由
小改动（改字段、修 bug）	手动路径	只需 propose → apply → archive，开全自动太重
中等需求（新接口、新页面）	两条都行	手动路径可跳过不需要的审查关；HyperSpec 全自动
大需求（跨模块、多 Service）	HyperSpec 路径	自动编排 TDD + 子代理 + 审查，断点可恢复
不要混用两条路径。同一个 change 要么全程手动，要么全程 HyperSpec。混用会导致状态文件与实际不一致。

3.1 手动路径（逐命令）
手动路径下，你逐个调用 /opsx:* 命令，Superpowers 以两种方式参与：

隐式（always_active）：test-driven-development 和 verification-before-completion 两个 skill 始终生效，AI 写代码时自动遵循 TDD，标记完成前自动验证
显式（on-demand）：你可以按需调用 /superpowers:* 命令
Phase 1：创建需求
/opsx:propose
AI 会引导你回答几个问题，然后自动生成 4 个工件：

工件	文件	作用
proposal	proposal.md	WHY — 为什么做
specs	specs/*.md	WHAT — 做什么
design	design.md	HOW — 怎么做
tasks	tasks.md	执行清单
工件创建顺序：proposal → specs → design → tasks（必须按序，不能跳步）

Phase 2：人工审核 + 规范层审查
步骤 1：人工审核（必做）

你必须审核以下内容：

proposal 边界是否正确（做什么 / 不做什么）
design 涉及的表名、接口、DTO 是否准确
tasks 粒度是否合理（每个 2-5 分钟）
如果边界不对，直接废弃重来比修修补补更快：

/opsx:explore        # 先反问澄清
/opsx:propose        # 重新生成
步骤 2：规范层审查（中大需求必做，小改动可跳过）

人工审核通过后、写代码之前，用 gstack 多角色审查确保需求和设计没问题：

gstack /office-hours              # AI 问 6 个灵魂拷问
gstack 会从 6 个维度追问你的需求：业务目标、并发场景、失败回滚、审计合规、跨服务影响、通知策略。回答后：

gstack /plan-ceo-review           # CEO 视角审查 proposal
什么时候跳过：小改动（改字段、修 bug）不需要这步。中等及以上需求建议跑。

步骤 3：任务拆细（中大需求必做）

/superpowers:writing-plans --input openspec/changes/<id>/tasks.md
将 tasks 拆细到 2-5 分钟粒度，生成 TDD 实现计划（保存到 superpowers/plans/）。

步骤 4：工程 + 设计审查（中大需求必做）

gstack /plan-eng-review           # 工程经理视角审查
gstack /plan-design-review        # 设计师视角审查（涉及 UI 时）
规范层审查的目的：写代码之前先把需求/design 的问题暴露出来，避免写完代码才发现方向错了。

Phase 3：实施
/opsx:apply
AI 按 tasks.md 逐条执行。此时 Superpowers 隐式生效：

test-driven-development（always_active）：AI 自动遵循 TDD 红绿重构
写失败测试 → 2. 确认失败 → 3. 写实现 → 4. 确认通过 → 5. 提交
verification-before-completion（always_active）：每个 task 完成前自动跑编译+测试验证
新代码必须 TDD。首次 Service 变更时自动建 src/test/ 骨架。旧代码修改可降级为手工验证。

如需子代理并行开发，可显式调用：

/superpowers:subagent-driven-development --tasks ... --spec ...
Phase 4：审查
按顺序跑 9 关审查流水线：

/opsx:verify                    # 1. 规范对齐
gstack /review                  # 2. 通用代码质量
/spring-architecture-review     # 3. Spring 分层
/sql-risk-review                # 4. SQL 风险
gstack /security-review         # 5. 安全审查
gstack /simplify                # 6. 简化重构
gstack /qa                      # 7. 真实测试
/prepare-review                 # 8. PR 摘要
/opsx:archive                   # 9. 归档
每关失败必须修完才能进下一关。

Phase 5：提交与归档
git add -A
git commit -m "feat(<change-id>): <title>"
归档由 /opsx:archive 完成，会把 change 移入 openspec/archive/ 并合并 specs。

手动路径的快捷方式
不是每个需求都要跑完整流程。根据复杂度裁剪：

需求复杂度	推荐步骤	跳过
小改动	propose → 人工审 → apply → prepare-review → archive	跳过规范层审查 + gstack 9 关
中等需求	propose → 人工审 → office-hours → writing-plans → apply → 第 1/3/4/8 关 → archive	跳过 CEO/Eng/Design 审查
大需求	propose → 人工审 → 规范层审查全部 → writing-plans → apply → 完整 9 关 → archive	不跳
3.2 HyperSpec 路径（全自动）
HyperSpec 路径只需一条命令，它会自动编排 OpenSpec + Superpowers + gstack 的全流程。

入口
/hyperspec
HyperSpec 做什么
HyperSpec 是纯编排层，不重写任何原生 skill 的功能，只负责：

项目感知 — 自动探测语言/框架/构建工具，生成 project_profile
状态检测 — 读写 .hyperspec-state.yaml，确定当前在哪个阶段
阶段路由 — 自动调用对应的原生 skill
Commit 纪律 — 每个 task 完成后自动 commit（不做 push）
三阶段流程
/hyperspec
│
├── propose 阶段
│   ├── 自动扫描项目 → 生成 project_profile
│   ├── 与你确认需求（一次只问一个问题）
│   ├── 调用 openspec-propose → 生成 proposal/specs/design/tasks
│   ├── 调用 writing-plans → 生成 TDD 实现计划（superpowers/plans/）
│   └── 【中大需求】gstack 规范层审查：
│       ├── gstack /office-hours        — 6 个灵魂拷问
│       ├── gstack /plan-ceo-review     — CEO 视角
│       ├── gstack /plan-eng-review     — 工程经理视角
│       └── gstack /plan-design-review  — 设计师视角（涉及 UI 时）
│
├── apply 阶段
│   ├── 根据复杂度自动选择执行模式：
│   │   ├── 完整模式（subagent-driven-development）— ≥6 task 或跨 ≥3 模块
│   │   └── 轻量模式（inline 执行）— ≤5 task 集中在 1-2 模块
│   ├── 每个 task：TDD 开发 → 编译检查 → 更新 checkbox → 自动 commit
│   ├── 调用 verification-before-completion → 全量验证
│   └── 调用 requesting-code-review → 全局代码审查
│
└── archive 阶段
    ├── 规格一致性验证（代码 vs specs/design/tasks 逐项对齐）
    ├── 调用 openspec-archive-change → 归档
    └── 分支收尾 + 清理状态文件
小改动自动跳过规范层审查：当 task ≤ 3 且集中在 1 个模块时，HyperSpec 自动跳过 gstack 审查，直接进入用户确认。task > 3 或涉及 ≥ 2 个模块时，规范层审查是强制的。

HyperSpec 的工具调用映射
HyperSpec 阶段	调用的 Skill	作用
propose	openspec-propose	生成 proposal/specs/design/tasks
propose	writing-plans（Superpowers）	把 tasks.md 拆细为 TDD 实现计划
propose	gstack /office-hours	6 个灵魂拷问（中大需求）
propose	gstack /plan-ceo-review	CEO 视角审查（中大需求）
propose	gstack /plan-eng-review	工程经理视角审查（中大需求）
propose	gstack /plan-design-review	设计师视角审查（涉及 UI）
apply	subagent-driven-development（Superpowers）	派子代理并行 TDD 开发
apply	verification-before-completion（Superpowers）	全量编译 + 测试验证
apply	requesting-code-review（Superpowers）	全局代码审查
archive	openspec-archive-change	归档变更
断点恢复
HyperSpec 维护 .hyperspec-state.yaml 中的 12 个 checkpoint：

profiler-done → requirements-confirmed → openspec-generated →
plan-generated → plan-generated-and-confirmed → task-N-complete →
verified → reviewed → apply-done → consistency-verified →
archived → done
如果中途断开（网络、关闭终端、AI 会话超时），重新运行 /hyperspec：

读取 .hyperspec-state.yaml 的当前 checkpoint
验证实际文件状态是否与 checkpoint 一致
路由到断点位置继续执行
原则：实际文件状态是 ground truth，状态文件只是缓存。两者冲突时以实际文件为准并修正状态文件。

HyperSpec 的自动 commit
HyperSpec 在 apply 阶段每完成一个 task 自动 commit：

commit message 格式：<类型>(<范围>): <task描述>
commit 前必须编译通过
全程不做 push（与项目 hooks 的 git push deny 规则一致）
原子性保证：先更新 checkbox + 状态文件，再 commit
与 Hooks 的兼容性
Hook	与 HyperSpec 的关系
ensure_change_context.py	HyperSpec propose 阶段第一步就创建 OpenSpec change 目录，后续 commit 时已检测到活跃 change → 放行
guard_write.py	HyperSpec 只写源码和 superpowers/plans/，不触碰受保护路径 → 放行
run_checks.sh	HyperSpec 自己管理编译检查，此 hook 也会在 Edit/Write 后触发 → 两次编译，结果一致
settings.local.json deny git push	HyperSpec 明确"不做 push" → 不冲突
四、常用命令速查
需求阶段
想做什么	命令
反问澄清需求	/opsx:explore
启动 change	/opsx:propose
单步推进下一个工件	/opsx:continue
一次生成全部工件	/opsx:ff
实施阶段
想做什么	命令
实施 change	/opsx:apply
系统化调试	/superpowers:systematic-debugging
拆细任务到 2-5 分钟	/superpowers:writing-plans
子代理自动 TDD 开发	/superpowers:subagent-driven-development
审查阶段
想做什么	命令
Spring 分层审查	/spring-architecture-review
SQL 风险审查	/sql-risk-review
生成 PR 摘要	/prepare-review
通用代码质量	gstack /review
安全审查	gstack /security-review
CEO 视角	gstack /plan-ceo-review
Eng 视角	gstack /plan-eng-review
归档
想做什么	命令
验证对齐	/opsx:verify
归档 change	/opsx:archive
批量归档	/opsx:bulk-archive
同步 specs	/opsx:sync
一键全流程
想做什么	命令
HyperSpec 全自动（推荐中大需求）	/hyperspec
Superpowers 自检	/superpowers:using-superpowers
其他
想做什么	命令
导出数据库表结构	/db-schema-export
查看当前 change	openspec list
HyperSpec 状态	cat .hyperspec-state.yaml
首次使用引导	/opsx:onboard
五、自动保护机制
Hooks（自动运行，无需手动触发）
时机	脚本	作用
编辑/写入文件前	guard_write.py	拦截对保护目录的写入（application.yml、db/、sql/ 等）
执行 Bash 命令前	ensure_change_context.py	无活跃 change 时，阻止风险命令执行
编辑/写入文件后	run_checks.sh	Java 文件保存后自动编译检查
权限控制
类型	内容
禁止	git push、kubectl、rm -rf、写入 application*.yml、写入 sql/、写入 secrets/
允许	git status、git diff、mvn compile、openspec *、Edit、ls、cat
如需修改受保护文件，必须在 design.md 中明确说明理由并经人工审核。

六、目录结构
sunny-mdm/
├── AGENTS.md                          # AI 协作入口（AI 读的第一个文件）
├── CLAUDE.md                          # AI 编码规则（分层架构、安全、测试）
├── Harness.md                         # 完整工作流手册
├── REVIEW.md                          # 代码审查规则
├── .hyperspec-state.yaml              # HyperSpec 12 步状态机（运行时生成）
│
├── .claude/
│   ├── settings.local.json            # 权限 + Hooks 配置
│   ├── hooks/                         # 3 个自动保护脚本
│   │   ├── guard_write.py             #   拦截受保护路径写入
│   │   ├── ensure_change_context.py   #   检查活跃 change 才允许风险命令
│   │   └── run_checks.sh              #   编辑后自动编译
│   ├── commands/opsx/                 # 11 个 OpenSpec 命令
│   └── skills/                        # 18 个 skill
│       ├── openspec-*/                # 11 个 OpenSpec 工作流 skill
│       ├── prepare-review/            # PR 摘要生成
│       ├── spring-architecture-review/ # Spring 分层审查
│       ├── sql-risk-review/           # SQL 风险审查
│       ├── db-schema-export/          # 数据库表结构导出
│       ├── harness-bootstrap/         # 一键部署 harness 到新项目
│       ├── gstack/                    # 多角色审查
│       └── hyperspec/                 # 编排层（全自动路径的核心）
│
├── openspec/
│   ├── config.yaml                    # OpenSpec 上下文注入配置
│   ├── changes/                       # 活跃 change（开发中）
│   └── archive/                       # 已归档 change（按月存储）
│
├── superpowers/
│   └── plans/                         # HyperSpec 生成的 TDD 实现计划
│
└── docs/
    ├── architecture/                  # 架构文档 + 隐性约定
    ├── database/                      # 数据库表结构文档
    ├── harness/                       # 本文档所在目录
    │   ├── usage-guide.md             # ← 你正在读的
    │   ├── integration.md             # 完整工具链集成文档
    │   ├── skill-strategy.md          # Skills 三档策略
    │   ├── pitfalls.md                # 避坑指南
    │   └── commands-cheatsheet.md     # 命令速查
    ├── help/                          # 平台能力使用指南（PO/S3/Kafka/OA/锁/导入导出）
    ├── product/                       # 产品文档
    └── standards/                     # 编码标准（API/数据库/测试）
七、典型场景
场景 1：新增一个接口（手动路径）
1. /opsx:explore                       # 和 AI 澄清需求
2. /opsx:propose                       # 生成 proposal/specs/design/tasks
3. 人工审核 proposal 边界和 tasks 粒度
4. gstack /office-hours                # 6 个灵魂拷问（可选，小改动跳过）
5. gstack /plan-ceo-review             # CEO 视角审（可选）
6. /superpowers:writing-plans          # 拆细 tasks（可选）
7. /opsx:apply                         # AI 逐条实施（Superpowers TDD 隐式生效）
8. /spring-architecture-review         # 检查分层合规
9. /sql-risk-review                    # 检查 SQL 安全
10. /prepare-review                    # 生成 PR 摘要
11. git commit + /opsx:archive         # 提交归档
场景 2：新增一个模块（HyperSpec 路径）
1. /hyperspec                          # 一条命令启动
2. 回答 AI 的需求确认问题（一次一个）
3. AI 自动生成 proposal/specs/design/tasks + TDD 实现计划
4. 回答 gstack 灵魂拷问（中大需求自动触发，小改动自动跳过）
5. 人工审核 proposal + 任务计划
6. 确认"开始实现"
7. 等待 HyperSpec 自动完成（TDD + commit + 验证 + 审查 + 归档）
   - 中断后重新运行 /hyperspec 即可断点恢复
场景 3：修复一个 Bug（手动路径）
1. /opsx:propose                       # 描述问题 + 修复方案
2. 人工审核修复范围
3. /opsx:apply                         # AI 实施
4. /prepare-review                     # 说明复现步骤 + 验证步骤
5. git commit + /opsx:archive
场景 4：数据库字段变更（手动路径）
1. /db-schema-export                   # 先导出当前表结构
2. /opsx:propose                       # 描述字段变更
3. 人工审核 design.md 中的 SQL 影响分析
4. /opsx:apply                         # AI 实施
5. /sql-risk-review                    # 重点检查索引和数据兼容
6. /prepare-review
7. git commit + /opsx:archive
场景 5：探索性讨论（不写代码）
/opsx:explore                          # 纯讨论模式，不实施
八、常见问题
Q: 两条路径能混用吗？
不能。同一个 change 要么全程手动（/opsx:*），要么全程 HyperSpec（/hyperspec）。混用会导致 .hyperspec-state.yaml 状态与实际文件不一致。

Q: 我不想跑完整的 9 关审查，可以吗？
可以。harness 是叠加式设计：

不装 Superpowers → TDD 降级为"至少补 1 个测试"（仅旧代码修改）
不装 gstack → 9 关中 5 关降级为独立规则审查
只用 OpenSpec → proposal → apply → archive 就是一个完整闭环
新代码不降级：必须有测试，/opsx:verify 拦截
Q: AI 拦截了我的操作，怎么办？
hooks 拦截通常是因为：

没有活跃 change → 先 /opsx:propose 创建一个
写入了受保护文件 → 在 design.md 中说明理由
执行了禁止命令 → 这些命令需要人工执行
Q: HyperSpec 自动 commit 会和 hooks 冲突吗？
不会。HyperSpec propose 阶段第一步就创建 OpenSpec change 目录，后续 git add/git commit 时 ensure_change_context.py 已检测到活跃 change → 放行。HyperSpec 不做 git push（与 deny 规则一致）。

Q: proposal 写错了怎么办？
直接废弃重来。修改一个方向错误的 proposal 比重新写一个更浪费时间。

Q: 工具链升级后，旧 change 会受影响吗？
不会。所有 change 都在 openspec/changes/ 和 openspec/archive/ 中独立存储，升级不影响已有工件。

Q: HyperSpec 中断后怎么办？
重新运行 /hyperspec。它会读取 .hyperspec-state.yaml 的 checkpoint，验证实际文件状态，路由到断点位置继续。

九、相关文档
文档	说明
Harness.md	完整工作流手册（设计哲学 + 实施指南）
AGENTS.md	AI 协作入口（必读顺序 + 硬约束）
CLAUDE.md	AI 编码规则（分层架构 + 安全 + 测试）
REVIEW.md	代码审查标准
integration.md	工具链完整集成文档
skill-strategy.md	Skills 三档启用策略
pitfalls.md	10 条避坑经验
commands-cheatsheet.md	命令速查表