# 集团 MCP Adapter 服务规划设计（v2）

> **文档版本**：v2.0
> **日期**：2026-07-24
> **作者**：集团 IT 部
> **状态**：设计评审中
> **变更说明**：本版替代 v1.0（`2026-07-22-mcp-service-design.md`）。经团队讨论决议：**不再接管 Gateway 层建设，专注 Adapter 层**，要求零编码、配置驱动、业务 API 变化自同步。

---

## 1. 背景与目标

### 1.1 业务背景

集团是制造业集团公司，自研多个生产相关业务系统（MES / WMS / QMS / EMS / 设备管理等），技术栈统一为 Java + SpringMVC。集团希望通过 MCP 协议让 AI 助手能访问这些自研系统的数据与能力。

### 1.2 团队决议（v2 调整点）

| 决议项 | v1 方案 | v2 方案 | 调整理由 |
|---|---|---|---|
| Gateway 层 | IT 部自建集中 Gateway | **不再接管 Gateway 建设** | 减少治理与运维负担，AI 平台侧自行管理多 MCP Server 接入 |
| Adapter 形态 | 协议在 Gateway、Adapter 做包装 | **Adapter 直接暴露 MCP 协议** | 每个 Adapter 即一个 MCP Server，职责纯粹 |
| 工具开发方式 | YAML 配置 + 注解编码（各占一半） | **配置驱动为主，零编码为目标** | 降低业务团队接入成本 |
| API 变化同步 | 手动改 YAML | **自动发现 + 自同步** | 业务 API 上线/修改后 Adapter 自动适配 |
| 首阶段范围 | 4 个子系统 + 50+ 工具 | **先做扎实一个 Adapter（QMS），再复制** | 把 starter 做透，再横向铺开 |

### 1.3 核心目标

1. **零编码上线**：业务系统上线一个新 API，Adapter 自动同步暴露为 MCP 工具，**不需要写任何 Java 代码**。
2. **API 变化自同步**：业务系统改 API 入参/出参/路径，Adapter 自动感知并更新工具元数据。
3. **少量配置微调**：脱敏、字段重命名、工具描述优化、行级权限等通过 YAML 配置完成。
4. **业务系统极低侵入**：仅引入共享 jar `mcp-auth-filter` + 暴露 OpenAPI 文档。

### 1.4 非目标（YAGNI）

- 不自建 MCP Gateway / Router / BFF
- 不做跨系统工具聚合（未来如有需求再讨论）
- 不重构业务系统代码
- 不引入 MCP `resources/*`、`prompts/*`、`notifications/*`
- 不实现 SSE 流（AI 平台只支持 HTTP，保持纯 JSON 模式）

---

## 2. 关键决策汇总

| 决策项 | 选择 | 理由 |
|---|---|---|
| 架构形态 | **每子系统一个 Adapter，直接暴露 MCP Server** | 去 Gateway、职责纯粹、故障域天然隔离 |
| 协议 | MCP Streamable HTTP（纯 JSON 模式） | 兼容自研 AI 平台仅支持 HTTP |
| 实现语言 | Java + Spring Boot 3.2 + Java 17 | 团队同栈 |
| 工具发现 | **从业务系统 OpenAPI 文档自动拉取并生成工具** | 业务 API 变化即工具变化，零编码 |
| 业务系统前置 | 集成 SpringDoc 暴露 `/v3/api-docs` | 业内标准，集成成本极低（一行 Maven 依赖） |
| 工具暴露策略 | **白名单模式（默认）+ 可切换全量模式** | 白名单安全可控；全量便利 |
| 配置覆盖 | YAML（`tools-override.yml`） | 不写代码即可完成脱敏/重命名/工具描述优化 |
| API 变化同步 | 启动全量拉取 + 运行时定时轮询（默认 5 分钟） | 简单可靠，未来可扩展 Webhook |
| 治理位置 | **下沉到 Adapter，由共享 starter 内置** | 没有 Gateway，治理必须下沉 |
| 工具授权 | 每 Adapter 维护自己的 `mcp_tool_grant` 表 | 数据本地化，运维清晰 |
| 审计 | 每 Adapter 写本地 `mcp_audit_log`，统一 schema | 便于后续汇总分析 |
| 业务系统改动 | 共享 jar `mcp-auth-filter` + SpringDoc 依赖 | 集中、最小、可复用 |
| 首个 Adapter | **QMS** | 查询场景丰富、管理者经营分析刚需 |
| 共享库 | `mcp-common` + `mcp-auth-filter` + `mcp-adapter-starter` | starter 是核心 IP |

---

## 3. 总体架构

### 3.1 三层切分

```
┌──────────────────────────────────────────────────────────────┐
│  消费层：企业 AI 助手 / IM bot                                  │
│  （自研 AI 平台自行管理多 MCP Server 接入）                    │
└──────────────────────────────────────────────────────────────┘
        │                              │
        │ MCP HTTP/JSON                │ MCP HTTP/JSON
        ▼                              ▼
┌──────────────────────┐   ┌──────────────────────┐   ┌─────────┐
│ qms-adapter          │   │ mes-adapter          │   │ ...     │
│ (MCP Server)         │   │ (MCP Server)         │   │         │
│                      │   │                      │   │         │
│ • MCP 协议端点       │   │ • MCP 协议端点       │   │         │
│ • 工具自动发现       │   │ • 工具自动发现       │   │         │
│ • 配置覆盖           │   │ • 配置覆盖           │   │         │
│ • 治理（授权/审计/限流）│   │ • 治理              │   │         │
│ • 数据补控（脱敏/筛选）│   │ • 数据补控           │   │         │
└──────────┬───────────┘   └──────────┬───────────┘   └────┬────┘
           │                          │                    │
           │ ① 拉 OpenAPI 文档        │ ① 拉 OpenAPI 文档  │
           │ ② HTTP 调业务 API        │ ② HTTP 调业务 API  │
           ▼                          ▼                    ▼
┌──────────────────────┐   ┌──────────────────────┐   ┌─────────┐
│ QMS 业务系统          │   │ MES 业务系统          │   │ ...     │
│ • SpringDoc 暴露      │   │ • SpringDoc 暴露      │   │         │
│   /v3/api-docs       │   │   /v3/api-docs       │   │         │
│ • mcp-auth-filter    │   │ • mcp-auth-filter    │   │         │
└──────────────────────┘   └──────────────────────┘   └─────────┘
```

### 3.2 职责边界

| 层 | 做什么 | 不做什么 |
|---|---|---|
| AI 平台 | 接入多个 MCP Server、管理用户对话上下文 | 不做协议转换、不做工具聚合（IT 部不负责） |
| Adapter | MCP 协议端点 + 工具自动发现 + 配置覆盖 + 治理 + 数据补控 + 调业务 API | 不做跨系统聚合 |
| 业务系统 | 业务逻辑 + 暴露 OpenAPI 文档 + 引入 `mcp-auth-filter` | 不改业务代码 |

### 3.3 Adapter 内部结构

```
┌─────────────────────────────────────────────────────────┐
│ Adapter（基于 mcp-adapter-starter 构建）                  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ MCP 协议层（starter 提供）                         │   │
│  │  • POST /mcp (initialize/tools.list/tools.call)   │   │
│  │  • JWT 验签、X-User-* 提取                        │   │
│  └──────────────────────────────────────────────────┘   │
│                       ↓                                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 工具注册中心（starter 提供）                       │   │
│  │  • OpenAPI 拉取器（定时轮询业务系统 /v3/api-docs）│   │
│  │  • OpenAPI → MCP Tool 转换器                      │   │
│  │  • YAML 配置覆盖合并器                            │   │
│  │  • 内存工具表（Caffeine 缓存）                    │   │
│  └──────────────────────────────────────────────────┘   │
│                       ↓                                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 调用执行器（starter 提供）                         │   │
│  │  • 按 OpenAPI 定义发 HTTP 请求                    │   │
│  │  • 响应裁剪/重命名/脱敏（按 YAML 配置）            │   │
│  │  • 行级权限筛选（按 user ctx）                    │   │
│  └──────────────────────────────────────────────────┘   │
│                       ↓                                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 治理层（starter 提供）                             │   │
│  │  • 工具授权表查询（mcp_tool_grant）               │   │
│  │  • 审计日志写入（mcp_audit_log）                  │   │
│  │  • 限流熔断（Resilience4j）                       │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**核心理念**：业务开发一个新 Adapter 时，只需要：
1. Maven 引入 `mcp-adapter-starter`
2. 写一份 `application.yml`（配置业务系统的 OpenAPI URL、数据库连接等）
3. 写一份可选的 `tools-override.yml`（微调工具行为）
4. `@EnableMcpAdapter` 启动

**不需要写任何工具定义代码。**

---

## 4. Adapter 核心设计

### 4.1 自动发现：OpenAPI 拉取

#### 4.1.1 前置条件

业务系统（SpringMVC）必须暴露 OpenAPI 3 文档：

```xml
<!-- 业务系统 Maven 引入 SpringDoc -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

业务系统启动后自动暴露：
- `GET /v3/api-docs` — OpenAPI 3 JSON 文档
- `GET /swagger-ui.html` — 可视化界面（可选）

**这是业务系统的两项最小改动**：① 引入 `mcp-auth-filter`；② 引入 SpringDoc。 Controller 代码完全不动。

#### 4.1.2 Adapter 的拉取机制

```yaml
# adapter 的 application.yml
mcp:
  adapter:
    namespace: qms                              # 工具命名空间前缀
    backend:
      openapi-url: http://qms-intra/v3/api-docs
      auth:
        type: service-account
        token: ${QMS_SERVICE_TOKEN}             # 服务账号 token
      poll-interval: 300s                       # 默认 5 分钟轮询一次
      poll-on-startup: true                     # 启动时立即拉取
    exposure:
      mode: whitelist                           # whitelist | all
      # 白名单模式：只暴露 include 列出的 API
      include:
        - { method: GET, path: /api/inspections/{id} }
        - { method: GET, path: /api/inspections }
        - { method: GET, path: /api/batches/{batchNo}/results }
        - { method: GET, path: /api/defects/top }
        # ... 业务团队按需添加
      exclude:
        - { method: POST, path: /api/internal/** }  # 即使全量模式也排除内部 API
```

#### 4.1.3 拉取流程

```
Adapter 启动
  → 立即拉取一次 OpenAPI 文档
  → swagger-parser 解析
  → 计算 hash，与上次对比
  → 若变化：
      → 按 exposure 配置过滤
      → 生成工具元数据集合
      → 合并 tools-override.yml 的覆盖配置
      → 替换内存工具表
  → 注册定时任务（每 poll-interval 秒重复）
  → MCP tools/list 返回最新工具集
```

### 4.2 工具生成：OpenAPI Operation → MCP Tool

#### 4.2.1 映射规则

| OpenAPI 元素 | MCP 工具字段 |
|---|---|
| `operationId` | `tool_name`（命名空间前缀，如 `qms_getInspectionById`） |
| 无 `operationId` | `tool_name` = `{namespace}_{method}_{path_简化}`（如 `qms_get_inspections`） |
| `summary` / `description` | MCP `description` |
| `parameters`（path/query/header） | MCP `input_schema.properties` |
| `requestBody`（JSON） | MCP `input_schema.properties`（扁平化） |
| `responses.200.content.application/json.schema` | 响应裁剪的依据 |

#### 4.2.2 工具命名建议

强烈建议业务系统 Controller 用 `@Operation(operationId = "...")` 显式命名：

```java
@RestController
@RequestMapping("/api/inspections")
public class InspectionController {

    @GetMapping("/{id}")
    @Operation(operationId = "queryInspectionById", summary = "按检验单号查询检验单详情")
    public InspectionDTO get(@PathVariable String id) { ... }

    @GetMapping
    @Operation(operationId = "listInspections", summary = "列出检验单（支持分页/筛选）")
    public Page<InspectionDTO> list(InspectionQuery query) { ... }
}
```

生成的工具名：`qms_queryInspectionById`、`qms_listInspections`——对 AI 友好。

**未加 operationId 也能工作**（自动生成），但工具名会不够语义化。

### 4.3 配置覆盖：YAML 微调

#### 4.3.1 覆盖文件

`adapter/src/main/resources/tools-override.yml`：

```yaml
overrides:
  # 示例 1：优化工具描述，让 AI 更易理解
  - tool_name: qms_queryInspectionById
    description: "按检验单号查询 QMS 检验单详情，包含检验项目、结果、检验员信息"
    
  # 示例 2：字段裁剪 + 重命名（API 返回字段对 AI 不友好）
  - tool_name: qms_listInspections
    response:
      pick: [id, batchNo, status, result, inspector, inspectAt]
      rename:
        id: inspectionId
        inspectAt: inspectedAt
    
  # 示例 3：字段脱敏（客户信息）
  - tool_name: qms_queryCustomerComplaint
    auth:
      field_mask: [customerPhone, customerEmail]   # 不返回给 AI
      row_filter: "dept = ${user.dept}"            # 只返回本部门数据
    
  # 示例 4：禁用某工具（业务系统临时下线 / 内部测试 API）
  - tool_name: qms_internal_debugEndpoint
    enabled: false
    
  # 示例 5：参数白名单（只暴露部分参数，隐藏复杂参数）
  - tool_name: qms_listInspections
    params:
      pick: [batchNo, status, fromDate, toDate, page, size]
    
  # 示例 6：工具分组（便于 AI 选择，未来用）
  - tool_name: qms_queryInspectionById
    group: inspection
```

#### 4.3.2 覆盖合并优先级

```
默认行为 < tools-override.yml < 注解（如有少量 Java 工具）
```

**80% 场景**：自动发现 + YAML 覆盖，零 Java 代码。
**20% 场景**：复杂聚合/计算逻辑，用 `@McpTool` 注解写 Java（仍可使用，作为逃生通道）。

### 4.4 API 变化同步

| 业务系统变化 | Adapter 行为 |
|---|---|
| 新增 API（在白名单内） | 下个轮询周期自动暴露为工具 |
| 新增 API（不在白名单） | 不暴露（除非加进 include） |
| 修改 API 入参（加字段） | 工具 input_schema 自动更新 |
| 修改 API 出参（加字段） | 工具输出自动包含（受 pick 限制） |
| 删除 API | 工具自动消失，tools/list 不再返回 |
| 修改 API 路径 | 旧工具消失，新工具出现（需更新 include） |
| 修改 operationId | 工具重命名（建议业务系统避免随意改 operationId） |

**配置层面**：业务团队改 API 后，如果要更新工具描述/脱敏规则，只需修改 `tools-override.yml` 并发版 Adapter（或后续支持热加载）。

### 4.5 MCP 协议端点（Adapter 直接暴露）

每个 Adapter 即一个 MCP Server，对外暴露：

```
POST /mcp
Content-Type: application/json
Accept: application/json   ← 不 Accept text/event-stream
Authorization: Bearer <AI平台签发的用户JWT>

请求体: JSON-RPC 2.0
{ "jsonrpc":"2.0", "id":1, "method":"initialize" }
{ "jsonrpc":"2.0", "id":2, "method":"tools/list" }
{ "jsonrpc":"2.0", "id":3, "method":"tools/call",
  "params":{"name":"qms_queryInspectionById","arguments":{"id":"INS20260724001"}} }
```

**AI 平台侧需要做**：配置每个 Adapter 的 URL（如 `http://qms-adapter.mcp.svc.cluster.local/mcp`）。这是 AI 平台的责任，IT 部仅提供 URL 清单。

### 4.6 治理下沉（共享 starter 内置）

| 治理能力 | 实现位置 | 说明 |
|---|---|---|
| JWT 验签 | starter MCP filter | 复用集团 SSO 公钥 |
| 工具授权 | starter + 每 Adapter 自己的 `mcp_tool_grant` 表 | 默认拒绝 + deny 优先 |
| 审计日志 | starter + 每 Adapter 自己的 `mcp_audit_log` 表 | 异步写、统一 schema |
| 限流 | starter + Resilience4j | 按 userId + tool_name |
| 熔断 | starter + Resilience4j | 业务 API 失败率超阈值熔断 |
| 超时 | starter 默认 8s | 可在 YAML 覆盖 |
| 调用链路 | starter 注入 traceId | Micrometer + 集团现有 APM |

### 4.7 数据补控（两层防线）

由于没有 Gateway，防线从三层压缩到两层：

| 层 | 做什么 |
|---|---|
| 业务系统 | 服务账号能访问的数据范围（已有粗粒度权限） |
| Adapter | YAML 的 `row_filter` / `field_mask`，按用户身份精筛和脱敏 |

**Adapter 必须补控**：业务 API 为前端定制，可能返回全量数据；Adapter 必须裁剪后再给 AI。

---

## 5. 业务系统侧的前置条件

业务系统接入 MCP 只需做**两件事**：

### 5.1 引入 SpringDoc（暴露 OpenAPI）

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

启动后自动暴露 `/v3/api-docs`。**Controller 代码完全不改**，但建议逐步在关键 Controller 上补 `@Operation(operationId="...", summary="...")` 让工具名更语义化（非强制）。

### 5.2 引入 `mcp-auth-filter`（识别服务账号 + 透传用户身份）

```xml
<dependency>
    <groupId>com.example.harness</groupId>
    <artifactId>mcp-auth-filter</artifactId>
    <version>1.0.0</version>
</dependency>
```

web.xml 或 SpringBoot 配置加一个 filter：

```java
@Bean
public FilterRegistrationBean<McpAuthFilter> mcpAuthFilter() {
    FilterRegistrationBean<McpAuthFilter> reg = new FilterRegistrationBean<>();
    reg.setFilter(new McpAuthFilter());
    reg.addUrlPatterns("/api/*");
    return reg;
}
```

filter 做两件事：
1. 识别 `X-MCP-Service-Token`（Adapter 服务账号），放行
2. 把 `X-User-Id` / `X-User-Roles` / `X-User-Dept` 放到 ThreadLocal，供现有权限框架使用

**这就是对业务系统的全部改动**。不涉及业务代码，集中在两个 Maven 依赖 + 一行配置。

### 5.3 现有业务系统没有 OpenAPI 怎么办？

| 情况 | 处理 |
|---|---|
| Spring Boot 3.x | 直接加 SpringDoc，零侵入 |
| Spring + SpringMVC（无 Boot） | 加 SpringDoc + 少量 XML 配置 |
| 老旧系统（Struts2、Servlet） | 方案 A：手写一份 OpenAPI YAML 放 Adapter 拉取；方案 B：升级到 SpringMVC（中长期） |

**待业务侧确认**：QMS 及其他主要子系统的具体框架版本（见第 11.2）。

---

## 6. 共享库设计

三组 Maven 库发布到集团 Maven 私服，各 Adapter 按需依赖。

### 6.1 `mcp-common`

```
共享 DTO、UserContext、常量、错误码
约 5-10 个类，稳定后极少改动
```

### 6.2 `mcp-auth-filter`

```
业务系统引入的鉴权 filter
识别 X-MCP-Service-Token、透传 X-User-Id
约 3-5 个类
```

### 6.3 `mcp-adapter-starter`（核心 IP）

这是本方案最重的库，承载所有"零编码、自适配"能力：

```
mcp-adapter-starter/
├── autoconfigure/
│   ├── McpServerAutoConfiguration       ← MCP 协议端点（基于 mcp-java-sdk）
│   ├── OpenApiDiscoveryAutoConfiguration ← OpenAPI 拉取与解析
│   ├── ToolRegistryAutoConfiguration    ← 工具注册中心（内存 + Caffeine）
│   ├── ToolOverrideAutoConfiguration    ← YAML 覆盖合并
│   ├── GovernanceAutoConfiguration      ← 授权、审计、限流、熔断
│   └── DataCompensationAutoConfiguration ← 字段裁剪、重命名、脱敏
├── core/
│   ├── OpenApiToolGenerator             ← OpenAPI → MCP Tool 转换
│   ├── ToolInvoker                      ← 按工具定义发 HTTP 请求
│   ├── FieldMasker                      ← 字段脱敏
│   └── RowFilterApplier                 ← 行级权限筛选
├── annotation/
│   ├── @EnableMcpAdapter                ← 启动开关
│   └── @McpTool                         ← 逃生通道：手写复杂工具
└── resources/
    └── default-tools-override.yml       ← 默认覆盖模板
```

**版本节奏**：starter 1.0 稳定后，新增能力（如 Webhook、热加载、分组导航）以小版本迭代。

---

## 7. 配置驱动的开发流程

这是 v2 的核心价值——**业务团队加新工具的体验**：

### 7.1 场景 A：业务上线新 API（零配置）

```
1. QMS 开发在 InspectionController 加：
     @GetMapping("/defects")
     @Operation(operationId = "listDefects", summary = "列出不良项记录")
     public Page<DefectDTO> listDefects(...) { ... }

2. QDS 发布，/v3/api-docs 自动包含新接口

3. QMS Adapter 下个轮询周期（≤ 5 分钟）检测到 hash 变化
   → 解析新 operation
   → 若在 include 白名单 → 自动生成 qms_listDefects 工具
   → tools/list 立即返回新工具

4. AI 平台下一次对话即可调用 qms_listDefects

【配置改动】：0 行
【代码改动】：0 行（Adapter 侧）
【QMS 侧改动】：业务本身的 Controller（本来就要写）
```

### 7.2 场景 B：业务改 API 入参（零配置）

```
1. QMS 开发改 listDefects 的入参：加一个 severity 字段
2. 发布后 OpenAPI 文档更新
3. Adapter 轮询发现 hash 变化
   → qms_listDefects 的 input_schema 自动加入 severity
4. AI 可使用新参数

【配置改动】：0 行
```

### 7.3 场景 C：需要脱敏某个字段（少量 YAML）

```
1. 发现 listDefects 返回的 inspectorPhone 不应给 AI 看
2. 在 tools-override.yml 加：

   - tool_name: qms_listDefects
     auth:
       field_mask: [inspectorPhone]

3. 发版 Adapter（小变更，重启即生效）
4. 后续支持热加载（不需重启）

【代码改动】：0 行
【配置改动】：3 行 YAML
```

### 7.4 场景 D：工具描述对 AI 不够清晰（少量 YAML）

```
1. AI 总是误用 qms_listInspections（参数搞错）
2. 在 tools-override.yml 优化描述：

   - tool_name: qms_listInspections
     description: |
       列出 QMS 检验单。
       必填参数：fromDate, toDate（日期范围，最长 30 天）。
       可选参数：status（PENDING/PASSED/FAILED）、batchNo。
       返回：分页结果，每页最多 100 条。

3. 重启 Adapter 即生效

【代码改动】：0 行
【配置改动】：5 行 YAML
```

### 7.5 场景 E：复杂聚合查询（注解，逃生通道）

```
1. AI 需要"查 OEE 综合指标"，需要调多个 API + 做计算
2. Adapter 工程师在 QmsCustomTools 类加：

   @McpTool(name = "qms_queryOee", description = "查询产线 OEE")
   public OeeResult queryOee(
       @McpParam("lineCode") String lineCode,
       @McpParam("from") LocalDate from,
       @McpParam("to") LocalDate to,
       UserContext user
   ) {
       // 并行调多个 API + 计算
       ...
   }

3. 发版 Adapter

【代码改动】：1 个方法（20% 场景）
```

---

## 8. 安全与权限模型

### 8.1 身份链路（简化）

```
[员工] → [AI 平台登录签 JWT] → [Adapter]
                                  │
                                  ├─ MCP filter 验签 JWT，提取 user ctx
                                  ├─ 查 mcp_tool_grant 表
                                  │   ├─ deny 或无记录 → 403
                                  │   └─ allow → 继续
                                  ├─ 调用业务 API 时 Header 透传：
                                  │   X-User-Id / X-User-Roles / X-User-Dept / X-Trace-Id
                                  │   X-MCP-Service-Token
                                  ▼
                              [业务系统 mcp-auth-filter]
                                  │
                                  └─ 识别服务账号 + 把 X-User-Id 放 ThreadLocal
                                     供现有权限框架使用
```

### 8.2 数据库表（每个 Adapter 本地维护）

**`mcp_tool_grant`**（工具授权表）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT PK | |
| user_id | VARCHAR | 员工 ID（与 role_id 二选一） |
| role_id | VARCHAR | 角色 ID（批量授权） |
| tool_name | VARCHAR | 工具名（含命名空间前缀） |
| decision | ENUM | `allow` / `deny` |
| effective_from | DATETIME | |
| effective_to | DATETIME | 可空（临时授权） |
| created_by | VARCHAR | 审批人 |

**`mcp_audit_log`**（调用审计表）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT PK | |
| trace_id | VARCHAR | 贯穿全链路 |
| user_id | VARCHAR | |
| tool_name | VARCHAR | |
| arguments_hash | VARCHAR | 参数哈希，不存 PII |
| status | ENUM | `success` / `deny` / `error` / `timeout` |
| duration_ms | INT | |
| error_code | VARCHAR | |
| error_msg | VARCHAR | 截断 |
| called_at | DATETIME | |

> **说明**：v1 设计的 `mcp_tool_registry` 表不再需要——工具元数据在 Adapter 内存中，由 OpenAPI 自动生成。

### 8.3 授权策略（与 v1 一致）

- 默认拒绝；deny 优先于 allow；角色批量授权；支持临时授权
- 管理后台：每个 Adapter 自带一个轻量授权页面（starter 提供）

### 8.4 脱敏策略（与 v1 一致）

| 字段类型 | 策略 |
|---|---|
| 身份证/手机号 | Adapter 输出前脱敏（保留前 3 后 4） |
| 客户信息/金额 | YAML `field_mask` 默认不返回 |
| 备注/自由文本 | 长度截断（超 500 字） |
| 参数 | 审计只存 hash |
| 大结果集 | 分页强制（单次最多 100 条） |

### 8.5 安全基线

| 链路 | 安全措施 |
|---|---|
| AI 平台 ↔ Adapter | HTTPS + JWT 验签 + IP 白名单（可选） |
| Adapter ↔ 业务系统 | HTTPS + 服务账号 token（X-MCP-Service-Token） |
| Adapter ↔ DB | 内网 + 数据库账号最小权限 |
| 敏感操作（未来开放写操作） | 工具 YAML 标 `require_approval: true`，返回 `pending_approval` |

---

## 9. 技术选型

### 9.1 技术栈清单

| 组件 | 选型 | 备注 |
|---|---|---|
| 框架 | Spring Boot 3.2.x | Java 17 LTS |
| MCP SDK | `io.modelcontextprotocol.sdk:mcp` | Adapter 直接依赖，作为 MCP Server |
| OpenAPI 解析 | `io.swagger.parser.swagger-parser` | 解析业务系统的 OpenAPI 3 文档 |
| HTTP 客户端 | OkHttp 4 / Spring WebClient | Adapter 调业务 API |
| 数据库 | MySQL 8.x | 复用集团现有 |
| 缓存 | Caffeine 本地 | 工具元数据、授权决策，TTL 5 分钟 |
| 限流熔断 | Resilience4j | starter 内置 |
| 可观测 | Micrometer + Prometheus + Grafana | 复用集团现有监控 |
| 日志 | SLF4J + Logback（结构化 JSON） | traceId 贯穿 |
| 部署 | Docker + 内网 K8s | Adapter 与业务系统同命名空间 |

### 9.2 代码仓库与部署

| # | 系统 | 代码仓库 | 部署位置 |
|---|---|---|---|
| 1 | QMS Adapter | `harness-qms-adapter` | `qms` 命名空间（与 QMS 业务系统同空间） |
| 2 | MES Adapter | `harness-mes-adapter` | `mes` 命名空间 |
| 3 | WMS Adapter | `harness-wms-adapter` | `wms` 命名空间 |
| 4 | EMS Adapter | `harness-ems-adapter` | `ems` 命名空间 |
| ... | 其他 Adapter | `harness-<sys>-adapter` | 对应业务系统命名空间 |

共享库（独立版本号，发 Maven 私服）：

| 模块 | 版本节奏 |
|---|---|
| `mcp-common` | 1.0 稳定后极少改动 |
| `mcp-auth-filter` | 1.0 稳定后极少改动 |
| `mcp-adapter-starter` | 核心库，按月/季度迭代新能力 |

### 9.3 Adapter 部署拓扑

```
namespace: qms
  ├── qms-business-pod   (业务系统，暴露 /v3/api-docs)
  └── qms-adapter-pod    (Adapter，暴露 /mcp)

namespace: mes
  ├── mes-business-pod
  └── mes-adapter-pod

namespace: wms
  ├── wms-business-pod
  └── wms-adapter-pod

namespace: ems
  ├── ems-business-pod
  └── ems-adapter-pod
```

每个 Adapter 都是独立的 MCP Server，AI 平台自行接入。

---

## 10. 实施路线图

### 10.1 里程碑

| 阶段 | 周期 | 交付物 | 验收 |
|---|---|---|---|
| **阶段 1：starter 骨架 + 自动发现** | 第 1-4 周 | `mcp-common` / `mcp-auth-filter` / `mcp-adapter-starter` 三组库；starter 实现 OpenAPI 拉取、工具自动生成、MCP 协议端点、YAML 覆盖 | 用一个 Mock 业务系统验证：改 OpenAPI 文档 → Adapter 自动更新工具 |
| **阶段 2：QMS 落地 + 治理完善** | 第 5-10 周 | `harness-qms-adapter` 生产落地；QMS 业务系统引入 SpringDoc + `mcp-auth-filter`；治理（授权/审计/限流）联调；YAML 覆盖验证 | 选 1 个质量部门试点上线，真实员工通过 AI 助手查 QMS |
| **阶段 3：加固 + 横向铺开** | 第 11-18 周 | 红蓝对抗、性能压测、运维 Runbook；按模板复制到 MES / WMS / EMS | 4 个 Adapter 上线，AI 平台工具目录成型 |
| **阶段 4：演进** | 持续 | Webhook 替代轮询、YAML 热加载、工具分组导航、跨 Adapter 搜索 | 按需迭代 |

### 10.2 关键节点

- **第 4 周末**：starter 可用，自动发现跑通——技术风险消除
- **第 10 周末**：QMS 真实上线——业务价值验证
- **第 18 周末**：4 个 Adapter 全部上线——规模化复制成功

### 10.3 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| 业务系统无 OpenAPI 文档 | 中 | 高 | 提供 SpringDoc 集成指南；老系统备选方案（手写 OpenAPI YAML） |
| 工具爆炸（全量模式导致工具过多） | 中 | 中 | 默认白名单模式；tools/list 支持分组 |
| 业务 API 频繁变化导致工具不稳定 | 中 | 中 | operationId 稳定约定；变更通知机制；审计可追溯 |
| 服务账号被滥用 | 低 | 高 | 专属账号 + 定期轮换 + 最小权限 + 审计调用链 |
| starter bug 影响所有 Adapter | 中 | 高 | starter 严格测试 + 灰度发布新版本 + 版本锁定 |
| AI 平台不支持多 MCP Server 接入 | 低 | 高 | 提前与 AI 平台团队对齐接入方式 |
| 质量数据合规风险（不合格率等） | 中 | 高 | 严格 `field_mask` + 角色授权 + 审计；合规部门确认 |
| Adapter 轮询给业务系统带来压力 | 低 | 低 | 默认 5 分钟，可配置；未来切 Webhook |

### 10.4 成功度量

- **覆盖**：18 周内接入 4+ 子系统
- **零编码验证**：业务系统上线一个新 API 到 AI 可调用 ≤ 10 分钟（仅轮询延迟）
- **稳定**：Adapter SLA 99.5%+，P95 延迟 < 1s（不含业务 API 本身）
- **安全**：0 起权限越权审计事件
- **效率**：新 Adapter 从 0 到上线 ≤ 3 周
- **配置覆盖率**：≥ 80% 工具完全自动发现 + YAML 微调，无需写 Java

---

## 11. 测试策略与验收

### 11.1 测试分层

| 层级 | 范围 | 工具 |
|---|---|---|
| 单元测试 | OpenApiToolGenerator、FieldMasker、RowFilterApplier、覆盖合并器 | JUnit 5 + Mockito，覆盖率 ≥ 80% |
| 契约测试 | starter ↔ 业务系统 OpenAPI 格式；MCP 协议响应 | Spring Cloud Contract |
| 集成测试 | Adapter ↔ Mock 业务系统全链路；自动发现；YAML 覆盖 | Testcontainers |
| 自动发现专项 | 改 OpenAPI 文档 → 工具自动更新；边界场景（无 operationId、复杂 schema） | 专项测试集 |
| 安全测试 | 未授权调用、越权参数、PII 必脱敏 | OWASP ZAP + 红蓝对抗 |
| 性能测试 | 单 Adapter：500 QPS `tools/list`、100 QPS `tools/call`；P95 < 1s | JMeter / k6 |
| AI 端到端 | AI 真实提问 → 工具调用 → 正确结果 | 固定 prompt 集 |

### 11.2 Adapter 上线准入清单

```
□ application.yml 配置 review 通过
□ tools-override.yml 覆盖项与业务部门确认
□ 业务系统 OpenAPI 文档可用且字段稳定
□ 业务系统已加 mcp-auth-filter 并通过联调
□ 授权角色已配置（最小可用角色）
□ field_mask 覆盖所有 PII/敏感字段
□ 集成测试、自动发现专项测试通过
□ 性能压测达标
□ 安全扫描无高危
□ 审计日志可追溯、traceId 贯穿验证
□ Runbook 已写、oncall 已知会
□ 灰度方案已定（先开 1 个部门）
```

### 11.3 验收标准

- **功能**：4 个 Adapter 上线，AI 平台真实可用
- **零编码目标**：业务侧上线新 API → AI 可调用 ≤ 10 分钟，零 Adapter 代码改动
- **性能**：Adapter P95 < 1s（不含业务 API）
- **安全**：0 高危漏洞；100% 工具走授权表；100% 调用有审计
- **可扩展**：新 Adapter ≤ 3 周

---

## 12. 附录

### 12.1 与 v1 的差异对照

| 维度 | v1（2026-07-22） | v2（2026-07-24） |
|---|---|---|
| 架构 | 两层 Adapter + Gateway | 一层 Adapter（直接 MCP Server） |
| 协议实现 | 仅 Gateway 依赖 MCP SDK | 每个 Adapter 依赖 MCP SDK |
| 工具来源 | YAML + 注解手写 | OpenAPI 自动发现 + YAML 覆盖 |
| API 变化同步 | 手动改 YAML | 自动（轮询） |
| 治理 | Gateway 集中 | starter 下沉到每个 Adapter |
| 工具元数据表 | 需要 `mcp_tool_registry` | 不需要（内存生成） |
| 业务系统改动 | mcp-auth-filter | mcp-auth-filter + SpringDoc |
| 首阶段范围 | 4 子系统 + 50+ 工具 | starter 做透 + QMS 落地 |

### 12.2 待业务侧澄清的后续问题

1. **业务系统框架版本**：QMS / MES / WMS / EMS 分别是 Spring Boot 几版本？是否有非 Spring 的老旧系统？
2. **OpenAPI 现状**：业务系统是否已集成 SpringDoc 或类似？若没有，集成成本评估
3. **AI 平台多 MCP Server 接入能力**：AI 平台是否支持配置多个 MCP Server URL？是否有数量限制？
4. **集团 Maven 私服**：是否可用？如何申请上传权限？
5. **SSO 公钥**：AI 平台签发 JWT 的公钥如何获取（JWKS endpoint 或静态公钥）？
6. **监控基础设施**：Prometheus / Grafana / APM 接入方式
7. **K8s 命名空间申请**：每个 Adapter 与业务系统同空间部署，命名空间申请流程
8. **质量部门试点范围**：QMS 试点用户范围与培训计划
9. **敏感数据脱敏规则**：客户投诉、不合格率等数据的具体脱敏规则（合规部门确认）

### 12.3 术语

| 术语 | 含义 |
|---|---|
| MCP | Model Context Protocol（Anthropic 主导的开放协议） |
| Streamable HTTP | MCP 2025-06-18 规范传输，本文采用纯 JSON 模式 |
| OpenAPI | 业内标准的 REST API 描述格式（前身 Swagger） |
| SpringDoc | Spring Boot 生态的 OpenAPI 3 文档生成库 |
| operationId | OpenAPI 中每个 API 操作的唯一标识，本方案用作工具名后缀 |
| Adapter | 把某业务系统的 API 自动包装成 MCP 工具的服务 |
| starter | Spring Boot 的"启动器"模块，引入即可自动装配 |

### 12.4 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-07-22 | 首版设计（Gateway + Adapter 两层） |
| v2.0 | 2026-07-24 | 团队决议：去 Gateway、Adapter-only、零编码自适配 |
