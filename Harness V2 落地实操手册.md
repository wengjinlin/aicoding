# Harness V2 落地实操手册

> 版本：1.0 | 更新日期：2026-06-17
> 定位：把《Harness V2 架构设计文档》从架构图变成可上手操作的工程手册
> 适用对象：Spring Boot / Java 后端项目（其他技术栈可参照骨架改造）
> 配套文档：`Harness V2 架构设计文档.md`（角色编排详见其第 8 章）
> 参考素材：`everything-claude-code/`、`oh-my-claudecode/`、Obsidian 知识库

---

## 序章：怎么用这本手册

### 阅读路径

| 你是 | 推荐路径 |
|------|---------|
| 第一次接触 Harness | 序章 → 第一部分 → 第二部分按顺序 → 第二十一章演示 |
| 已有 Claude Code 经验，想接 Harness | 跳到第二部分 → 第三部分项目文档 |
| 只想要某层能力（如审查） | 直接跳到对应章节（每章独立） |
| 要在新项目从零搭 | 序章 → 第一部分 → 第三部分按需 → 第四部分 |

### 时间预算

| 阶段 | 工作量 | 产出 |
|------|-------|------|
| 准备阶段（章一-章三） | 0.5 天 | 环境就绪、目录骨架 |
| 分层落地（章四-章十二） | 2-3 天 | 7 层全部可运行 |
| 项目文档（章十三-章二十） | 1-2 天（含 AI 自动补全） | 全套规范文档 |
| 验证（章二十一-章二十二） | 0.5 天 | 一个真实需求跑通 |

**总工期**：约 4-6 天可完成首版 Harness 落地。

---

# 第一部分：准备阶段

## 章一：项目适配性评估

### 1.1 适合用 Harness V2 的项目特征

✅ **强烈推荐**：
- Spring Boot / Java 后端项目（L4 有现成 ECC 技能）
- 中大型团队（≥ 3 人开发），需要统一规范
- 长期维护项目（≥ 6 个月），需要积累本能
- 多需求并发场景（≥ 2 个并发育）

⚠️ **谨慎使用**：
- 小脚本 / 一次性工具
- 全新项目还未定型（先跑 MVP，再上 Harness）
- 极简前端项目（L4 技能偏后端）

❌ **不建议**：
- 没有 git 仓库的项目
- 团队对 Claude Code 完全陌生的项目（先单独跑通 1-2 周）
- 强依赖图形界面的项目（Harness 是 CLI 驱动）

### 1.2 前置条件检查表

在项目根目录跑以下命令，每条都得通过：

```bash
# 1. Git 仓库已初始化
git status                                # 必须能输出当前分支

# 2. Java 环境
java -version                             # ≥ 1.8（推荐 JDK 17）
echo $JAVA_HOME                           # 必须指向有效 JDK

# 3. Maven（Harness V2 文档指定的 Maven 路径）
"/c/Program Files/JetBrains/IntelliJ IDEA 2025.3/plugins/maven/lib/maven3/bin/mvn.cmd" -v

# 4. Claude Code CLI
claude --version                          # 必须 ≥ 2.0

# 5. 项目能编译（这是 baseline，不通过先修业务）
mvn -q compile
```

### 1.3 不通过怎么办

| 检查失败 | 应对 |
|---------|------|
| Maven 路径不对 | 改用项目 `mvnw` wrapper，或修改 `~/.bashrc` 加 alias |
| Claude Code 没装 | `npm install -g @anthropic-ai/claude-code` |
| 项目编译失败 | **先别上 Harness**，把项目编译修好再来 |
| JAVA_HOME 没设 | `export JAVA_HOME="/d/jdk1.8.0_171"`（按实际路径） |

---

## 章二：环境搭建

### 2.1 必装组件清单

| 组件 | 版本 | 用途 | 安装方式 |
|------|------|------|---------|
| Claude Code | ≥ 2.0 | Harness 宿主 | `npm i -g @anthropic-ai/claude-code` |
| OpenSpec | 最新 | L1 规范层 | `npm i -g @fission-ai/openspec` |
| Superpowers | 最新 | L2 纪律层 | `npx skills add obra/superpowers` |
| gstack | 最新 | L3 审查（9 关） | `npx skills add garrytan/gstack` |
| HyperSpec | 最新 | L7 编排 | `npx skills add wind7rui/HyperSpec` |
| OMC MCP | 最新 | L5 LSP/AST 工具 | 见 `oh-my-claudecode/` 安装说明 |

### 2.2 一键安装脚本

在项目根目录执行：

```bash
# 1. 全局工具
npm install -g @anthropic-ai/claude-code @fission-ai/openspec

# 2. 项目级 skills（在项目根目录运行）
npx skills add obra/superpowers -y
npx skills add garrytan/gstack -y
npx skills add wind7rui/HyperSpec -y

# 3. ECC 插件市场（在 Claude Code 内执行）
# 启动 claude，然后输入：
#   /plugin marketplace add affaan-m/ecc
#   /plugin install ecc@ecc

# 4. OMC 插件（同上）
#   /plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode
#   /plugin install oh-my-claudecode
#   然后终端跑：omc setup
```

### 2.3 验证安装

```bash
# 在 Claude Code 会话内逐条输入，每条都应返回非空结果
/opsx:explore --help
/superpowers:list
/gstack:review --help
/hyperspec --help
```

任一报"command not found"，回到 2.2 重装对应组件。

---

## 章三：目录骨架一键初始化

### 3.1 完整目录树（项目根）

```
your-project/
├── .claude/
│   ├── settings.local.json          # 权限 + Hooks + MCP 配置
│   ├── hooks/                       # Hook 脚本
│   │   ├── guard_write.py
│   │   ├── ensure_change_context.py
│   │   ├── run_checks.sh
│   │   └── apply-role.sh
│   ├── commands/                    # Slash commands
│   │   └── opsx/                    # OpenSpec 命令组
│   ├── skills/                      # 技能库（L4 ECC）
│   │   ├── springboot-patterns/
│   │   ├── springboot-tdd/
│   │   ├── jpa-patterns/
│   │   ├── api-design/
│   │   ├── database-migrations/
│   │   ├── quick-review/            # 自建 3 关审查
│   │   └── harness-bootstrap/
│   ├── instincts/                   # L6 本能知识（运行时生成）
│   └── team-roles/                  # 8 角色模板（L7 扩展）
│       ├── pm.md
│       ├── architect.md
│       ├── tech-lead.md
│       ├── developer.md
│       ├── reviewer.md
│       ├── tester.md
│       ├── devops.md
│       └── permissions.json
├── openspec/
│   ├── config.yaml                  # 模型路由 + 项目配置
│   ├── changes/                     # 进行中的变更
│   └── archive/                     # 已归档的变更
├── superpowers/
│   └── plans/                       # TDD 计划
├── docs/
│   ├── architecture/                # 架构文档
│   ├── database/                    # 数据库文档
│   ├── standards/                   # 编码规范
│   ├── harness/                     # Harness 自文档
│   └── help/                        # 帮助文档
├── AGENTS.md                        # 项目规范（最高优先级）
├── CLAUDE.md                        # Claude 协作指令
├── REVIEW.md                        # 审查清单
└── .hyperspec-state.yaml            # HyperSpec 状态文件（运行时生成）
```

### 3.2 一键创建脚本

把以下保存为 `init-harness.sh`，在项目根执行：

```bash
#!/usr/bin/env bash
set -e

# 创建目录
mkdir -p .claude/{hooks,commands/opsx,skills,instincts,team-roles}
mkdir -p openspec/{changes,archive}
mkdir -p superpowers/plans
mkdir -p docs/{architecture,database,standards,harness,help}

# 占位文件（后续章节会填充）
touch AGENTS.md CLAUDE.md REVIEW.md
touch openspec/config.yaml
touch .claude/settings.local.json

echo "✅ Harness 目录骨架已创建"
echo "下一步：按手册章四-章十二填充各层"
```

执行：

```bash
chmod +x init-harness.sh
./init-harness.sh
```

### 3.3 验收清单

- [ ] `tree -L 2 .claude/` 显示 hooks/commands/skills/instincts/team-roles 五个子目录
- [ ] `ls openspec/` 显示 config.yaml（空）、changes/、archive/
- [ ] `ls docs/` 显示五个子目录
- [ ] 根目录有 AGENTS.md、CLAUDE.md、REVIEW.md（空文件，待填）

### 3.4 实战项目示例：QMS
![img.png](img.png)

---

# 第二部分：分层落地

> 每层独立成章。**建议按顺序落地**——L1 是基础，L2-L7 都依赖它。

## 章四：L1 OpenSpec 规范层

### 4.1 目标

强制 4 工件顺序：`proposal → specs → design → tasks`，禁止跳步。

### 4.2 操作步骤

```bash
# 1. 初始化 OpenSpec（在项目根）
openspec init

# 2. 配置项目（编辑 openspec/config.yaml，详见章十六）

# 3. 验证
openspec validate
```

### 4.3 AI 自动补全提示词

第一次在新项目跑 OpenSpec 时，把以下提示词贴进 Claude Code：

```
我要在本项目启用 OpenSpec 规范驱动开发。请：

1. 阅读 `openspec/config.yaml`（若不存在则创建），结合本项目实际情况补全：
   - 项目名称、版本、技术栈
   - 模型路由（propose=opus, specs=sonnet, apply=sonnet, archive=haiku）
   - 项目类型（spring-boot / node / python / other）

2. 探测本项目实际技术栈：
   - 读取 pom.xml（如有）→ Spring Boot + Java
   - 读取 package.json（如有）→ Node.js
   - 读取 requirements.txt（如有）→ Python
   - 把探测结果写入 openspec/config.yaml 的 tech_stack 字段

3. 在 openspec/changes/ 下创建 README.md，说明：
   - changes/ 目录的用途（存放进行中的变更）
   - 命名规范（add-feature-x / fix-bug-y / refactor-z）
   - 何时移到 archive/（变更归档后）

4. 验证 `openspec validate` 通过

5. 把上述改动用 git commit，message: "chore(harness): L1 OpenSpec 规范层初始化"
```

### 4.4 验收

- [ ] `openspec validate` 无报错
- [ ] `openspec/config.yaml` 含项目实际技术栈
- [ ] 跑 `/opsx:propose "添加用户登录"` 能正常生成 proposal 工件

### 4.5 实战项目示例：QMS
![img_1.png](img_1.png)

[config.yaml](file/openspec-config.yaml)
[README.md](file/openspec-README.md)

---

## 章五：L2 Superpowers 纪律层

### 5.1 目标

把 TDD 红绿重构、子代理、完成验证焊进开发循环。

### 5.2 操作步骤

```bash
# 1. 安装 Superpowers skills
npx skills add obra/superpowers -y

# 2. 标记 always-active 的两个核心技能（编辑 .claude/settings.local.json）
#    见下方 AI 提示词
```

### 5.3 AI 自动补全提示词

```
我要配置 Superpowers 纪律层。请：

1. 读取 `.claude/settings.local.json`（若不存在则创建），确保以下两个 skill 始终激活：
   - test-driven-development（always_active: true）
   - verification-before-completion（always_active: true）

2. 检查本项目是否有测试框架：
   - Maven 项目：查 pom.xml 是否有 junit / mockito / spring-boot-starter-test
   - 缺失则在 pom.xml 添加对应依赖

3. 创建 `superpowers/plans/README.md`，说明：
   - 这个目录存放 writing-plans 生成的 TDD 计划
   - 计划文件命名规范：plan-{需求名}-{日期}.md
   - 计划包含的字段（任务清单、依赖关系、验收标准）

4. 写一个测试样板文件 `.claude/skills/_templates/test-template.java`：
   - 标准的 Spring Boot Test 类骨架
   - @SpringBootTest 注解
   - @MockBean 注入示例
   - 一个 @Test 方法示例

5. commit: "chore(harness): L2 Superpowers 纪律层 + TDD 模板"
```

### 5.4 验收

- [ ] Claude Code 会话启动时显示 "test-driven-development active"
- [ ] 修改一个 `.java` 文件后，AI 自动建议先写测试

### 5.5 实战项目示例：QMS
```settings.local.json
{
  "skills": {
    "test-driven-development": {
      "always_active": true
    },
    "verification-before-completion": {
      "always_active": true
    }
  }
}
```
[test-template.java](file/test-template.java)
[superpower-README.md](file/superpower-README.md)

---

## 章六：L3 双轨审查层

### 6.1 目标

`/quick-review`（3 关，2 分钟）+ `/full-review`（gstack 9 关，15 分钟）自动路由。

### 6.2 操作步骤

```bash
# 1. 安装 gstack
npx skills add garrytan/gstack -y

# 2. 创建自建 quick-review skill（见 AI 提示词）
```

### 6.3 AI 自动补全提示词

```
我要配置双轨审查层。请：

1. 创建 `.claude/skills/quick-review/SKILL.md`，内容：
   - 名称：quick-review
   - 描述：3 关快速审查（语法 / 测试 / 安全），耗时 ~2 分钟
   - 触发：/quick-review 命令
   - 适用：单 task 完成、小改动
   - 3 关详细清单：
     a. 语法检查：编译通过、无未使用 import、命名规范
     b. 测试覆盖：新代码有测试、所有测试通过、覆盖核心分支
     c. 安全：无硬编码密码、无 SQL 拼接、权限校验完整

2. 创建 `.claude/commands/quick-review.md`，内容：
   - 调用 quick-review skill
   - 路由规则：当前 change 的 task 数 ≤ 3 → 走 quick-review；> 3 → 提示用 /full-review

3. 在项目根 REVIEW.md 写入：
   - 审查触发时机（每个 task 完成、合并前、发布前）
   - 双轨对比表（quick vs full）
   - 9 关详细清单（参考 gstack 文档）

4. commit: "chore(harness): L3 双轨审查层（quick + gstack）"
```

### 6.4 验收

- [ ] `/quick-review` 在小改动后能跑出 3 关报告
- [ ] `/full-review` 在大改动后能跑出 9 关报告

### 6.5 实战项目示例：QMS
[quick-review.md](file/quick-review.md)
[SKILL.md](file/quick-review/SKILL.md)
[REVIEW.md](file/REVIEW.md)

---

## 章七：L4 ECC 技能层（Spring Boot 专用）

### 7.1 目标

为 Spring Boot / JPA / Java 项目注入领域知识技能。

### 7.2 操作步骤

```bash
# 1. 安装 ECC 插件（在 Claude Code 内）
/plugin marketplace add affaan-m/everything-claude-code
/plugin install ecc@ecc

# 2. 选择性激活技能（按项目实际用到的）
```

### 7.3 AI 自动补全提示词

```
我要配置 L4 ECC 技能层（针对本项目是 Spring Boot + JPA）。请：

1. 读取 pom.xml，识别实际依赖：
   - Spring Boot 版本
   - 是否用 JPA / MyBatis / MyBatis-Plus
   - 是否用 Spring Security
   - 数据库类型（Oracle/MySQL/PostgreSQL）
   - 是否有 Docker / K8s 部署

2. 基于识别结果，在 `.claude/settings.local.json` 的 active_skills 字段激活：
   - springboot-patterns（必装）
   - springboot-tdd（必装）
   - springboot-security（如有 spring-security 依赖）
   - jpa-patterns（如有 spring-data-jpa 依赖）
   - database-migrations（如有 flyway/liquibase 依赖）
   - postgres-patterns / mysql-patterns（按数据库类型）
   - api-design（必装，REST 规范）
   - backend-patterns（必装）
   - docker-patterns（如有 Dockerfile）
   - deployment-patterns（如有 CI/CD 配置）

3. 在 `.claude/skills/` 下创建 `_project_specific/SKILL.md`，记录：
   - 本项目特有的业务术语（如"凭证"、"对账"、"工单"）
   - 本项目特有的模块边界（哪些模块禁止改）
   - 本项目依赖的内部库（如何引入、版本）

4. commit: "chore(harness): L4 ECC 技能层激活"
```

### 7.4 验收

- [ ] 在 Claude Code 内输入 `/skills` 显示已激活的 Spring Boot 技能
- [ ] 写一个新 Controller 时，AI 自动建议用 `@RestController` + `@RequestMapping`

### 7.5 实战项目示例：QMS
```settings.local.json
{
  "skills": {
    "ecc:springboot-patterns": {
      "always_active": true,
      "rationale": "Spring Boot 项目（web + tomcat + aop + actuator）"
    },
    "ecc:springboot-tdd": {
      "always_active": true,
      "rationale": "Spring Boot 测试规范"
    },
    "ecc:mysql-patterns": {
      "always_active": true,
      "rationale": "pom 含 mysql-connector-java"
    },
    "ecc:postgres-patterns": {
      "always_active": true,
      "rationale": "pom 含 postgresql 驱动"
    },
    "ecc:api-design": {
      "always_active": true,
      "rationale": "REST API 设计规范（项目用 Knife4j/Swagger）"
    },
    "ecc:backend-patterns": {
      "always_active": true,
      "rationale": "后端通用模式"
    }
  }
}
```
[SKILL.md](file/_project_specific/SKILL.md)

---

## 章八：L5 OMC MCP 工具精度层

### 8.1 目标

把 LSP（hover/goto-def/references）和 AST（grep/replace）工具暴露给 Claude。

### 8.2 操作步骤

```bash
# 1. 安装 OMC（在 Claude Code 内）
/plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode
/plugin install oh-my-claudecode

# 2. 跑 setup
/oh-my-claudecode:setup

# 3. 配置 MCP（编辑 .claude/settings.local.json，见 AI 提示词）
```

### 8.3 AI 自动补全提示词

```
我要配置 L5 OMC MCP 工具层。请：

1. 读取 `.claude/settings.local.json`，确保 mcpServers 字段包含：
   - oh-my-claudecode: 暴露 lsp_hover / lsp_goto_definition / lsp_find_references / lsp_diagnostics / lsp_completion / lsp_rename
   - oh-my-claudecode: 暴露 ast_grep_search / ast_grep_replace
   - oh-my-claudecode: 暴露 python_repl（用于数据校验）

2. 探测本项目的 LSP 配置：
   - Java 项目：检查是否安装 jdtls（Eclipse JDT Language Server）
   - 把 Java LSP 启动命令写入 MCP 配置的 args 字段
   - 验证：lsp_hover 能对 String 类返回有效信息

3. 创建 `.claude/skills/_project_specific/ast-rules.yml`，定义：
   - 本项目禁止的 AST 模式（如 System.out.println 出现在非 test 代码）
   - 本项目强制的 AST 模式（如 Controller 方法必须有 @AuditLog 注解）

4. 在 docs/harness/l5-mcp-tools.md 写一份使用说明：
   - 何时该用 lsp_goto_definition（追依赖链）
   - 何时该用 ast_grep_search（找模式化代码）
   - 何时该用 python_repl（验证 SQL 数据）

5. commit: "chore(harness): L5 OMC MCP 工具层"
```

### 8.4 验收

- [ ] Claude Code 会话中能用 `lsp_hover` 查看类定义
- [ ] 能用 `ast_grep_search` 找出所有 `@RestController` 类

### 8.5 实战项目示例：QMS
```settings.local.json
{
  "permissions": {
    "allow": [
      "Bash(mkdir -p E:/IdeaProjects/sunny-qms/sunny-qms-service/.claude/rules)",
      "Bash(cp C:/Users/wengjl/.claude/plugins/cache/omc/oh-my-claudecode/4.14.7/templates/rules/karpathy-guidelines.md E:/IdeaProjects/sunny-qms/sunny-qms-service/.claude/rules/)",
      "Bash(cp C:/Users/wengjl/.claude/plugins/cache/omc/oh-my-claudecode/4.14.7/templates/rules/testing.md E:/IdeaProjects/sunny-qms/sunny-qms-service/.claude/rules/)",
      "Bash(cp C:/Users/wengjl/.claude/plugins/cache/omc/oh-my-claudecode/4.14.7/templates/rules/security.md E:/IdeaProjects/sunny-qms/sunny-qms-service/.claude/rules/)"
    ]
  },
  "env": {
    "JAVA_HOME": "D:\\jdk1.8.0_171",
    "PATH": "C:\\Users\\wengjl\\.trae\\extensions\\redhat.java-1.49.0-win32-x64\\server\\bin;C:\\Users\\wengjl\\.pyenv\\pyenv-win\\shims;${PATH}"
  },
  "mcpServers": {
    "oh-my-claudecode": {
      "_comment": "L5 MCP 工具层 - 由 OMC plugin 自动注册为 mcp__plugin_oh-my-claudecode_t__*。此字段为 L5 层显式声明/可追溯记录，便于审计与迁移。实际启动入口：dist/mcp/standalone-server.js（stdio）。",
      "command": "node",
      "args": [
        "C:\\Users\\wengjl\\.claude\\plugins\\cache\\omc\\oh-my-claudecode\\4.14.7\\dist\\mcp\\standalone-server.js"
      ],
      "env": {
        "JAVA_HOME": "D:\\jdk1.8.0_171",
        "PATH": "C:\\Users\\wengjl\\.trae\\extensions\\redhat.java-1.49.0-win32-x64\\server\\bin;C:\\Users\\wengjl\\.pyenv\\pyenv-win\\shims;${PATH}"
      },
      "_tools_exposed": [
        "lsp_hover",
        "lsp_goto_definition",
        "lsp_find_references",
        "lsp_diagnostics",
        "lsp_completion",
        "lsp_rename",
        "ast_grep_search",
        "ast_grep_replace",
        "python_repl"
      ],
      "_java_lsp": {
        "server": "Eclipse JDT Language Server (jdtls)",
        "launcher": "C:\\Users\\wengjl\\.trae\\extensions\\redhat.java-1.49.0-win32-x64\\server\\bin\\jdtls.bat",
        "runtime": "python (pyenv-win) + JDK 1.8.0_171",
        "extensions": [".java"]
      }
    }
  }
}
```
[l5-mcp-tools.md](file/l5-mcp-tools.md)
[ast-rules.yml](file/_project_specific/ast-rules.yml)

---

## 章九：L6 ECC 本能层

### 9.1 目标

跨会话积累项目知识，下次启动自动加载。

### 9.2 操作步骤

本能层是运行时生成的，无需手动初始化。但需要：

```bash
# 1. 创建本能目录
mkdir -p .claude/instincts

# 2. 配置 SessionEnd hook 自动捕获（见 AI 提示词）
```

### 9.3 AI 自动补全提示词

```
我要配置 L6 本能层。请：

1. 在 `.claude/instincts/` 创建以下骨架文件（每个文件 200 字以内，简洁）：
   - project-overview.md：项目一句话定位、核心模块、技术栈
   - business-glossary.md：业务术语速查（中文+英文+一句话定义）
   - tech-decisions.md：关键技术决策（为什么选 MyBatis 而非 JPA、为什么单体而非微服务）
   - known-pitfalls.md：已知坑（如 BaseEntity 必须加 @MappedSuperclass）
   - module-boundaries.md：模块边界（哪些代码不能动）
   - testing-conventions.md：测试规范（命名、覆盖率、Mock 策略）

2. 在 `.claude/settings.local.json` 配置 SessionEnd hook：
   - 触发时机：会话结束
   - 执行脚本：调用 /instinct-export 把本次会话学到的新知识写入 instincts/

3. 在 `.claude/settings.local.json` 配置 SessionStart hook：
   - 触发时机：会话启动
   - 执行脚本：加载所有 instincts/*.md 到上下文

4. 在 docs/harness/l6-instincts.md 写说明：
   - 本能层是"项目肌肉记忆"
   - 不要把临时信息写入 instincts（如某次 bug 修复细节）
   - 只写"下次会话也需要知道"的稳定知识

5. commit: "chore(harness): L6 本能层骨架 + hooks"
```

### 9.4 验收

- [ ] `.claude/instincts/` 下有 6 个骨架文件
- [ ] Claude Code 启动时显示 "loaded N instincts"
- [ ] 一次会话结束后，instincts/ 下出现新内容（或更新时间戳变化）

### 9.5 实战项目示例：QMS
```settings.local.json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash E:/IdeaProjects/sunny-qms/sunny-qms-service/.claude/hooks/load-instincts.sh",
            "timeout": 10,
            "statusMessage": "Loading L6 instincts..."
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash E:/IdeaProjects/sunny-qms/sunny-qms-service/.claude/hooks/export-instincts.sh",
            "timeout": 10,
            "statusMessage": "Exporting L6 instincts..."
          }
        ]
      }
    ]
  }
}

```
[l6-instincts.md](file/l6-instincts.md)

[export-instincts.sh](file/hooks/export-instincts.sh)
[load-instincts.sh](file/hooks/load-instincts.sh)

[business-glossary.md](file/instincts/business-glossary.md)
[known-pitfalls.md](file/instincts/known-pitfalls.md)
[module-boundaries.md](file/instincts/module-boundaries.md)
[project-overview.md](file/instincts/project-overview.md)
[tech-decisions.md](file/instincts/tech-decisions.md)
[testing-conventions.md](file/instincts/testing-conventions.md)

---

## 章十：L7 HyperSpec 编排层

### 10.1 目标

12 checkpoint 状态机 + 断点恢复 + 一键全自动。

### 10.2 操作步骤

```bash
# 1. 安装 HyperSpec
npx skills add wind7rui/HyperSpec -y

# 2. 初始化状态文件
touch .hyperspec-state.yaml

# 3. 试用
/hyperspec "添加用户登录功能"
```

### 10.3 AI 自动补全提示词

```
我要配置 L7 HyperSpec 编排层。请：

1. 创建 `.hyperspec-state.yaml`（初始内容）：
   ```yaml
   current_change: null
   current_checkpoint: null
   current_role: null
   history: []
   notifications: []
   ```yaml

2. 创建 `docs/harness/l7-checkpoints.md`，详细列出 12 个 checkpoint：
   1. profiler-done（项目探测完成）
   2. requirements-confirmed（需求确认）
   3. openspec-generated（4 工件生成）
   4. plan-generated（TDD 计划生成）
   5. plan-generated-and-confirmed（计划确认）
   6. task-N-complete（每个 task 完成）
   7. verified（验证通过）
   8. reviewed（审查通过）
   9. apply-done（变更应用）
   10. consistency-verified（一致性验证）
   11. archived（归档）
   12. done（完成）

   每个 checkpoint 写清楚：
   - 触发条件
   - 上一 checkpoint（前置）
   - 下一 checkpoint
   - 通知消息
   - 失败时如何回退

3. 创建 `.claude/commands/hyperspec.md`（若 HyperSpec 已安装则跳过），内容：
   - 接收需求描述
   - 启动 12 checkpoint 流程
   - 断点恢复：读取 .hyperspec-state.yaml 从上次 checkpoint 继续

4. commit: "chore(harness): L7 HyperSpec 编排层"
```

### 10.4 验收

- [ ] `/hyperspec "测试需求"` 能跑通至少 5 个 checkpoint
- [ ] 中途 Ctrl+C 后再次运行 `/hyperspec` 能从断点继续

### 10.5 实战项目示例：QMS
[l7-checkpoints.md](file/l7-checkpoints.md)
[.hyperspec-state.yaml](file/.hyperspec-state.yaml)

---

## 章十一：横切层 — 安全保护层

### 11.1 目标

4 个核心 Hook 防止 AI 越界。

### 11.2 操作步骤

创建 4 个 Hook 脚本：

### 11.3 AI 自动补全提示词

```
我要配置安全保护层（4 个 Hook）。请按以下规格创建：

1. `.claude/hooks/guard_write.py`：
   - 触发：每次 Edit/Write 工具调用前
   - 拦截规则（基于本项目实际）：
     a. application.yml / application.properties → 必须人工确认
     b. src/main/resources/db/migration/ → 必须人工确认（数据库迁移）
     c. src/main/resources/sql/ → 必须人工确认
     d. 财务相关包（如 com.xxx.finance）→ 必须人工确认
   - 实现：扫描目标 path，命中规则就 System.exit(1) + 打印警告
   - 白名单：通过环境变量 HARNESS_ALLOW_WRITE 跳过（仅编排器使用）

2. `.claude/hooks/ensure_change_context.py`：
   - 触发：每次 Bash 工具调用前
   - 规则：若当前没有 active OpenSpec change（openspec/changes/ 为空），阻止危险命令：
     - git push / git commit --amend / git reset --hard
     - mvn deploy / docker push
     - 数据库迁移命令
   - 实现：检查 openspec/changes/ 目录非空；空则拦截

3. `.claude/hooks/run_checks.sh`：
   - 触发：每次 Edit/Write 工具调用后
   - 规则：如果改的是 .java 文件，自动跑：
     - mvn -q compile（编译检查）
     - 失败则打印错误并要求修复
   - 实现：bash 脚本，根据修改的文件扩展名分支
   - 注意：使用项目指定的 Maven 路径
     `/c/Program Files/JetBrains/IntelliJ IDEA 2025.3/plugins/maven/lib/maven3/bin/mvn.cmd`

4. `.claude/hooks/apply-role.sh`：
   - 触发：SessionStart
   - 规则：根据 .hyperspec-state.yaml 的 current_role 加载对应角色配置
   - 实现：从 .claude/team-roles/{role}.md 加载 system prompt 追加

5. 在 `.claude/settings.local.json` 注册上述 4 个 hook，绑定正确的 event：
   - PreToolUse: guard_write.py, ensure_change_context.py
   - PostToolUse: run_checks.sh
   - SessionStart: apply-role.sh
   - SessionEnd: 调用 instinct-export（见章九）

6. 在 docs/harness/security-hooks.md 写文档：
   - 每个 hook 的拦截规则
   - 临时绕过方式（明确说这是危险的）
   - 调试 hook 的方法

7. commit: "chore(harness): 安全保护层 4 个 hook"
```

### 11.4 验收

- [ ] 试图改 `application.yml` 时被拦截
- [ ] 改 `.java` 文件后自动跑编译检查
- [ ] 没有 active change 时 `git push` 被拦截

### 11.5 实战项目示例：QMS
[security-hooks.md](file/security-hooks.md)

[4hooks-settings.local.json](file/4hooks-settings.local.json)

[apply-role.sh](file/hooks/apply-role.sh)
[run_checks.sh](file/hooks/run_checks.sh)
[guard_write.py](file/hooks/guard_write.py)
[ensure_change_context.py](file/hooks/ensure_change_context.py)

---

## 章十二：横切层 — 模型路由层

### 12.1 目标

按 checkpoint 复杂度路由模型，省 token。

### 12.2 操作步骤

编辑 `openspec/config.yaml`：

### 12.3 AI 自动补全提示词

```
我要配置模型路由层。请编辑 openspec/config.yaml 添加 routing 段：

1. 探测本项目的实际模型可用性：
   - 读取 ~/.claude/settings.json 看默认 model
   - 询问用户是否有 opus / sonnet / haiku 的访问权限（如果都通就全配）

2. 在 openspec/config.yaml 写入：
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
     by_role:                           # 单实例多角色模式（详见章二十三）
       pm: opus
       architect: opus
       tech-lead: sonnet
       developer: sonnet                # 默认
       developer-complex: opus          # 复杂 task 自动升级
       reviewer: opus                   # 审查者必须 opus，避免共谋
       tester: sonnet
       devops: sonnet
       team-lead: haiku                 # 协调者用便宜模型
   ```yaml    

3. 在 docs/harness/l12-model-routing.md 写决策依据：
   - 为什么 propose 用 opus（需求理解错了后面全错）
   - 为什么 reviewer 必须用 opus（避免和 Developer 共谋）
   - 为什么 team-lead 用 haiku（决策简单，省 token）
   - 如何手动覆盖（环境变量 ANTHROPIC_MODEL）

4. commit: "chore(harness): 模型路由层"
```

### 12.4 验收

- [ ] `openspec/config.yaml` 有 model_routing 段
- [ ] 跑 `/hyperspec` 时，proposal 阶段用的是 opus，archive 阶段用的是 haiku（看日志确认）

### 12.5 实战项目示例：QMS

---

# 第三部分：项目文档 AI 自动补全（核心）

> **这部分是手册的核心**。每章给出一个项目级文档的骨架 + 让 AI 自动补全的提示词。
> AI 补全时务必让它**读项目实际代码**，不要让它凭空编。

## 章十三：AGENTS.md 项目规范（最高优先级）

### 13.1 文件作用

`AGENTS.md` 是 AI 协作的最高优先级指令，**会覆盖默认行为**。所有 AI agent 启动时第一时间读这个文件。

### 13.2 模板骨架

```markdown
# {项目名} AGENTS.md

## 项目定位
{一句话}

## 技术栈（强制版本）
- 框架：Spring Boot X.Y.Z
- ORM：MyBatis-Plus X.Y.Z / Spring Data JPA X.Y.Z
- 数据库：MySQL 8.x / PostgreSQL 14 / Oracle 12c
- JDK：17
- 构建：Maven 3.9

## 模块边界（红线）
- 禁止修改：{列举不能动的包/模块}
- 谨慎修改：{列举需要评审的包}
- 自由修改：{列举可自由改的包}

## 业务术语
- {术语 1}：{定义}
- {术语 2}：{定义}

## 编码规范
- 命名：{Controller/Service/Mapper 命名规则}
- 分层：{Controller → Service → Mapper 的依赖方向}
- 异常：{统一异常处理类}
- 日志：{日志规范}

## 验证命令（改完业务代码必跑）
1. mvn compile
2. mvn test
3. mvn checkstyle:check

## 禁止事项
- ❌ 不允许硬编码密码/密钥
- ❌ 不允许在 Controller 直接写 SQL
- ❌ 不允许 System.out.println
- ❌ 不允许 @Autowired 字段注入（必须构造器注入）
```

### 13.3 AI 自动补全提示词

```
请基于本项目实际情况生成 AGENTS.md。要求：

1. 探测项目实际技术栈：
   - 读 pom.xml 提取 Spring Boot / ORM / 数据库驱动版本
   - 读 src/main/resources/application.yml 提取数据库类型
   - 读 .java-version / pom.xml 的 maven.compiler.target 提取 JDK 版本

2. 探测项目模块结构：
   - 列出 src/main/java/ 下的包结构（深度 3 层）
   - 识别哪些是核心业务包（看是否有 @RestController / @Service）
   - 识别哪些是工具/配置包（看是否有 @Configuration / Util 后缀）

3. 探测编码规范现状：
   - 抽查 5 个 Controller 看命名风格（@RestController vs @Controller）
   - 抽查 5 个 Service 看是否有接口（IXxxService + XxxServiceImpl）
   - 抽查 3 个 Entity 看 JPA/MyBatis 注解风格
   - 抽查测试目录看测试规范

4. 基于探测结果填充 AGENTS.md 模板：
   - 技术栈版本必须和 pom.xml 一致
   - 模块边界按"业务包 vs 工具包"区分
   - 业务术语如果探测不到，列出 5 个最常见的业务实体名让我确认
   - 编码规范按项目现状写（如果项目用字段注入就写"字段注入"，不要硬塞构造器注入）

5. 验证命令部分，用项目实际能跑通的命令：
   - 如果有 Maven Wrapper，优先用 ./mvnw
   - 如果没有 checkstyle 插件，从验证清单里删掉

6. 生成完成后，把 AGENTS.md 内容打印出来让我确认
7. 我确认后再 commit: "docs: 生成 AGENTS.md 项目规范"

注意：
- 不要凭空编造版本号
- 不要塞项目没有的工具
- 如果某项探测失败，在文件里写 TODO 标记，不要瞎猜
```

### 13.4 验收

- [ ] AGENTS.md 技术栈版本和 pom.xml 完全一致
- [ ] 模块边界真实反映 src/main/java 包结构
- [ ] 业务术语用项目里真实出现的名词
- [ ] AI 改代码时不再问"用什么版本"之类的基础问题

### 13.5 实战项目示例：QMS
[AGENTS.md](file/AGENTS.md)

---

## 章十四：CLAUDE.md 协作指令

### 14.1 文件作用

`CLAUDE.md` 是 Claude Code 专用的协作指令，**用户全局指令 + 项目指令双层**。项目级 CLAUDE.md 优先级高于全局。

### 14.2 模板骨架

```markdown
# {项目名} CLAUDE.md

## 协作规则
- 始终用中文交流
- 计划执行结束时不需要执行 npm build 测试
- 不要在文件里写无意义注释（只在 WHY 非显然时写）

## Maven 路径
使用 `/c/Program Files/JetBrains/IntelliJ IDEA 2025.3/plugins/maven/lib/maven3/bin/mvn.cmd`
调用前 export JAVA_HOME="/d/jdk1.8.0_171"（按实际改）

## OpenSpec 工作流规则

### spec-driven Schema 工件创建顺序（必须遵守）
无论项目是否配置了自定义 schema，使用 OpenSpec 时**必须按以下顺序创建 artifacts**：
proposal → specs → design → tasks

| 顺序 | Artifact | 作用 | 核心问题 |
|------|----------|------|----------|
| 1 | proposal | 定义变更动机 | WHY |
| 2 | specs | 定义需求规格 | WHAT |
| 3 | design | 定义技术设计 | HOW |
| 4 | tasks | 执行开发任务 | 执行 |

### 重要原则
1. 即使多个 artifacts 同时显示 "ready"，也必须按顺序创建
2. specs 必须在 design 之前（先需求后设计）

### 判断口诀
"先需求后设计，先 WHAT 后 HOW"

## 当前日期
Today's date is 2026-06-17
```

### 14.3 AI 自动补全提示词

```
请基于本项目实际情况生成 CLAUDE.md。要求：

1. 读取 ~/.claude/CLAUDE.md（用户全局指令），把全局规则拷过来
2. 添加项目特定的规则：
   - Maven 路径（基于本机实际安装位置）
   - JDK 路径（JAVA_HOME）
   - 项目语言（中文）
3. 把 OpenSpec 工作流规则完整包含进去（见模板骨架的 "OpenSpec 工作流规则" 段）
4. 探测项目实际命令：
   - 启动命令（mvn spring-boot:run / java -jar）
   - 测试命令（mvn test）
   - 打包命令（mvn package）
   - 把这些命令写入 CLAUDE.md 的"项目命令"段
5. 探测项目目录约定：
   - 代码在 src/main/java/...
   - 测试在 src/test/java/...
   - 资源在 src/main/resources/...
   - 把这些路径写入 CLAUDE.md 的"目录约定"段
6. commit: "docs: 生成 CLAUDE.md 项目协作指令"

注意：
- 不要和 AGENTS.md 重复（AGENTS.md 偏规范，CLAUDE.md 偏协作）
- 不要塞入会变的信息（如 git 分支名）
- 保持简洁，超过 100 行就太长了
```

### 14.4 验收

- [ ] Claude Code 启动时显示 "loaded CLAUDE.md"
- [ ] 用 OpenSpec 时不再跳步生成 design
- [ ] AI 用正确的 Maven 路径跑命令

### 14.5 实战项目示例：QMS
[CLAUDE.md](file/CLAUDE.md)

---

## 章十五：REVIEW.md 审查清单

### 15.1 文件作用

`REVIEW.md` 是代码审查的标准清单，被 `/quick-review` 和 `/full-review` 引用。

### 15.2 模板骨架

```markdown
# {项目名} REVIEW.md

## 双轨审查路由

| 触发条件 | 走哪条 |
|---------|-------|
| 单 task 完成、改动 < 50 行 | quick-review（3 关，2 分钟） |
| 多 task、改动 > 50 行、合并前 | full-review（gstack 9 关，15 分钟） |
| 发布前 | full-review + 人工复核 |

## quick-review 3 关

### 关 1：语法
- [ ] 编译通过（mvn compile）
- [ ] 无未使用 import
- [ ] 命名符合规范（Controller/Service/Mapper）
- [ ] 无 System.out.println（必须用 @Slf4j）

### 关 2：测试
- [ ] 新代码有对应测试
- [ ] 所有测试通过（mvn test）
- [ ] 覆盖核心分支（happy path + 至少 1 个 error path）
- [ ] Mock 使用规范（@MockBean 而非 @Mock）

### 关 3：安全
- [ ] 无硬编码密码/密钥
- [ ] 无 SQL 拼接（必须用参数化）
- [ ] 权限校验完整（@PreAuthorize 或拦截器）
- [ ] 敏感数据日志脱敏

## full-review 9 关（gstack 扩展）

### 关 4：架构
- [ ] 分层正确（Controller 不直接调 Mapper）
- [ ] 依赖方向正确（不循环依赖）
- [ ] 模块边界遵守 AGENTS.md 红线

### 关 5：API 设计
- [ ] RESTful 风格
- [ ] HTTP 方法正确（GET/POST/PUT/DELETE）
- [ ] 状态码符合规范
- [ ] 版本化（/api/v1/...）

### 关 6：数据访问
- [ ] 事务边界正确（@Transactional 范围合理）
- [ ] N+1 查询已优化
- [ ] SQL 注入防护
- [ ] 索引利用合理

### 关 7：异常处理
- [ ] 全局异常处理（@ControllerAdvice）
- [ ] 业务异常 vs 系统异常分离
- [ ] 错误信息不泄漏敏感数据

### 关 8：性能
- [ ] 无明显性能问题（大循环、N+1、不必要的对象创建）
- [ ] 缓存策略合理
- [ ] 异步处理已考虑

### 关 9：可维护性
- [ ] 命名清晰
- [ ] 单一职责
- [ ] 关键逻辑有注释（仅 WHY）
- [ ] 魔法数字已提取常量

## 项目特有关（按需启用）

### 关 10：业务规则
- [ ] 业务约束已校验（如金额必须 > 0）
- [ ] 状态机转换合法
- [ ] 审计日志已记录

### 关 11：兼容性
- [ ] 不破坏现有 API
- [ ] 数据库变更可向后兼容
- [ ] 配置变更已通知运维
```

### 15.3 AI 自动补全提示词

```
请基于本项目实际情况生成 REVIEW.md。要求：

1. 探测项目现状：
   - 读 pom.xml 看是否有 checkstyle / spotbugs / jacoco 插件
   - 读 src/main/java 看是否有 GlobalExceptionHandler / @ControllerAdvice
   - 读 application.yml 看是否启用 @EnableWebSecurity
   - 抽查 3 个 Service 看 @Transactional 使用习惯

2. 基于探测结果调整审查清单：
   - 如果项目用 MyBatis 而非 JPA，"数据访问"关改为 MyBatis 相关（XML SQL 注入、动态 SQL 安全）
   - 如果项目没有 Security，"安全"关简化
   - 如果项目有 checkstyle，"语法"关加 "checkstyle 通过"

3. 添加项目特有的审查关：
   - 如果是财务系统，加"金额计算必须用 BigDecimal"
   - 如果是审批系统，加"审批节点不能跳过"
   - 如果是报表系统，加"权限过滤必须包含部门维度"

4. 引用 AGENTS.md 的"禁止事项"，把它们都列入审查清单

5. 在文件顶部加使用说明：
   - 审查者（AI 或人）按顺序过清单
   - 每项打勾或打叉（不通过必须写理由）
   - 任何一关不通过 → 打回 Developer

6. commit: "docs: 生成 REVIEW.md 审查清单"

注意：
- 清单要可执行，不要写"代码要好"这种空话
- 每项要能机器验证或人工快速判断
- 控制在 80 行以内（太长审查者看不下去）
```

### 15.4 验收

- [ ] 每一项审查点都可执行（能跑命令或读代码判断）
- [ ] `/quick-review` 引用 3 关清单
- [ ] `/full-review` 引用 9+ 关清单

### 15.5 实战项目示例：QMS
[2REVIEW.md](file/2REVIEW.md)

---

## 章十六：openspec/config.yaml 模型路由配置

### 16.1 文件作用

OpenSpec 的项目级配置，包含模型路由、技能激活、schema 自定义。

### 16.2 完整模板

```yaml
# openspec/config.yaml
project:
  name: {项目名}
  version: 1.0.0
  type: spring-boot        # spring-boot / node / python / other
  language: java
  build_tool: maven

tech_stack:
  framework: spring-boot
  framework_version: 2.7.18
  orm: mybatis-plus        # jpa / mybatis / mybatis-plus
  orm_version: 3.5.3.1
  database: mysql          # mysql / postgresql / oracle
  java_version: 8

model_routing:
  default: sonnet
  by_checkpoint:
    propose: opus
    specs-draft: sonnet
    design-draft: opus
    tasks-decompose: sonnet
    task-execute: sonnet
    review-quick: sonnet
    review-full: opus
    archive: haiku

skills_activation:
  - springboot-patterns
  - springboot-tdd
  - jpa-patterns
  - api-design
  - database-migrations
  - quick-review

schema_customization:
  proposal_required_sections:
    - why
    - what-changes
    - impact
  specs_required_sections:
    - user-stories
    - acceptance-criteria
    - non-functional
  design_required_sections:
    - architecture
    - data-model
    - api-contract
    - risks
  tasks_required_sections:
    - task-list
    - dependencies
    - acceptance-per-task

protected_paths:
  - src/main/resources/application.yml
  - src/main/resources/db/migration/
  - src/main/resources/sql/
  - "**/finance/**"           # 财务模块红线

notification:
  on_checkpoint:
    - openspec-generated
    - plan-generated-and-confirmed
    - reviewed
    - archived
```

### 16.3 AI 自动补全提示词

```
请基于本项目实际情况生成 openspec/config.yaml。要求：

1. 探测项目实际信息（重要：必须基于实际探测，不要编造）：
   - pom.xml → project.name, project.version, project.type, tech_stack 全部字段
   - src/main/resources/application.yml → database 类型
   - src/main/resources/db/migration/ → 是否有 flyway/liquibase

2. 基于探测结果填充模板（见上方完整模板）

3. protected_paths 段：
   - 默认包含 application.yml / db/migration / sql
   - 扫描 src/main/java/ 找出"核心业务包"（看 @Transactional 集中的包），加入保护

4. skills_activation 段：
   - 默认激活 springboot / jpa / api-design / database-migrations
   - 探测到 Spring Security → 加 springboot-security
   - 探测到 Docker → 加 docker-patterns

5. schema_customization 段：
   - 如果项目简单（< 5 个 Entity），用默认 schema
   - 如果项目复杂（≥ 10 个 Entity），加 risks 段强制
   - 如果是微服务，加 service-contract 段

6. 验证：openspec validate 必须通过

7. commit: "docs: 生成 openspec/config.yaml"

注意：
- YAML 缩进必须正确（2 空格）
- 版本号必须和 pom.xml 完全一致
- 不要写项目没有的技术栈
```

### 16.4 验收

- [ ] `openspec validate` 通过
- [ ] `cat openspec/config.yaml | grep framework_version` 和 pom.xml 一致
- [ ] 模型路由生效（跑 `/hyperspec` 时各阶段模型正确）

### 16.5 实战项目示例：QMS
[2openspec-config.yaml](file/2openspec-config.yaml)

---

## 章十七：docs/architecture/ 架构文档群

### 17.1 文件作用

向 AI 提供项目全局架构视角，避免 AI 改代码时"只见树木不见森林"。

### 17.2 文档清单

| 文件 | 作用 |
|------|------|
| `overview.md` | 项目整体架构图（C4 模型 Context 级） |
| `modules.md` | 模块依赖关系图 |
| `layers.md` | 分层架构（Controller/Service/Mapper/Entity） |
| `data-flow.md` | 核心业务的数据流 |
| `decisions.md` | ADR（Architecture Decision Records） |

### 17.3 AI 自动补全提示词

```
请基于本项目代码生成 docs/architecture/ 下的 5 个文档。要求：

### 17.3.1 overview.md（架构总览）

1. 扫描 src/main/java/ 列出顶层包（如 com.xxx.user / com.xxx.finance）
2. 读 pom.xml 识别技术栈
3. 读 application.yml 识别中间件（Redis/MQ/ES）
4. 生成 C4 Context 级架构图（用 mermaid）：
   ```mermaid
   graph TB
   User[用户] --> App[本系统]
   App --> DB[(MySQL)]
   App --> Redis[(Redis)]
   App --> MQ[RabbitMQ]
   ```mermaid
5. 一段话定位：项目做什么、给谁用、核心价值

### 17.3.2 modules.md（模块依赖）

1. 扫描每个顶层包，识别包之间的依赖（看 import 语句）
2. 生成依赖图（mermaid graph LR）
3. 标注每个模块的职责（一句话）
4. 标注模块边界（哪些模块禁止互相依赖）

### 17.3.3 layers.md（分层架构）

1. 抽样 5 个 Controller / 5 个 Service / 5 个 Mapper
2. 总结本项目的分层规范：
   - Controller 层职责（参数校验、调用 Service、返回 VO）
   - Service 层职责（业务逻辑、事务、调 Mapper）
   - Mapper 层职责（数据库操作）
   - Entity / DTO / VO 的转换规则
3. 用 ASCII 画分层图

### 17.3.4 data-flow.md（核心数据流）

1. 识别项目最核心的 3-5 个业务用例（如"下单"、"支付"、"对账"）
2. 对每个用例画 sequence diagram（mermaid sequenceDiagram）
3. 标注：
   - 涉及哪些表
   - 跨越哪些模块
   - 异常分支怎么走
4. 如果项目特殊用例识别不出来，让我提示

### 17.3.5 decisions.md（ADR 架构决策记录）

1. 扫描代码找"为什么"的线索：
   - 为什么用 MyBatis-Plus 而非 JPA
   - 为什么单体而非微服务
   - 为什么用同步而非异步
2. 对每个决策写 ADR：
   ```markdown
   # ADR-001: 选择 MyBatis-Plus 而非 JPA

   ## 状态
   Accepted

   ## 背景
   {探测到的线索：SQL 复杂度高、团队习惯}

   ## 决策
   使用 MyBatis-Plus

   ## 后果
   - 优点：SQL 可控、性能可优化
   - 缺点：跨数据库移植性差
   ```markdown

5. 如果探测不到决策依据，列出 5 个候选决策让我确认

### 17.3.6 提交

6. commit: "docs: 生成 architecture 架构文档群（5 个文件）"

注意：
- 不要凭空写"未来可能扩展到微服务"——只写已经存在的事实
- mermaid 图必须能渲染（语法正确）
- ADR 必须基于代码证据，不要瞎编
- 每个文件控制在 100 行以内
```

### 17.4 验收

- [ ] 5 个文件都生成
- [ ] mermaid 图能在 GitHub 渲染
- [ ] 模块依赖图与实际 import 一致

### 17.5 实战项目示例：QMS
[data-flow.md](file/architecture/data-flow.md)
[decisions.md](file/architecture/decisions.md)
[layers.md](file/architecture/layers.md)
[modules.md](file/architecture/modules.md)
[overview.md](file/architecture/overview.md)

---

## 章十八：docs/database/ 数据库文档群

### 18.1 文件作用

让 AI 改 SQL / Entity 时理解数据库全局。

### 18.2 文档清单

| 文件 | 作用 |
|------|------|
| `schema.md` | 数据库表清单 + ER 图 |
| `conventions.md` | 命名规范、字段类型规范 |
| `migrations.md` | 迁移脚本规范（Flyway/Liquibase） |
| `indexes.md` | 索引清单 + 设计依据 |

### 18.3 AI 自动补全提示词

```
请基于本项目代码生成 docs/database/ 下的 4 个文档。要求：

### 18.3.1 schema.md（表清单 + ER 图）

1. 探测数据源（按优先级）：
   a. application.yml 的数据库连接 → 连数据库读 information_schema（如果有权限）
   b. src/main/resources/sql/*.sql 文件 → 解析 CREATE TABLE
   c. src/main/resources/db/migration/ → Flyway 迁移脚本
   d. 实体类（@Table / @TableName 注解）→ 反推表结构

2. 对每张表生成：
   - 表名（含中文注释）
   - 字段清单（字段名、类型、是否可空、默认值、注释）
   - 主键、唯一键、外键
   - 索引

3. 生成 ER 图（mermaid erDiagram）：
   ```mermaid
   erDiagram
   USER ||--o{ ORDER : places
   ORDER ||--|{ ORDER_ITEM : contains
   USER {
     bigint id PK
     string username
   }
   ```mermaid

### 18.3.2 conventions.md（数据库规范）

1. 扫描现有表结构，总结规范：
   - 表名风格（snake_case vs camelCase）
   - 字段命名（created_at / create_time）
   - 主键风格（id vs xxx_id）
   - 软删除（deleted_at / is_deleted）
   - 审计字段（created_by / updated_by / created_at / updated_at）
2. 写规范文档：
   - 必须字段（每张表都要有的）
   - 命名规则
   - 字段类型选择（金额用 decimal、状态用 tinyint）

### 18.3.3 migrations.md（迁移规范）

1. 探测迁移工具：
   - 有 flyway-core 依赖 → Flyway 规范
   - 有 liquibase-core 依赖 → Liquibase 规范
   - 都没有 → 写手动 SQL 规范

2. 写规范：
   - 文件命名（V{版本}__{描述}.sql）
   - 必须向前兼容（不能直接 DROP COLUMN）
   - 大表变更需要分批
   - 索引创建必须用 ONLINE（MySQL）

### 18.3.4 indexes.md（索引清单）

1. 扫描现有索引：
   - 从 schema 提取所有 CREATE INDEX
   - 或从数据库读（如果有权限）

2. 列出所有索引 + 设计依据：
   - 哪些字段常被 WHERE（看 Mapper.xml / Repository）
   - 哪些字段常被 ORDER BY
   - 哪些字段常被 JOIN

3. 给出索引优化建议（仅列出明显的，不要过度）

### 18.3.5 提交

commit: "docs: 生成 database 数据库文档群（4 个文件）"

注意：
- 不要修改实际数据库，只读不写
- 表结构以代码事实为准（migration 文件 > entity 注解）
- ER 图控制在 30 个实体以内（太大拆多个图）
- 如果某项探测失败，明确写 "TODO: 需要人工补充"
```

### 18.4 验收

- [ ] schema.md 列出项目所有表
- [ ] ER 图能在 GitHub 渲染
- [ ] conventions.md 反映项目真实习惯（不是教科书规范）

### 18.5 实战项目示例：QMS
[conventions.md](file/database/conventions.md)
[indexes.md](file/database/indexes.md)
[migrations.md](file/database/migrations.md)
[schema.md](file/database/schema.md)

---

## 章十九：docs/standards/ 编码规范群

### 19.1 文件作用

细化的编码规范，被 ECC 技能和 Review 引用。

### 19.2 文档清单

| 文件 | 作用 |
|------|------|
| `java.md` | Java 编码规范 |
| `spring.md` | Spring Boot 使用规范 |
| `mybatis.md` / `jpa.md` | ORM 规范（按项目选） |
| `testing.md` | 测试规范 |
| `naming.md` | 命名规范 |

### 19.3 AI 自动补全提示词

```
请基于本项目代码生成 docs/standards/ 下的规范文档。要求：

### 19.3.1 java.md（Java 规范）

1. 扫描项目代码总结（不要照搬阿里巴巴 Java 规范，要基于项目实际）：
   - 包结构习惯（com.xxx.{module}.{layer}）
   - 类命名（XxxController / XxxServiceImpl / XxxMapper）
   - 方法命名（业务方法 vs 工具方法风格）
   - 异常使用（自定义异常 vs RuntimeException）
   - 注解使用（@Slf4j / @Data / @RequiredArgsConstructor 的普及度）
   - Stream / Optional 的使用频率

2. 写规范文档：
   - 必须遵守（红色线）
   - 推荐做法（绿色）
   - 禁止做法（黑色）

### 19.3.2 spring.md（Spring Boot 规范）

1. 探测项目实际用法：
   - @RestController vs @Controller + @ResponseBody
   - @Service 是否带接口
   - @Autowired 字段注入 vs 构造器注入（用 @RequiredArgsConstructor）
   - @Transactional 使用范围（Service vs Method）
   - 配置管理（application.yml vs @Value vs @ConfigurationProperties）

2. 写规范：
   - 强制（如"必须构造器注入"）
   - 选择（如"@Transactional 加在 Service 类还是方法上"）
   - 配置文件分层（application.yml / application-dev.yml / application-prod.yml）

### 19.3.3 mybatis.md 或 jpa.md（ORM 规范，按项目选）

如果项目用 MyBatis-Plus：
1. 探测：
   - Mapper 接口 vs XML SQL 的使用比例
   - BaseMapper 扩展习惯
   - LambdaQueryWrapper vs QueryWrapper
   - 分页插件配置
2. 规范：
   - 简单 CRUD 用 BaseMapper
   - 复杂查询用 XML
   - 禁止手写 SQL 拼接

如果项目用 JPA：
1. 探测：
   - Entity 关联（@OneToMany / @ManyToOne 使用）
   - Fetch 类型（LAZY vs EAGER）
   - Repository 自定义查询
2. 规范：
   - 默认 LAZY
   - N+1 问题避免
   - 复杂查询用 Specification 或 @Query

### 19.3.4 testing.md（测试规范）

1. 探测：
   - 测试覆盖率（如果项目有 jacoco 报告）
   - 测试命名风格（should_xxx vs testXxx）
   - @SpringBootTest vs @DataJpaTest 等切片测试
   - Mock 使用（@MockBean vs @Mock + @ExtendWith）

2. 规范：
   - 测试目录结构（src/test/java 镜像 main）
   - 命名（should_return_xxx_when_yyy）
   - AAA 结构（Arrange / Act / Assert）
   - 测试覆盖目标（核心 Service ≥ 80%，Controller ≥ 60%）

### 19.3.5 naming.md（命名规范）

1. 扫描项目实际命名习惯：
   - 包名（com.xxx.yyy）
   - 类名后缀（Controller / Service / Impl / Mapper / Repository / Entity / DTO / VO / BO）
   - 方法名（业务命名 vs CRUD 命名）
   - 常量（UPPER_SNAKE vs camelCase）
   - 数据库字段（snake_case）

2. 规范文档：
   - 后缀含义表（DTO vs VO vs BO 的区别）
   - 命名禁忌（如 ServiceImpl 不要写成 Service）
   - 中文映射（业务术语 → 代码命名）

### 19.3.6 提交

commit: "docs: 生成 standards 编码规范群"

注意：
- 规范要基于项目现状，不是教科书
- 如果项目实际做法"不规范"，先记录现状，再标记"建议改进"
- 每个文件 ≤ 80 行
- 不要塞项目没用到的技术
```

### 19.4 验收

- [ ] 每个文件基于项目实际代码生成（不是泛泛规范）
- [ ] AI 改代码时遵循这些规范
- [ ] Review 时引用这些规范

### 19.5 实战项目示例：QMS
[java.md](file/standards/java.md)
[mybatis.md](file/standards/mybatis.md)
[naming.md](file/standards/naming.md)
[spring.md](file/standards/spring.md)
[testing.md](file/standards/testing.md)

---

## 章二十：docs/harness/ Harness 自文档

### 20.1 文件作用

把 Harness 配置本身文档化，让新人（包括 AI）理解项目用了 Harness 的哪些能力。

### 20.2 文档清单

| 文件 | 作用 |
|------|------|
| `overview.md` | Harness 落地总览（用了哪几层） |
| `commands.md` | 项目可用 slash 命令速查 |
| `hooks.md` | Hook 清单 + 拦截规则 |
| `skills.md` | 激活的技能清单 + 触发条件 |
| `workflow.md` | 一次完整需求的工作流（从 /hyperspec 到 archive） |
| `troubleshooting.md` | 常见问题排查 |

### 20.3 AI 自动补全提示词

```
请基于本项目 Harness 实际配置生成 docs/harness/ 下的 6 个文档。要求：

### 20.3.1 overview.md（Harness 落地总览）

1. 扫描 .claude/ 目录，识别实际启用的能力：
   - .claude/skills/ 下有哪些 skill 目录
   - .claude/hooks/ 下有哪些 hook 脚本
   - .claude/commands/ 下有哪些命令
   - .claude/team-roles/ 下有哪些角色（单实例多角色编排）
   - .claude/instincts/ 下有哪些本能

2. 生成 7 层架构落地清单表：
   | 层 | 状态 | 实际文件 |
   |----|------|---------|
   | L1 OpenSpec | ✅ 启用 | openspec/ |
   | L2 Superpowers | ✅ 启用 | tdd + verification |
   | ... | | |

3. 一段话总结：本项目的 Harness 用到了什么程度（基础 / 中级 / 高级）

### 20.3.2 commands.md（命令速查）

1. 列出所有可用的 slash 命令：
   - OpenSpec: /opsx:explore /opsx:propose /opsx:continue /opsx:ff /opsx:verify /opsx:apply /opsx:archive
   - HyperSpec: /hyperspec /quick-review /full-review
   - gstack: 列出实际安装的命令
   - Superpowers: 列出实际安装的命令
   - 自建: /...

2. 对每个命令写：
   - 作用（一句话）
   - 触发条件（什么时候用）
   - 示例（一个具体的调用例子）

3. 按使用频率排序（高频在上）

### 20.3.3 hooks.md（Hook 文档）

1. 读 .claude/settings.local.json，列出所有注册的 hook
2. 对每个 hook 写：
   - 触发时机（PreToolUse / PostToolUse / SessionStart / SessionEnd）
   - 拦截规则
   - 临时绕过方法
   - 调试方法（如何手动跑一次）

3. 重要提醒：
   - 哪些是"硬拦截"（会阻止操作）
   - 哪些是"软提醒"（只警告）

### 20.3.4 skills.md（技能文档）

1. 读 .claude/settings.local.json 的 active_skills 字段
2. 对每个激活的 skill 写：
   - 名称
   - 作用
   - 自动触发条件（如果 always_active）
   - 手动调用方式
   - 何时不该用

3. 分类：
   - 工作流类（TDD / verification）
   - 领域类（springboot / jpa）
   - 审查类（quick-review / gstack）
   - 工具类（mcp / ast）

### 20.3.5 workflow.md（完整工作流）

1. 用一个真实例子（最好是项目最近做过的需求）演示完整流程：
   Step 1: 用户输入 /hyperspec "添加用户登录"
   Step 2: 项目探测（profiler-done checkpoint）
   Step 3: 需求澄清（requirements-confirmed）
   Step 4: 生成 4 工件（openspec-generated）
   Step 5: TDD 计划（plan-generated）
   Step 6: 确认计划（plan-generated-and-confirmed）
   Step 7: 执行 tasks（task-N-complete）
   Step 8: 验证（verified）
   Step 9: 审查（reviewed）
   Step 10: 应用（apply-done）
   Step 11: 一致性验证（consistency-verified）
   Step 12: 归档（archived）

2. 对每个 Step 写：
   - 谁在做（PM / Architect / Developer / Reviewer）
   - 输入什么（上游 artifact）
   - 输出什么（下游 artifact）
   - 用的什么命令
   - 用时多久（实测）

3. 画流程图（mermaid flowchart）

### 20.3.6 troubleshooting.md（常见问题）

列出 10 个高频问题 + 解决方案：
1. /hyperspec 跑到一半卡住怎么办
2. Hook 误拦截合法操作怎么办
3. AI 用错模型（如 archive 用了 opus）怎么办
4. OpenSpec validate 报错怎么办
5. 测试覆盖不足被 verification 卡住怎么办
6. quick-review 不通过但不知道哪一关
7. 角色切换后上下文残留（如 Developer 视角污染 Reviewer 判断）怎么办
8. 本能层积累的"垃圾知识"怎么清理
9. AI 改了不该改的文件（红线模块）怎么办
10. Maven 路径找不到怎么办

### 20.3.7 提交

commit: "docs: 生成 harness 自文档（6 个文件）"

注意：
- 文档要真实反映项目状态（探测失败就写"未启用"，不要瞎编）
- 命令清单按项目实际安装的为准
- workflow 那篇用真实例子，不要套模板
```

### 20.4 验收

- [ ] overview.md 与 .claude/ 目录真实状态一致
- [ ] commands.md 列出的命令都能在 Claude Code 内找到
- [ ] workflow.md 用的是真实例子

### 20.5 实战项目示例：QMS
[workflow.md](file/workflow.md)
[troubleshooting.md](file/troubleshooting.md)
[skills.md](file/skills.md)
[hooks.md](file/hooks.md)
[commands.md](file/commands.md)
[overview.md](file/overview.md)

---

# 第四部分：流程演示与排错

## 章二十一：完整流程跑通（真实需求演示）

### 21.1 演示需求

用"为系统添加用户登录功能"作为演示，跑通 12 个 checkpoint。

### 21.2 步骤

```bash
# Step 1: 确认 Harness 就绪
cd your-project
claude                                    # 启动 Claude Code

# 在 Claude Code 内：

# Step 2: 提需求
/hyperspec "添加用户登录功能，要求：
- 用户名密码登录
- 密码用 BCrypt 加密
- 支持 token 续期
- 失败 5 次锁定 30 分钟"

# Step 3: AI 自动跑完 propose 阶段
# - 探测项目（找到 Spring Security 现状）
# - 与你多轮澄清（你想用什么 token？JWT 还是 Session？）
# - 生成 proposal.md
# - checkpoint: profiler-done → requirements-confirmed → openspec-generated

# Step 4: 确认 proposal
# AI 会问"proposal 是否确认？"，确认后进入 plan

# Step 5: AI 自动生成 TDD 计划
# - 拆分 5-8 个 task
# - 标注依赖关系
# - checkpoint: plan-generated → plan-generated-and-confirmed

# Step 6: 确认计划
# 检查 tasks.md，可以调整

# Step 7: 执行 task
# - AI 按 task 顺序执行
# - 每个 task 走 TDD（红 → 绿 → 重构）
# - 每个 task 完成后 auto commit
# - checkpoint: task-1-complete → task-2-complete → ... → task-N-complete

# Step 8: 验证
# - 跑所有测试
# - checkpoint: verified

# Step 9: 审查
# - AI 自动跑 /quick-review 或 /full-review（按 task 数）
# - checkpoint: reviewed

# Step 10: 应用 + 归档
# - checkpoint: apply-done → consistency-verified → archived → done
```

### 21.3 期望耗时

| 阶段 | 耗时 |
|------|------|
| propose（含澄清） | 10-15 分钟 |
| plan | 5-10 分钟 |
| task 执行（5 个 task） | 30-60 分钟 |
| verify + review | 10-15 分钟 |
| archive | 2-5 分钟 |
| **总计** | **60-100 分钟** |

### 21.4 中途出问题怎么办

| 问题 | 应对 |
|------|------|
| AI 卡在某个 checkpoint | Ctrl+C，重新跑 `/hyperspec`，会从断点继续 |
| Hook 误拦截 | 看错误信息，调整 `.claude/hooks/*.py` 规则 |
| 测试不通过 | AI 会自动修复，最多 3 轮；超过则人工介入 |
| 审查不通过 | AI 会按 review 报告修复，最多 3 轮 |

---

## 章二十二：常见问题排查

### 22.1 环境问题

| 现象 | 原因 | 解决 |
|------|------|------|
| `mvn: command not found` | Maven 不在 PATH | 用全路径 `/c/Program Files/JetBrains/.../mvn.cmd` |
| `claude: command not found` | Claude Code 未装 | `npm i -g @anthropic-ai/claude-code` |
| JAVA_HOME 不对 | JDK 路径变 | `export JAVA_HOME=/d/jdk1.8.0_171` |
| `/opsx:explore` 不识别 | OpenSpec 未装 | `npm i -g @fission-ai/openspec` |

### 22.2 流程问题

| 现象 | 原因 | 解决 |
|------|------|------|
| `/hyperspec` 一开始就报错 | .hyperspec-state.yaml 损坏 | 删除重跑 |
| 跑到一半 AI 退出 | 模型限流 / 网络问题 | 重新跑 `/hyperspec`，从断点继续 |
| Hook 把所有 Edit 都拦了 | guard_write.py 配置过严 | 临时 `export HARNESS_ALLOW_WRITE=1` |
| AI 用了 opus 跑 archive | 模型路由没生效 | 检查 openspec/config.yaml |

### 22.3 文档问题

| 现象 | 原因 | 解决 |
|------|------|------|
| AI 不遵守 AGENTS.md | AGENTS.md 太长 / 冲突 | 精简到 80 行内；删除和 CLAUDE.md 重复的部分 |
| AI 用错 Spring Boot 版本 | pom.xml 版本和文档不一致 | 重新生成 AGENTS.md（章十三提示词） |
| 审查清单不适用项目 | REVIEW.md 是通用模板 | 用章十五提示词重新生成 |

### 22.4 调试技巧

```bash
# 1. 看 HyperSpec 状态
cat .hyperspec-state.yaml

# 2. 看本次会话用了哪些模型
grep "model" ~/.claude/logs/{latest}.log

# 3. 看 Hook 是否触发
cat .claude/hooks.log 2>/dev/null

# 4. 手动跑 hook 验证
python .claude/hooks/guard_write.py <test-path>

# 5. 看 OpenSpec 状态
openspec list
openspec validate
```

---

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
- 同时 ≥ 3 个并发育求
- 单需求 task ≥ 8 个且无依赖、可真并行
- 跨模块大型重构

**升级前提**：单实例方案已稳定运行 ≥ 2 个月，且团队能投入 2-3 周开发 Python 编排器。

**绝大多数项目永远不需要升级**——单实例多角色已覆盖 95%+ 场景。

---

# 附录

## 附录 A：完整目录树参考

见章三 3.1 节。

## 附录 B：命令速查表

| 命令 | 作用 | 阶段 |
|------|------|------|
| `/hyperspec "需求描述"` | 一键全自动 | 全流程 |
| `/opsx:explore` | 项目探测 | propose |
| `/opsx:propose` | 生成 4 工件 | propose |
| `/opsx:continue` | 继续上次中断 | 断点恢复 |
| `/opsx:ff` | 快进到下一 checkpoint | 调试 |
| `/opsx:verify` | 验证一致性 | verify |
| `/opsx:apply` | 应用变更 | apply |
| `/opsx:archive` | 归档 | archive |
| `/quick-review` | 3 关快速审查 | review |
| `/full-review` | 9 关深度审查 | review |
| `/instinct-export` | 导出本能 | SessionEnd |
| `/instinct-import` | 导入本能 | SessionStart |

## 附录 C：参考文档索引

### 项目内文档
- `Harness V2 架构设计文档.md` — 架构理论基础（角色编排详见第 8 章）
- `Harness 使用指南.md` — 用户视角使用指南
- `Harness V2 PPT生成文档.md` — 培训 PPT 素材

### 参考项目
- `everything-claude-code/` — ECC 插件市场（L4 技能来源）
- `oh-my-claudecode/` — OMC（L5 MCP 工具来源）

### Obsidian 知识库（精选 5 篇）
路径前缀：`C:\Users\wengjl\iCloudDrive\iCloud~md~obsidian\知识库\笔记同步助手\`

1. `2026-05-25\Harness Engineering 从零理解到动手实践.md` — Harness 三支柱理论
2. `2026-05-25\从 Rule、Spec 到 Harness：AI Coding 的渐进式建设路径.md` — 四层控制面
3. `2026-05-25\从Prompt、Context到Harness，工程的三次进化与终局之战.md` — 三次进化论
4. `2026-05-26\逆天的架构：用 Harness+Langgraph+A2A 写一个 Agent Team.md` — 多 agent 理论扩展（本项目不采用，仅供了解）
5. `2026-05-20\OpenSpec 项目实战（一）从零搭建项目骨架.md` — OpenSpec 脚手架实录

## 附录 D：落地检查清单（Print & Tick）

### 准备阶段
- [ ] 章一 前置条件全部通过
- [ ] 章二 必装组件全部装好
- [ ] 章三 目录骨架创建完成

### 7 层架构
- [ ] 章四 L1 OpenSpec 装好且能 validate
- [ ] 章五 L2 Superpowers TDD 激活
- [ ] 章六 L3 双轨审查可用
- [ ] 章七 L4 ECC 技能按项目激活
- [ ] 章八 L5 OMC MCP 工具可用
- [ ] 章九 L6 本能层骨架建好
- [ ] 章十 L7 HyperSpec 能跑通 5+ checkpoint
- [ ] 章十一 安全保护层 4 个 Hook 注册
- [ ] 章十二 模型路由配置生效

### 项目文档（AI 自动补全）
- [ ] 章十三 AGENTS.md 生成
- [ ] 章十四 CLAUDE.md 生成
- [ ] 章十五 REVIEW.md 生成
- [ ] 章十六 openspec/config.yaml 生成
- [ ] 章十七 docs/architecture/ 5 个文档生成
- [ ] 章十八 docs/database/ 4 个文档生成
- [ ] 章十九 docs/standards/ 5 个文档生成
- [ ] 章二十 docs/harness/ 6 个文档生成

### 角色编排（章二十三）
- [ ] `.claude/team-roles/` 下 8 个角色文件已创建
- [ ] `.claude/team-roles/permissions.json` 权限矩阵生效
- [ ] `.claude/commands/coordinator.md` 子命令可用（switch-to/rollback/status）
- [ ] apply-role.sh SessionStart 加载角色配置
- [ ] guard_write.py 按角色拦截越权
- [ ] docs/harness/role-orchestration.md 记录设计

### 验证
- [ ] 章二十一 用真实需求跑通完整流程
- [ ] 章二十二 排查指南可用

**全部勾选完成 = Harness V2 落地成功** 🎉

---

> 手册版本：1.0
> 维护策略：随架构演进而更新；每次大改架构同步更新本手册
> 反馈渠道：落地过程中遇到问题，记录到 `docs/harness/troubleshooting.md` 持续积累
