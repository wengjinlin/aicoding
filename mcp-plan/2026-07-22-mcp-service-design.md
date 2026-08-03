# 集团 MCP 服务规划设计

> **文档版本**：v1.0
> **日期**：2026-07-22
> **作者**：集团 IT 部（与 Claude Code 协同设计）
> **状态**：设计评审中

---

## 1. 背景与目标

### 1.1 业务背景

集团是一家制造业集团公司，自研多个生产相关的业务系统（MES / WMS / QMS / EMS / 设备管理等），技术栈统一为 Java + SpringMVC。面对 AI 浪潮，集团希望让员工和管理者通过 AI 助手便捷、安全地访问这些自研系统的数据与能力。

### 1.2 现状与约束

| 维度 | 现状 |
|---|---|
| 业务系统接口 | 已有 HTTP API，但治理不规范、权限不完整、为前端定制 |
| 代码改动边界 | 尽量不动业务代码；可接受的"最小改动"方式是集中到适配层 |
| AI 平台 | 集中部署的企业内部 AI 助手 + IM 集成；**仅支持 HTTP，不支持 SSE** |
| 身份与权限 | 已有统一登录；业务系统权限不完整，需要 MCP 层补控 |
| 系统边界 | 多个独立子系统（MES / WMS / QMS / EMS 等），数据库与部署均独立 |
| 首阶段重点 | **查询为主**，后续逐步开放操作 |

### 1.3 目标

1. **第一阶段（B）**：建立标准两层 Adapter + Gateway 架构，以 QMS 为首个生产 Adapter，覆盖 4+ 子系统，工具数 50+。
2. **第二阶段（C）**：在 Gateway 上演进跨系统业务域聚合工具，降低 AI 工具选择复杂度。

### 1.4 非目标（YAGNI）

- 不做 MCP `resources/*`、`prompts/*`、`notifications/*`（只做 `tools/*`）
- 不引入 Nacos / Eureka 等重量级注册中心
- 不做参数级权限（仅做"用户↔工具"二元授权）
- 不重构业务系统代码

---

## 2. 关键决策汇总

| 决策项 | 选择 | 理由 |
|---|---|---|
| 架构形态 | 两层 Adapter + Gateway | 业务零侵入、集中治理、可渐进 |
| 传输协议 | MCP Streamable HTTP（纯 JSON 模式，无 SSE） | 兼容自研 AI 平台只支持 HTTP 的限制 |
| 实现语言 | 全 Java + Spring Boot 3.2 + Java 17 | 团队同栈、可复用业务系统基础设施 |
| MCP SDK 位置 | 仅 Gateway 依赖 `mcp-java-sdk` | 协议演进只动一处 |
| 工具定义方式 | YAML 配置（80%）+ Java 注解（20%） | 简单包装快速、复杂逻辑可控 |
| 数据存储 | MySQL（复用集团现有） | 不引入新依赖 |
| 权限策略 | 默认拒绝 + deny 优先 + 角色批量 + 临时授权 | 安全基线 |
| 数据补控 | 三层防线：业务粗粒度 + Adapter 精筛脱敏 + Gateway 工具授权 | 现有 API 权限不完整，必须补 |
| 首个 Adapter | **QMS**（质量管理系统） | 查询场景丰富、管理者经营分析刚需、数据结构化 |
| 部署形态 | **N+1 个独立部署系统**：1 个 Gateway（独立命名空间）+ N 个 Adapter（与业务系统同命名空间）；共享三组 Maven 库 | Adapter 贴近业务、Gateway 集中治理、故障域隔离 |
| 业务系统改动 | 唯一改动：共享 jar `mcp-auth-filter.jar` 加 filter | 集中、最小、可复用 |

---

## 3. 总体架构

### 3.1 四层切分

```
┌──────────────────────────────────────────────────────────────┐
│  消费层：企业 AI 助手 / IM bot / 管理者看板                    │
│  （自研 AI 平台，仅支持 HTTP，已统一员工登录身份）             │
└──────────────────────┬───────────────────────────────────────┘
                       │ HTTP POST (MCP Streamable HTTP / JSON)
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  MCP Gateway（1 个集中部署的 Java Spring Boot 服务）           │
│  职责：                                                        │
│   • 实现 MCP 协议端点（initialize / tools/list / tools/call）  │
│   • 工具注册中心：启动时从各 Adapter 拉取工具元数据             │
│   • 身份校验 + 工具授权（员工能不能调这个工具）                │
│   • 调用审计、限流、熔断、调用链路日志                          │
│   • 不做业务逻辑、不直接碰业务数据库                            │
└──────────────────────┬───────────────────────────────────────┘
                       │ 内部 REST（带用户身份 token 透传）
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  Adapter 层（每子系统一个 Java Spring Boot 服务）              │
│   qms-adapter │ mes-adapter │ wms-adapter │ ems-adapter │ ... │
│  职责：                                                        │
│   • 把子系统的 HTTP API 包装成 MCP 工具（配置/注解驱动）        │
│   • 字段映射、参数校验、结果裁剪、命名规范化                    │
│   • 数据补控：行级权限筛选、字段脱敏                            │
│   • 以业务系统 Service 账号调用现有 API                         │
└──────────────────────┬───────────────────────────────────────┘
                       │ HTTPS（业务系统现有 HTTP API）
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  业务系统层（不动或极少动）                                    │
│   MES / WMS / QMS / EMS / 设备管理 ...（Java + SpringMVC）     │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 职责边界

| 层 | 做什么 | 不做什么 |
|---|---|---|
| Gateway | 协议端点、工具元数据注册、授权决策、审计、限流、熔断 | 不碰业务、不直连 DB、不做跨系统聚合（C 阶段才加） |
| Adapter | 工具定义、字段映射、数据补控、调业务 API | 不实现 MCP 协议、不做跨系统聚合 |
| 业务系统 | 原有业务逻辑 | 仅新增一行 filter 配置引入 `mcp-auth-filter.jar` |

### 3.3 C 阶段演进路径

```
Gateway 上新增一层"业务域聚合工具"，仍用 @McpTool 注解：

  @McpTool(name = "query_batch_quality_full_profile")
  → 内部并行调 qms_adapter + mes_adapter + wms_adapter
  → 拼装成统一视图返回给 AI

命名空间用业务域：quality_ / production_ / inventory_ / equipment_

不改 Adapter、不改业务系统、不引入新协议。
```

---

## 4. MCP Gateway 设计

### 4.1 协议端点

对外只暴露一个端点 `POST /mcp`，实现 MCP Streamable HTTP（**纯 JSON 模式，不开 SSE 流**）：

```
POST /mcp
Content-Type: application/json
Accept: application/json   ← 明确不 Accept text/event-stream
Authorization: Bearer <AI平台签发的用户JWT>

请求体: JSON-RPC 2.0
{ "jsonrpc":"2.0", "id":1, "method":"tools/list" }
{ "jsonrpc":"2.0", "id":2, "method":"tools/call",
  "params":{"name":"qms_query_inspection","arguments":{...}} }
```

只实现三个 method：`initialize` / `tools/list` / `tools/call`。

### 4.2 工具注册中心（轻量）

- **存储**：Gateway 内一张表 `mcp_tool_registry`
- **注册方式**：Adapter 启动时通过 `POST /internal/register` 把工具元数据推给 Gateway；Gateway 每 N 分钟轮询健康检查，失联工具自动降级禁用
- **不引入** Eureka/Nacos，Spring Boot 自带定时任务 + 数据库即可

### 4.3 身份与权限（透传 + 补控）

```
[AI平台JWT] → Gateway 校验签名、提取用户身份(userId/role/dept)
            → 工具授权表 mcp_tool_grant(userId, tool_name, allow/deny)
            → deny 或无记录：直接 403
            → allow：调用 Adapter 时在 Header 透传
              X-User-Id / X-User-Roles / X-User-Dept / X-Trace-Id
```

### 4.4 治理基线

| 能力 | 实现 |
|---|---|
| 限流 | Gateway 层 Resilience4j，按 userId + tool_name 限流 |
| 熔断 | Adapter 调用失败率超阈值 → 熔断，工具标记不可用 |
| 审计 | 每次调用落库：who / what / when / arguments_hash / status / duration / traceId |
| 可观测 | Micrometer + Prometheus + Grafana；traceId 贯穿 |
| 超时 | 分两层：Gateway 对单次 `tools/call` 总超时 10s（在 `mcp_tool_registry.timeout_ms` 可覆盖）；Adapter 调业务 API 默认 8s（在工具 YAML `backend.timeout_ms` 可覆盖）。两者关系：业务 API 超时 < Gateway 总超时，给 Adapter 留处理余量 |

---

## 5. Adapter 设计

### 5.1 工具定义方式：配置 + 注解双轨

**方式一：YAML 配置驱动（占 80%，适合简单包装）**

```yaml
# qms-adapter/src/main/resources/tools/query-inspection.yml
tool:
  name: qms_query_inspection
  description: 按检验单号或批次号查询 QMS 检验结果
  backend:
    method: GET
    url: http://qms-intra/api/inspections/{inspectionId}
    timeout_ms: 8000
  params:
    - name: inspectionId
      type: string
      required: true
      description: 检验单号
  response:
    pick: [id, batchNo, status, result, inspector, inspectAt]
    rename: { id: inspectionId, inspectAt: inspectedAt }
  auth:
    row_filter: "dept = ${user.dept}"
    field_mask: [customerName, customerContact]
```

Adapter 启动时扫描 `tools/*.yml`，解析成工具元数据推给 Gateway，并生成对应调用处理器。

**方式二：Java 注解（占 20%，适合复杂聚合）**

```java
@McpTool(name = "qms_query_defect_rate", description = "查询产线/批次缺陷率与 TOP 不良项")
public DefectRateResult queryDefectRate(
    @McpParam("lineCode") String lineCode,
    @McpParam("from") LocalDate from,
    @McpParam("to") LocalDate to,
    UserContext user
) {
    // 多 API 调用 + 计算
    ...
}
```

### 5.2 与业务 API 的交互

- **认证**：Adapter 持有业务系统的服务账号（长期 token 或 Mutual TLS）
- **调用**：HTTP 客户端（OkHttp / Spring WebClient），不改业务 Controller
- **业务系统最小改动**：引入共享 jar `mcp-auth-filter.jar`，加一个 filter 识别"MCP 服务账号 + 透传 X-User-Id"，把 X-User-Id 放到 ThreadLocal 供现有权限框架使用

### 5.3 数据补控：三层防线

| 层 | 做什么 |
|---|---|
| 业务系统 | 服务账号能访问的数据范围（已有粗粒度权限） |
| Adapter | YAML 的 `row_filter` / `field_mask`，按用户身份精筛和脱敏 |
| Gateway | 工具授权表控制"这个用户能不能调这个工具" |

**Adapter 必须补控**的原因：业务 API 为前端定制，前端可能只显示该用户该看的，但 API 返回全量。Adapter 必须裁剪后再给 AI，否则等于绕过权限。

### 5.4 多 Adapter 部署模式

```
每个 Adapter 是独立 Spring Boot 进程：
  - 可与业务系统同机部署（低延迟）
  - 也可集中在 K8s namespace（统一运维）
  - 独立发版周期
  - 独立配置
```

工具命名空间：`qms_*` / `mes_*` / `wms_*` / `ems_*`，避免重名。

---

## 6. 安全与权限模型

### 6.1 端到端身份链路

```
┌──────────┐   ① 用户登录    ┌──────────┐   ② JWT(含 userId/role/dept)
│ 员工     │ ──────────────→ │ AI 平台   │ ─────────────────────────┐
└──────────┘                 │ (签 JWT) │                          │
                             └──────────┘                          ▼
                                                  ┌────────────────────────┐
                                                  │ MCP Gateway            │
                                                  │ ③ 验签、解析 user ctx  │
                                                  │ ④ 查工具授权表         │
                                                  │ ⑤ 命中 allow → 放行   │
                                                  └────────┬───────────────┘
                                                           │ ⑥ Header 透传
                                                           │   X-User-Id
                                                           │   X-User-Roles
                                                           │   X-User-Dept
                                                           │   X-Trace-Id
                                                           ▼
                                                  ┌────────────────────────┐
                                                  │ Adapter               │
                                                  │ ⑦ 把 user ctx 注入    │
                                                  │   YAML 的 row_filter  │
                                                  └────────┬───────────────┘
                                                           │ ⑧ 业务 API
                                                           │   带 MCP 服务账号
                                                           ▼
                                                  ┌────────────────────────┐
                                                  │ 业务系统               │
                                                  │ ⑨ mcp-auth-filter      │
                                                  │   拿到 X-User-Id       │
                                                  │   供现有权限框架用      │
                                                  └────────────────────────┘
```

### 6.2 三张核心表

**`mcp_tool_registry`**（工具注册表）

| 字段 | 类型 | 说明 |
|---|---|---|
| tool_name | VARCHAR PK | 如 `qms_query_inspection` |
| namespace | VARCHAR | `qms` / `mes` / `wms` / ... |
| adapter_endpoint | VARCHAR | 如 `http://qms-adapter:8080` |
| description | TEXT | 给 AI 看的工具说明 |
| input_schema | JSON | JSON Schema |
| output_schema | JSON | JSON Schema（可选） |
| auth_required | BOOLEAN | 默认 true |
| timeout_ms | INT | Gateway 调用总超时，默认 10000ms |
| require_approval | BOOLEAN | 写操作类工具为 true |
| enabled | BOOLEAN | |
| version | VARCHAR | |
| registered_at | DATETIME | |

**`mcp_tool_grant`**（工具授权表）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT PK | |
| user_id | VARCHAR | 员工 ID（与 role_id 二选一） |
| role_id | VARCHAR | 角色 ID（批量授权） |
| tool_name | VARCHAR FK | |
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
| arguments_hash | VARCHAR | 参数哈希（脱敏后），不存 PII 原文 |
| status | ENUM | `success` / `deny` / `error` / `timeout` |
| duration_ms | INT | |
| error_code | VARCHAR | |
| error_msg | VARCHAR | 截断 |
| called_at | DATETIME | |

### 6.3 授权策略

- **默认拒绝**：`mcp_tool_grant` 查不到 → 直接 403
- **deny 优先于 allow**：同时命中时 deny 赢
- **角色授权**：按 `role_id` 批量给（如"质量工程师"角色可调 `qms_*`）
- **临时授权**：`effective_to` 到期自动失效
- **管理界面**：IT 管理员审批授权、员工申请工具的简单管理后台

### 6.4 脱敏策略

| 字段类型 | 策略 |
|---|---|
| 身份证/手机号 | Adapter 输出前脱敏（保留前 3 后 4） |
| 金额/成本/客户信息 | YAML `field_mask` 声明，默认不返回，授权工具才返回 |
| 备注/自由文本 | 长度截断（超 500 字截断 + "..."） |
| 参数 | 审计日志只存 hash，不存 PII 原文 |
| 大结果集 | 分页强制（单次最多 100 条），避免上下文爆炸 |

### 6.5 安全基线

- Gateway ↔ AI 平台：HTTPS + JWT 验签 + IP 白名单
- Gateway ↔ Adapter：内网 HTTP + 共享密钥签名头 `X-Adapter-Token`
- Adapter ↔ 业务系统：HTTPS + 服务账号
- 敏感操作（写工具）：`require_approval: true` → Gateway 返回 `result: "pending_approval"`，AI 平台走审批流（为后续开放操作能力预留）

---

## 7. 技术选型

### 7.1 MCP 实现语言对比

| 维度 | Java + Spring Boot | TypeScript + Node | Python + FastAPI |
|---|---|---|---|
| SDK 成熟度 | 官方 `mcp-java-sdk`，稳定 | 官方首选，最成熟 | 官方，成熟 |
| 团队匹配 | ✅ 主力栈 | ❌ 新栈要养 | ❌ 新栈 |
| 复用业务基础设施 | ✅ SSO 客户端、日志、监控 jar | ❌ 需重写 | ❌ 需重写 |
| AI/数据生态 | 一般 | 好 | ✅ 最佳 |
| 运维成本 | ✅ 单栈 | ❌ 多一套 | ❌ 多一套 |
| **结论** | **✅ 推荐** | 不推荐 | 不推荐 |

### 7.2 技术栈清单

| 组件 | 选型 | 备注 |
|---|---|---|
| 框架 | Spring Boot 3.2.x | Java 17 LTS |
| MCP SDK | `io.modelcontextprotocol.sdk:mcp`（Gateway only） | 锁定版本 |
| HTTP 客户端 | OkHttp 4 / Spring WebClient | Adapter 调业务 API |
| 元数据存储 | MySQL 8.x | 复用集团现有 |
| 缓存 | Caffeine 本地 | 工具元数据、授权决策，TTL 5 分钟 |
| 限流熔断 | Resilience4j | Gateway 层 |
| 可观测 | Micrometer + Prometheus + Grafana | 复用集团现有监控 |
| 日志 | SLF4J + Logback（结构化 JSON） | traceId 贯穿 |
| 配置中心 | Spring 配置文件起步；后续按需接 Nacos | 不强依赖 |
| 部署 | Docker + 内网 K8s（如有）或 Tomcat | Adapter 可与业务系统同机 |

### 7.3 系统形态与部署单元

**重要**：本方案不是单一系统，而是 **N+1 个独立可部署系统 + 一组共享 Maven 库**。

#### 7.3.1 共享库（Maven jar，发布到集团 Maven 私服，**非部署单元**）

| 模块 | 作用 | 被谁依赖 |
|---|---|---|
| `mcp-common` | 共享 DTO、UserContext、常量、错误码 | Gateway / 所有 Adapter / 业务系统（如需） |
| `mcp-auth-filter` | 业务系统引入的鉴权 filter（识别服务账号 + 透传 X-User-Id） | 各业务系统 |
| `mcp-adapter-starter` | Adapter 开发的 Spring Boot starter（`@McpTool` 注解、YAML 解析、自动注册） | 各 Adapter |

共享库独立版本号、独立发布到私服，各系统按需声明依赖。

#### 7.3.2 部署单元（独立系统、独立仓库、独立发版）

| # | 系统 | 代码仓库 | 部署位置 | 说明 |
|---|---|---|---|---|
| 1 | **MCP Gateway** | `harness-mcp-gateway` | 独立命名空间 `mcp-gateway` | 集中部署、多副本、协议与治理层 |
| 2 | QMS Adapter | `harness-qms-adapter` | `qms` 命名空间（与 QMS 业务系统同空间） | 首个 Adapter（B-1） |
| 3 | MES Adapter | `harness-mes-adapter` | `mes` 命名空间（与 MES 业务系统同空间） | B-2 |
| 4 | WMS Adapter | `harness-wms-adapter` | `wms` 命名空间 | B-2 |
| 5 | EMS Adapter | `harness-ems-adapter` | `ems` 命名空间 | B-2 |
| ... | 其他子系统 Adapter | `harness-<sys>-adapter` | 对应业务系统命名空间 | 按需扩展 |

> 仓库策略：Gateway 独立仓库；Adapter 可以"一系统一仓库"（推荐，团队边界清晰）或"一个 monorepo 下多模块"（适合小团队统一管理）。两种都可以，但**部署上必须各自独立**。

#### 7.3.3 部署拓扑（K8s 命名空间视角）

```
namespace: mcp-gateway                  ← Gateway 独立命名空间
  └── mcp-gateway-pod (replicas=3)
        ↓ 内网 HTTP + X-Adapter-Token
        ↓ (启动时拉取工具元数据 + 运行时调用)
        │
        ├──→ namespace: qms              ← QMS 业务 + QMS Adapter 同空间
        │     ├── qms-business-pod
        │     └── qms-adapter-pod
        │           ↓ HTTP + 服务账号
        │           ↓
        │           qms-business-pod
        │
        ├──→ namespace: mes
        │     ├── mes-business-pod
        │     └── mes-adapter-pod
        │
        ├──→ namespace: wms
        │     ├── wms-business-pod
        │     └── wms-adapter-pod
        │
        └──→ namespace: ems
              ├── ems-business-pod
              └── ems-adapter-pod
```

#### 7.3.4 这样切分的好处

1. **Adapter 与业务系统同 namespace**：内网调用延迟最低，K8s NetworkPolicy 最简
2. **Gateway 独立集中**：协议演进、扩容、升级不影响业务系统可用性
3. **故障域清晰**：单个 Adapter 挂了只影响该子系统；Gateway 多副本保证高可用
4. **发版解耦**：各 Adapter 由对应业务团队维护，互不阻塞
5. **共享库版本化**：通过 Maven 私服管理升级节奏，可灰度推进

#### 7.3.5 各部署单元的依赖与职责速查

| 单元 | 依赖 | 主要职责 |
|---|---|---|
| MCP Gateway | `mcp-common` + `mcp-java-sdk` + MySQL + Resilience4j + Caffeine | MCP 协议端点、工具元数据注册中心、授权决策、审计、限流熔断 |
| `<sys>-adapter` | `mcp-common` + `mcp-adapter-starter` | 包装业务 API 为 MCP 工具、字段映射、数据补控 |
| 业务系统 | `mcp-auth-filter` | 加 filter 识别服务账号 + 透传 X-User-Id（**唯一代码接触**） |

---

## 8. 实施路线图

### 8.1 B 阶段里程碑

| 阶段 | 周期 | 交付物 | 验收 |
|---|---|---|---|
| **B-0 地基** | 第 1-3 周 | 发布三组共享库到 Maven 私服：`mcp-common` / `mcp-auth-filter` / `mcp-adapter-starter` 骨架；**Gateway 独立仓库 `harness-mcp-gateway`** 跑通 MCP 协议端点（部署到 `mcp-gateway` 命名空间）；三张表 + 授权管理最小页面 | AI 平台能调通 `tools/list`，返回示例工具 |
| **B-1 首个生产 Adapter（QMS）** | 第 4-8 周 | **QMS Adapter 独立仓库 `harness-qms-adapter`**，部署到 `qms` 命名空间（与 QMS 业务系统同空间）；落地 10-15 个查询工具：检验单查询 / 批次检验结果 / 不合格品记录 / CAPA 跟踪 / 客户投诉 / SPC 指标 / 质量追溯链 等；QMS 业务系统 Maven 引入 `mcp-auth-filter`；Gateway ↔ QMS Adapter 权限/审计/限流联调 | 选 1 个质量部门试点上线，真实员工通过 AI 助手查 QMS |
| **B-2 横向铺开** | 第 9-16 周 | 各业务团队按模板起独立仓库：`harness-mes-adapter` / `harness-wms-adapter` / `harness-ems-adapter`，分别部署到对应业务命名空间；工具数到 50+；管理后台完善（授权审批、审计查询、监控大盘） | 4 个子系统均上线，AI 平台工具目录成型 |
| **B-3 加固** | 第 17-20 周 | 红蓝对抗、性能压测、灾备方案（Gateway 多副本、各 Adapter 健康检查、命名空间 NetworkPolicy）、运维 Runbook | 生产稳定性达标（SLA 99.5%+） |

**关键节点**：B-1 结束（第 8 周）即有可演示的真实业务价值，不必等全部铺完。

### 8.2 C 阶段演进

**触发条件**：B-2 完成后，发现 AI 频繁需要跨子系统拼接才能回答问题（如"这张订单的完整质量履历" = QMS 检验 + MES 工单 + WMS 出库 + EMS 设备参数）。

**做的事**：
- Gateway 新增"业务域聚合工具"层，仍用 `@McpTool` 注解
- 工具并行调多个 Adapter，拼装统一视图返回
- 命名空间用业务域：`quality_` / `production_` / `inventory_` / `equipment_`

**不做的事**：
- 不改 Adapter（仍是子系统级原子工具）
- 不引入新协议
- 不改业务系统

**收益**：工具数量从"原子级 50+"压到"业务域级 15-20"，AI 选择更准、调用更少、上下文更省。

### 8.3 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| 现有 API 返回 PII 未脱敏 | 高 | 高 | Adapter 强制走 `field_mask`；上线前安全扫描；审计只存 hash |
| 业务 API 响应慢拖垮 Gateway | 高 | 中 | Adapter 超时 8s + Gateway 总超时 10s + Resilience4j 熔断 |
| AI 误用工具（错数据被当成事实） | 中 | 高 | 工具描述写明数据范围/时效；关键工具加 `require_approval`；审计追溯 |
| 工具爆炸（100+ 选择困难） | 中 | 中 | B-2 后评估，必要时进入 C 阶段聚合 |
| 服务账号被滥用 | 低 | 高 | 服务账号专属、定期轮换、最小权限、审计调用链 |
| AI 平台协议升级 | 低 | 中 | Gateway 是唯一协议层，升级只动一处 |
| 集团组织调整影响权限 | 中 | 中 | 授权表支持角色 + 到期失效，避免静态绑定员工 |
| **质量数据合规风险**（不合格率、客诉等敏感） | 中 | 高 | 严格走 `field_mask` + 角色授权 + 审计；质量部门单独审批流 |

### 8.4 成功度量

- **覆盖**：B-2 结束时接入 4+ 子系统，工具数 50+
- **活跃**：月活调用 > X 万次（与业务部门对齐具体数字）
- **稳定**：SLA 99.5%+，P95 延迟 < 2s（不含业务 API 本身耗时）
- **安全**：0 起权限越权审计事件
- **效率**：新 Adapter 从 0 到上线 ≤ 3 周（靠 starter 模板）

---

## 9. 测试策略与验收

### 9.1 测试分层

| 层级 | 范围 | 工具/方式 |
|---|---|---|
| 单元测试 | YAML 解析、字段映射、脱敏、row_filter、注解处理器 | JUnit 5 + Mockito，覆盖率 ≥ 80% |
| 契约测试 | Adapter ↔ Gateway 工具元数据结构；Adapter ↔ 业务 API 字段约定 | Spring Cloud Contract 或 JSON Schema 校验 |
| 集成测试 | Gateway → Adapter → Mock 业务 API 全链路；授权表生效；审计落库 | Testcontainers（MySQL、Mock Server） |
| 安全测试 | 未授权调用必拒；越权参数必筛；PII 必脱敏；服务账号被盗用场景 | OWASP ZAP 扫描 + 红蓝对抗 |
| 性能测试 | 单 Gateway：500 QPS `tools/list`、100 QPS `tools/call`；P95 < 2s | JMeter / k6 |
| AI 端到端 | AI 平台真实提问 → 工具调用 → 正确结果；误用、模糊提问的降级 | 手工 + 半自动化（固定 prompt 集） |

### 9.2 Adapter 上线准入清单

```
□ YAML/注解工具定义 review 通过
□ 字段映射覆盖（业务 API 返回 vs 工具输出）
□ field_mask 覆盖所有 PII/敏感字段
□ row_filter 与业务部门确认数据范围
□ 工具授权角色已配置（最小可用角色）
□ 业务 API 已加 mcp-auth-filter 并通过联调
□ 集成测试通过、契约测试通过
□ 性能压测达标
□ 安全扫描无高危
□ 审计日志可追溯、traceId 贯穿验证
□ Runbook 已写、oncall 已知会
□ 灰度方案已定（先开 1 个部门）
```

### 9.3 B 阶段验收标准

- **功能**：QMS + 3 个其他子系统接入，工具数 ≥ 50，AI 平台真实可用
- **性能**：Gateway P95 < 2s（不含业务 API 本身）；Adapter P95 < 1s
- **安全**：0 高危漏洞；100% 工具走授权表；100% 调用有审计
- **可运维**：单个 Adapter 故障不影响其他；Gateway 支持滚动发布
- **可扩展**：新增 Adapter ≤ 3 周（starter 模板支撑）
- **用户满意度**：试点部门主观评分 ≥ 4/5

---

## 10. 附录

### 10.1 术语

| 术语 | 含义 |
|---|---|
| MCP | Model Context Protocol，模型上下文协议（Anthropic 主导的开放协议） |
| Streamable HTTP | MCP 2025-06-18 规范的新传输，单端点 POST，响应可为 JSON 或 SSE 流；本文档采用纯 JSON 模式 |
| Adapter | 把某个业务子系统的 API 包装成 MCP 工具的服务 |
| Gateway | 对 AI 平台统一暴露 MCP 协议、做治理的集中服务 |
| 工具（Tool） | MCP 中 AI 可调用的能力单元，对应一个函数 |
| BFF | Backend For Frontend，为前端定制的后端聚合层 |

### 10.2 待业务侧澄清的后续问题

下列问题不阻塞本设计落地，可在 B-0 / B-1 阶段与业务部门对齐：

1. QMS 系统现有 HTTP API 的完整清单（URL、入参、出参、权限）——由 QMS 开发团队提供
2. 集团是否已有 SSO/CAS/OAuth2？签发的 JWT 字段格式（userId / role / dept 命名）
3. 集团监控基础设施（Prometheus / Grafana / 内网 APM）的具体接入方式
4. 内网 K8s 是否可用、命名空间申请流程
5. 质量部门试点用户范围与培训计划
6. 客户投诉、不合格率等敏感数据的具体脱敏规则（由合规部门确认）

### 10.3 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-07-22 | 首版设计，完成 7 段评审确认 |
