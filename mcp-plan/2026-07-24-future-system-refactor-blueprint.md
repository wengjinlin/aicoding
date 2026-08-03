# 未来业务系统重构蓝图：AI 友好标准

> **文档版本**：v1.1
> **日期**：2026-07-29（v1.1）/ 2026-07-24（v1.0）
> **作者**：集团 IT 部
> **状态**：设计评审中
> **目的**：为集团自研业务系统（MES / WMS / QMS / EMS 等）未来重构提供"AI 友好"标准，使重构后的系统能从 v3 声明式模式平滑切换到 v2 自动发现模式
> **关联文档**：
> - `2026-07-24-mcp-adapter-design-v3.md`（v3 当前方案）
> - `2026-07-24-mcp-adapter-design.md`（v2 自动发现模式，目标态）
> - `2026-07-24-qms-migration-feasibility.md`（QMS 现状分析）

---

## 1. 文档目的

### 1.1 为什么需要这份蓝图

集团当前采用 v3 方案接入 MCP：业务系统零代码改动，IT 部显式声明工具，Adapter 内置智能翻译层。这是**针对老系统现状的务实方案**。

但 v3 有其成本：
- 每个工具都需要 IT 部人工设计与维护 YAML
- 业务系统新增/修改 API 后，IT 部需要主动跟进声明工具
- 工具描述质量依赖人工把关
- 业务系统 API 治理问题被"绕过"而非"解决"

**理想态**是 v2：业务系统 API 治理良好，Adapter 自动发现、自动同步。但 v2 要求业务系统达到"AI 友好"标准。

本蓝图定义这套标准，作为：
1. **未来业务系统重构的验收依据**
2. **从 v3 切换到 v2 的判定条件**
3. **新业务系统立项时的设计输入**

### 1.2 适用范围

- 集团所有自研业务系统（含现有系统的重构、新系统立项）
- 不强制现有系统立即按本蓝图整改——v3 方案已为现状兜底
- 重构契机（如重大业务调整、技术债集中清理、新系统立项）来临时，本蓝图即生效

### 1.3 与 v3 的关系

```
现状（v3）：业务系统原样 → IT 部声明工具 → 智能翻译
                                      ↓
                              [业务系统重构达标]
                                      ↓
未来（v2）：业务系统暴露标准 OpenAPI → Adapter 自动发现 → 零维护上线
```

本蓝图定义"达标"的具体内容。

---

## 2. 当前老系统问题汇总（以 QMS 为参照）

下列问题在 v3 方案下被 Adapter 智能翻译层"兜底"，不需要立即整改。但重构时应彻底解决。

| # | 问题 | QMS 体现 | 影响 |
|---|---|---|---|
| 1 | API 非 RESTful | 几乎全 POST，URL 如 `qmsDeviceMainData/selectForPage` | 工具名难以语义化、HTTP 方法语义混乱 |
| 2 | 无 operationId | Controller 未用 `@Operation(operationId=...)` | 自动生成的工具名丑陋 |
| 3 | Swagger 注解质量参差 | CLAUDE.md 强制但老代码未贯彻 | 文档不可靠，自动发现风险高 |
| 4 | 入参嵌套 DTO | `QmsDeviceMainDataDto` 含实体+分页+Map+list | AI 无法构造请求 |
| 5 | `Map<String,String[]>` 通用参数 | `paraMap` 字段 | Schema 无法生成，AI 完全无法理解 |
| 6 | 统一 `Result<?>` 包装 | code/msg/data 结构 | 需要剥离才能让 AI 消费 |
| 7 | 字段 c/n/d 前缀 | cCreateuser、dCreatetime、nVersion | 对 AI 极不友好 |
| 8 | 字段名语义化不足 | cFactorycode、cDevicename | AI 难以推断含义 |
| 9 | Entity 暴露在响应中 | Controller 返回 Entity 而非 VO | 内部字段泄露、字段不稳定 |
| 10 | 鉴权与权限点分离 | `@Authignore` 自研标记 | 与标准注解生态不兼容 |
| 11 | 多数据源混杂 | MySQL + PostgreSQL + Oracle | 数据语义不一致 |
| 12 | 业务模块过度细粒度 | 100+ 模块、117 controller 目录 | 工具规模爆炸 |

---

## 3. 未来业务系统应达到的 8 项标准

### 3.1 标准 1：API 设计规范（RESTful）

#### 3.1.1 要求

- **HTTP 方法语义正确**：
  - `GET`：查询（无副作用，可缓存）
  - `POST`：新增 / 触发操作
  - `PUT` / `PATCH`：更新
  - `DELETE`：删除
- **URL 资源化命名**：
  - 使用名词复数：`/api/devices`、`/api/inspections`
  - 层级表达从属：`/api/batches/{batchNo}/inspections`
  - 使用 kebab-case（不强制，但保持一致）
- **版本管理策略（强制升级，不携带 URL 版本前缀）**：
  - URL **不携带版本前缀**（不使用 `/api/v1/`、`/api/v2/`）
  - 业务系统迭代时通过**破坏性变更直接替换**旧 API，由 IT 部协调内部使用方同步切换
  - 适用条件：内部自研系统 + 无第三方外部调用方 + 集团内可强制协同
  - 例外：对外开放 API（如有合作伙伴 / 供应商调用），按行业标准独立管理版本

#### 3.1.2 反例（QMS 现状）

```java
@PostMapping("selectForPage")                    // 查询用 POST
@PostMapping("update_init")                      // 下划线 + 动词
@PostMapping("insert")                           // 动词 URL
@RequestMapping("qmsDeviceMainData")             // camelCase
```

#### 3.1.3 正例（重构后）

```java
@GetMapping("/api/devices")                      // GET 查询
@GetMapping("/api/devices/{id}")                 // 路径参数
@PostMapping("/api/devices")                     // POST 新增
@PutMapping("/api/devices/{id}")                 // PUT 更新
@DeleteMapping("/api/devices/{id}")              // DELETE 删除
```

#### 3.1.4 检查点

- [ ] 所有查询接口用 GET
- [ ] 所有写接口用对应方法（POST/PUT/PATCH/DELETE）
- [ ] URL 是名词复数 + 资源层级
- [ ] URL 不携带版本前缀（强制升级策略）
- [ ] 无下划线 / 动词 URL

---

### 3.2 标准 2：OpenAPI 3 文档规范

#### 3.2.1 要求

- **使用 OpenAPI 3**（不是 Swagger 2）：集成 SpringDoc，暴露 `/v3/api-docs`
- **每个 API 必填 `operationId`**：语义化、camelCase、全局唯一
- **每个 API 必填 `summary` 和 `description`**：summary 一句话，description 详尽
- **参数与请求体必填 `description` 和 `example`**
- **响应 schema 完整定义**

#### 3.2.2 反例（QMS 现状）

```java
@ApiOperation("分页列表查询")                    // 无 operationId，描述过简
@PostMapping("selectForPage")
public Result<?> queryList(@RequestBody QmsDeviceMainDataDto dto) { ... }
// 参数无 description、无 example
```

#### 3.2.3 正例（重构后）

```java
@GetMapping("/api/devices")
@Operation(
    operationId = "listDevicesByFactory",
    summary = "按工厂分页查询设备清单",
    description = "按工厂代码分页查询设备主数据。支持按设备名模糊匹配、状态过滤。"
)
public PageResult<DeviceVO> listDevices(
    @Parameter(description = "工厂代码", example = "F01", required = true)
    @RequestParam String factoryCode,

    @Parameter(description = "设备名（模糊匹配）", example = "注射机")
    @RequestParam(required = false) String deviceName,

    @Parameter(description = "页码，从 1 开始", example = "1")
    @RequestParam(defaultValue = "1") int pageNo,

    @Parameter(description = "每页条数，最大 100", example = "10")
    @RequestParam(defaultValue = "10") @Max(100) int pageSize
) { ... }
```

#### 3.2.4 检查点

- [ ] 集成 SpringDoc（不是 SpringFox）
- [ ] `/v3/api-docs` 端点可用
- [ ] 每个 API 有 operationId（全局唯一）
- [ ] 每个 API 有 summary 和 description
- [ ] 每个参数有 description 和 example
- [ ] 响应 schema 完整

---

### 3.3 标准 3：字段命名规范（语义化）

#### 3.3.1 要求

- **禁止 c/n/d 前缀**：使用业务语义命名
  - `cCreateuser` → `creator` / `createdBy`
  - `dCreatetime` → `createTime` / `createdAt`
  - `cFactorycode` → `factoryCode`
  - `cDevicename` → `deviceName`
- **命名风格统一**：camelCase（Java）/ snake_case（数据库）
- **单词完整**：避免缩写（`qty` → `quantity`、`qty` 若是行业术语可保留）

#### 3.3.2 反例（QMS 现状）

```java
public class QmsDeviceMainData {
    private BigDecimal id;
    private String cDevicecode;          // 前缀 + 缩写
    private String cDevicename;
    private String cFactorycode;
    private String cCreateuser;          // 创建人，前缀 + 拼接
    private Date dCreatetime;
    private Integer nVersion;
}
```

#### 3.3.3 正例（重构后）

```java
public class Device {
    private Long id;
    private String deviceCode;
    private String deviceName;
    private String factoryCode;
    private String createdBy;
    private Instant createdAt;
    private Integer version;
}
```

#### 3.3.4 数据库字段映射

数据库字段保留 c/n/d 前缀（向后兼容）：
- 数据库：`c_createuser`、`d_createtime`
- Entity：通过 `@TableField("c_createuser")` 映射到 `createdBy`

#### 3.3.5 检查点

- [ ] API 入参/出参字段无 c/n/d 前缀
- [ ] 字段名是完整单词或行业通用缩写
- [ ] 命名风格统一（camelCase）
- [ ] 数据库字段保留前缀（通过 ORM 映射）

---

### 3.4 标准 4：响应规范

#### 3.4.1 要求

- **查询类 API 直接返回业务数据**（不包装 Result）
- **写操作 API 返回操作结果**（含生成的 ID）
- **错误统一通过 Problem Details（RFC 7807）或类似标准格式返回**：HTTP 状态码即语义
- **分页查询返回标准化分页结构**

#### 3.4.2 反例（QMS 现状）

```java
public Result<?> queryList(...) {
    return Result.success(page);                // 业务数据被 Result 包装
}
```

```json
// 响应：AI 需要 unwrap
{
  "code": 200,
  "msg": "success",
  "data": {
    "records": [...],
    "total": 100
  }
}
```

#### 3.4.3 正例（重构后）

```java
public PageResult<DeviceVO> listDevices(...) {
    return new PageResult<>(records, total, pageNo, pageSize);
}
```

```json
// 直接返回业务数据
{
  "records": [...],
  "total": 100,
  "pageNo": 1,
  "pageSize": 10
}
```

错误返回（HTTP 4xx/5xx + Problem Details）：

```json
{
  "type": "https://api.example.com/errors/permission-denied",
  "title": "Permission Denied",
  "status": 403,
  "detail": "您没有查看此设备的权限",
  "instance": "/api/v1/devices/12345"
}
```

#### 3.4.4 检查点

- [ ] 查询 API 直接返回业务数据（无 Result 包装）
- [ ] 分页响应符合统一结构（records/total/pageNo/pageSize）
- [ ] 错误使用 HTTP 状态码 + Problem Details
- [ ] 无 i18n 嵌入响应（i18n 在客户端处理）

---

### 3.5 标准 5：DTO 设计规范

#### 3.5.1 要求

- **入参扁平**：避免 DTO 嵌套实体；查询参数用 `@RequestParam` 或扁平 Query DTO
- **出参用 VO**：Controller 返回 VO 而非 Entity
- **禁止通用 Map 参数**：不用 `Map<String, String[]>` 等无 schema 的参数
- **请求体与响应体分离**：CreateReq / UpdateReq / XxxVO 不混用

#### 3.5.2 反例（QMS 现状）

```java
@Data
public class QmsDeviceMainDataDto {
    private List<QmsDeviceMainData> qmsDeviceMainDataList;     // 批量
    private QmsDeviceMainData qmsDeviceMainData;               // 单条
    private Integer pageNo;
    private Integer pageSize;
    private Map<String, String[]> paraMap;                     // 通用 Map
    private List<BigDecimal> idList;
}
// 一个 DTO 同时承载查询、新增、更新、删除、批量操作
```

#### 3.5.3 正例（重构后）

```java
// 查询参数扁平
public record DeviceQueryParams(
    @NotBlank String factoryCode,
    String deviceName,
    String status,
    @Min(1) @DefaultValue(1) int pageNo,
    @Min(1) @Max(100) @DefaultValue(10) int pageSize
) {}

// 新增请求
public record DeviceCreateReq(
    @NotBlank String deviceCode,
    @NotBlank String deviceName,
    @NotBlank String factoryCode
) {}

// 更新请求
public record DeviceUpdateReq(
    String deviceName,
    String status
) {}

// 响应 VO
public record DeviceVO(
    Long id,
    String deviceCode,
    String deviceName,
    String factoryCode,
    String status,
    String createdBy,
    Instant createdAt
) {}
```

#### 3.5.4 检查点

- [ ] 查询参数扁平（无嵌套 DTO）
- [ ] 无 `Map<String, ?>` 通用参数
- [ ] 请求与响应用不同类（CreateReq/UpdateReq/XxxVO）
- [ ] Controller 返回 VO 不返回 Entity

---

### 3.6 标准 6：鉴权规范

#### 3.6.1 要求

- **使用标准注解**：Spring Security 的 `@PreAuthorize` / `@Secured`，或 OpenAPI 3 的 `SecurityScheme`
- **服务账号机制**：业务系统支持识别服务账号（用于 MCP Adapter 调用）
- **用户身份透传**：业务系统能消费 HTTP Header 中的 `X-User-Id` 等身份字段
- **权限点集中管理**：权限代码（如 `device:read`）有命名规范、可在文档中体现

#### 3.6.2 反例（QMS 现状）

```java
@Authignore("/qmsDeviceMainData/selectForPage")       // 自研注解，无标准语义
@PostMapping("selectForPage")
public Result<?> queryList(...) { ... }
// 服务账号、身份透传机制不明确
```

#### 3.6.3 正例（重构后）

```java
@GetMapping("/api/devices")
@PreAuthorize("hasAuthority('device:read')")          // 标准注解
@Operation(
    operationId = "listDevices",
    security = @SecurityRequirement(name = "bearerAuth")   // OpenAPI 安全要求
)
public PageResult<DeviceVO> listDevices(...) { ... }
```

服务账号识别：

```java
// Filter 中识别服务账号
if (hasMcpServiceToken(request)) {
    authenticateAsServiceAccount();
    applyUserIdFromHeader(request.getHeader("X-User-Id"));
}
```

#### 3.6.4 检查点

- [ ] 鉴权用 Spring Security 标准注解
- [ ] OpenAPI 文档声明 SecurityScheme
- [ ] 业务系统能识别 MCP 服务账号
- [ ] 业务系统能消费 `X-User-Id` 等 Header
- [ ] 权限点命名规范统一（`{domain}:{action}`）

---

### 3.7 标准 7：元数据端点规范

#### 3.7.1 要求

- **`/v3/api-docs` 端点稳定可用**：OpenAPI 3 文档在所有环境可访问
- **变更通知机制**（可选，加分项）：业务系统 API 变更时主动通知 Adapter（Webhook）
- **多文档分组**（大型系统）：按业务域分组（`/v3/api-docs/device`、`/v3/api-docs/inspection`）

#### 3.7.2 反例（QMS 现状）

- Swagger 2 `/v2/api-docs`，非 OpenAPI 3
- 无变更通知机制，Adapter 需轮询
- 无分组，单文档覆盖 100+ 模块

#### 3.7.3 正例（重构后）

```yaml
# 业务系统 application.yml
springdoc:
  api-docs:
    path: /v3/api-docs
    groups:
      enabled: true
  group-configs:
    - group: device
      paths: /api/devices/**
    - group: inspection
      paths: /api/inspections/**
```

Webhook 通知（可选）：

```java
@EventListener
public void onApiChange(ApiChangeEvent event) {
    mcpAdapterWebhookClient.notify(event.getChangedPaths());
}
```

#### 3.7.4 检查点

- [ ] `/v3/api-docs` 端点在所有环境可用
- [ ] 大型系统按业务域分组
- [ ] （可选）实现变更 Webhook
- [ ] OpenAPI 文档通过 schema 校验

---

### 3.8 标准 8：支持动态聚合查询能力

#### 3.8.1 要求

业务系统对常用数据集（订单、检验单、缺陷等）暴露**半通用聚合查询端点**，使 AI 能在白名单范围内自由组合维度与指标进行分析，避免"列表翻页累积 + AI 内存计算"的低效模式。

- **统一聚合端点**：`POST /api/aggregate`（或 `/api/{dataset}/aggregate`）
- **白名单维度**：业务系统预先声明每个数据集可聚合的维度（如 orders 数据集可按 factory / product / customer / month 聚合）
- **白名单指标**：count / sum:{field} / avg:{field} / rate:{passField}/{totalField}，禁止任意 field 表达式
- **过滤条件下推**：filter 参数与 list API 共享 schema，自动应用行级权限
- **结果上限**：topN ≤ 200，避免无限制返回
- **执行超时**：单次聚合查询 ≤ 5 秒

#### 3.8.2 反例（v3 兜底期）

IT 部针对每个分析需求手工写 SQL + 包装为专用 MCP 工具：

```yaml
# 一个分析需求 = 一个工具，工具数量随业务需求线性增长
tool:
  name: qms_statInspectionRateByFactory
  # ... 固定的维度组合
tool:
  name: qms_statInspectionRateByProduct
  # ... 另一个固定组合
tool:
  name: qms_statInspectionRateByInspector
  # ... 又一个固定组合
```

10 个分析需求 = 10 个工具，维护成本高。

#### 3.8.3 正例（重构后）

业务系统提供半通用聚合 API：

```java
@PostMapping("/api/aggregate")
@Operation(
    operationId = "aggregateQuery",
    summary = "数据聚合查询（白名单维度）",
    description = "在白名单维度与指标内执行 group by 聚合查询"
)
@PreAuthorize("hasAuthority('aggregate:read')")
public AggregateResultVO aggregate(
    @RequestBody @Valid AggregateQueryReq req
) {
    return aggregateService.query(req);
}
```

白名单声明（业务系统侧维护）：

```java
@Component
public class AggregateWhitelist {
    private static final Map<String, DatasetSpec> WHITELIST = Map.of(
        "orders", new DatasetSpec(
            List.of("factory", "product", "customer", "month", "week"),
            List.of("count", "sum:amount", "avg:amount")
        ),
        "inspections", new DatasetSpec(
            List.of("factory", "line", "inspector", "month"),
            List.of("count", "rate:passed/total")
        )
    );
}
```

MCP Adapter 端只需暴露一个工具：

```yaml
tool:
  name: qms_aggregate
  description: |
    数据聚合查询。AI 提交数据集 + 维度组合 + 指标，服务端 group by 执行。
    支持数据集：orders / inspections / defects（各自有白名单维度）
  backend:
    method: POST
    url: http://qms-intra/api/aggregate
```

#### 3.8.4 检查点

- [ ] 业务系统暴露 `/api/aggregate` 端点（或 `/api/{dataset}/aggregate`）
- [ ] 维度白名单文档化（每个数据集的可聚合维度）
- [ ] 指标白名单文档化（仅允许 count / sum / avg / rate）
- [ ] 过滤条件与 list API 共享 schema
- [ ] 行级权限自动下推到 where 子句
- [ ] topN 上限 ≤ 200
- [ ] 单次查询超时 ≤ 5 秒
- [ ] 审计日志记录每次聚合查询的维度组合

---

## 4. 重构检查清单

### 4.1 三档分级

| 等级 | 范围 | 达标意义 |
|---|---|---|
| **L1：Controller 级** | 单个 Controller 满足 8 项标准 | 该 Controller 可切换 v2 自动发现 |
| **L2：模块级** | 一个业务模块下所有 Controller 达 L1 | 该模块整体切 v2 |
| **L3：系统级** | 所有模块达 L2 + 元数据端点规范 | 系统整体切 v2 |

### 4.2 L1 Controller 级检查清单

```
□ 所有 API 符合 RESTful（GET/POST/PUT/PATCH/DELETE 语义）
□ URL 资源化命名（名词复数 + 路径参数）
□ URL 不携带版本前缀（强制升级策略）
□ 每个 API 有 operationId（全局唯一、camelCase）
□ 每个 API 有 summary 和 description
□ 每个参数有 description 和 example
□ 响应 schema 完整
□ 字段无 c/n/d 前缀
□ 字段名语义化（完整单词）
□ Controller 返回 VO 不返回 Entity
□ 入参扁平（无嵌套 DTO，无 Map）
□ 请求与响应类分离
□ 鉴权用 Spring Security 标准注解
□ 查询 API 直接返回数据（无 Result 包装）
□ 错误用 HTTP 状态码 + Problem Details
```

### 4.3 L2 模块级检查清单

```
□ 模块下所有 Controller 达 L1
□ 模块的 OpenAPI 文档独立可访问（如 /v3/api-docs/{module}）
□ 模块的工具授权表已对齐
□ 模块的字段命名与跨模块术语统一（如"工厂代码"在所有模块都叫 factoryCode）
```

### 4.4 L3 系统级检查清单

```
□ 所有模块达 L2
□ /v3/api-docs 在所有环境稳定可用
□ 大型系统按业务域分组文档
□ 业务系统暴露 /api/aggregate 端点（半通用聚合查询）
□ 服务账号机制成熟
□ 鉴权统一接入集团 SSO
□ 字段命名规范文档化（含术语表）
□ OpenAPI 文档通过自动化校验（CI 流水线）
□ （可选）API 变更 Webhook 通知
```

---

## 5. 重构优先级与路径

### 5.1 价值/难度矩阵

|  | **低难度** | **高难度** |
|---|---|---|
| **高价值** | 优先级 1：字段命名规范、Result 解包规范化、operationId 补全 | 优先级 2：URL RESTful 化、入参扁平化、鉴权规范化、支持动态聚合查询能力 |
| **低价值** | 优先级 3：错误格式统一、文档分组 | 优先级 4：Webhook 通知 |

### 5.2 推荐重构顺序

**第 1 步（最高 ROI）**：字段命名 + Result 解包规范
- 影响所有 Controller，但单点改动小
- 让现有 v3 工具的 `field rename` 与 `unwrap-result` 配置大幅减少
- 不强制立即切换 v2

**第 2 步**：operationId 补全 + OpenAPI 3 升级
- 为切 v2 做准备
- 不影响现有 API 行为

**第 3 步**：URL RESTful 化 + 入参扁平化
- 涉及前端配合，工作量大
- 通常伴随业务系统大版本升级

**第 4 步**：鉴权与元数据端点规范
- 服务账号机制、Webhook 通知等
- 切 v2 自动发现的"最后一公里"

**第 5 步**：支持动态聚合查询能力
- 业务系统暴露 `/api/aggregate` 端点 + 维度 / 指标白名单
- 让 v3 演进阶段 3 的"半通用聚合工具"具备落地前提
- 影响：v3 专用聚合工具可逐步 deprecated，被一个半通用工具替代

### 5.3 重构契机

何时启动重构？典型契机：
- 业务系统大版本升级（如 QMS 2.0）
- 重大业务调整（如新工厂、新产线接入）
- 技术债集中清理周期
- 框架强制升级（如 Spring Boot 2 → 3）
- 新系统立项时（直接按蓝图设计，不走 v3）

---

## 6. 与 v3 Adapter 的衔接

### 6.1 双模式共存

业务系统可以**渐进式**从 v3 切换到 v2：

```
阶段 A（现状）：所有工具走 v3 声明式
                ↓ 业务系统逐步重构
阶段 B（混合）：部分模块达标 → 切 v2 自动发现；其余仍 v3
                ↓ 全系统达标
阶段 C（理想）：所有工具走 v2 自动发现，v3 工具退役
```

### 6.2 单模块切换流程

当某模块（如 `deviceMasterData`）达 L2 标准：

```
1. 评估检查：按 L2 清单逐项核对
2. 试运行：在测试环境，用 v2 Adapter 拉取该模块的 OpenAPI 文档
3. 工具对照：v2 自动生成的工具 vs v3 现有声明的工具，参数/响应/描述是否一致
4. 灰度切换：先让小部分流量走 v2，观察 AI 调用准确率与审计日志
5. 全量切换：稳定后下线 v3 工具 YAML
```

### 6.3 切换判定指标

| 指标 | 阈值 | 说明 |
|---|---|---|
| L2 清单达标率 | 100% | 必须 |
| 工具对照一致率 | ≥ 95% | 自动生成 vs 声明式行为一致 |
| AI 调用成功率 | 不下降 | 切换后 ≥ 切换前 |
| 工具描述质量 | 自动生成 ≥ 声明式 | 业务侧主观评分 |

---

## 7. 案例对比：QmsDeviceMainDataController

### 7.1 当前形态（v3 兜底）

```java
// Controller（QMS 现状）
@RestController
@RequestMapping("qmsDeviceMainData")
@Api(tags = "基础数据管理-设备主数据管理")
public class QmsDeviceMainDataController {

    @ApiOperation("分页列表查询")
    @ApiOperationSupport(order = 1, includeParameters = {
        "qmsDeviceMainDataDto.pageNo",
        "qmsDeviceMainDataDto.pageSize",
        "qmsDeviceMainDataDto.qmsDeviceMainData"
    })
    @PostMapping("selectForPage")
    @Authignore("/qmsDeviceMainData/selectForPage")
    public Result<?> queryList(@RequestBody QmsDeviceMainDataDto dto) {
        return qmsDeviceMainDataService.queryList(dto);
    }
}
```

**v3 适配**（IT 部写 YAML）：

```yaml
tool:
  name: qms_listDeviceByFactory
  description: |
    按工厂代码分页查询设备主数据清单。
    必填：factoryCode
    可填：deviceName、pageNo（默认 1）、pageSize（默认 10，最大 100）
  backend:
    method: POST
    url: http://qms-intra/qmsDeviceMainData/selectForPage
  params:
    - { name: factoryCode, type: string, required: true }
    - { name: deviceName,  type: string }
    - { name: pageNo,      type: integer, default: 1 }
    - { name: pageSize,    type: integer, default: 10, maximum: 100 }
  translation:
    request:
      wrap-to: |
        {
          "qmsDeviceMainDataDto": {
            "pageNo": ${pageNo},
            "pageSize": ${pageSize},
            "qmsDeviceMainData": {
              "cFactorycode": ${factoryCode},
              "cDevicename": ${deviceName}
            }
          }
        }
    response:
      unwrap-result: true              # 剥离 Result<?>
  response:
    pick: [id, cDevicecode, cDevicename, cFactorycode, cStatus]
    # 字段重命名走全局规则：cDevicecode → deviceCode 等
  auth:
    row_filter: "cFactorycode IN (${user.allowedFactories})"
    field_mask: [cCreateuser, dCreatetime]
```

**配置量**：约 30 行 YAML

### 7.2 重构后形态（v2 自动发现）

```java
// Controller（重构后）
@RestController
@RequestMapping("/api/v1/devices")
@Tag(name = "设备主数据", description = "设备基础信息管理")
public class DeviceController {

    @GetMapping
    @Operation(
        operationId = "listDevicesByFactory",
        summary = "按工厂分页查询设备清单",
        description = "按工厂代码分页查询设备主数据。支持按设备名模糊匹配、状态过滤。",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @PreAuthorize("hasAuthority('device:read')")
    public PageResult<DeviceVO> listDevices(
        @Parameter(description = "工厂代码", example = "F01", required = true)
        @RequestParam String factoryCode,
        @Parameter(description = "设备名（模糊匹配）")
        @RequestParam(required = false) String deviceName,
        @Parameter(description = "页码")
        @RequestParam(defaultValue = "1") int pageNo,
        @Parameter(description = "每页条数")
        @RequestParam(defaultValue = "10") @Max(100) int pageSize
    ) {
        return deviceService.list(factoryCode, deviceName, pageNo, pageSize);
    }
}
```

**v2 适配**（IT 部只配置暴露范围，不写工具定义）：

```yaml
# Adapter application.yml
mcp:
  adapter:
    namespace: qms
    backend:
      openapi-url: http://qms-intra/v3/api-docs/device
    exposure:
      mode: whitelist
      include:
        - { operationId: listDevicesByFactory }
```

**配置量**：约 10 行（且新增 API 自动同步）

### 7.3 对比小结

| 维度 | 当前（v3 兜底） | 重构后（v2 自动） |
|---|---|---|
| 业务系统改动 | 0 | 1 个 Controller 重写 |
| Adapter 工具配置 | 30 行 YAML | 0 行（自动发现） |
| 工具描述质量 | 依赖 IT 部撰写 | 来自 Controller 注解 |
| 新增 API 上线 | IT 部写 YAML | Adapter 自动同步 |
| API 变更同步 | 改 YAML | 自动 |

---

## 8. 附录

### 8.1 术语

| 术语 | 含义 |
|---|---|
| RESTful | 符合 REST 架构风格的 API 设计 |
| OpenAPI 3 | 业内标准的 REST API 描述格式（前身 Swagger） |
| SpringDoc | Spring Boot 的 OpenAPI 3 文档生成库 |
| operationId | OpenAPI 中每个 API 操作的唯一标识 |
| Problem Details | RFC 7807 定义的 HTTP 错误响应格式 |
| VO | View Object，专门用于响应输出的对象 |
| L1/L2/L3 | Controller 级 / 模块级 / 系统级的达标等级 |

### 8.2 推荐技术栈

| 组件 | 推荐版本 |
|---|---|
| Spring Boot | 3.2.x |
| Java | 17 LTS |
| OpenAPI 文档 | SpringDoc 2.3+ |
| 鉴权 | Spring Security + 集团 SSO（OAuth2 / OIDC） |
| 验证 | Jakarta Bean Validation（`@Valid`、`@NotBlank`、`@Max`） |
| 错误格式 | Problem Details（RFC 7807） |
| 持久化 | MyBatis-Plus 或 JPA |

### 8.3 参考资源

- MCP 协议规范（2025-06-18 Streamable HTTP）
- OpenAPI 3.1 规范
- RFC 7807 Problem Details
- SpringDoc 官方文档
- Spring Security 官方文档

### 8.4 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-07-24 | 首版，定义 AI 友好标准与重构路径 |
| v1.1 | 2026-07-29 | 移除 URL 版本前缀要求（强制升级策略）；新增标准 8（支持动态聚合查询能力）；L1 / L3 检查清单同步更新 |
