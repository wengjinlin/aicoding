# Harness V2 架构演讲稿

> 主题：从 Vibe Coding 到工程化护栏 —— Harness 完全体架构与落地
> 时长建议：60-80 分钟
> 适用听众：研发团队、技术负责人、AI Coding 实践者

---

## 开场白

各位同事，大家好。

今天我想跟大家聊一个话题，就是怎么让 AI 真正在我们的项目里"扎下根"——不是偶尔玩一玩、写两段代码就完事，而是变成一个可以长期依赖、稳定交付的"工程伙伴"。

这套东西我们叫它 **Harness V2**。它不是一个新的模型，也不是一个新的 IDE 插件，而是**一套完整的工程化工作流架构**。简单说，它解决的就是一句话——**怎么让 AI 不再"靠感觉"干活，而是像一支有纪律、有规范、有流程的研发团队那样工作**。

那么接下来，我会从下面几个方面展开：先聊聊 AI Coding 是怎么一步步演化到今天的，为什么会催生 Harness 这种东西；然后带大家把 Harness 的七层架构拆开看一遍；接着说它具体怎么运转；最后两块是重头戏——**怎么从零开始落地这套架构**，以及**怎么用"角色编排"把单台 Claude 变成一支虚拟研发团队**。

好，咱们开始。

---

## 第一部分：AI Coding 的演化之路

### 从 Prompt 到 Harness：三次范式跃迁

要理解 Harness，咱们得先回头看看这两年 AI 辅助编程是怎么一路演化的。

过去两年，整个行业其实经历了**三次范式跃迁**。每一次跃迁，解决的都是一个更深一层的问题。

**第一次跃迁，叫 Prompt Engineering，也就是提示词工程。**

2023 到 2024 年那会儿，"提示词工程师"一度被炒得特别火。零样本提示、少样本提示、思维链、角色扮演……各种技巧层出不穷。大家核心在琢磨一件事——**怎么跟 AI 说清楚我要什么**。

但很快大家就发现，随着模型能力飞速提升，从 GPT-3 到 GPT-4 再到 Claude 3，写好提示词的边际效益越来越低。模型本身已经够聪明了，你哪怕说得模糊一点，它也能理解。**真正的问题，不再是"怎么说清楚"，而是"它根本不知道关键信息"**。

**这就引出了第二次跃迁——Context Engineering，上下文工程。**

当模型够强却依然出错时，大家才意识到，问题出在上下文窗口里到底装了什么。于是 RAG（检索增强生成）、上下文压缩、滚动摘要、层次记忆这些技术被系统化用起来了。OpenAI 的实战经验也验证了一条铁律：**与其把一份巨型规范全塞进去，不如压缩成百行索引、需要时动态加载子文档**，反而模型遵从度更高。Context Engineering 回答的是"模型在回答时该知道什么"。

**第三次跃迁，就是我们今天的主角——Harness Engineering，驾驭工程。**

即使你的提示词再精准、上下文再完备，一个不受约束的 Agent 依然会失控。它会顺手重构不该动的模块、声称测试通过但其实根本没跑、命名风格和项目完全不一致……这些问题，**不是模型的问题，而是系统层面缺乏约束、验证和反馈机制**。Harness 就是为了解决这个问题而生的，它回答的是"整个 AI 系统如何可靠地运转"。

这里我想强调一句——**这三者不是替代关系，而是嵌套关系**。没有 Prompt 基础，Context 就没法被正确理解；没有 Context 支撑，Harness 就在信息真空里运行；没有 Harness 约束，再好的 Prompt 和 Context 也是沙滩上的城堡。

### 从 Vibe Coding 到工程化护栏

说完了三次跃迁，咱们再聊一个最近特别火、但也是问题不断的概念——**Vibe Coding**。

Andrej Karpathy 在 2025 年提出了这个词，翻译过来大概叫"氛围编程"。就是开发者通过自然语言描述意图，让 AI 生成代码，观察效果后再反馈调整。效率惊人，调研显示能提升 126%。但同时也带来四大痛点：

第一，**代码正确性失控**——AI 会生成那种"看起来对、其实错"的幻觉代码；
第二，**架构一致性缺失**——快速迭代导致"意大利面条式代码"；
第三，**需求歧义和翻译损耗**——自然语言天生不精确，给 AI 留下了太大的"自由发挥"空间；
第四，**缺乏可追溯性**——没有单一事实来源，团队协作很困难。

那么社区怎么应对的呢？大家在实战中逐步形成了五大方法论，作为 Vibe Coding 的**工程化护栏**：

- **SDD**（规格驱动开发）——战略层，解决"做什么"，规格是唯一事实来源；
- **DDD**（领域驱动设计）——架构层，解决"怎么组织"，给 AI 提供架构边界；
- **ATDD**（验收测试驱动）——验收层，用 Given-When-Then 防止实现细节泄露；
- **TDD**（测试驱动开发）——执行层，用 Red-Green-Refactor 让测试成为 AI 的契约；
- **BDD**（行为驱动开发）——协作层，跨角色用统一语言、生成活文档。

这五大方法组合起来，才能让 Vibe Coding 从"靠感觉"进化成"有护栏、可追溯、可重复"的工程化范式。

### Rule → Spec → Loop → Harness：控制面的逐层收紧

接下来再讲一个 Phodal 提出的四步渐进路径，它非常精炼地概括了 AI Coding 的落地路径。他发现，**AI Coding 的瓶颈从来不在生成端，而在接收端**。

四步分别是：

| 阶段 | 核心问题 | 本质 |
|------|----------|------|
| **Rule** | 不要乱来 | 先写 NEVER 和 DO NOT，让 AI 先学会不越界 |
| **Spec** | 这次只做什么 | 把模糊意图压缩成可执行、可审查、可验证的变更 |
| **Loop** | 怎么持续收敛 | 读取上下文→做最小改动→运行验证→记录状态→进入下一轮 |
| **Harness** | 凭什么被信任 | 约束+验证+评审+放行，让组织放心 |

这四层是有严格依赖关系的：没有 Rule，Spec 就是在给一个无边界的 Agent 提需求；没有 Spec，Loop 只是把错误更高效地放大；没有 Loop，Harness 就只能在末端被动兜底。

### Harness 的衰变定律

说完路径，还有一个非常有意思的规律，是 Anthropic 自己研究发现的——**模型能力越强，所需的 Harness 越简单**。

Claude 3.0 时代需要极严格约束的规则，到 Claude 3.5 时代很多规则已经不必要了。这意味着 Harness 的设计应该集中在两类场景：

第一类，**模型短期内无法自行解决的问题**——比如行业特定规则、合规要求、复杂系统协同；
第二类，**即使模型能力再强也无法自行建立的外部接口**——比如工具调用、API 集成、权限控制。

**能根据模型能力的边界动态调整 Harness 的"厚度"，才能在工程效率上获得最高回报**。这一点，是我们后面所有设计的指导思想。

### 本文档的 Harness 架构

好，铺垫完了，咱们本文档描述的 7 层 Harness 架构，其实就是上面这条演化路径的工程化落地：

| 演化阶段 | 对应架构层 | 实现方式 |
|----------|-----------|---------|
| Rule | CLAUDE.md + Hooks | 编码红线、文件保护、约束检查 |
| Spec | L1 OpenSpec | 4 工件强制顺序：proposal → specs → design → tasks |
| Loop | L2 Superpowers + L7 HyperSpec | TDD 红绿重构循环 + 12 checkpoint 状态机 |
| Harness | L3 审查层 + 安全保护层 | 双轨审查 + guard_write + run_checks |

在此基础上，L4 领域知识层、L5 工具精度层、L6 持续学习层进一步增强了 AI 的领域感知和工具精确度，让整个系统从"偶尔能用"走向"稳定交付"。

---

## 第二部分：Harness 整体介绍

### 什么是 Harness

刚才其实已经陆续提了一些，咱们这里给个正式定义：

**Harness 是一套为 Claude Code 设计的分层 AI 开发工作流架构**。它通过 7 层架构，把 AI 辅助开发从"随意对话"升级为"工程化流水线"，在**规范管理、编码纪律、代码审查、流程编排、领域知识、工具精度、持续学习**这 7 个维度，提供完整的支撑。

### 核心设计理念

Harness 的设计理念可以用七个关键词概括：

第一，**规范先行**——需求不清不写代码，先 WHAT 后 HOW；
第二，**纪律内置**——TDD 不是可选项，是新代码的强制约束；
第三，**审查自适应**——改一个字段不跑 9 关审查，但跨模块重构也不能省略任何关卡；
第四，**编排自动化**——一条命令启动全自动流程，断点还能恢复；
第五，**领域感知**——内置制造业 Spring Boot / JPA / 平台包的领域知识；
第六，**工具精确**——LSP/AST 级别的代码分析，不靠文本猜测；
第七，**越用越聪明**——跨会话积累项目知识，隐性约定自动沉淀。

这七条理念，后面的每一层架构，都是它们的具体落地。

---

## 第三部分：架构总览

### 七层架构图

[外链图片：harness-v2-architecture.svg]

整体结构大家看图就行，下面咱们直接逐层过一遍。

### 各层职责一览

| 层级 | 名称 | 核心工具 | 职责 |
|------|------|----------|------|
| **L7** | 编排层 | HyperSpec | 全流程编排、状态管理、审查路由、通知 |
| **L1** | 规范层 | OpenSpec | 工件化需求管理（proposal→specs→design→tasks） |
| **L2** | 纪律层 | Superpowers | TDD 红绿重构、子代理开发、完成验证 |
| **L3** | 审查层 | quick-review + gstack | 双轨代码审查，按复杂度自动路由 |
| **L4** | 领域知识层 | ECC 技能库 | Spring Boot/JPA/API 编码模式 |
| **L5** | 工具精度层 | OMC MCP | LSP/AST 结构化代码分析 |
| **L6** | 持续学习层 | ECC 本能 | 跨会话知识积累与沉淀 |
| — | 安全保护层 | Hooks | 文件保护、变更上下文、编译检查 |
| — | 模型路由层 | OMC 路由 | 按任务复杂度选择 Claude 模型 |

下面咱们一层一层详细拆开看。

---

## 第四部分：核心层详解

### 4.1 L1 规范层 —— OpenSpec

**第一层是规范层，工具是 OpenSpec。它的作用是把模糊的需求转化为结构化的工程工件，确保"做什么"在写代码前就明确。**

这里最核心的一条规则是——**4 工件必须按顺序创建，不可跳步**：

```
proposal ──→ specs ──→ design ──→ tasks
 (WHY)      (WHAT)    (HOW)     (执行清单)
```

每个工件的作用我快速过一下：

- **proposal** 写到 `proposal.md`，记录变更动机和边界（做什么、不做什么），**人类必审**；
- **specs** 写到 `specs/*.md`，记录需求规格、接口定义、数据结构，**人类选审**；
- **design** 写到 `design.md`，记录技术方案、涉及模块、表名、接口，**人类必审**；
- **tasks** 写到 `tasks.md`，是 2-5 分钟粒度的原子任务清单，**人类审粒度**。

配套的命令体系也很清晰：

| 命令 | 作用 |
|------|------|
| `/opsx:explore` | 反问澄清需求（不生成工件） |
| `/opsx:propose` | 生成 4 工件 |
| `/opsx:continue` | 单步推进下一个工件 |
| `/opsx:ff` | 一次生成全部工件 |
| `/opsx:verify` | 验证代码与规范对齐 |
| `/opsx:apply` | 按 tasks 逐条执行 |
| `/opsx:archive` | 归档变更 |

记不住没关系，关键是记住一个原则——**先需求、后设计，先 WHAT 后 HOW**。

### 4.2 L2 纪律层 —— Superpowers

**说完了规范，接下来是纪律。这一层工具叫 Superpowers，作用是强制执行编码纪律，确保新代码有测试、有验证。**

核心技能有五个：

- `test-driven-development`——隐式激活，强制走 TDD 红绿重构；
- `verification-before-completion`——隐式激活，标记完成前必须跑编译+测试；
- `subagent-driven-development`——按需调用，为每个原子任务派发独立子代理并行开发；
- `writing-plans`——按需调用，把 tasks.md 拆细成 TDD 实现计划；
- `systematic-debugging`——按需调用，遇到 Bug 系统化排查。

这里我重点说一下 **TDD 强约束规则**。我们来自 openspec/config.yaml 的约束：每个 task 必须包含 5 个固定步骤——

1. 写失败测试（附完整测试代码）；
2. 跑测试——确认失败（附命令+预期输出）；
3. 写最小实现（附完整实现代码）；
4. 跑测试——确认通过（附命令+预期输出）；
5. 提交（附 git 命令）。

也就是说，**不是嘴上说"我走了 TDD"就算 TDD**，必须把这五步的痕迹都留在任务清单里。

### 4.3 L3 审查层 —— 双轨审查

**纪律有了，还得有把关的。L3 是审查层，它的核心思想是——根据变更复杂度自动选择审查强度，避免"杀鸡用牛刀"。**

#### 4.3.1 轻量审查 —— quick-review（3 关）

**适用场景是日常 CRUD 字段变更、Bug 修复、小接口调整。**

触发条件全部满足才行：task 数量 ≤ 3、涉及模块 ≤ 1、无 DDL 变更、无跨服务调用变更。

3 关流水线长这样：

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│   第 1 关       │     │   第 2 关      │     │   第 3 关       │
│  spec-align    │────→│  risk-check    │────→│  archive       │
│  规范对齐       │      │  风险检查       │     │  归档          │
└────────────────┘     └────────────────┘     └────────────────┘
```

**第 1 关叫 spec-align**，做规范对齐和工程质量检查：
- 代码与 tasks.md 逐条对齐，无遗漏无多余；
- Spring 分层——Controller 不直接操作 DAO，Service 继承 BaseServiceManager；
- DTO 规范——单一 DTO 不拆分，Controller 层只用 DTO 不用 Entity；
- Entity 规范——禁用 Lombok，手写 getter/setter；
- 平台包使用——优先 sunny-base-*，不引重叠依赖；
- 通用质量——无死代码、无 console.log、无 TODO、import 干净。

**第 2 关叫 risk-check**，做风险检查：
- SQL 安全——参数化查询、无拼接 SQL、SELECT * 检查；
- 空值处理——新字段可空性、前端空值展示、接口返回 null 安全；
- 索引感知——新增 WHERE 条件是否走索引、避免全表扫描；
- 隐性约定——修改状态字段/接口返回前已查 docs/architecture/implicit-contracts.md；
- 接口兼容——不破坏已有接口契约，字段新增而非修改；
- 数据兼容——DDL 变更对存量数据的处理。

**第 3关就是 archive**，复用 `/opsx:archive` 把 change 移入 `openspec/archive/` 并合并 specs。

#### 4.3.2 完整审查 —— gstack（9 关）

**适用场景是新模块开发、跨模块重构、涉及 DDL、新集成对接这种大动作。**

触发条件任一满足即可：task 数量 > 3、涉及模块 ≥ 2、有 DDL 变更、有跨服务调用变更，或者用户显式调用 `/full-review`。

9 关流水线是这样的：

```
┌──────┐  ┌───────┐  ┌────────┐  ┌─────┐  ┌────────┐
│ 1.   │  │ 2.    │  │ 3.     │  │ 4.  │  │ 5.     │
│verify│→ │review │→ │spring  │→ │ sql │→ │security│
└──────┘  └───────┘  └────────┘  └─────┘  └────────┘
                                                │
┌───────┐  ┌───────┐  ┌────────┐  ┌────────┐    │
│ 9.    │  │ 8.    │  │ 7.     │  │ 6.     │←───┘
│archive│← │  PR   │← │  qa    │← │simplify│
└───────┘  └───────┘  └────────┘  └────────┘
```

9 关具体是：
1. `/opsx:verify`——规范对齐；
2. `gstack /review`——通用代码质量；
3. `/spring-architecture-review`——Spring 分层审查；
4. `/sql-risk-review`——SQL 风险审查；
5. `gstack /security-review`——安全审查；
6. `gstack /simplify`——简化重构；
7. `gstack /qa`——真实测试；
8. `/prepare-review`——PR 摘要；
9. `/opsx:archive`——归档。

**这里有一个关键约束——每关失败必须修完才能进下一关**，不允许带病过关。

#### 4.3.3 自动路由机制

[外链图片：harness-v2-dual-review.svg]

至于简单变更和复杂变更分别走哪条路，由系统自动判断。当然用户也可以显式覆盖——`/quick-review` 强制走轻量、`/full-review` 强制走完整。

### 4.4 L7 编排层 —— HyperSpec

**说完了规范、纪律、审查，怎么把它们串成一条流水线？这就是 L7 编排层 HyperSpec 的作用。**

[外链图片：harness-v2-hyperspec-flow.svg]

核心能力有五条：

| 能力 | 说明 |
|------|------|
| 12 checkpoint 状态机 | 追踪流程进度，断点可恢复 |
| 三阶段流程 | propose → apply → archive |
| 审查路由 | 自动判断使用轻量或完整审查 |
| 通知回调 | 关键节点通知（Telegram/Discord/Slack） |
| 自动 commit | 每完成一个 task 自动 commit |

**12 Checkpoint 状态机**是 HyperSpec 的灵魂，记一下这条链：

```
profiler-done → requirements-confirmed → openspec-generated →
plan-generated → plan-generated-and-confirmed → task-N-complete →
verified → reviewed → apply-done → consistency-verified →
archived → done
```

**断点恢复规则**这里要强调一下——**实际文件状态是 ground truth，状态文件只是缓存**。两者冲突时以实际文件为准并修正状态文件。这点非常重要，否则 AI 一旦状态错乱就再也回不来了。

**通知回调点**有四个关键节点：
- openspec-generated——"需求工件已生成，请审核 proposal"；
- plan-generated-and-confirmed——"实现计划已确认，即将开始编码"；
- reviewed——"审查已完成，请查看结果"；
- archived——"变更已归档，流程结束"。

### 4.5 L4 领域知识层 —— ECC 技能库

**说完了上面那些流程性的层，咱们再看另外三个偏"知识"的层。先看 L4 领域知识层。**

它的作用很简单——**为 AI 提供制造业 Spring Boot 项目的领域编码模式，让 AI 写出符合团队规范的代码**。

集成的技能清单我快速读一下，大家有个印象就行：

| 技能 | 提供什么 | 何时激活 |
|------|----------|----------|
| `springboot-patterns` | Spring Boot 分层架构、Bean 管理、配置模式 | 涉及 Spring 代码时 |
| `springboot-security` | 认证授权、权限控制、安全配置 | 涉及安全相关代码时 |
| `springboot-tdd` | Spring Boot 测试模式、Mock 策略 | 写测试时 |
| `jpa-patterns` | JPA 实体设计、关联映射、N+1 问题 | 涉及 Entity/Mapper 时 |
| `api-design` | RESTful API 设计、DTO 设计 | 设计/实现接口时 |
| `database-migrations` | 数据库迁移策略、DDL 安全 | 涉及 DDL 时 |
| `backend-patterns` | 后端通用模式（缓存、异常、日志） | 通用后端代码 |
| `postgres-patterns` | PostgreSQL 特有模式、性能优化 | 涉及 SQL 优化时 |
| `deployment-patterns` | 部署模式、环境配置 | 涉及部署时 |
| `docker-patterns` | Docker 最佳实践 | 涉及容器化时 |

集成方式也简单——放入 `.claude/skills/` 目录，HyperSpec apply 阶段会根据文件类型自动激活。

### 4.6 L5 工具精度层 —— OMC MCP

**L5 解决的是"AI 看代码到底看得准不准"的问题。它提供结构化代码分析能力，让审查和实现基于精确的代码结构而非文本猜测。**

工具清单包括：

| 工具 | 类型 | 用途 |
|------|------|------|
| `lsp_hover` | LSP | 查看类型信息、文档 |
| `lsp_goto_definition` | LSP | 跳转到定义 |
| `lsp_find_references` | LSP | 查找所有引用 |
| `lsp_diagnostics` | LSP | 获取编译错误/警告 |
| `lsp_completion` | LSP | 代码补全 |
| `lsp_rename` | LSP | 安全重命名 |
| `ast_grep_search` | AST | 按语法结构搜索代码模式 |
| `ast_grep_replace` | AST | 按语法结构替换代码模式 |
| `python_repl` | REPL | 交互式 Python 执行 |

**审查层增强效果**特别明显，对比一下：

- 原来做 Spring 分层审查只能文本匹配 import，现在用 LSP 能**精确分析类依赖关系**；
- 原来 SQL 风险审查只能正则匹配 SQL 字符串，现在用 AST 能**精确定位 SQL 构建模式**；
- 原来是通用 diff 审查，现在可以做 **LSP 引用分析 + AST 模式匹配**。

集成方式——注册为 MCP 服务器到 `.claude/settings.local.json`。

### 4.7 L6 持续学习层 —— ECC 本能系统

**这一层是让 AI 越用越聪明的关键——它自动积累跨会话的项目知识，减少重复犯错。**

学习内容主要是四类：

| 知识类型 | 示例 | 存储位置 |
|----------|------|----------|
| 隐性约定 | "这个字段改了必须同步改那个表" | `.claude/instincts/` |
| 踩坑经验 | "这个 Service 不能直接注入，要用工厂获取" | `.claude/instincts/` |
| 团队偏好 | "我们团队习惯用 QueryDSL 不用 JPQL" | `.claude/instincts/` |
| API 变更 | "这个接口已废弃，用新接口" | `.claude/instincts/` |

工作机制分四步——
1. **观察模式**（SessionStart Hook）：加载已有本能；
2. **捕获模式**（SessionEnd Hook）：自动提取本次会话的隐性知识；
3. **应用模式**：AI 在编码时自动参考本能知识；
4. **分享模式**：支持 `/instinct-export`、`/instinct-import` 团队共享。

这里要特别说一下——**本能系统和现有的 `docs/architecture/implicit-contracts.md` 不冲突**。现有那份是显式约定，保持不变；本能系统作为补充，自动发现和积累隐式约定。两者各司其职：**显式优先，本能补充**。

### 4.8 安全保护层 —— Hooks

**安全保护层是横切层，靠 3 个 Hook 脚本兜底：**

| 时机 | 脚本 | 作用 |
|------|------|------|
| 编辑/写入前 | `guard_write.py` | 拦截对保护目录的写入（application.yml、db/、sql/） |
| Bash 命令前 | `ensure_change_context.py` | 无活跃 change 时阻止风险命令 |
| 编辑/写入后 | `run_checks.sh` | Java 文件保存后自动编译检查 |

这三个 Hook 就是 AI 的"安全带"。

### 4.9 模型路由层

**最后一层是模型路由层，作用很直接——按任务复杂度选择 Claude 模型，优化成本。**

| 级别 | 模型 | 适用场景 | Harness 中的应用 |
|------|------|----------|-----------------|
| 低 | haiku | 快速查询、简单搜索 | OpenSpec explore、轻量审查 spec-align |
| 中 | sonnet | 标准实现、常规审查 | Superpowers apply、quick-review risk-check |
| 高 | opus | 架构决策、深度分析 | OpenSpec propose、gstack 审查、复杂 debug |

实现方式——在 `openspec/config.yaml` 中配置路由提示，HyperSpec 各阶段自动选择。

---

## 第五部分：AI 工作流程

好，前面咱们把 9 层都过了一遍。现在可能有人会问——**这些层之间到底怎么协同？AI 进入项目之后，到底经历了什么样的一个生命周期？**咱们来看看。

### 5.1 AI 会话的完整生命周期

当开发者打开 Claude Code 进入项目时，**AI 并不是"从零开始"的**。它沿着 Harness 架构的各层，经历一个完整的 **初始化 → 理解 → 执行 → 验证 → 学习** 过程。

简单说就是六步——
- **① 会话启动**：上下文加载、技能自检、本能加载；
- **② 需求理解**：规范层启动、工件生成、人类审核；
- **③ 计划拆解**：纪律层介入、TDD 计划、复杂度判断；
- **④ 编码实施**：领域技能、工具辅助、TDD 循环；
- **⑤ 审查归档**：审查层路由、自动审查、归档变更；
- **⑥ 学习沉淀**：本能捕获、知识沉淀、状态持久。

下面咱们一个阶段一个阶段细看。

### 5.2 阶段 ①：会话启动 —— AI 如何"认识"你的项目

**AI 进入项目后，第一件事不是写代码，而是加载上下文、建立认知。**

[外链图片：harness-ai-session-init.svg]

这个时候，AI 的"大脑"里装的是什么呢？
- 项目的编码规范和分层规则；
- 所有可用的技能（56+ 个）和工具（18+ 个 MCP 工具）；
- 历史会话积累的项目知识（本能系统）；
- 当前工作状态（是否有未完成的变更）。

这一步做好了，AI 才算"准备好"了。

### 5.3 阶段 ②：需求理解 —— AI 如何"想清楚"做什么

**当开发者发出 `/opsx:propose` 或 `/hyperspec` 后，AI 进入需求理解阶段。**

这个阶段背后其实在跑六件事：

1. **项目感知**（模型路由 → haiku）——自动探测技术栈：Spring Boot + MyBatis + Vue，生成 project_profile；
2. **需求对话**（模型路由 → opus，深度分析）——一次只问一个问题，结合 ECC 本能中的历史知识提问，比如"上次改这个字段时出了问题，这次要注意什么？"；
3. **生成工件**（L1 规范层 — OpenSpec）——严格按顺序：proposal → specs → design → tasks，每个工件写入 `openspec/changes/<id>/`，tasks 粒度自动拆到 2-5 分钟，注入 TDD 强约束规则；
4. **TDD 计划生成**（L2 纪律层 — Superpowers）——调用 writing-plans 技能，为每个 task 生成 5 步 TDD 实现计划，写入 `superpowers/plans/`；
5. **规范层审查**（L3 审查层 — 复杂度路由）——判断 task 数量、模块数、是否有 DDL，中大需求走 gstack /office-hours + CEO/Eng 审查，小改动自动跳过；
6. **通知回调**——发出"需求工件已生成，请审核 proposal"。

这一阶段做完，**AI 调用了模型路由层、L1 规范层、L2 纪律层、L3 审查层、L6 学习层一共 5 层能力**。是不是已经感受到层的协同了？

接下来人类审核 proposal 边界和 tasks 粒度。

### 5.4 阶段 ③④：编码实施 —— AI 如何"按规矩"写代码

**人类审核通过后，AI 进入编码阶段。这是 Harness 最核心的部分——AI 不是随意写代码，而是在多层约束下工作。**

[外链图片：harness-ai-tdd-layers.svg]

AI 在写每一行代码时，**同时有六个层在它背后盯着**：

| 层 | 做了什么 | AI 的感受 |
|----|----------|-----------|
| L2 纪律层 | 强制先写测试，再写实现 | "我不能直接写代码，必须先写失败的测试" |
| L4 领域层 | springboot/jpa 技能自动激活 | "我知道 Entity 禁用 Lombok，Service 要继承 BaseServiceManager" |
| L5 工具层 | LSP 查看类型定义，AST 搜索代码模式 | "我看到了这个类的实际依赖关系，不是猜的" |
| L6 学习层 | 参考历史本能 | "上次踩过坑，这个字段改了要同步改另一个表" |
| 安全保护层 | Hook 自动检查 | "我不能写 application.yml，不能没有活跃 change 就改代码" |
| 模型路由层 | 标准实现用 sonnet | "写一个 Entity 字段，用 sonnet 就够了" |

这就是为什么 Harness 写出来的代码靠谱——**每一行都有约束在兜底**。

### 5.5 阶段 ⑤：审查归档 —— AI 如何"自己查"自己

**编码完成后，AI 进入审查阶段。不是简单地"再看一遍"，而是按预定义的检查清单系统化审查。**

流程是这样的：所有 Task 完成 + 全量验证通过之后，进入 L3 审查层的自动路由——

- 简单变更（task≤3, 单模块, 无DDL）走 **quick-review 3 关**：
  - 第 1 关 spec-align（sonnet）：逐条对齐 tasks.md、Spring 分层、DTO 规范、Entity 规范、通用质量；
  - 第 2 关 risk-check（sonnet）：L5 工具层辅助——用 AST 搜 SQL 拼接模式、用 LSP diagnostics 检查编译警告，再叠加 SQL 安全、空值处理、隐性约定（L6 本能参考）、接口兼容；
  - 第 3 关 archive：调用 `/opsx:archive` 归档变更。

- 复杂变更（task>3 或 跨模块 或 有DDL）走 **gstack 完整 9 关**。

审查通过进入归档；审查失败，AI 自动修复、重新审查，最多 3 轮。

通知回调点："审查已完成，请查看结果"。

### 5.6 阶段 ⑥：学习沉淀 —— AI 如何"记住"这次经验

**流程结束后，AI 不是"失忆"的。它通过 L6 持续学习层自动沉淀知识。**

具体来说做三件事：

第一，**知识捕获**（SessionEnd Hook 触发）——分析本次会话的代码变更，识别隐性知识。比如——
- "发现修改 OrderService 时必须同步更新 Inventory"；
- "这个项目的统一响应格式是 Result<T>"；
- "DTO 命名规范是 XxxDTO，不分 Param/Query/VO"。
- 然后写入 `.claude/instincts/` 目录。

第二，**状态持久化**——HyperSpec 更新 `.hyperspec-state.yaml` 到 done 状态，会话状态写入持久化存储，下次会话可恢复上下文。

第三，**通知**——"变更已归档，流程结束"。

这个学习效果是**复利式的**——
- 第 1 次使用：AI 不知道项目规矩，全靠 CLAUDE.md；
- 第 5 次使用：AI 记住了 10+ 条隐性约定；
- 第 20 次使用：AI 累积了 50+ 条项目知识——**写代码越来越"像你们团队的老人"**。

这就是 Harness 越用越好用的根本原因。

### 5.7 各层在各阶段的激活状态总览

[外链图片：harness-ai-lifecycle.svg]

这张图大家可以自己看一下，是把上面咱们讲的所有内容整合在一张图里。

---

## 第六部分：开发流程

那么具体到一个真实需求，开发流程长什么样？Harness 提供两条路径——**手动路径**和 **HyperSpec 全自动路径**。

### 6.1 手动路径

手动路径的入口由用户根据变更大小选择，分小改动、中等需求、大需求三档：

整体分 5 个 Phase——

**Phase 1：创建需求**——`/opsx:explore` 反问澄清（可选）→ `/opsx:propose` 生成 4 工件 → 人工审核 proposal 边界和 tasks 粒度。

**Phase 2：规范层审查**（中大需求走，小改动跳过）——`gstack /office-hours` 6 个灵魂拷问、`gstack /plan-ceo-review` CEO 视角、`/superpowers:writing-plans` 拆细到 2-5 分钟、`gstack /plan-eng-review` 工程经理视角、`gstack /plan-design-review` 设计师视角（涉及 UI 时）。

**Phase 3：实施**——`/opsx:apply` 按 tasks 逐条执行，Superpowers TDD 隐式生效，ECC 领域技能自动激活，OMC MCP LSP/AST 辅助精确实现。

**Phase 4：审查（自动路由）**——自动判断变更复杂度：task≤3 ∧ 单模块 ∧ 无DDL 走 quick-review 3 关，其他走 gstack 9 关。

**Phase 5：提交归档**——`git add -A && git commit`，然后 `/opsx:archive`。

### 6.2 HyperSpec 全自动路径

**如果说手动路径像开手动挡的车，那 HyperSpec 全自动路径就是开自动驾驶。**

一条命令 `/hyperspec` 启动，背后自动跑完三阶段——

**Propose 阶段**——项目感知 → 需求确认 → 生成工件（proposal/specs/design/tasks）→ TDD 计划生成 → 规范层审查（自动判断）→ checkpoint: plan-generated-and-confirmed → 通知"实现计划已确认，即将开始编码"。

**Apply 阶段**——
- 自动选择执行模式：≥6 task 或跨 ≥3 模块 → subagent 并行；≤5 task 集中 1-2 模块 → inline 串行；
- 每个 Task：TDD 开发（红→绿→重构）+ ECC 领域技能自动激活 + OMC MCP LSP/AST 辅助 → 编译检查 → 更新 tasks.md checkbox → 自动 git commit（原子性）；
- verification-before-completion：全量编译 + 测试验证；
- 审查阶段（自动路由）：简单 → quick-review 3 关，复杂 → gstack 9 关；
- checkpoint: reviewed → 通知"审查已完成，请查看结果"。

**Archive 阶段**——规格一致性验证（代码 vs specs 逐项对齐）→ 归档变更（archive，合并 specs）→ 清理状态 → checkpoint: archived → done → 通知"变更已归档，流程结束" → ECC 本能系统自动捕获本次会话知识。

### 6.3 断点恢复

**这里有个非常实用的能力——断点恢复。** 如果你跑到一半中断了，再次运行 `/hyperspec`，它会：读取状态文件 → 验证文件状态（以实际文件为 ground truth）→ 路由到断点 → 继续执行。

也就是说，**任何中途出错都不丢工作进度**。

### 6.4 典型场景示例

为了让大家有直观感受，我给三个典型场景：

**场景 1：新增一个字段（轻量审查）**——
`/opsx:propose` → proposal：为物料主数据新增"安全库存"字段 → 人工审核 1 分钟 → `/opsx:apply`：Entity 加字段 + getter/setter、DTO 加字段、Mapper XML 加映射（Service 和 Controller 无需改）→ Superpowers TDD 隐式生效、ECC 自动激活 → 审查路由判断（task=2, 模块=1, 无DDL）→ quick-review → 3 关全过。**总耗时：约 5 分钟**。

**场景 2：修一个 Bug（轻量审查）**——
`/opsx:propose` → proposal：修复库存出库数量校验错误 → `/opsx:apply`：修 Service 层校验逻辑 → TDD 先写失败测试复现 Bug，再修复，确认通过 → quick-review 3 关全过，隐性约定检查到位。**总耗时：约 3 分钟**。

**场景 3：新增一个业务模块（完整审查）**——
`/opsx:explore` 澄清需求 → `/opsx:propose` 生成 4 工件 → `gstack /office-hours` 灵魂拷问 → `gstack /plan-ceo-review` → `/superpowers:writing-plans` 拆细 → `gstack /plan-eng-review` → `/opsx:apply` 子代理并行 → 审查路由判断（task=12, 模块=3, 有DDL）→ gstack 完整 9 关 → `/opsx:archive`。**总耗时：约 30-60 分钟**。复杂任务理应投入更多审查时间，这是合理的。

---

## 第七部分：Harness 架构 0-1 搭建

**好，前面咱们讲的全是"是什么"和"怎么运转"。接下来的第七部分是重头戏——怎么从零开始搭建这套架构。**

这一部分的内容主要来自《Harness V2 落地实操手册》，我把里面的关键步骤展开跟大家过一遍。**对于手册里引用的外部文档（比如 ECC 插件市场、OMC 安装说明、HyperSpec 上游文档），咱们这里只简单提一下定位，不展开细节，大家需要的时候去对应手册查阅就行。**

### 7.1 准备阶段

搭建之前，先评估、再准备环境、最后建目录骨架。

#### 7.1.1 项目适配性评估

**首先，不是所有项目都适合上 Harness V2。** 咱们分三类：

✅ **强烈推荐**：Spring Boot / Java 后端项目（L4 有现成 ECC 技能）、中大型团队（≥ 3 人开发）、长期维护项目（≥ 6 个月）、多需求并发（≥ 2 个并发育）。

⚠️ **谨慎使用**：小脚本/一次性工具、全新项目还未定型（先跑 MVP 再说）、极简前端项目（L4 技能偏后端）。

❌ **不建议**：没有 git 仓库、团队对 Claude Code 完全陌生（先单独跑通 1-2 周）、强依赖图形界面的项目（Harness 是 CLI 驱动）。

#### 7.1.2 前置条件检查

在项目根目录跑 5 条命令，每条都得通过：

```bash
git status                                # 必须能输出当前分支
java -version                             # ≥ 1.8（推荐 JDK 17）
"/c/Program Files/JetBrains/IntelliJ IDEA 2025.3/plugins/maven/lib/maven3/bin/mvn.cmd" -v
claude --version                          # 必须 ≥ 2.0
mvn -q compile                            # 必须能编译
```

**特别提醒——如果项目编译不通过，先别上 Harness，把项目编译修好再来**。

#### 7.1.3 必装组件清单与环境搭建

需要的组件包括 Claude Code（≥ 2.0）、OpenSpec、Superpowers、gstack、HyperSpec、OMC MCP。具体安装方式咱们这里不展开，去实操手册的"环境搭建"章查看，里面有详细的一键安装脚本和验证命令。

**核心原则——任一组件 `/xxx --help` 报"command not found"，就回去重装对应组件。**

#### 7.1.4 目录骨架一键初始化

 Harness 推荐的标准目录结构长这样：

```
your-project/
├── .claude/
│   ├── settings.local.json          # 权限 + Hooks + MCP 配置
│   ├── hooks/                       # Hook 脚本
│   ├── commands/                    # Slash commands
│   ├── skills/                      # 技能库（L4 ECC）
│   ├── instincts/                   # L6 本能知识
│   └── team-roles/                  # 8 角色模板
├── openspec/                        # L1 规范层
├── superpowers/plans/               # L2 TDD 计划
├── docs/{architecture,database,standards,harness,help}/
├── AGENTS.md                        # 项目规范（最高优先级）
├── CLAUDE.md                        # Claude 协作指令
├── REVIEW.md                        # 审查清单
└── .hyperspec-state.yaml            # HyperSpec 状态文件
```

手册里提供了 `init-harness.sh` 一键脚本，可以一次性把所有目录和占位文件创建出来。验收清单也简单——目录树对了、根文件有了就行。

### 7.2 分层落地（L1-L7 逐层操作）

接下来咱们按层逐一落地。**每一层都遵循同一个套路——目标 → 操作步骤 → AI 自动补全提示词 → 验收。**

#### 7.2.1 L1 OpenSpec 规范层

**目标**——强制 4 工件顺序：`proposal → specs → design → tasks`，禁止跳步。

**操作步骤**——
1. 在项目根执行 `openspec init`；
2. 编辑 `openspec/config.yaml` 配置项目（详见后面"项目文档"章）；
3. `openspec validate` 验证。

**AI 自动补全**——你可以让 AI 探测项目实际技术栈（读 pom.xml / package.json / requirements.txt），把探测结果写入 `openspec/config.yaml`，同时在 `openspec/changes/` 下创建 README 说明用途、命名规范、归档时机，最后 `openspec validate` 通过后 commit。

**验收**——`openspec validate` 无报错、config.yaml 含实际技术栈、跑 `/opsx:propose "添加用户登录"` 能正常生成 proposal 工件。

#### 7.2.2 L2 Superpowers 纪律层

**目标**——把 TDD 红绿重构、子代理、完成验证焊进开发循环。

**操作步骤**——
1. `npx skills add obra/superpowers -y`；
2. 编辑 `.claude/settings.local.json`，标记两个核心技能 always_active：
   - `test-driven-development`
   - `verification-before-completion`

**AI 自动补全**——检查测试框架依赖（Maven 项目查 pom.xml 是否有 junit/mockito/spring-boot-starter-test，缺失则补），创建 `superpowers/plans/README.md` 说明用途，写一个测试样板文件 `.claude/skills/_templates/test-template.java`，包含 `@SpringBootTest`、`@MockBean` 注入示例。

**验收**——会话启动时显示 "test-driven-development active"；修改 `.java` 文件后 AI 自动建议先写测试。

#### 7.2.3 L3 双轨审查层

**目标**——`/quick-review`（3 关，2 分钟）+ `/full-review`（gstack 9 关，15 分钟）自动路由。

**操作步骤**——`npx skills add garrytan/gstack -y`，然后创建自建 quick-review skill。

**AI 自动补全**——创建 `.claude/skills/quick-review/SKILL.md`（3 关详细清单：语法、测试、安全）、创建 `.claude/commands/quick-review.md`（路由规则）、在根 `REVIEW.md` 写入双轨对比表和 9 关清单。

**验收**——`/quick-review` 在小改动后能跑出 3 关报告，`/full-review` 在大改动后能跑出 9 关报告。

#### 7.2.4 L4 ECC 技能层（Spring Boot 专用）

**目标**——为 Spring Boot / JPA / Java 项目注入领域知识技能。

**操作步骤**——通过 Claude Code 内的 `/plugin marketplace add affaan-m/everything-claude-code` 和 `/plugin install ecc@ecc` 安装，然后选择性激活技能。**这部分的插件市场详细文档大家去 ECC 上游项目查阅即可，这里不展开。**

**AI 自动补全**——读 pom.xml 识别实际依赖（Spring Boot 版本、ORM 类型、数据库类型、是否有 Docker/K8s），按需激活：
- springboot-patterns（必装）、springboot-tdd（必装）、api-design（必装）、backend-patterns（必装）；
- springboot-security（如有 spring-security 依赖）；
- jpa-patterns / mysql-patterns / postgres-patterns（按需）；
- docker-patterns / deployment-patterns（如有 CI/CD 配置）。

另外，建议在 `.claude/skills/_project_specific/SKILL.md` 里记录项目特有业务术语、模块边界、内部库。

#### 7.2.5 L5 OMC MCP 工具精度层

**目标**——把 LSP（hover/goto-def/references）和 AST（grep/replace）工具暴露给 Claude。

**操作步骤**——通过 `/plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode` 和 `/plugin install oh-my-claudecode` 安装，跑 `/oh-my-claudecode:setup`。**OMC 上游的安装细节这里也不展开。**

**AI 自动补全**——核心是在 `.claude/settings.local.json` 的 `mcpServers` 字段配置 OMC 暴露的工具（lsp_hover / lsp_goto_definition / lsp_find_references / lsp_diagnostics / lsp_completion / lsp_rename / ast_grep_search / ast_grep_replace / python_repl）。Java 项目要探测 jdtls（Eclipse JDT Language Server）的安装路径，写入 MCP 配置的 args。

**配置关键点**——JAVA_HOME、PATH 必须正确指向你的 JDK 和 jdtls 启动器路径，比如：
- `JAVA_HOME`: 指向你的 JDK 安装路径
- jdtls 启动器：`redhat.java` 扩展下的 `server/bin/jdtls.bat`

**验收**——会话中能用 `lsp_hover` 查看类定义，能用 `ast_grep_search` 找出所有 `@RestController` 类。

#### 7.2.6 L6 ECC 本能层

**目标**——跨会话积累项目知识，下次启动自动加载。

**操作步骤**——本能层是运行时生成的，无需手动初始化，但要创建 `.claude/instincts/` 目录，并配置 SessionStart / SessionEnd hook。

**AI 自动补全**——在 `.claude/instincts/` 创建 6 个骨架文件（每个 ≤ 200 字）：
- `project-overview.md`——项目一句话定位、核心模块、技术栈；
- `business-glossary.md`——业务术语速查（中文+英文+一句话定义）；
- `tech-decisions.md`——关键技术决策；
- `known-pitfalls.md`——已知坑；
- `module-boundaries.md`——模块边界；
- `testing-conventions.md`——测试规范。

然后配置 SessionEnd hook 调用 `/instinct-export` 自动捕获新知识；SessionStart hook 加载所有 instincts。

**验收**——`instincts/` 下有 6 个骨架文件、会话启动显示 "loaded N instincts"、一次会话结束后 instincts 出现新内容。

#### 7.2.7 L7 HyperSpec 编排层

**目标**——12 checkpoint 状态机 + 断点恢复 + 一键全自动。

**操作步骤**——`npx skills add wind7rui/HyperSpec -y`，初始化 `.hyperspec-state.yaml`，试用 `/hyperspec "添加用户登录功能"`。

**AI 自动补全**——核心是把 12 个 checkpoint 详细的触发条件、上一 checkpoint（前置）、下一 checkpoint、通知消息、失败回退写到 `docs/harness/l7-checkpoints.md`，让 AI 自己理解状态机。**HyperSpec 上游的状态机详细文档这里不展开。**

12 个 checkpoint 复习一下：profiler-done → requirements-confirmed → openspec-generated → plan-generated → plan-generated-and-confirmed → task-N-complete → verified → reviewed → apply-done → consistency-verified → archived → done。

**验收**——`/hyperspec "测试需求"` 能跑通至少 5 个 checkpoint；中途 Ctrl+C 后再次运行能从断点继续。

#### 7.2.8 横切层 —— 安全保护层（4 个 Hook）

**目标**——4 个核心 Hook 防止 AI 越界。

**操作步骤**——创建 4 个 Hook 脚本：

1. **`guard_write.py`**（PreToolUse）——每次 Edit/Write 前触发。拦截规则：application.yml / application.properties 必须人工确认；`db/migration/` 必须人工确认；`sql/` 必须人工确认；财务相关包必须人工确认。白名单通过环境变量 `HARNESS_ALLOW_WRITE=1` 跳过。

2. **`ensure_change_context.py`**（PreToolUse）——每次 Bash 前触发。规则：若 `openspec/changes/` 为空（无 active change），阻止 `git push` / `git commit --amend` / `git reset --hard` / `mvn deploy` / `docker push` / 数据库迁移命令。

3. **`run_checks.sh`**（PostToolUse）——每次 Edit/Write 后触发。规则：如果改的是 `.java` 文件，自动跑 `mvn -q compile`，失败则打印错误要求修复。**注意要使用项目指定的 Maven 路径**——`/c/Program Files/JetBrains/IntelliJ IDEA 2025.3/plugins/maven/lib/maven3/bin/mvn.cmd`。

4. **`apply-role.sh`**（SessionStart）——根据 `.hyperspec-state.yaml` 的 `current_role` 加载对应角色配置（这个后面讲 Agent Team 时还会再细讲）。

最后在 `.claude/settings.local.json` 注册这 4 个 hook，绑定正确的 event。

**验收**——试图改 `application.yml` 时被拦截、改 `.java` 文件后自动跑编译检查、没有 active change 时 `git push` 被拦截。

#### 7.2.9 横切层 —— 模型路由层

**目标**——按 checkpoint 复杂度路由模型，省 token。

**操作步骤**——编辑 `openspec/config.yaml` 添加 routing 段。核心配置长这样：

```yaml
model_routing:
  default: sonnet                    # 默认模型，性价比最高
  by_checkpoint:
    propose: opus                    # 需求生成需要最强推理
    requirements-clarify: opus       # 多轮对话需要理解力
    specs-draft: sonnet              # 规格生成中等复杂度
    design-draft: opus               # 架构设计需要全局视角
    tasks-decompose: sonnet          # 任务拆解中等
    task-execute: sonnet             # 编码中等（TDD 已约束）
    task-execute-complex: opus       # 复杂 task（如重构）
    review-quick: sonnet             # 3 关审查中等
    review-full: opus                # 9 关审查需要深度
    test-run: haiku                  # 跑测试无需智能
    archive: haiku                   # 归档无需智能
    debug: opus                      # 调试需要推理
  by_role:                           # 单实例多角色模式（后面讲）
    pm: opus
    architect: opus
    tech-lead: sonnet
    developer: sonnet                # 默认
    developer-complex: opus          # 复杂 task 自动升级
    reviewer: opus                   # 审查者必须 opus，避免共谋
    tester: sonnet
    devops: sonnet
    team-lead: haiku                 # 协调者用便宜模型
```

**为什么这么选**——
- propose 用 opus：需求理解错了后面全错；
- reviewer 必须用 opus：避免和 Developer 共谋；
- team-lead 用 haiku：决策简单，省 token。

**验收**——config.yaml 有 model_routing 段；跑 `/hyperspec` 时 proposal 阶段用 opus、archive 阶段用 haiku（看日志确认）。

### 7.3 项目文档 AI 自动补全（核心）

**这一部分是整个落地手册的核心。**为什么？因为前面的分层是"骨架"，而项目文档是"血肉"——只有把项目实际的技术栈、规范、业务术语、架构信息文档化，AI 才能真正像"自己人"一样干活。

手册里给出了 **8 类项目文档** 的 AI 自动补全提示词。我快速过一遍，每一类大家记住它的定位就行——**核心原则都是：让 AI 读项目实际代码生成，不要凭空编。**

#### 7.3.1 AGENTS.md —— 项目规范（最高优先级）

`AGENTS.md` 是 AI 协作的**最高优先级指令**，会覆盖默认行为。所有 AI agent 启动时第一时间读这个文件。

**模板骨架包含**——项目定位、技术栈（强制版本）、模块边界（红线：禁止修改 / 谨慎修改 / 自由修改）、业务术语、编码规范、验证命令、禁止事项（如：不允许硬编码密码、不允许在 Controller 直接写 SQL、不允许 System.out.println、不允许 @Autowired 字段注入）。

**AI 自动补全要点**——
1. 探测项目实际技术栈（pom.xml 提取 Spring Boot/ORM/数据库驱动版本，application.yml 提取数据库类型，pom.xml 提取 JDK 版本）；
2. 探测项目模块结构（src/main/java 下的包结构深度 3 层，识别业务包 vs 工具/配置包）；
3. 探测编码规范现状（抽查 5 个 Controller、5 个 Service、3 个 Entity、测试目录）；
4. 基于探测结果填充模板——**版本必须和 pom.xml 一致**，模块边界按"业务包 vs 工具包"区分，业务术语探测不到就列出 5 个最常见业务实体名让用户确认；
5. 验证命令用项目实际能跑通的（有 Maven Wrapper 优先用 `./mvnw`，没有 checkstyle 就从清单删掉）。

**关键提醒**——不要凭空编造版本号；不要塞项目没有的工具；探测失败写 TODO 标记。

#### 7.3.2 CLAUDE.md —— Claude 协作指令

`CLAUDE.md` 是 Claude Code 专用的协作指令，**用户全局指令 + 项目指令双层**。项目级优先级高于全局。

**模板骨架包含**——协作规则（始终用中文、计划结束不跑 npm build、不写无意义注释）、Maven 路径、OpenSpec 工作流规则（强调先需求后设计、先 WHAT 后 HOW）、当前日期。

**AI 自动补全要点**——
1. 读取 `~/.claude/CLAUDE.md`（用户全局指令）拷过来；
2. 添加项目特定规则（Maven 路径、JDK 路径、项目语言）；
3. **完整包含 OpenSpec 工作流规则**——4 工件强制顺序、specs 必须在 design 之前；
4. 探测项目实际命令（启动 / 测试 / 打包）；
5. 探测项目目录约定。

**关键提醒**——不要和 AGENTS.md 重复（AGENTS.md 偏规范，CLAUDE.md 偏协作）；不要塞入会变的信息（如 git 分支名）；保持简洁，超过 100 行就太长了。

#### 7.3.3 REVIEW.md —— 审查清单

`REVIEW.md` 是代码审查的标准清单，被 `/quick-review` 和 `/full-review` 引用。

**模板骨架包含**——
- 双轨审查路由表（触发条件 → 走哪条）；
- **quick-review 3 关**：语法（编译通过、无未使用 import、命名规范、无 System.out.println）、测试（新代码有测试、所有测试通过、覆盖核心分支、Mock 使用规范）、安全（无硬编码密码、无 SQL 拼接、权限校验完整、敏感数据日志脱敏）；
- **full-review 9 关**：架构、API 设计、数据访问、异常处理、性能、可维护性（前 6 关 + 项目特有关）；
- 项目特有关（按需）：业务规则、兼容性。

**AI 自动补全要点**——
1. 探测项目现状（pom.xml 是否有 checkstyle/spotbugs/jacoco，是否有 GlobalExceptionHandler/@ControllerAdvice，是否启用 @EnableWebSecurity，抽查 Service 看 @Transactional 习惯）；
2. 基于探测调整审查清单（项目用 MyBatis 而非 JPA → "数据访问"关改为 MyBatis 相关；项目没有 Security → "安全"关简化；项目有 checkstyle → "语法"关加 "checkstyle 通过"）；
3. 添加项目特有关（财务系统加"金额计算必须用 BigDecimal"，审批系统加"审批节点不能跳过"，报表系统加"权限过滤必须包含部门维度"）；
4. 引用 AGENTS.md 的"禁止事项"，把它们都列入审查清单。

**关键提醒**——清单要可执行（能跑命令或读代码判断），不要写"代码要好"这种空话；每项要能机器验证或人工快速判断；控制在 80 行以内。

#### 7.3.4 openspec/config.yaml —— 模型路由配置

OpenSpec 的项目级配置，包含模型路由、技能激活、schema 自定义、保护路径、通知。

**完整模板**——
- `project`：项目名称、版本、类型（spring-boot/node/python/other）、语言、构建工具；
- `tech_stack`：框架及版本、ORM 及版本、数据库、Java 版本；
- `model_routing`：前面 7.2.9 那段；
- `skills_activation`：默认激活 springboot-patterns/springboot-tdd/jpa-patterns/api-design/database-migrations/quick-review；
- `schema_customization`：proposal/specs/design/tasks 各自必需的 section；
- `protected_paths`：默认包含 application.yml/db/migration/sql，加扫描出的核心业务包；
- `notification`：在 openspec-generated/plan-generated-and-confirmed/reviewed/archived 这 4 个 checkpoint 通知。

**AI 自动补全要点**——必须基于实际探测（pom.xml、application.yml、db/migration/ 目录）；protected_paths 扫描 src/main/java 找"核心业务包"（看 @Transactional 集中的包）加入保护；skills_activation 探测到 Spring Security 加 springboot-security、探测到 Docker 加 docker-patterns；最后 `openspec validate` 必须通过。

#### 7.3.5 docs/architecture/ —— 架构文档群

向 AI 提供项目全局架构视角，避免"只见树木不见森林"。包含 5 个文件：
- `overview.md`——架构总览（C4 Context 级 mermaid 图）；
- `modules.md`——模块依赖关系图（基于实际 import 语句）；
- `layers.md`——分层架构（基于抽样 5 个 Controller/Service/Mapper）；
- `data-flow.md`——核心业务数据流（识别 3-5 个核心用例画 sequence diagram）；
- `decisions.md`——ADR 架构决策记录（基于代码证据，不瞎编）。

**关键提醒**——不要凭空写"未来可能扩展到微服务"——只写已经存在的事实；mermaid 图必须能渲染；ADR 必须基于代码证据；每个文件控制在 100 行以内。

#### 7.3.6 docs/database/ —— 数据库文档群

让 AI 改 SQL/Entity 时理解数据库全局。包含 4 个文件：
- `schema.md`——表清单 + ER 图（mermaid erDiagram，≤ 30 个实体）；
- `conventions.md`——命名规范、字段类型规范（基于现有表总结，不是教科书）；
- `migrations.md`——迁移脚本规范（Flyway/Liquibase）；
- `indexes.md`——索引清单 + 设计依据。

**关键提醒**——只读不写，不修改实际数据库；表结构以代码事实为准（migration 文件 > entity 注解）。

#### 7.3.7 docs/standards/ —— 编码规范群

细化的编码规范，被 ECC 技能和 Review 引用。包含 5 个文件：
- `java.md`——Java 规范（基于项目实际，不照搬阿里巴巴规范）；
- `spring.md`——Spring Boot 规范（强制/选择，比如构造器注入是强制，@Transactional 加在 Service 还是 Method 是选择）；
- `mybatis.md` 或 `jpa.md`——ORM 规范（按项目选）；
- `testing.md`——测试规范（命名 AAA 结构、覆盖目标）；
- `naming.md`——命名规范（后缀含义表、命名禁忌、中文映射）。

**关键提醒**——基于项目现状，不是教科书；如果项目实际做法"不规范"，先记录现状，再标记"建议改进"；每个文件 ≤ 80 行。

#### 7.3.8 docs/harness/ —— Harness 自文档

把 Harness 配置本身文档化，让新人（包括 AI）理解项目用了 Harness 的哪些能力。包含 6 个文件：
- `overview.md`——Harness 落地总览（7 层架构落地清单表）；
- `commands.md`——项目可用 slash 命令速查（按使用频率排序）；
- `hooks.md`——Hook 清单 + 拦截规则（哪些是硬拦截、哪些是软提醒）；
- `skills.md`——激活的技能清单 + 触发条件；
- `workflow.md`——一次完整需求的工作流（用真实例子）；
- `troubleshooting.md`——常见问题排查（10 个高频问题）。

**关键提醒**——文档要真实反映项目状态（探测失败就写"未启用"，不要瞎编）；命令清单按项目实际安装的为准；workflow 用真实例子，不要套模板。

### 7.4 完整流程跑通（真实需求演示）

文档全部生成完，咱们就可以用真实需求跑一次完整流程了。手册里给的演示需求是 **"MDM 新增变体视图维护 PLM 继承接口"**，跑通 12 个 checkpoint。

整体步骤是这样的——

**Step 1：确认 Harness 就绪**——`cd your-project` → `claude`。

**Step 2：提需求**——`/opsx:explore 1.md` 采用需求澄清命令对话，持续对话澄清，直到 claude 输出最终确认方案。**这一步就是 PM 在干活。**

**Step 3：工件生成**——确认方案后直接 `/hyperspec`（无需带具体内容，有上下文），AI 自动跑完工件生成阶段，自动拆分 task，生成 TDD 计划。

**Step 4：审核工件**——确认 task 任务没问题后，给"继续（apply）"命令。

**Step 5：执行 task**——AI 按 task 顺序执行，每个 task 走 TDD（红→绿→重构），每个 task 完成后 auto commit。checkpoint 链：task-1-complete → task-2-complete → ... → task-N-complete。

**Step 6：验证**——跑所有测试，checkpoint: verified。

**Step 7：审查**——AI 自动按 task 数选择 `/quick-review` 或 `/full-review`，checkpoint: reviewed。

**Step 8：人工审查**——查看 AI 输出的审查报告。

**Step 9：应用 + 归档**——checkpoint: apply-done → consistency-verified → archived → done。

**中途出问题怎么办？**——AI 卡在某个 checkpoint：Ctrl+C 重新跑 `/hyperspec` 从断点继续；Hook 误拦截：看错误信息调整 hook 规则；测试不通过：AI 自动修复最多 3 轮，超过则人工介入；审查不通过：AI 按 review 报告修复最多 3 轮。

### 7.5 常见问题排查

最后给一份排错速查表，**大家遇到问题可以快速对照**：

**环境问题**——`mvn: command not found` 用全路径；`claude: command not found` 用 `npm i -g @anthropic-ai/claude-code` 重装；JAVA_HOME 不对 `export JAVA_HOME=/d/jdk1.8.0_171`；`/opsx:explore` 不识别用 `npm i -g @fission-ai/openspec` 重装。

**流程问题**——`/hyperspec` 一开始报错：删除 `.hyperspec-state.yaml` 重跑；跑到一半 AI 退出：重新跑 `/hyperspec` 从断点继续；Hook 把所有 Edit 都拦了：临时 `export HARNESS_ALLOW_WRITE=1`；AI 用了 opus 跑 archive：检查 openspec/config.yaml 模型路由。

**文档问题**——AI 不遵守 AGENTS.md：精简到 80 行内、删和 CLAUDE.md 重复的部分；AI 用错 Spring Boot 版本：重新生成 AGENTS.md；审查清单不适用项目：重新生成 REVIEW.md。

**调试技巧**——`cat .hyperspec-state.yaml` 看状态；`grep "model" ~/.claude/logs/{latest}.log` 看模型使用；`cat .claude/hooks.log` 看 hook 触发；`python .claude/hooks/guard_write.py <test-path>` 手动跑 hook；`openspec list / openspec validate` 看 OpenSpec 状态。

---

## 第八部分：Agent Team 角色编排层（L7 扩展维度）

**好，前面咱们讲完了 7 层架构和落地。但是这里还有一个非常关键的问题没回答——一个真实需求进来，谁负责把业务语言翻译成技术语言？谁拆任务？谁写代码？谁把关？谁发布？**

这就引出了第八部分——**Agent Team 角色编排层**。这是 L7 HyperSpec 的扩展维度。

### 8.1 设计动机：从"单 Agent 跑流程"到"角色团队接需求"

前面 7 层解决了 **AI 怎么不被搞砸**（Rule/Spec/Loop/Harness），但没有显式回答一个问题：

> 一个真实需求进来，谁负责把业务语言翻译成技术语言？谁拆任务？谁写代码？谁把关？谁发布？

**传统软件团队里这些职责是由不同角色承担的**——PM、架构师、开发、测试、运维，他们各有专业视角，相互制衡。

Harness 默认让一个 Claude 实例从头干到尾，会导致两个严重问题——
- **PM 视角与 Developer 视角混淆**——写代码时还在纠结需求边界；
- **Reviewer 角色缺失独立判断**——自己写的代码自己审。

**Agent Team 角色编排层**就是在 L7 HyperSpec 之上加一个维度：每个 checkpoint 分配给特定角色，每个角色加载专属的 prompt + skills + 工具权限 + 模型，形成端到端接力。

### 8.2 核心设计原则

| 原则 | 含义 |
|------|------|
| **单实例角色切换** | 不引入真多 agent 框架，同一 Claude 按 checkpoint 切换"角色帽子"，加载对应配置 |
| **上下文隔离** | 每个角色只看自己职责相关的上下文，避免视角污染 |
| **工具权限分层** | Reviewer 只读、Developer 可写（受 guard_write 保护）、DevOps 可 commit |
| **工件交接** | 角色之间通过标准工件（proposal/specs/design/tasks）传递，不靠记忆 |
| **回退机制** | Reviewer 可打回 Developer，PM 可拒绝 Architect 的 specs |

这里我要特别强调一下"**单实例角色切换**"——**我们不引入真的多 agent 框架，而是同一个 Claude 按 checkpoint 切换"角色帽子"，加载对应配置**。这点很重要，决定了后面所有的实现方式。

### 8.3 八个角色定义

我们定义了 8 个角色，每个角色我从五个维度介绍——职责、主导 checkpoint、加载技能、工具权限、推荐模型。

#### 角色 1：PM 产品经理

- **职责**：业务需求分析、变更动机澄清、边界定义；
- **主导 checkpoint**：`proposal-draft`；
- **加载技能**：requirements-analysis、business-domain；
- **工具权限**：Read/Grep/Glob（**只读，不能改代码**）；
- **推荐模型**：opus（深度业务理解）；
- **输入 → 输出**：业务需求描述/用户故事/历史 proposal → `proposal.md`。

#### 角色 2：Architect 架构师

- **职责**：技术方案设计、API 契约定义、数据库建模；
- **主导 checkpoint**：`proposal-review`、`specs-draft`、`design-draft`；
- **加载技能**：springboot、jpa、api-design、ddd、architecture-patterns；
- **工具权限**：Read/Grep/Glob + LSP（看现有代码结构）+ AST 搜索；
- **推荐模型**：opus；
- **输入 → 输出**：proposal.md/现有代码/历史 design → `specs.md`、`design.md`。

#### 角色 3：Tech Lead 技术负责人

- **职责**：任务拆解、依赖分析、风险识别、估时；
- **主导 checkpoint**：`tasks-draft`；
- **加载技能**：task-decomposition、estimation、risk-analysis；
- **工具权限**：Read/Grep/Glob + LSP；
- **推荐模型**：sonnet；
- **输入 → 输出**：design.md → `tasks.md`（每个 task 边界清晰、可独立验证）。

#### 角色 4：Developer 开发

- **职责**：TDD 编码实现（红绿重构 5 步循环）；
- **主导 checkpoint**：`task-N-tdd`（N = 1, 2, 3, ...）；
- **加载技能**：springboot、jpa、mybatis、vue（按文件类型自动激活）；
- **工具权限**：Edit/Write（**受 guard_write 保护**）、Bash（运行测试）、LSP goto_def、AST；
- **推荐模型**：sonnet（标准）/ opus（复杂任务）；
- **强约束**：TDD 红绿循环、每个 task 5 步、**不能跨 task 改代码**；
- **输入 → 输出**：tasks.md（当前 task）+ 相关代码 → 生产代码 + 测试代码。

#### 角色 5：Reviewer 代码审查员

- **职责**：质量把关、规格合规、安全审查（**不写代码**）；
- **主导 checkpoint**：`task-N-review`、`final-review`；
- **加载技能**：code-review、security-review、simplify；
- **工具权限**：**完全只读**——Read/Grep/Glob/LSP，**不能 Edit/Write**；
- **推荐模型**：**opus**（独立审查视角，避免与 Developer 同模型"共谋"）；
- **输入 → 输出**：task 代码 diff + specs/design（合规对照） → `review-report.md`（通过/打回 + 具体理由 + 修改建议）。

#### 角色 6：Tester 测试

- **职责**：集成测试、边界测试、验收测试；
- **主导 checkpoint**：`integration-test`、`acceptance-test`；
- **加载技能**：integration-test、boundary-test、test-design；
- **工具权限**：Bash（运行测试）、Read（看测试结果）、**不能改生产代码**；
- **推荐模型**：sonnet；
- **输入 → 输出**：所有 task 完成/测试套件 → `test-report.md`（通过率、失败用例、覆盖率）。

#### 角色 7：DevOps 发布

- **职责**：归档、变更记录、版本发布；
- **主导 checkpoint**：`archive-draft`、`archive-apply`；
- **加载技能**：deployment、changelog、release-management；
- **工具权限**：Edit（**仅 docs/changelog**）、Bash（git commit、CI 触发）；
- **推荐模型**：sonnet；
- **输入 → 输出**：所有工件/review-report/test-report → `CHANGELOG.md`、git commit + tag、release notes。

#### 角色 8：Coordinator 协调员（Scrum Master）

- **职责**：贯穿全程，推进 checkpoint、断点恢复、冲突升级、通知回调；
- **主导 checkpoint**：**所有阶段**（meta 角色，不直接产出业务工件）；
- **加载技能**：hyperspec、orchestration、conflict-resolution；
- **工具权限**：HyperSpec 状态机读写、通知系统；
- **推荐模型**：**haiku**（轻量决策，省 token）；
- **输入 → 输出**：当前 checkpoint 状态/角色反馈 → checkpoint 转移、升级报告、人类介入请求。

### 8.4 Checkpoint × Role 映射表

把这 8 个角色串到 12 个 checkpoint 上，就是这张表：

| 阶段 | Checkpoint | 主导角色 | 协作角色 | 输入 → 输出 |
|------|-----------|---------|---------|------------|
| Propose | `proposal-draft` | **PM** | Architect（咨询） | 业务需求 → proposal.md |
| Propose | `proposal-review` | **Architect** | PM | proposal.md → 通过/打回 |
| Apply | `specs-draft` | **Architect** | PM | proposal.md → specs.md |
| Apply | `design-draft` | **Architect** | Tech Lead | specs.md → design.md |
| Apply | `tasks-draft` | **Tech Lead** | Architect | design.md → tasks.md |
| Apply | `task-N-tdd` | **Developer** | Tester（验收） | task → 代码+测试 |
| Apply | `task-N-review` | **Reviewer** | — | 代码 → review 通过/打回 |
| Apply | `integration-test` | **Tester** | Developer | 全部 task → test-report |
| Apply | `final-review` | **Reviewer** + **Architect** | — | 全部 → 最终批准 |
| Archive | `archive-draft` | **DevOps** + **PM** | — | 工件 → CHANGELOG |
| Archive | `archive-apply` | **DevOps** | Coordinator | 全部 → git commit |
| 全程 | 状态推进 | **Coordinator** | — | checkpoint 转移 |

### 8.5 工件交接流（Handoff Pipeline）

```
   业务需求（用户/PM 输入）
        │
        ▼ [PM 接力]
   proposal.md（变更动机 + 边界）
        │
        ▼ [Architect 接力]
   specs.md → design.md（规格 + 技术方案）
        │
        ▼ [Tech Lead 接力]
   tasks.md（可执行任务清单）
        │
        ▼ [Developer 循环 × N]
   task-1 代码+测试 → task-2 → ... → task-N
        │
        ▼ [Reviewer 把关 × N]
   review-report.md（每个 task 通过/打回）
        │
        ▼ [Tester 集成]
   test-report.md（集成测试 + 验收）
        │
        ▼ [Reviewer + Architect 最终批准]
   final-approval
        │
        ▼ [DevOps 收尾]
   CHANGELOG.md + git commit + tag
```

**这一套最关键的设计是什么？——每个工件是下一角色的唯一输入契约**，不依赖任何"上下文记忆"或"上次对话"。这让流程**可断点恢复、可审计、可回退**。

### 8.6 工具权限矩阵

| 角色 | Edit/Write | Bash | Read/Grep | LSP/AST | git commit | CI 触发 |
|------|:---------:|:----:|:---------:|:-------:|:----------:|:-------:|
| PM | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ |
| Architect | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| Tech Lead | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| Developer | ✓（受 guard） | ✓（run_tests） | ✓ | ✓ | commit only | ✗ |
| Reviewer | ✗（只读） | ✗ | ✓ | ✓ | ✗ | ✗ |
| Tester | ✗ | ✓（run_tests） | ✓ | ✗ | ✗ | ✗ |
| DevOps | ✓（仅 docs） | ✓ | ✓ | ✗ | ✓ | ✓ |
| Coordinator | ✗ | ✓（hyperspec） | ✓ | ✗ | ✗ | ✗ |

**Reviewer 严格只读** 是关键设计——避免"自己写自己审"的共谋问题。Reviewer 用 opus 模型 + 与 Developer（sonnet）不同的模型，进一步保证独立性。

### 8.7 上下文隔离规则

每个角色切换时，HyperSpec 自动清空无关上下文，只加载该角色需要的：

| 角色 | 加载上下文 | 清空上下文 |
|------|-----------|-----------|
| PM | 业务需求、历史 proposal | 代码细节、技术实现 |
| Architect | proposal、现有代码结构、历史 design | 业务原始描述 |
| Tech Lead | design.md、模块依赖图 | 业务背景、代码细节 |
| Developer | 当前 task、相关代码、TDD 纪律 | 业务需求、其他 task |
| Reviewer | 代码 diff、specs/design（合规对照）、安全清单 | 业务背景、开发思路 |
| Tester | 测试套件、验收标准 | 实现细节 |
| DevOps | 全部工件、发布历史 | 业务需求细节 |

**好处**：避免"PM 思维污染 Developer 决策"、"Developer 思维污染 Reviewer 判断"。

### 8.8 回退与升级机制

| 触发条件 | 回退到 | 触发者 |
|---------|-------|-------|
| Reviewer 打回 task | `task-N-tdd`（重做） | Reviewer |
| Tester 发现集成 bug | `task-N-tdd`（指定 task） | Tester |
| PM 拒绝 specs | `specs-draft`（重写） | PM |
| Architect 发现 proposal 不可行 | `proposal-draft`（重定义边界） | Architect |
| 角色之间冲突（如 Developer 与 Reviewer 争执） | 升级给 Coordinator | 任意角色 |
| Coordinator 无法决策 | 请求人类介入 | Coordinator |

### 8.9 与现有 7 层架构的关系

最后说一个关键认知——**Agent Team 不是新的第 8 层，而是 L7 HyperSpec 的扩展维度**：

```
原 HyperSpec：1D 编排（checkpoint 顺序）
   propose → apply → archive

加 Team 后：2D 编排（checkpoint × role）
   propose(PM→Architect) → apply(Architect→TechLead→Developer→Reviewer→Tester) → archive(DevOps)
```

每个角色实际上是 **7 层架构的特定配置组合**：

| 角色配置项 | 来源层 |
|-----------|-------|
| 角色的技能子集 | L4 ECC 技能库 |
| 角色的工具权限 | L5 OMC MCP + L3 审查层 |
| 角色的历史经验 | L6 ECC 本能 |
| 角色的 TDD 纪律 | L2 Superpowers |
| 角色遵循的规格 | L1 OpenSpec 工件 |
| 角色的推进状态 | L7 HyperSpec |
| 角色的安全约束 | 安全保护层 Hooks |
| 角色的模型选择 | 模型路由层 |

所以**角色编排不是"另起炉灶"，而是把已有 7 层架构按角色切片重组**。

### 8.10 典型场景：一个新需求进来时

需求：财务系统新增"按部门统计月度报销"功能。

| 阶段 | 角色 | 产出 |
|------|------|------|
| 1 | **PM** 介入 | proposal.md：动机=财务月报自动化；边界=只读统计、不改报销流程 |
| 2 | **Architect** 介入 | specs.md（验收标准：6 个 Given-When-Then）+ design.md（新增 DeptStatsService + 复用 ReportExporter） |
| 3 | **Tech Lead** 介入 | tasks.md 拆为 4 个 task：DTO 定义 / Service 实现 / Controller 接口 / 前端图表 |
| 4 | **Developer** 循环 4 次 | 每个 task 走 TDD 红绿重构，产出代码 + 单元测试 |
| 5 | **Reviewer** 把关 4 次 | 每个 task 审查规格合规 + 安全 + 命名规范 |
| 6 | **Tester** 介入 | 跑集成测试、跨模块回归、性能基准 |
| 7 | **Reviewer + Architect** 最终批准 | 检查整体架构一致性 |
| 8 | **DevOps** 收尾 | CHANGELOG、git commit、CI 触发、tag |
| 全程 | **Coordinator** 推进 | 12 个 checkpoint 状态转移、断点保护 |

**整个过程对用户来说就是一句 `/hyperspec propose "财务月报按部门统计"`，背后 8 个角色按 checkpoint 顺序接力完成。**

---

## 第九部分：Agent Team 落地搭建

讲完了原理，最后这部分咱们看怎么把 Agent Team 落地。**核心是采用"单实例多角色"方案。**

### 9.1 为什么是单实例多角色（不是多 agent）

| 维度 | 单实例多角色（本项目采用） | 多 agent + A2A（不采用） |
|------|-------------------------|------------------------|
| Claude 会话数 | **1** | N（每角色独立 `claude -p` 子进程） |
| 协调者 | 主会话自身 + checkpoint 状态机 | 外部 Python 编排器 |
| 角色切换 | 加载新 system prompt + 清理上下文 | fork 新进程 |
| 真并行 | 否（串行切换） | 是 |
| 复杂度 | 低（复用 HyperSpec） | 高（需 Python 编排器 + Workspace + 锁） |
| 适用场景 | **绝大多数项目** | ≥ 3 并发育求 + 单需求 ≥ 8 task |

**单实例的核心收益**（也是它够用的原因）：
- **上下文隔离**：每次切换角色清空上一角色的视角，避免"Developer 视角污染 Reviewer 判断"；
- **工具权限分明**：Reviewer 只读、Developer 可写、DevOps 可发布；
- **工件驱动交接**：角色间通过 `proposal.md → specs.md → design.md → tasks.md` 流转，不靠口头沟通。

**绝大多数项目永远不需要升级到多 agent**——单实例多角色已覆盖 95%+ 场景。

### 9.2 角色配置文件结构

每个角色对应一个配置文件 `.claude/team-roles/{role}.md`，结构如下（以 Developer 为例）：

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

### 9.3 角色激活与切换机制

**机制**：HyperSpec 在推进每个 checkpoint 时，根据 Checkpoint × Role 映射表自动切换角色。

**切换动作**（由 Coordinator 角色 + HyperSpec 协作完成）：

1. 写 `.hyperspec-state.yaml`：
   ```yaml
   current_role: developer
   current_checkpoint: task-3-complete
   role_context:
     loaded_skills: [springboot-tdd, jpa-patterns]
     allowed_tools: [Read, Grep, Edit, Write, Bash]
     model: sonnet
   ```

2. SessionStart hook（`apply-role.sh`）读取 `current_role`，注入对应 `.claude/team-roles/{role}.md` 的指令到当前会话；

3. 若 `context_cleanup_on_enter: true`：
   - Coordinator 角色发出 `/compact` 信号；
   - 把上一角色的中间结论压缩为简短摘要；
   - 加载新角色 system prompt；

4. HyperSpec 推进到下一 checkpoint 时，重复 1-3。

### 9.4 工具权限矩阵（permissions.json）

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

**强制点**：`guard_write.py`（安全保护层）在每次 Edit/Write 时读 `current_role`，按此矩阵拦截越权操作。

### 9.5 上下文隔离与切换冲突

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

### 9.6 回滚机制

任意 checkpoint 失败或角色判断错误，可回滚：

```bash
/coordinator rollback              # 回到上一 checkpoint
/coordinator rollback-to task-2-complete    # 回到指定 checkpoint
/coordinator reset                 # 紧急重置（保留 artifacts，清空状态）
```

**回滚安全性**：
- artifacts 是 git 提交的，回滚状态机不丢工件；
- 已发布的 git tag 不会被回滚覆盖（DevOps 重做时强制 bump 版本）。

### 9.7 创建 8 角色配置（落地步骤）

具体落地时，让 AI 一次性生成所有配置：

1. 在 `.claude/team-roles/` 下创建 8 个角色文件（pm.md / architect.md / tech-lead.md / developer.md / reviewer.md / tester.md / devops.md / coordinator.md），每个文件包含 frontmatter + 你的视角 + 红线 + 标准流程 + 输出；

2. 创建 `.claude/team-roles/permissions.json`（按 9.4 矩阵），**关键——基于 AGENTS.md 的"模块边界"调整每个角色的 denied**，财务模块等红线对 Architect/Developer/Reviewer 全部 denied；

3. 探测项目实际，调整角色定义——Spring Boot + JPA 给 Developer 加 jpa-patterns；Spring Boot + MyBatis 给 Developer 加 mybatis-patterns；有 Spring Security 给 Architect 加 springboot-security；项目用 Maven 则把所有 bash 权限中的 npm 改为 mvn；

4. 修改 `.claude/hooks/apply-role.sh`——SessionStart 时读取 `.hyperspec-state.yaml` 的 current_role，把 `.claude/team-roles/{current_role}.md` 内容追加到 system prompt，current_role 为空时加载 coordinator.md 作为默认；

5. 修改 `.claude/hooks/guard_write.py`——写入前先读 current_role，加载 permissions.json，检查目标 path 是否在当前角色的 write 权限内，不在则拦截并提示当前角色应使用哪个角色；

6. 在 `.claude/commands/coordinator.md` 创建 Coordinator 命令——子命令：switch-to {role} / rollback / rollback-to {checkpoint} / reset / status；

7. 在 `docs/harness/role-orchestration.md` 写完整说明——8 角色定义表、checkpoint × 角色映射表、工作交接流水线图（ASCII）、工具权限矩阵、上下文隔离规则、回滚机制。

**验收清单**——`.claude/team-roles/` 下有 8 个 .md 文件；permissions.json 路径与 AGENTS.md 模块边界一致；`/coordinator` 子命令可用；apply-role.sh SessionStart 时能加载角色配置；guard_write.py 按 current_role 拦截越权（手动测试：Coordinator 角色试图改 src/main/java 应被拦）；docs/harness/role-orchestration.md 完整记录设计。

### 9.8 使用示例

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

### 9.9 与多 agent 方案的关系（仅供了解）

**如果未来确实出现以下场景**，可参考 `Harness Agent Team 多agent架构设计.md` 升级到多 agent：
- 同时 ≥ 3 个并发需求；
- 单需求 task ≥ 8 个且无依赖、可真并行；
- 跨模块大型重构。

**升级前提**：单实例方案已稳定运行 ≥ 2 个月，且团队能投入 2-3 周开发 Python 编排器。

**对于多 agent 方案的细节，本文档不展开，大家有需要去查阅那份独立文档。**

---

## 结语

好，到这里，Harness V2 的完整画卷就给大家讲完了。

咱们简单回顾一下今天讲的——

第一，**AI Coding 经历了三次范式跃迁**：从 Prompt Engineering 到 Context Engineering 再到 Harness Engineering。Harness 不是替代前两者，而是在它们之上的"系统层约束"。

第二，**Harness 的 7 层架构**——L1 规范层（OpenSpec）、L2 纪律层（Superpowers）、L3 审查层（双轨审查）、L4 领域知识层（ECC 技能库）、L5 工具精度层（OMC MCP）、L6 持续学习层（ECC 本能）、L7 编排层（HyperSpec）——加上安全保护层和模型路由层两个横切层，构成完整能力栈。

第三，**AI 工作流程是六阶段生命周期**：会话启动 → 需求理解 → 计划拆解 → 编码实施 → 审查归档 → 学习沉淀。每一阶段都有多层协同工作。

第四，**从零搭建 Harness 的完整路径**——准备阶段（评估、环境、目录骨架）→ 分层落地（L1-L7 逐层操作）→ 项目文档 AI 自动补全（8 类文档：AGENTS.md、CLAUDE.md、REVIEW.md、config.yaml、architecture、database、standards、harness）→ 完整流程跑通。

第五，**Agent Team 角色编排层**——8 个角色（PM、Architect、Tech Lead、Developer、Reviewer、Tester、DevOps、Coordinator）通过单实例多角色方案，把 L7 HyperSpec 从 1D 编排升级为 2D 编排。

我想留给大家一个核心认知——**Harness 的本质，不是把 AI 框死，而是给 AI 一套"工程化的肌肉记忆"**。它让 AI 从一个"偶尔能干的聪明人"，变成一支"稳定输出的虚拟研发团队"。

而且这套东西是**越用越聪明的**——每一次会话都在沉淀本能，每一个 checkpoint 都在积累信任。**给 Harness 两三个月，你的项目就会有一支不会离职、不会偷懒、不会"自由发挥"的 AI 研发铁军。**

好，今天的分享就到这里，谢谢大家！

---

## 附录：相关文档索引

下面这些文档是本演讲稿主要参考的来源，大家深入实施时可查阅：

| 文档 | 作用 |
|------|------|
| `Harness V2 架构设计文档2.md` | 主架构文档（演讲稿主线来源） |
| `Harness V2 落地实操手册2-1.md` | 落地实操手册主体（第七部分展开来源） |
| `Harness V2 落地实操手册2-2.md` | Agent Team 落地手册（第九部分展开来源） |
| `Harness Agent Team 多agent架构设计.md` | 多 agent 升级方案（仅供了解，本演讲稿未展开） |
| `everything-claude-code/`（ECC 上游） | L4 领域技能库来源 |
| `oh-my-claudecode/`（OMC 上游） | L5 LSP/AST 工具来源 |
| `HyperSpec`（上游项目） | L7 编排层工具 |
| `Superpowers`（上游项目） | L2 纪律层工具 |
| `gstack`（上游项目） | L3 完整审查 9 关工具 |
| `OpenSpec`（上游项目） | L1 规范层工具 |

**对于上游项目的安装、配置、内部细节，本演讲稿只做简要介绍，需要时请直接查阅对应项目文档。**
