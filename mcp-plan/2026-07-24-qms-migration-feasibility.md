# QMS 系统 MCP 接入改造可行性报告

> **文档版本**：v1.0
> **日期**：2026-07-24
> **分析对象**：`D:\project\sunny-qms-service`（sunny-qms-service，舜宇智能开发平台 QMS 模块）
> **关联文档**：`2026-07-24-mcp-adapter-design.md`（v2 方案）
> **目的**：评估 v2 方案对真实老业务系统的适配性，识别差距与风险，提出调整建议

---

## 1. 概览

**结论先行**：

| 维度 | v2 方案假设 | QMS 实际 | 适配度 |
|---|---|---|---|
| 框架 | Spring Boot | Spring Boot（继承 `com.sunny:base-platform` 父 POM） | ✅ 一致 |
| API 文档 | OpenAPI 3（SpringDoc） | **Swagger 2（SpringFox + Knife4j 2.x）** | ❌ 不一致 |
| Controller 风格 | 偏 RESTful，GET 查询 | **几乎全 POST，URL 非 RESTful** | ❌ 差距大 |
| 入参 | 扁平参数 / 简单对象 | **嵌套 DTO + paraMap + 分页混合** | ❌ 差距大 |
| 出参 | 数据直接返回 | **统一 `Result<?>` 包装** | ⚠️ 需剥离 |
| 字段命名 | 默认对 AI 友好 | **c/n/d 前缀规则（cCreateuser、dCreatetime）** | ❌ 极不友好 |
| 鉴权 | 标准注解 | **`@Authignore` 自研权限点** | ⚠️ 需映射 |
| 业务规模 | 中等 | **117 个 controller 目录、100+ 业务模块** | ⚠️ 远超预期 |

**核心判断**：

> **v2 方案的"零编码上线"愿景成立，但 starter 与 tools-override.yml 的能力被严重低估，工作量需要重估。业务系统侧"零代码改动"基本可行，但接入质量高度依赖 tools-override.yml 的微调工作量。**

---

## 2. QMS 项目现状分析

### 2.1 技术栈

| 组件 | 实际 | 备注 |
|---|---|---|
| 父 POM | `com.sunny:base-platform:0.0.1` | 集团自研基座 |
| Spring Boot | starter-web / starter-tomcat / starter-aop / starter-actuator / starter-test | 版本由父 POM 管理（未直接可见，需查私服） |
| 服务发现 | `spring-cloud-starter-alibaba-nacos-discovery` | Nacos |
| RPC | `spring-cloud-starter-openfeign` + `feign-okhttp` | OpenFeign |
| 持久化 | `mybatis-spring-boot-starter` | MyBatis |
| 数据库 | MySQL + PostgreSQL（双数据源） | 同时支持 Oracle（`ojdbc8`） |
| 连接池 | Druid | |
| API 文档 | **`knife4j-spring-boot-starter` + Swagger 2 注解** | SpringFox 2.x 体系 |
| 权限 | `com.sunny:sunny-auth-client:0.0.21-SNAPSHOT` | 自研鉴权 |
| 日志 | `sunny-base-log` | 自研统一日志 |
| 缓存 | `sunny-dynamic-redis` | 自研 Redis 增强 |
| 消息 | `sunny-base-kafka` | Kafka |
| 其他自研 | 导入导出、分页、代码生成、S3、PO、分布式锁、OA 流程、国际化 | 大量集团基础设施 |

### 2.2 Controller 现状（典型样例）

**文件**：`QmsDeviceMainDataController.java`（截选）

```java
@RestController
@RequestMapping("qmsDeviceMainData")
@Api(tags = "基础数据管理-设备主数据管理")
public class QmsDeviceMainDataController {

    @ApiOperation("修改初始化查询")
    @PostMapping("update_init")
    public Result<?> selectOne(@RequestBody QmsDeviceMainDataDto qmsDeviceMainDataDto) { ... }

    @ApiOperation("分页列表查询")
    @ApiOperationSupport(order = 1, includeParameters = {
        "qmsDeviceMainDataDto.pageNo",
        "qmsDeviceMainDataDto.pageSize",
        "qmsDeviceMainDataDto.qmsDeviceMainData"
    })
    @PostMapping("selectForPage")
    @Authignore("/qmsDeviceMainData/selectForPage")
    public Result<?> queryList(@RequestBody QmsDeviceMainDataDto qmsDeviceMainDataDto) { ... }

    @ApiOperation("新增页面保存")
    @PostMapping("insert")
    public Result<?> insert(@RequestBody QmsDeviceMainDataDto qmsDeviceMainDataDto) { ... }
    // update / delete 同样模式
}
```

**特征归纳**：

1. **注解体系**：Swagger 2（`@Api` / `@ApiOperation` / `@ApiModelProperty`）+ Knife4j 增强（`@ApiOperationSupport`）
2. **HTTP 方法**：几乎全 POST（包括查询、删除）
3. **URL 风格**：camelCase + 下划线（`qmsDeviceMainData/selectForPage`），无 RESTful 风格
4. **入参**：单一 `@RequestBody Dto`，Dto 内含实体 + 分页 + paraMap + list 等多类字段
5. **出参**：统一 `Result<?>` 包装
6. **权限点**：`@Authignore("/xxx/yyy")`，URL 路径作为权限标识
7. **无 operationId**：工具名必须由 Adapter 自动生成

### 2.3 DTO 结构（典型样例）

**文件**：`QmsDeviceMainDataDto.java`

```java
@Data
public class QmsDeviceMainDataDto {
    private List<QmsDeviceMainData> qmsDeviceMainDataList;
    private QmsDeviceMainData qmsDeviceMainData = new QmsDeviceMainData();
    @ApiModelProperty(value = "当前页", required=true)
    private Integer pageNo = 1;
    @ApiModelProperty(value = "每页行数", required=true)
    private Integer pageSize = 10;
    private Map<String, String[]> paraMap;       // ← 对 AI 极不友好
    private List<BigDecimal> idList;
}
```

**问题**：
- DTO 同时承载"单条数据"、"批量数据"、"分页参数"、"动态查询条件"四种语义
- AI 看到这种 schema 无法判断该填什么字段
- 团队已用 `@ApiOperationSupport(includeParameters=...)` 做裁剪，但这只影响文档展示，不改变实际入参结构

### 2.4 字段命名规范（来自 CLAUDE.md）

| 前缀 | 含义 | 示例 |
|---|---|---|
| `c` | 字符型字段 | `cCreateuser`、`cSeltype` |
| `n` | 数值型字段 | `nSfExport`、`nVersion` |
| `d` | 日期型字段 | `dCreatetime`、`dUpdatetime` |
| 主键 `id` | 统一 `BigDecimal` 类型 | — |

**对 AI 的影响**：工具返回的字段名几乎全部带 c/n/d 前缀，AI 难以自然理解（如"创建人"返回为 `cCreateuser` 而不是 `creator`）。

### 2.5 业务规模

- **117 个 controller 目录**
- **100+ 业务模块**（按 `src/main/java/com/sunny/modules/` 下目录统计）
- 模块命名前缀：`Qms*`、`bkm`、`common`、`deviceMainData`、`dynamicRule`、`experienceBase`、`inspectionTask`、`spc`、`productionorder`、`qmsVda*`、`qmsSystem*`、`qmsProbfbctrl*`、`qmsQualitydata*` 等
- **多环境**：dev / mcppro / mcptest / pro / prodev / proyn / test（7 套）

> **规模影响**：即使只暴露查询类 API，QMS 一个系统就可能产生 **300-500 个候选工具**。v2 方案设想的"白名单默认 + 全量可切换"必须严格执行白名单。

### 2.6 鉴权机制

- 包：`com.sunny:sunny-auth-client:0.0.21-SNAPSHOT`
- 注解：`@Authignore("/url/path")` 标记权限点
- **未知细节**（待 sunny-auth-client 源码确认）：
  - 鉴权载体（Header 名称、token 格式）
  - 是否基于 JWT
  - 用户身份获取方式（ThreadLocal？Request attribute？）
  - 角色信息是否包含

---

## 3. v2 方案适配性逐项评估

### 3.1 ✅ SpringDoc 集成（不需要）

**v2 假设**：业务系统引入 SpringDoc 暴露 `/v3/api-docs`
**QMS 实际**：已有 Knife4j + SpringFox Swagger 2，自动暴露 `/v2/api-docs`

**结论**：
- **不需要再加 SpringDoc**，避免依赖冲突
- **Adapter 必须支持 Swagger 2 解析**（`swagger-parser` 支持 v2 + v3 双格式）
- v2 方案文档需要修订：把"业务系统接入前置"从"加 SpringDoc"改为"确认已有 Swagger 文档可用（v2 或 v3 均可）"

### 3.2 ❌ Controller 改造（v2 假设成立，但质量打折）

**v2 假设**：业务 Controller 代码完全不改
**QMS 实际**：业务 Controller 代码确实不需要改，但暴露出的工具质量会很差

**工具名生成挑战**：
```
原 URL：POST qmsDeviceMainData/selectForPage
原 @ApiOperation："分页列表查询"
无 operationId
```

可能的工具名生成策略：
- 策略 A（URL 派生）：`qms_qmsDeviceMainData_selectForPage` —— 重复、难看
- 策略 B（中文描述 slugify）：`qms_分页列表查询` —— MCP 工具名不允许中文
- 策略 C（URL + 方法 + hash）：`qms_post_qmsDeviceMainData_selectForPage_1` —— 难看
- 策略 D（推荐）：`{namespace}_{controllerSimple}_{operationSlug}` —— 如 `qms_deviceMainData_listPage`，但需要人工映射

**实际处理**：tools-override.yml 必须为每个要暴露的工具显式指定 `tool_name`，无法做到纯自动。

### 3.3 ❌ DTO 嵌套处理（v2 严重低估）

**v2 假设**：参数扁平传入
**QMS 实际**：参数必须包装成 DTO 嵌套结构

**示例**：`selectForPage` 实际需要 AI 构造：
```json
{
  "qmsDeviceMainDataDto": {
    "pageNo": 1,
    "pageSize": 10,
    "qmsDeviceMainData": { "factoryCode": "F01", "deviceName": "..." }
  }
}
```

**Adapter 必须支持的增强能力**：
1. **DTO 扁平化**：tools-override.yml 声明"把 `qmsDeviceMainDataDto.qmsDeviceMainData.*` 提升到顶层"
2. **自动包装**：AI 传扁平参数，Adapter 自动按 DTO 结构包装
3. **参数白名单**：把 `paraMap`、`idList` 等不友好字段从工具 input_schema 中剔除

### 3.4 ⚠️ Result 包装剥离

**v2 假设**：响应直接是业务数据
**QMS 实际**：统一 `Result<?>` 包装（典型结构 `{ code, msg, data }`）

**Adapter 必须支持**：tools-override.yml 声明响应解包路径，如：
```yaml
response:
  unwrap: "$.data"     # 从 Result.data 取真正业务数据
  pick: [...]
```

### 3.5 ❌ 字段命名映射

**v2 假设**：字段默认对 AI 友好
**QMS 实际**：c/n/d 前缀规则贯穿所有 Entity

**Adapter 必须支持**：tools-override.yml 支持字段重命名规则（可批量）：
```yaml
rename:
  # 单字段
  cCreateuser: creator
  dCreatetime: createTime
  # 规则化（推荐）
  rules:
    - pattern: "^c(.+)$"
      replace: "${1}"
      rename-only-on-output: true
```

### 3.6 ⚠️ 鉴权集成

**v2 假设**：mcp-auth-filter 透传 X-User-Id
**QMS 实际**：已有 sunny-auth-client 鉴权体系

**集成方案**（待 sunny-auth-client 源码确认细节后定）：
- **方案 A（推荐）**：mcp-auth-filter 不替代 sunny-auth-client，仅注入"MCP 服务账号"身份绕过普通用户鉴权，并透传真实用户 ID 到 ThreadLocal 供业务权限框架使用
- **方案 B**：复用 sunny-auth-client 既有机制，mcp-auth-filter 仅做 token 透传

**风险**：sunny-auth-client 是 `0.0.21-SNAPSHOT` 快照版本，接口可能不稳定。

### 3.7 ⚠️ 业务规模

**v2 假设**：单系统工具数 15-30
**QMS 实际**：候选工具 300-500

**应对**：
- **严格白名单**：首阶段只暴露 IT 与业务共同挑选的 10-15 个高价值查询
- **模块分组**：tools-override.yml 支持按业务模块分组（`deviceMainData`、`inspectionTask`、`spc` 等）
- **工具描述必须充分**：每个工具的 description 要写清"该查什么、不该查什么、参数怎么填"，避免 AI 误用

---

## 4. v2 方案文档需要修订的内容

基于以上分析，建议 v2 文档（`2026-07-24-mcp-adapter-design.md`）做以下修订：

### 4.1 第 4.1 节"自动发现：OpenAPI 拉取"

**原文**：业务系统集成 SpringDoc 暴露 `/v3/api-docs`
**修订**：
- Adapter 同时支持 Swagger 2（`/v2/api-docs`）与 OpenAPI 3（`/v3/api-docs`）
- 业务系统已集成 Knife4j/SpringDoc/SpringFox 任一即可，无需新增依赖
- application.yml 增加 `openapi-version: auto | v2 | v3` 配置

### 4.2 第 4.2 节"工具生成"映射规则

**新增规则**：
- 优先使用 `@ApiOperation` 的中文描述作为工具描述
- 工具名生成策略：`{namespace}_{controllerPathSegment}_{methodDescriptionSlug}`，并允许 tools-override.yml 显式指定
- 自动剥离 `Result<?>` 包装（通过反射或配置）

### 4.3 第 4.3 节"配置覆盖"YAML 能力扩展

新增能力：

```yaml
overrides:
  - tool_name: qms_deviceMainData_listPage
    source:                                      # 自动发现的源
      method: POST
      path: /qmsDeviceMainData/selectForPage
    description: |                               # 覆盖描述
      分页查询设备主数据。必填：pageNo、pageSize。
      可填：qmsDeviceMainData.factoryCode（工厂代码）、deviceName（设备名，模糊匹配）。
    
    # DTO 扁平化：声明实际期望的扁平参数
    params:
      flatten:                                   
        from: qmsDeviceMainDataDto.qmsDeviceMainData
        to: root
      pick: [pageNo, pageSize, factoryCode, deviceName]
      rename:
        factoryCode: factory
        deviceName: name
    
    # 响应解包与字段映射
    response:
      unwrap: "$.data"                            # 剥离 Result 包装
      pick: [id, cDevicecode, cDevicename, cFactory]
      rename:
        cDevicecode: deviceCode
        cDevicename: deviceName
        cFactory: factoryCode
    
    # 数据补控
    auth:
      field_mask: [cCreateuser]                   # 创建人不返回给 AI
      row_filter: "cFactory in ${user.allowedFactories}"
    
    # 启用
    enabled: true
    group: deviceMasterData
```

**新增 YAML 全局规则**（减少重复配置）：

```yaml
global:
  rename-rules:
    - { pattern: "^c(.+)$", replace: "${1}", apply: output-only }
    - { pattern: "^n(.+)$", replace: "${1}", apply: output-only }
    - { pattern: "^d(.+)$", replace: "${1}", apply: output-only }
  response-unwrap: "$.data"                      # 全局 Result 解包
```

### 4.4 第 5 节"业务系统侧前置条件"

**修订**：
- 业务系统前置：**已有 Swagger 文档（v2 或 v3）可用**（QMS 已满足）
- 引入 `mcp-auth-filter`，与现有鉴权体系（如 sunny-auth-client）协作而非替代
- **不需要新增 SpringDoc 依赖**（避免与现有 SpringFox 冲突）

### 4.5 第 10 节"实施路线图"

**工作量重估**：

| 阶段 | v2 原估 | QMS 实际重估 | 差异原因 |
|---|---|---|---|
| 阶段 1 starter 骨架 + 自动发现 | 4 周 | **6-8 周** | 需支持 Swagger 2、DTO 扁平化、Result 解包、字段重命名规则 |
| 阶段 2 QMS 落地 | 6 周 | **8-10 周** | 每个工具都要写 tools-override；QMS 业务复杂度高 |
| 阶段 3 加固 + 横向铺开 | 8 周 | **12+ 周** | QMS 单系统 100+ 模块，无法一次铺完，需要分批 |
| **小计** | 18 周 | **26-30 周** | **+50% 工作量** |

**首阶段范围建议（强烈建议缩小）**：
- **POC 范围**：从 QMS 中挑 **1-2 个 Controller 模块**（建议 `deviceMainData` + `inspectionTask`）
- **POC 工具数**：8-12 个（而非原计划的 10-15 个 / 全 QMS）
- **POC 验证点**：starter 能力（Swagger 2 解析、DTO 扁平化、Result 解包、字段重命名、鉴权集成）
- **POC 通过后再扩展到 QMS 其他模块**

---

## 5. 关键风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| starter 能力不足（Swagger 2 解析、DTO 扁平化） | 高 | 高 | POC 阶段先验证 starter 能力，再扩展 |
| sunny-auth-client 集成方式不明确 | 高 | 高 | 与 sunny 平台团队对齐，获取源码与文档 |
| 字段重命名规则误伤（如 `cName` 实际就是字段名而非字符型）| 中 | 中 | rename-rules 支持白名单排除；逐工具验证 |
| QMS 模块过多，白名单维护成本爆炸 | 高 | 中 | 按业务域分批接入；每批 1-2 个模块 |
| 业务 API 用 POST 接收复杂 DTO，AI 调用失败率高 | 高 | 高 | tools-override 显式声明扁平参数；工具描述详尽；增加 POC 测试集 |
| 工具描述对 AI 不够清晰，AI 误用 | 中 | 高 | 接入前由业务部门审核工具描述；上线后根据审计日志优化 |
| 117 个 controller 全量接入后工具爆炸（即使白名单） | 中 | 中 | starter 支持"工具分组 + 按需加载"（如 tools/list?group=xxx） |
| 字段包含敏感质量数据（不合格率、客户投诉） | 高 | 高 | 严格 `field_mask` + 角色授权 + 合规部门确认 |
| 父 POM `base-platform:0.0.1` 版本管理不透明 | 中 | 中 | 与平台组确认依赖版本；如必要显式锁定关键库版本 |
| SNAPSHOT 依赖（sunny-auth-client、sunny-base-*）不稳定 | 中 | 中 | 在 Adapter 侧锁定稳定版本；订阅平台组发布通知 |

---

## 6. 改造可行性结论

### 6.1 业务系统侧（v2 假设基本成立）

- ✅ **不需要改业务代码**
- ✅ **不需要新增 SpringDoc 依赖**（已有 Swagger 2）
- ⚠️ 引入 `mcp-auth-filter`（一个 Maven 依赖 + 一行 filter 配置）
- ⚠️ 少量 Controller 可能需要补 `@ApiOperation` 描述（CLAUDE.md 已要求，应该都有）

**业务侧改动量：0 行业务代码 + 1 个 Maven 依赖 + 1 行 filter 配置**

### 6.2 Adapter starter 侧（v2 严重低估）

需要新增的核心能力：
1. Swagger 2 解析（已有 swagger-parser 工具，工作量可控）
2. DTO 扁平化与自动包装
3. Result 包装剥离
4. 字段重命名规则（含全局规则）
5. 工具名智能生成 + 显式覆盖
6. 鉴权集成适配 sunny-auth-client

**starter 开发工作量：v2 原 4 周 → 实际 6-8 周**

### 6.3 接入运营侧（v2 严重低估）

每个工具的接入都需要写一份 tools-override.yml，包括：
- 显式工具名（避免自动生成的丑陋名字）
- 详尽描述（让 AI 知道何时用、参数怎么填）
- DTO 扁平化配置
- 字段重命名
- 数据脱敏

**QMS 全量接入工作量：v2 原 6 周 → 实际 8-10 周（仅 QMS）**

### 6.4 最终建议

1. **修订 v2 方案文档**，纳入本报告识别的能力扩展（Swagger 2 支持、DTO 扁平化、Result 解包、字段重命名规则、鉴权适配）
2. **缩小首阶段 POC 范围**：1-2 个 Controller 模块、8-12 个工具
3. **POC 阶段优先验证 starter 能力**，再扩展业务覆盖
4. **与 sunny 平台团队对齐**：获取 sunny-auth-client 文档、base-platform 版本规划、Maven 私服上传权限
5. **重估工期**：总工期从 18 周调整为 26-30 周；首阶段 POC 控制在 8 周内

---

## 7. 待业务/平台团队澄清的问题

1. **sunny-auth-client 鉴权细节**：token 载体（Header 名）、用户身份获取方式（ThreadLocal API）、角色信息获取、是否有"服务账号"概念
2. **base-platform 父 POM**：Spring Boot 版本、Spring Cloud 版本、Knife4j 版本（推断为 2.x 但需确认）
3. **Knife4j 版本确认**：是 2.x（Swagger 2）还是 4.x（兼容 OpenAPI 3）
4. **`@Authignore` 语义**：是"忽略鉴权"还是"标记权限点"？名称有歧义，需确认
5. **业务规模确认**：实际 Controller 数量？哪些模块是高优先级查询场景（适合 POC）？
6. **字段前缀规则例外**：是否有不以 c/n/d 开头的字段？rename-rules 需要例外清单吗？
7. **`Result<?>` 结构**：标准字段（code/msg/data）？错误码清单？是否有 i18n？
8. **多数据源**：MySQL + PostgreSQL + Oracle，查询会跨库吗？影响 row_filter 实现
9. **集团 Maven 私服**：IT 部能否上传 `mcp-*` 共享库？申请流程？
10. **环境策略**：dev / mcppro / mcptest / pro / prodev / proyn / test 7 套环境，POC 用哪套？mcppro/mcptest 看起来专为 MCP 准备？

---

## 8. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-07-24 | 首版，基于 QMS 代码分析生成 |
