# sunny-mcp-adapter 详细落地方案

> **文档版本**：v1.0
> **日期**：2026-07-24
> **作者**：集团 IT 部
> **状态**：待团队评审
> **目的**：基于 v3 设计（`2026-07-24-mcp-adapter-design-v3.md`），提供 sunny-mcp-adapter 项目的分阶段详细落地方案，目标是 4 周内完成可演示的最小 demo，作为团队评审与下一步规划的依据
> **演示目标**：本地启动 QMS 真实业务系统 + sunny-mcp-adapter（qms-adapter 分支）+ 本地 MCP 客户端，端到端跑通

---

## 1. 目标与范围

### 1.1 demo 目标

向团队展示 v3 方案的核心能力，验证以下关键问题：

1. **业务系统零改动**：QMS 真实代码不动，仅引入 `mcp-auth-filter`
2. **声明式工具可行**：YAML 定义工具即可上线，不写 Java 代码
3. **智能翻译层有效**：Result 自动解包、c/n/d 字段重命名、DTO 嵌套包装三大支柱在实际 QMS API 上工作
4. **MCP 协议跑通**：本地 MCP 客户端能 list / call 工具
5. **分支策略可维护**：master 框架 + 业务分支配置的代码组织可行

### 1.2 demo 范围

**包含**：
- master 分支：框架核心（MCP 协议、工具加载、翻译层、治理最简版）
- qms-adapter 分支：QMS 配置 + 2-3 个真实 QMS 工具
- 共享 MySQL：授权表 + 审计表（含 namespace 字段）
- 本地演示：QMS 业务系统本地启动 + Adapter 本地启动 + MCP 客户端

**不包含**（demo 后再做）：
- 可视化工具编辑器
- 完整的治理（精细限流、熔断、Webhook）
- K8s 部署（demo 用本地）
- 多 Adapter 横向铺开（demo 只做 QMS）
- 安全生产加固（JWT 验签简化、HTTPS 暂用 HTTP）

### 1.3 时间盒

**4 周**：3 周开发 + 1 周演示材料与团队评审准备。

---

## 2. 关键约束（用户提供）

| # | 约束 | 说明 |
|---|---|---|
| 1 | 业务系统 | 真实 QMS（本地启动服务演示） |
| 2 | 演示方式 | 本地 Adapter + 本地 MCP 客户端配置 |
| 3 | 仓库策略 | 单 git 仓库 `sunny-mcp-adapter`，master 主干 + 业务分支 |
| 4 | 配置隔离 | 业务分支只放配置 + 工具 YAML + 业务专属定制代码 |
| 5 | 数据库 | 共享同一个 MySQL 实例（不浪费资源） |
| 6 | K8s 部署 | 各业务 namespace 拉取同 git 项目不同分支构建镜像 |

---

## 3. 整体架构

### 3.1 系统拓扑（demo 阶段）

```
┌────────────────────────────────────────────────────────────┐
│  本地 MCP 客户端（Claude Desktop / mcp-inspector / curl）   │
└──────────────────────┬─────────────────────────────────────┘
                       │ HTTP POST /mcp (JSON-RPC)
                       ▼
┌────────────────────────────────────────────────────────────┐
│  sunny-mcp-adapter（本地启动，qms-adapter 分支构建）         │
│  • MCP 协议端点                                            │
│  • 加载 tools/*.yml                                        │
│  • 智能翻译层（Result 解包 + 字段重命名 + DTO 包装）        │
│  • 调用业务 API                                            │
│  • 授权表 + 审计表（共享 MySQL）                            │
└──────────────────────┬─────────────────────────────────────┘
                       │ HTTP 调真实 QMS API
                       ▼
┌────────────────────────────────────────────────────────────┐
│  QMS 业务系统（本地启动，原样 + mcp-auth-filter）            │
│  • 真实 Controller、Service、Mapper                         │
│  • MySQL + PostgreSQL（QMS 自己的库）                       │
└────────────────────────────────────────────────────────────┘

                       Adapter 侧
                          │
                          ▼
                ┌──────────────────┐
                │ 共享 MySQL       │
                │ schema: mcp_adapter │
                │   mcp_tool_grant │
                │   mcp_audit_log  │
                └──────────────────┘
```

### 3.2 分支与部署对应（未来 K8s）

```
sunny-mcp-adapter 仓库（单 git）
│
├── master 分支          ← 框架主干
│
├── qms-adapter 分支     ← QMS 配置 + 工具
│   → 构建镜像 sunny-mcp-adapter:qms-<tag>
│   → 部署到 K8s namespace: qms
│
├── mes-adapter 分支     ← MES 配置 + 工具
│   → 构建镜像 sunny-mcp-adapter:mes-<tag>
│   → 部署到 K8s namespace: mes
│
└── wms-adapter / ems-adapter / ...
```

### 3.3 分支管理原则

| 内容 | master | 业务分支 |
|---|---|---|
| 框架代码（协议、翻译层、治理） | ✅ 维护 | ❌ 禁止改 |
| mcp-common / mcp-auth-filter | ✅ 维护 | ❌ 禁止改 |
| application.yml | 模板（占位符） | ✅ 覆盖为业务实际值 |
| tools/*.yml | 示例（可用作模板） | ✅ 业务真实工具 |
| 业务专属 Java 代码（@McpTool 复杂工具） | ❌ 不放 | ✅ 视需要添加 |
| 单元测试 / 集成测试 | ✅ 维护 | ✅ 可追加业务专属测试 |

**升级机制**：master 推进框架版本 → 各业务分支 `git rebase master` 或 `merge master` → 解决配置文件冲突（应该很少，因为业务分支只动配置和工具 YAML）。

---

## 4. 仓库结构

### 4.1 仓库布局（master 分支）

```
sunny-mcp-adapter/                              （git 根）
├── pom.xml                                      ← 父 POM（聚合模块）
├── README.md
├── CHANGELOG.md
├── .gitignore
├── docs/                                        ← 设计文档与开发指南
│   ├── architecture.md
│   ├── tool-yaml-guide.md                      ← 工具 YAML 编写指南
│   └── new-branch-guide.md                     ← 新建业务分支流程
│
├── mcp-common/                                  ← 共享 DTO、常量、错误码
│   ├── pom.xml
│   └── src/main/java/com/sunny/mcp/common/
│       ├── dto/UserContext.java
│       ├── dto/ToolDefinition.java
│       ├── constant/McpConstants.java
│       └── exception/McpException.java
│
├── mcp-auth-filter/                             ← 业务系统引入的鉴权 filter
│   ├── pom.xml
│   └── src/main/java/com/sunny/mcp/auth/
│       ├── McpAuthFilter.java
│       ├── McpServiceTokenValidator.java
│       └── UserContextHolder.java              ← ThreadLocal
│
├── mcp-adapter-framework/                      ← 框架核心（"starter"角色）
│   ├── pom.xml
│   ├── src/main/java/com/sunny/mcp/framework/
│   │   ├── autoconfigure/
│   │   │   ├── McpAdapterAutoConfiguration.java
│   │   │   ├── McpServerAutoConfiguration.java
│   │   │   ├── ToolLoaderAutoConfiguration.java
│   │   │   ├── TranslationEngineAutoConfiguration.java
│   │   │   └── GovernanceAutoConfiguration.java
│   │   ├── protocol/
│   │   │   ├── McpServerHandler.java           ← 实现 initialize/tools.list/tools.call
│   │   │   └── McpProtocolFilter.java          ← JWT 验签、X-User-* 提取
│   │   ├── tool/
│   │   │   ├── ToolLoader.java                 ← 启动时加载 tools/*.yml
│   │   │   ├── ToolRegistry.java               ← 内存工具表（Caffeine）
│   │   │   ├── ToolValidator.java              ← YAML schema 校验
│   │   │   └── ToolInvoker.java                ← 按 backend 定义发 HTTP
│   │   ├── translation/                        ← 智能翻译层（核心 IP）
│   │   │   ├── TranslationEngine.java          ← 翻译总调度
│   │   │   ├── ResultUnwrapper.java            ← Result 自动解包
│   │   │   ├── FieldRenamer.java               ← 字段重命名规则引擎
│   │   │   ├── DtoWrapper.java                 ← DTO 嵌套包装（wrap-to）
│   │   │   ├── FieldMasker.java                ← 字段脱敏
│   │   │   └── RowFilterApplier.java           ← 行级权限筛选
│   │   ├── governance/
│   │   │   ├── ToolGrantService.java           ← 工具授权查询
│   │   │   ├── AuditLogService.java            ← 审计日志写入
│   │   │   └── RateLimiter.java                ← 限流（Resilience4j）
│   │   └── annotation/
│   │       ├── EnableMcpAdapter.java
│   │       └── McpTool.java                     ← 复杂工具逃生通道
│   └── src/main/resources/
│       └── default-translation.yml              ← 默认翻译规则（c/n/d 前缀）
│
├── adapter-app/                                 ← Adapter 主程序（通用启动入口）
│   ├── pom.xml
│   ├── src/main/java/com/sunny/mcp/app/
│   │   └── McpAdapterApplication.java          ← @EnableMcpAdapter 启动类
│   └── src/main/resources/
│       ├── application.yml                     ← master 分支：模板（占位符）
│       ├── application-dev.yml                 ← 本地开发默认配置
│       └── tools/                              ← master 分支：示例工具
│           ├── _example-simple.yml             ← 示例：扁平入参 API
│           └── _example-complex.yml            ← 示例：嵌套 DTO + Result 包装
│
└── adapter-tests/                               ← 集成测试与端到端测试
    ├── pom.xml
    └── src/test/java/com/sunny/mcp/test/
        ├── translation/
        │   ├── ResultUnwrapperTest.java
        │   ├── FieldRenamerTest.java
        │   └── DtoWrapperTest.java
        ├── protocol/
        │   └── McpServerHandlerTest.java
        └── e2e/
            └── ToolCallE2ETest.java
```

### 4.2 业务分支的差异（以 qms-adapter 为例）

业务分支**只动** `adapter-app/`，其他模块完全跟随 master：

```
sunny-mcp-adapter/  (qms-adapter 分支)
├── mcp-common/                    ← 与 master 完全一致
├── mcp-auth-filter/               ← 与 master 完全一致
├── mcp-adapter-framework/         ← 与 master 完全一致
├── adapter-app/
│   ├── src/main/resources/
│   │   ├── application.yml        ← QMS 真实配置（覆盖 master 模板）
│   │   │                            （namespace: qms、QMS URL、QMS 服务账号 token）
│   │   └── tools/                 ← QMS 真实工具（替换 master 的示例）
│   │       ├── query-inspection-by-id.yml
│   │       ├── list-inspections.yml
│   │       └── query-device-by-factory.yml
│   └── src/main/java/com/sunny/mcp/app/
│       └── qms/                   ← 仅在需要复杂工具时
│           └── QmsCustomTools.java   ← @McpTool 注解的复杂工具
└── adapter-tests/
    └── src/test/.../qms/          ← QMS 专属测试
```

### 4.3 Maven 模块依赖关系

```
adapter-app  →  depends on  →  mcp-adapter-framework
                                    ↓
                              mcp-common
mcp-auth-filter  →  depends on  →  mcp-common
mcp-adapter-framework  →  depends on  →  mcp-common
```

> 注意：master 分支暂不发布到 Maven 私服。所有模块在单仓库内通过 Maven reactor 编译。未来若 sunny 平台团队需要复用 mcp-common 或 mcp-auth-filter，再考虑发私服。

---

## 5. 共享数据库设计

### 5.1 数据库选型

- **复用集团现有 MySQL 8.x 实例**（申请一个新 schema `mcp_adapter`）
- **不新建数据库实例**（遵循"不浪费资源"约束）

### 5.2 表结构（含 namespace 字段，所有 adapter 共享）

```sql
CREATE SCHEMA IF NOT EXISTS mcp_adapter DEFAULT CHARACTER SET utf8mb4;
USE mcp_adapter;

-- 工具授权表（多 adapter 共享，用 namespace 区分）
CREATE TABLE mcp_tool_grant (
  id              BIGINT       NOT NULL AUTO_INCREMENT,
  namespace       VARCHAR(50)  NOT NULL COMMENT '业务系统命名空间：qms/mes/wms/ems',
  user_id         VARCHAR(50)  NULL     COMMENT '员工 ID（与 role_id 二选一）',
  role_id         VARCHAR(50)  NULL     COMMENT '角色 ID',
  tool_name       VARCHAR(200) NOT NULL COMMENT '工具名（含 namespace 前缀）',
  decision        VARCHAR(10)  NOT NULL COMMENT 'allow / deny',
  effective_from  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  effective_to    DATETIME     NULL     COMMENT '可空，临时授权',
  created_by      VARCHAR(50)  NOT NULL,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_user_tool (namespace, user_id, tool_name),
  KEY idx_role_tool (namespace, role_id, tool_name),
  KEY idx_tool      (namespace, tool_name)
) ENGINE=InnoDB COMMENT='MCP 工具授权表';

-- 审计日志表（多 adapter 共享）
CREATE TABLE mcp_audit_log (
  id              BIGINT       NOT NULL AUTO_INCREMENT,
  namespace       VARCHAR(50)  NOT NULL,
  trace_id        VARCHAR(50)  NOT NULL,
  user_id         VARCHAR(50)  NOT NULL,
  tool_name       VARCHAR(200) NOT NULL,
  arguments_hash  VARCHAR(64)  NULL     COMMENT '参数 SHA-256，不存 PII 原文',
  status          VARCHAR(20)  NOT NULL COMMENT 'success / deny / error / timeout',
  duration_ms     INT          NOT NULL,
  error_code      VARCHAR(50)  NULL,
  error_msg       VARCHAR(500) NULL,
  called_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ns_time   (namespace, called_at),
  KEY idx_user_time (user_id, called_at),
  KEY idx_tool      (tool_name, called_at),
  KEY idx_trace     (trace_id)
) ENGINE=InnoDB COMMENT='MCP 调用审计日志表';
```

### 5.3 多租户策略

| 维度 | 实现 |
|---|---|
| 数据隔离 | `namespace` 字段（qms / mes / wms / ems） |
| 查询隔离 | 所有 SQL 必带 `WHERE namespace = ?` |
| 配置注入 | `application.yml` 配置 `mcp.adapter.namespace: qms` |
| 错误防护 | 框架层强制注入 namespace，业务代码无法绕过 |

### 5.4 demo 阶段简化

- demo 期间用本地 MySQL（如 `localhost:3306`）
- 不做历史数据归档
- 审计表预估 6 个月内数据量 < 100 万行，无需分区

---

## 6. 分阶段实施计划

### 阶段 1：项目骨架与 MCP 协议层（第 1 周）

**目标**：搭好仓库结构 + MCP 协议端点能响应 `initialize` / `tools/list`（空工具表）。

**任务清单**：

| # | 任务 | 产出 |
|---|---|---|
| 1.1 | 创建 git 仓库 `sunny-mcp-adapter`，初始化 master 分支 | git 仓库 |
| 1.2 | 搭建 Maven 父 POM + 5 个子模块（common / auth-filter / framework / app / tests） | pom.xml × 6 |
| 1.3 | 配置 Java 17 + Spring Boot 3.2.x + lombok + junit5 | 父 POM |
| 1.4 | 实现 mcp-common 基础 DTO（UserContext、ToolDefinition、McpException） | mcp-common |
| 1.5 | 引入 mcp-java-sdk 依赖，实现 McpServerHandler（initialize/tools.list/tools.call 三个方法） | mcp-adapter-framework |
| 1.6 | 实现 McpProtocolFilter（JWT 验签、X-User-* 提取到 UserContext） | mcp-adapter-framework |
| 1.7 | 实现 ToolRegistry（Caffeine 内存工具表，先空） | mcp-adapter-framework |
| 1.8 | 实现 adapter-app 启动类（@EnableMcpAdapter） | adapter-app |
| 1.9 | 配置 application-dev.yml（端口、DB 连接占位） | adapter-app |
| 1.10 | 本地启动验证：curl `POST /mcp` 调 initialize 与 tools/list 返回空工具集 | curl 通过 |

**阶段验证**：

```bash
# 启动 adapter-app
cd adapter-app && mvn spring-boot:run

# 测试 initialize
curl -X POST http://localhost:8085/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <mock-jwt>" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'

# 测试 tools/list（应返回空工具集）
curl -X POST http://localhost:8085/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <mock-jwt>" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
```

**交付物**：
- 可启动的 adapter-app
- MCP 协议端点跑通（空工具集）
- Maven 多模块结构成型
- README.md 含本地启动说明

---

### 阶段 2：声明式工具加载与基础调用（第 2 周前半）

**目标**：从 YAML 加载工具 + 简单 HTTP 调用（不带翻译层，先跑通链路）。

**任务清单**：

| # | 任务 | 产出 |
|---|---|---|
| 2.1 | 设计工具 YAML schema（参考 v3 文档第 4 节） | docs/tool-yaml-guide.md |
| 2.2 | 实现 ToolLoader（启动时扫描 `classpath:tools/*.yml`，SnakeYAML 解析） | framework/tool/ToolLoader |
| 2.3 | 实现 ToolValidator（必填字段、schema 合法性校验） | framework/tool/ToolValidator |
| 2.4 | 实现 ToolInvoker（按 backend 定义发 HTTP 请求，OkHttp） | framework/tool/ToolInvoker |
| 2.5 | 实现 `tools/call` 全链路（参数校验 → 调用 → 返回） | McpServerHandler |
| 2.6 | 写 2 个最简示例工具 YAML（`_example-simple.yml` 等） | adapter-app/tools/ |
| 2.7 | 集成测试：用 mock HTTP server 验证调用链路 | adapter-tests |

**阶段验证**：

```bash
# tools/list 应返回 2 个示例工具
curl -X POST http://localhost:8085/mcp \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

# tools/call 调用示例工具
curl -X POST http://localhost:8085/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call",
       "params":{"name":"example_echo","arguments":{"msg":"hello"}}}'
```

**交付物**：
- YAML 工具加载机制可用
- 工具调用链路打通（不含翻译层）

---

### 阶段 3：智能翻译层（第 2 周后半 ~ 第 3 周前半）

**目标**：实现 v3 核心IP——Result 解包 + 字段重命名 + DTO 包装。

**任务清单**：

| # | 任务 | 产出 |
|---|---|---|
| 3.1 | 实现 ResultUnwrapper（JsonPath 检测 `$.code` / `$.data`，按成功码判断） | framework/translation/ResultUnwrapper |
| 3.2 | 实现 FieldRenamer（正则规则引擎 + 例外白名单 + 递归处理容器） | framework/translation/FieldRenamer |
| 3.3 | 实现 DtoWrapper（`wrap-to` 模板解析与变量替换） | framework/translation/DtoWrapper |
| 3.4 | 实现 FieldMasker（按 field_mask 配置剔除字段） | framework/translation/FieldMasker |
| 3.5 | 实现 TranslationEngine（总调度：请求翻译 → 调用 → 响应翻译） | framework/translation/TranslationEngine |
| 3.6 | 集成到 ToolInvoker 调用链 | framework/tool/ToolInvoker |
| 3.7 | 配置默认翻译规则（`default-translation.yml`，c/n/d 前缀规则） | framework/resources/ |
| 3.8 | 单元测试：三大支柱各 10+ 测试用例（含边界） | adapter-tests/translation/ |
| 3.9 | 集成测试：mock 业务 API 返回 `Result<?>` + c/n/d 字段 + 嵌套 DTO，验证翻译正确 | adapter-tests/e2e/ |
| 3.10 | 打印字段重命名映射日志（启动时） | framework/translation/FieldRenamer |

**关键测试用例（必须覆盖）**：

```
ResultUnwrapper:
  ✓ 标准结构 { code: 200, msg, data } → 取 data
  ✓ 业务失败码（如 code = 500）→ 抛错，msg 返给 AI
  ✓ 非 Result 结构（直接是数据）→ 跳过解包
  ✓ data 为 null → 返空
  ✓ HTTP 4xx/5xx → 直接抛错

FieldRenamer:
  ✓ cCreateuser → createUser
  ✓ dCreatetime → createTime
  ✓ nVersion → version
  ✓ 白名单 cName → 保持 cName
  ✓ 嵌套对象 / List / Map 递归处理
  ✓ response.rename 显式映射优先于规则
  ✓ 不匹配任何规则 → 保持原名

DtoWrapper:
  ✓ ${param} 变量替换
  ✓ ${param:default} 默认值
  ✓ 必填参数缺失 → 校验失败
  ✓ 嵌套 JSON 构造（QmsDeviceMainDataDto 场景）
  ✓ 数字 / 字符串 / 布尔 / null 字面量
```

**阶段验证**：

启动后日志应打印：

```
[Tool: example_queryDevice] translation config:
  result-unwrap: true (path=$.data, success-codes=[200,0,"success"])
  field-rename rules: 3 active
    cCreateuser → createUser
    dCreatetime → createTime
    nVersion → version
  field-rename exceptions: [cName, nCount]
  dto-wrap: qmsDeviceMainDataDto.qmsDeviceMainData
```

**交付物**：
- 翻译层三大支柱可用
- 完整的单元测试与集成测试覆盖
- 默认 c/n/d 规则开箱即用

---

### 阶段 4：治理最简版与 mcp-auth-filter（第 3 周后半）

**目标**：授权表生效 + 审计落库 + QMS 引入 mcp-auth-filter。

**任务清单**：

| # | 任务 | 产出 |
|---|---|---|
| 4.1 | 创建共享 schema `mcp_adapter` + 两张表（grant / audit） | SQL 脚本 |
| 4.2 | 实现 ToolGrantService（查授权表，默认拒绝 + deny 优先 + 角色批量） | framework/governance/ |
| 4.3 | 实现 AuditLogService（异步写 mcp_audit_log） | framework/governance/ |
| 4.4 | 集成 Resilience4j 限流（按 userId + tool_name） | framework/governance/ |
| 4.5 | 实现 mcp-auth-filter（识别 X-MCP-Service-Token + 透传 X-User-Id 到 ThreadLocal） | mcp-auth-filter |
| 4.6 | mcp-auth-filter 单元测试 | mcp-auth-filter/src/test/ |
| 4.7 | 授权管理最小页面（可选，时间内做不完可后置）：先用 SQL 直接插数据 | — |

**阶段验证**：

```bash
# 授权表插入测试数据
INSERT INTO mcp_adapter.mcp_tool_grant 
  (namespace, user_id, tool_name, decision, created_by) 
VALUES 
  ('qms', 'demo_user', 'qms_queryInspectionById', 'allow', 'admin');

# 未授权用户调用 → 403
curl -X POST http://localhost:8085/mcp \
  -H "Authorization: Bearer <jwt-for-other-user>" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{...}}'

# 授权用户调用 → 成功，审计表有记录
SELECT * FROM mcp_adapter.mcp_audit_log ORDER BY id DESC LIMIT 1;
```

**交付物**：
- 治理三件套（授权 / 审计 / 限流）
- mcp-auth-filter 可被 QMS 引入

---

### 阶段 5：QMS 真实接入（第 3 周末，可与阶段 4 并行）

**目标**：QMS 业务系统本地启动 + 引入 mcp-auth-filter + 创建 qms-adapter 分支 + 落地 3 个真实工具。

**任务清单**：

| # | 任务 | 产出 |
|---|---|---|
| 5.1 | QMS 引入 mcp-auth-filter（Maven 依赖 + Filter 配置） | QMS pom.xml + WebConfig |
| 5.2 | QMS 本地启动验证（确认服务正常、原有 API 仍可用） | QMS 本地运行 |
| 5.3 | 从 master 创建 `qms-adapter` 分支 | git branch |
| 5.4 | 在 qms-adapter 分支配置 application.yml（namespace=qms、QMS URL、服务账号 token） | adapter-app/application.yml |
| 5.5 | 编写 3 个 QMS 真实工具 YAML（建议如下） | adapter-app/tools/ |
| 5.6 | 端到端联调：每个工具 curl 验证 | 测试记录 |

**3 个 demo 工具建议**（按实施难度递增）：

**工具 1：检验单查询（验证 Result 解包 + 字段重命名）**
```yaml
# tools/query-inspection-by-id.yml
tool:
  name: qms_queryInspectionById
  description: |
    按检验单号查询 QMS 检验单详情，含基础信息、检验项目、结果。
    必填：inspectionId（检验单号）
  backend:
    method: POST
    url: http://localhost:8084/qmsInspectionTask/update_init
    auth: { type: service-account, token: ${QMS_SERVICE_TOKEN} }
  params:
    - { name: inspectionId, type: string, required: true, description: 检验单号 }
  translation:
    request:
      wrap-to: |
        { "qmsInspectionTaskDto": { "qmsInspectionTask": { "id": ${inspectionId} } } }
    response:
      unwrap-result: true
  response:
    pick: [id, cInspectionno, cStatus, dInspecttime, cInspector]
    # 字段重命名走默认规则：cInspectionno → inspectionNo 等
  auth:
    field_mask: [cCreateuser, dCreatetime]
```

**工具 2：设备清单分页查询（验证 DTO 嵌套包装 + 分页）**

参照 v3 文档第 4.1 节示例。

**工具 3：不合格统计（验证复杂参数 + 聚合查询）**

按 QMS 实际有的"不良项统计"接口改造。

**阶段验证**：

```bash
# 在 qms-adapter 分支构建并启动
git checkout qms-adapter
cd adapter-app && mvn spring-boot:run

# 三个工具都能通过 curl 调用成功
curl -X POST http://localhost:8085/mcp \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call",
       "params":{"name":"qms_queryInspectionById",
                 "arguments":{"inspectionId":"INS20260724001"}}}'

# AI 看到的响应：字段是语义化命名（无 c/d 前缀）、无 Result 包装
```

**交付物**：
- qms-adapter 分支可用
- 3 个真实 QMS 工具端到端跑通
- 演示数据准备（QMS 库里有对应的检验单/设备/不良项数据）

---

### 阶段 6：本地 MCP 客户端演示配置（第 4 周前半）

**目标**：让团队在 Claude Desktop / mcp-inspector 看到真实调用效果。

**任务清单**：

| # | 任务 | 产出 |
|---|---|---|
| 6.1 | 评估 MCP 客户端支持 streamable-http 的程度（Claude Desktop 版本、mcp-inspector 等） | 评估报告 |
| 6.2 | 配置 mcp-inspector 连接本地 Adapter（最稳） | mcp-inspector config |
| 6.3 | 配置 Claude Desktop（若当前版本支持 streamable-http） | claude_desktop_config.json |
| 6.4 | 准备演示用 prompt 集（5-10 个真实问题） | docs/demo-prompts.md |
| 6.5 | 录制演示视频（备用，防止现场网络/服务问题） | demo-video.mp4 |

**演示用 prompt 示例**：

```
1. "帮我查一下检验单 INS20260724001 的详情"
   → AI 调用 qms_queryInspectionById

2. "F01 工厂有哪些设备？前 10 条"
   → AI 调用 qms_listDeviceByFactory

3. "最近一周哪些工厂的不合格率最高？"
   → AI 调用 qms_statDefectRate

4. "检验员张三今天检了哪些单子？"
   → 测试 AI 选择工具的准确性

5. "把检验单 INS20260724001 删掉"
   → 测试工具未授权 / 工具不存在的降级
```

**交付物**：
- 可现场演示的 MCP 客户端配置
- 演示 prompt 脚本
- 备用视频

---

### 阶段 7：演示材料与团队评审（第 4 周后半）

**目标**：准备好完整的团队评审材料。

**任务清单**：

| # | 任务 | 产出 |
|---|---|---|
| 7.1 | 编写团队评审 PPT（架构、demo 效果、后续规划） | review.pptx |
| 7.2 | 录制 5 分钟 demo 视频（核心场景） | demo.mp4 |
| 7.3 | 编写后续路线（demo 通过后的完整实施计划） | docs/roadmap.md |
| 7.4 | 准备 Q&A 文档（预判团队可能问的问题） | docs/qa.md |
| 7.5 | 内部演练 1-2 次 | — |

**评审材料结构**：

```
1. 背景与问题（5 min）
   - AI 浪潮下的挑战
   - 集团业务系统现状（引用 QMS 分析报告）

2. v3 方案介绍（10 min）
   - 核心理念：声明式 + 智能翻译
   - 与 v1/v2 的差异
   - 三大支柱

3. Demo 演示（10 min）
   - 现场跑或视频
   - 翻译层 before/after 对比

4. 分支与部署策略（5 min）
   - 单仓库多分支
   - 共享数据库
   - K8s 部署

5. 后续规划（5 min）
   - 通过后的实施路线
   - 风险与求助

6. Q&A（10+ min）
```

**交付物**：
- 评审 PPT
- Demo 视频
- 后续路线文档
- Q&A 文档

---

## 7. 每周里程碑与交付物汇总

| 周 | 阶段 | 关键里程碑 | 可见交付物 |
|---|---|---|---|
| 第 1 周 | 阶段 1 | 仓库与协议层跑通 | 可启动的空工具 Adapter |
| 第 2 周 | 阶段 2 + 3 前半 | 工具加载 + 翻译层 | 翻译层单测通过 |
| 第 3 周 | 阶段 3 后半 + 4 + 5 | 翻译层完整 + 治理 + QMS 接入 | 3 个真实 QMS 工具跑通 |
| 第 4 周 | 阶段 6 + 7 | 演示配置 + 评审材料 | 团队评审包 |

---

## 8. 关键技术决策

### 8.1 依赖版本（建议锁定）

| 依赖 | 版本 | 理由 |
|---|---|---|
| Java | 17 LTS | 团队同栈、长期支持 |
| Spring Boot | 3.2.x | 与 Spring Framework 6 兼容、SpringDoc 2.x 支持 |
| mcp-java-sdk | 0.10.0（或当前稳定版） | MCP 协议实现 |
| SnakeYAML | 2.2 | Spring Boot 自带 |
| Jayway JsonPath | 2.9.x | Result 解包路径表达式 |
| OkHttp | 4.12.x | HTTP 客户端 |
| Caffeine | 3.1.x | 内存缓存 |
| Resilience4j | 2.2.x | 限流熔断 |
| Lombok | 1.18.x（仅 DTO） | 团队已有使用习惯 |
| JUnit 5 | 5.10.x | 测试框架 |
| Mockito | 5.x | Mock |
| Testcontainers | 1.19.x | 集成测试 |

### 8.2 自动装配机制

`mcp-adapter-framework` 用 Spring Boot 标准自动装配：

```java
// src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
com.sunny.mcp.framework.autoconfigure.McpAdapterAutoConfiguration
com.sunny.mcp.framework.autoconfigure.McpServerAutoConfiguration
com.sunny.mcp.framework.autoconfigure.ToolLoaderAutoConfiguration
com.sunny.mcp.framework.autoconfigure.TranslationEngineAutoConfiguration
com.sunny.mcp.framework.autoconfigure.GovernanceAutoConfiguration
```

业务分支的 `adapter-app` 只需：

```java
@SpringBootApplication
@EnableMcpAdapter
public class McpAdapterApplication {
    public static void main(String[] args) {
        SpringApplication.run(McpAdapterApplication.class, args);
    }
}
```

### 8.3 配置覆盖优先级

```
默认值（framework 内置）
  < application.yml（master 模板）
  < application-{profile}.yml（业务分支覆盖）
  < 工具 YAML 的 translation.response 配置（工具级覆盖）
```

### 8.4 测试策略

| 层级 | 范围 | 工具 |
|---|---|---|
| 单元测试 | 翻译层、加载器、治理服务 | JUnit5 + Mockito，覆盖率 ≥ 80% |
| 集成测试 | Adapter 全链路 + Mock 业务 HTTP | Spring Boot Test + MockWebServer |
| E2E 测试 | 真实 QMS + Adapter + 工具调用 | 手工 + 脚本 |

---

## 9. Demo 演示场景（向团队展示）

### 9.1 场景 1：声明式工具上线（5 分钟）

```
讲解：声明一个新工具只需 10 行 YAML
操作：打开 tools/query-inspection-by-id.yml，讲解关键字段
演示：保存 YAML → 重启 Adapter → tools/list 立即返回新工具
```

### 9.2 场景 2：翻译层 before/after（核心，5 分钟）

```
讲解：业务 API 返回什么 vs AI 看到什么
操作：
  Step 1：直接 curl 调 QMS 业务 API
    → 看到原始响应：{ code:200, msg:"success", data:{ cCreateuser:"zhangsan", dCreatetime:"2026-07-24T...", cInspectionno:"INS..." } }
  
  Step 2：通过 MCP 调同一个工具
    → AI 看到的响应：{ inspectionNo:"INS...", createUser:"zhangsan", createTime:"2026-07-24T..." }
  
对比：cCreateuser → createUser、dCreatetime → createTime、剥离 Result 包装
```

### 9.3 场景 3：DTO 嵌套包装（3 分钟）

```
讲解：AI 传扁平参数，Adapter 自动包装为 QMS 嵌套 DTO
操作：在 mcp-inspector 输入扁平参数 { factoryCode:"F01", pageNo:1 }
      → 日志展示实际发给 QMS 的请求体（嵌套 DTO）
```

### 9.4 场景 4：AI 真实对话调用（5 分钟）

```
讲解：让团队直接和 AI 对话
操作：在 Claude Desktop / mcp-inspector 提问
  "帮我查检验单 INS20260724001 的详情"
  → AI 自动选择 qms_queryInspectionById 工具
  → 返回结果展示
```

### 9.5 场景 5：治理（授权 + 审计）（2 分钟）

```
讲解：默认拒绝 + 审计可追溯
操作：
  - 用未授权用户调工具 → 403
  - 查询审计表 → 看到调用记录
```

---

## 10. 风险与应对

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| mcp-java-sdk 版本不稳定或文档不足 | 中 | 高 | 阶段 1 前先用最简 demo 验证 SDK；预备方案是自己实现 JSON-RPC 端点 |
| MCP 客户端（Claude Desktop）不支持 streamable-http | 中 | 中 | 主演示用 mcp-inspector（官方调试工具，支持完善）；Claude Desktop 作为加分项 |
| QMS sunny-auth-client 集成不顺畅 | 高 | 中 | demo 阶段 JWT 验签可简化（mock 公钥），mcp-auth-filter 不替代 sunny-auth-client，仅注入身份 |
| QMS 本地启动复杂（依赖 Nacos / Kafka / 多 DB） | 高 | 中 | 提前与 QMS 团队对齐本地启动文档；备用方案：用 mcppro / mcptest 环境的 QMS |
| 翻译层规则误伤（cName 等例外） | 中 | 中 | 阶段 3 单测必须覆盖例外清单；QMS 字段重命名映射日志打印 |
| wrap-to 模板语法不够用 | 低 | 中 | 阶段 3 设计 API 时预留扩展；必要时引入 FreeMarker |
| 工具描述质量不达标，AI 调用准确率低 | 高 | 高 | 工具描述模板 + 评审清单；演示前用 prompt 集预演 |
| 时间盒紧张（4 周） | 高 | 中 | 阶段 5/6 可并行；演示材料优先级高于完美实现 |
| 单 git 仓库分支冲突频繁 | 低 | 低 | 业务分支严格只动配置与工具 YAML；冲突主要在 application.yml，约定用 profile 机制 |

---

## 11. demo 通过后的后续路线

### 11.1 后续路线概览

```
demo 通过（第 4 周末）
    ↓
阶段 8：补充生产级能力（第 5-8 周，4 周）
    • JWT 真实验签（接集团 SSO）
    • 真实 sunny-auth-client 集成
    • 限流熔断完善
    • 监控接入（Prometheus / Grafana）
    • 完整的授权管理 UI
    • YAML 热加载
    ↓
阶段 9：QMS 横向扩展（第 9-12 周，4 周）
    • QMS 工具数扩到 30+（覆盖主要查询场景）
    • 字段重命名规则在 QMS 全字段验证
    • 灰度上线（先 1 个部门试点）
    ↓
阶段 10：多系统铺开（第 13-20 周，8 周）
    • 复制分支模式到 MES / WMS / EMS
    • K8s 部署落地（各 namespace 拉取对应分支）
    • 红蓝对抗、性能压测
    ↓
阶段 11：可视化工具编辑器（第 21-26 周，6 周）
    • mcp-tool-designer 独立服务
    • Web UI 创建工具
    • 工具版本管理与回滚
```

### 11.2 团队评审通过后的关键决策点

demo 评审时需要团队共同决策：

1. **后续资源投入**：IT 部投入几人？业务团队如何参与？
2. **优先级排序**：先扩 QMS 工具覆盖，还是先铺开到多系统？
3. **业务侧协作模式**：业务团队是否设"工具设计师"角色？工具上线流程？
4. **生产部署节奏**：K8s 命名空间申请、镜像构建流水线、灰度策略
5. **与 sunny 平台团队的协作**：mcp-auth-filter 是否上升到 sunny-base 系列？sunny-auth-client 集成方案？

---

## 12. 附录

### 12.1 立即可执行的第一步

**今天/明天就可以做的**：

1. 在集团 Git 平台创建仓库 `sunny-mcp-adapter`
2. 创建 master 分支，初始化 Maven 父 POM 与 5 个空模块
3. 申请 MySQL `mcp_adapter` schema
4. 与 QMS 团队对齐本地启动文档（依赖、配置、账号）
5. 评估 mcp-java-sdk 当前稳定版本

### 12.2 关键文件清单（首周交付）

```
sunny-mcp-adapter/
├── pom.xml                                     ← 父 POM
├── README.md                                   ← 项目说明
├── mcp-common/pom.xml
├── mcp-auth-filter/pom.xml
├── mcp-adapter-framework/pom.xml
├── adapter-app/pom.xml
├── adapter-tests/pom.xml
├── adapter-app/src/main/java/com/sunny/mcp/app/McpAdapterApplication.java
├── adapter-app/src/main/resources/application-dev.yml
└── docs/
    ├── architecture.md
    └── tool-yaml-guide.md
```

### 12.3 术语

| 术语 | 含义 |
|---|---|
| master 分支 | 框架主干，所有业务分支的基础 |
| 业务分支 | 基于 master，加配置与工具 YAML，对应一个业务系统 adapter |
| namespace | 业务系统命名空间（qms / mes / wms / ems），数据库隔离用 |
| mcp-adapter-framework | 框架核心模块（"starter"角色，但单仓库内不发布私服） |
| adapter-app | Adapter 主程序模块（业务分支只动这里） |
| 翻译层 | Result 解包 + 字段重命名 + DTO 包装三大支柱的统称 |

### 12.4 待对齐问题（启动前需要回答）

1. 集团 Git 平台用哪个？（自建 GitLab / Gitea / 其他）
2. sunny-mcp-adapter 仓库归属哪个组？
3. MySQL 共享实例的连接信息与申请流程
4. QMS 本地启动的最小依赖清单（Nacos / Kafka / DB 是否必需）
5. QMS 的 sunny-auth-client 是否有 mock 模式（便于 demo 不依赖真实 SSO）
6. mcp-java-sdk 当前推荐版本与文档入口
7. mcp-inspector 是否需要内网代理（如需外网下载）

### 12.5 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-07-24 | 首版，基于 v3 设计与用户约束生成分阶段落地方案 |
