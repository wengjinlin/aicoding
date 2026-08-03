# 集团 MCP Adapter 服务规划设计（v3）

> **文档版本**：v3.1
> **日期**：2026-07-29（v3.1）/ 2026-07-24（v3.0）
> **作者**：集团 IT 部
> **状态**：设计评审中
> **变更说明**：本版针对真实老业务系统现状（以 sunny-qms-service 为参照）调整 v2 设计。**核心转变：放弃"业务 API 自动发现"幻想，改为"IT 部显式声明工具 + Adapter 内置智能翻译层"**。目标不变：业务系统零代码改动 + MCP 可用。v2 文档（自动发现模式）保留作为未来业务系统重构达标后的目标形态。

---

## 1. 背景与目标

### 1.1 业务背景

集团是制造业集团公司，自研多个生产相关业务系统（MES / WMS / QMS / EMS / 设备管理等），技术栈 Java + SpringMVC。集团希望通过 MCP 协议让 AI 助手访问自研系统数据与能力。

### 1.2 三版演进

| 版本 | 日期 | 核心 | 状态 |
|---|---|---|---|
| v1 | 2026-07-22 | Gateway + Adapter 两层 | 已被 v2 替代（去 Gateway） |
| v2 | 2026-07-24 | Adapter-only + 业务 API 自动发现 | 理想态，依赖业务 API 治理 |
| **v3** | **2026-07-24** | **Adapter-only + IT 显式声明 + 智能翻译层** | **当前方案，适配老系统现状** |

### 1.3 为什么从 v2 转向 v3

v2 假设业务系统 API 治理良好（OpenAPI 3、RESTful、字段对 AI 友好）。但以 sunny-qms-service 为例的真实老系统：

| 维度 | v2 假设 | QMS 实际 |
|---|---|---|
| API 文档 | OpenAPI 3 | Swagger 2 + Knife4j（注解不规范） |
| HTTP 方法 | RESTful | 几乎全 POST |
| URL | 资源化 | camelCase + 下划线（如 `selectForPage`） |
| 入参 | 扁平 | 嵌套 DTO + `Map<String,String[]>` paraMap |
| 出参 | 直接返回 | 统一 `Result<?>` 包装 |
| 字段 | 默认友好 | c/n/d 前缀规则（cCreateuser / dCreatetime） |
| 业务规模 | 中等 | 117 controller 目录、100+ 模块 |

如果硬走 v2 自动发现，每个工具的 `tools-override.yml` 配置量会爆炸，反而比手写代码还累。v3 转变思路：**接受业务 API 现状，IP 转移到 Adapter 的智能翻译层**。

### 1.4 核心目标

1. **业务系统零代码改动**（仅引入 `mcp-auth-filter` 一个 Maven 依赖 + 一行 filter 配置）
2. **MCP 可用**（AI 平台能调通 QMS / MES / WMS / EMS 等业务能力）
3. **声明式工具**（IT 部用 YAML 显式声明，治理完全可控）
4. **智能翻译降低工作量**（声明一个新工具平均 10-20 行 YAML，而非 100+ 行）
5. **为未来留路径**（业务系统重构达标后可平滑切换到 v2 自动发现模式）

### 1.5 非目标（YAGNI）

- 不自建 Gateway / Router / BFF
- 不做跨系统工具聚合
- 不改业务系统代码
- 不引入 MCP `resources/*` / `prompts/*` / `notifications/*`
- 不实现 SSE 流（AI 平台只支持 HTTP，保持纯 JSON 模式）
- 不依赖业务系统 API 文档质量（关键转变）

---

## 2. 关键决策汇总

| 决策项 | 选择 | 理由 |
|---|---|---|
| 架构形态 | 每子系统一个 Adapter，直接暴露 MCP Server | 去 Gateway、职责纯粹、故障域隔离 |
| 协议 | MCP Streamable HTTP（纯 JSON 模式） | 兼容自研 AI 平台仅支持 HTTP |
| 实现语言 | Java + Spring Boot 3.2 + Java 17 | 团队同栈 |
| **工具来源** | **IT 部用 YAML 显式声明**（不自动发现） | 业务 API 质量不可靠，治理在 IT 部 |
| **核心 IP** | **智能翻译层**（Result 解包 + 字段重命名 + DTO 包装） | 让声明式工具工作量可控 |
| 字段重命名规则 | 内置默认（c/n/d 前缀）+ YAML 可覆盖 + 白名单 | 开箱即用 + 灵活 |
| Result 解包 | 内置默认（`$.data`）+ 可配置路径 | 适配 sunny `Result<?>` 包装 |
| DTO 包装 | YAML 声明 `wrap-to` 模板，Adapter 自动构造 | AI 传扁平参数，业务 API 收嵌套 |
| 业务系统改动 | **仅 mcp-auth-filter**（不需要 SpringDoc、不需要改 Controller） | 业务零侵入 |
| 治理位置 | 下沉到 Adapter，starter 内置 | 没有 Gateway，必须下沉 |
| 工具授权 | 每 Adapter 本地 `mcp_tool_grant` 表 | 数据本地化 |
| 审计 | 每 Adapter 本地 `mcp_audit_log` 表，统一 schema | 便于汇总分析 |
| 可视化工具编辑器 | 阶段 3 交付 | 先验证核心，再做运营工具 |
| 首个 Adapter | QMS | 查询场景丰富、管理者刚需、有现成代码可参照 |
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
│ • 声明式工具加载     │   │ • 声明式工具加载     │   │         │
│ • 智能翻译层（核心） │   │ • 智能翻译层         │   │         │
│ • 治理（授权/审计/限流）│   │ • 治理              │   │         │
│ • 数据补控（脱敏/筛选）│   │ • 数据补控           │   │         │
└──────────┬───────────┘   └──────────┬───────────┘   └────┬────┘
           │                          │                    │
           │ HTTP 调业务 API          │ HTTP 调业务 API    │
           ▼                          ▼                    ▼
┌──────────────────────┐   ┌──────────────────────┐   ┌─────────┐
│ QMS 业务系统          │   │ MES 业务系统          │   │ ...     │
│ • 原样保留            │   │ • 原样保留            │   │         │
│ • 仅引入              │   │ • 仅引入              │   │         │
│   mcp-auth-filter     │   │   mcp-auth-filter     │   │         │
└──────────────────────┘   └──────────────────────┘   └─────────┘
```

### 3.2 职责边界

| 层 | 做什么 | 不做什么 |
|---|---|---|
| AI 平台 | 接入多个 MCP Server | 不做协议转换、工具聚合 |
| Adapter | MCP 协议 + 声明式工具加载 + 智能翻译 + 治理 + 数据补控 + 调业务 API | 不做跨系统聚合；不依赖业务 API 文档质量 |
| 业务系统 | 业务逻辑原样运行 + 引入 `mcp-auth-filter` | 不改业务代码 |

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
│  │ 声明式工具加载器（starter 提供）                   │   │
│  │  • 启动时加载 tools/*.yml                         │   │
│  │  • 校验工具定义合法性                              │   │
│  │  • 内存工具表（Caffeine 缓存）                    │   │
│  └──────────────────────────────────────────────────┘   │
│                       ↓                                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 智能翻译层（starter 核心_IP）                      │   │
│  │  • 请求翻译：扁平参数 → DTO 嵌套包装               │   │
│  │  • 响应翻译：Result 解包 + 字段重命名              │   │
│  │  • 字段映射规则引擎（c/n/d 前缀 → 语义化）         │   │
│  └──────────────────────────────────────────────────┘   │
│                       ↓                                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 调用执行器（starter 提供）                         │   │
│  │  • 按 backend 定义发 HTTP 请求                    │   │
│  │  • 响应裁剪/脱敏（按 YAML 配置）                   │   │
│  │  • 行级权限筛选                                    │   │
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

### 3.4 业务开发新 Adapter 时的最小步骤

1. Maven 引入 `mcp-adapter-starter`
2. 写 `application.yml`（配置业务系统 URL、DB 连接）
3. 写 `tools/*.yml`（每个工具一份，IT 部主导）
4. `@EnableMcpAdapter` 启动

**不需要写任何 Java 代码**（除非是复杂聚合工具，用 `@McpTool` 注解逃生通道）。

---

## 4. 声明式工具模型

### 4.1 工具 YAML 完整 Schema

```yaml
# tools/query-device-by-factory.yml
tool:
  # ===== 元数据 =====
  name: qms_listDeviceByFactory              # 必填，工具名（含命名空间前缀）
  group: deviceMasterData                    # 可选，工具分组
  tags: [device, factory, query]             # 可选，标签
  description: |                             # 必填，给 AI 看的工具说明
    按工厂代码分页查询设备主数据清单。
    必填：factoryCode（工厂代码，如 F01）
    可填：deviceName（设备名，模糊匹配）、pageNo（默认 1）、pageSize（默认 10，最大 100）
    返回：设备列表，含设备代码、名称、所属工厂、状态
  
  # ===== 后端调用 =====
  backend:
    method: POST                              # 业务 API 方法
    url: http://qms-intra/qmsDeviceMainData/selectForPage
    auth:
      type: service-account
      token: ${QMS_SERVICE_TOKEN}             # 服务账号 token
    timeout_ms: 8000
  
  # ===== AI 看到的扁平参数 =====
  params:
    - name: factoryCode
      type: string
      required: true
      description: 工厂代码（如 F01、F02）
    - name: deviceName
      type: string
      required: false
      description: 设备名（模糊匹配）
    - name: pageNo
      type: integer
      required: false
      default: 1
    - name: pageSize
      type: integer
      required: false
      default: 10
      maximum: 100
  
  # ===== 智能翻译 =====
  translation:
    # 请求翻译：把 AI 扁平参数包装为业务 API 期望的嵌套结构
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
    
    # 响应翻译：默认走全局配置，这里可覆盖
    response:
      unwrap-result: true                     # 自动剥离 Result<?> 包装（默认 true）
      # result-data-path: $.data             # 默认 $.data，可覆盖
  
  # ===== 响应字段处理 =====
  response:
    pick: [id, cDevicecode, cDevicename, cFactorycode, cStatus]
    rename:
      cDevicecode: deviceCode                 # 单字段覆盖（默认规则已处理则不必写）
      cDevicename: deviceName
      cFactorycode: factoryCode
      cStatus: status
  
  # ===== 数据补控 =====
  auth:
    row_filter: "cFactorycode IN (${user.allowedFactories})"
    field_mask: [cCreateuser, dCreatetime]    # 创建人/时间不返回给 AI
  
  # ===== 工具开关 =====
  enabled: true
  timeout_ms: 8000                            # 调用超时
```

### 4.2 字段说明

| 字段 | 必填 | 说明 |
|---|---|---|
| `tool.name` | 是 | 工具名，格式 `{namespace}_{verb}{Object}`，如 `qms_listDeviceByFactory` |
| `tool.description` | 是 | 给 AI 的工具说明，应包含"何时用、参数语义、返回内容"。**质量直接决定 AI 调用准确率** |
| `tool.group` | 否 | 工具分组（如 `deviceMasterData`、`inspectionTask`），便于 tools/list 过滤 |
| `tool.tags` | 否 | 自由标签 |
| `backend.*` | 是 | 业务 API 调用配置 |
| `params` | 是 | AI 看到的扁平参数列表（JSON Schema 风格） |
| `translation.request.wrap-to` | 视情况 | 若业务 API 入参是嵌套 DTO，必须配置；扁平 API 可省略 |
| `translation.response.unwrap-result` | 否 | 默认 true，自动剥离 `Result<?>` |
| `response.pick` / `rename` | 否 | 字段裁剪与重命名 |
| `auth.row_filter` / `field_mask` | 否 | 行级权限与字段脱敏 |
| `enabled` | 否 | 默认 true |

### 4.3 工具命名规范

```
{namespace}_{verb}{Object}

namespace: qms / mes / wms / ems
verb:      list / get / query / search / count / stat / export
Object:    Device / Inspection / Batch / Order / Defect

例：
  qms_listDeviceByFactory       ✓ 好
  qms_queryInspectionById       ✓ 好
  qms_getInspection_001         ✗ 避免数字后缀
  qms_selectForPage             ✗ 业务 API 名直译，AI 难理解
```

### 4.4 工具描述质量要求

工具描述是 AI 调用准确率的**决定性因素**。建议模板：

```
{一句话功能说明}

何时用：{适用场景，1-2 句}
何时不用：{不适用场景，1-2 句}

参数：
  - {param1}（必填）：{含义 + 格式 + 示例}
  - {param2}（可选）：{含义 + 默认值 + 示例}

返回：
  {返回内容描述 + 关键字段说明 + 数据范围}
```

**示例**：

```yaml
description: |
  按检验单号查询 QMS 检验单详情，含检验项目、结果、检验员信息。
  
  何时用：用户想知道某张具体检验单的状态、结果、是谁检的、何时检的
  何时不用：用户要"列出/统计/搜索"检验单（用 qms_listInspections 或 qms_statInspectionRate）
  
  参数：
    - inspectionId（必填）：检验单号，格式 INS + 8 位日期 + 3 位流水（如 INS20260724001）
  
  返回：
    检验单详情，含基础信息、检验项目列表、单项结果、最终判定、检验员姓名、检验时间
```

---

## 5. 智能翻译层（核心 IP）

### 5.1 三大支柱概览

| 支柱 | 默认行为 | 配置位置 |
|---|---|---|
| **Result 自动解包** | 检测 `{ code, msg, data }` 结构，取 `$.data` | 全局 / 工具级 |
| **字段重命名规则引擎** | c/n/d 前缀自动语义化 | 全局 / 工具级 / 白名单 |
| **DTO 嵌套自动包装** | 按 `wrap-to` 模板构造请求体 | 工具级（必填） |

### 5.2 支柱 1：Result 自动解包

#### 5.2.1 工作原理

Adapter 收到业务 API 响应后：

```
1. 解析 JSON
2. 检测是否为标准 Result 结构：
   - 包含 code / msg / data 三个字段
   - 是 → 进入步骤 3
   - 否 → 跳过解包，直接走字段处理
3. 检查 code：
   - 成功码（默认 200、0、"success"）→ 取 data 字段
   - 失败码 → 抛出错误给 AI，msg 作为错误信息
4. data 即业务数据，继续字段重命名与裁剪
```

#### 5.2.2 默认配置（全局）

```yaml
# application.yml
mcp:
  adapter:
    translation:
      response:
        unwrap-result: true                # 默认 true
        result-data-path: "$.data"
        result-code-path: "$.code"
        result-msg-path: "$.msg"
        result-success-codes: [200, 0, "200", "0", "success", "SUCCESS"]
```

#### 5.2.3 工具级覆盖

```yaml
# 某工具的 YAML
translation:
  response:
    unwrap-result: false                   # 该工具响应不是 Result 结构
    # 或自定义路径：
    # result-data-path: "$.payload"
```

#### 5.2.4 边界处理

| 场景 | 处理 |
|---|---|
| 响应不是 Result 结构 | 跳过解包 |
| Result code 为失败 | 抛错，msg 返给 AI |
| 嵌套 Result（罕见） | 仅解外层 |
| Result.data 是 null/空 | 返空数据，不报错 |
| HTTP 状态码非 2xx | 直接抛错（不走 Result 解包） |

### 5.3 支柱 2：字段重命名规则引擎

#### 5.3.1 默认规则（适配 sunny 平台 c/n/d 前缀）

```
全局默认规则：
  ^c([A-Z].+)$  →  ${1}     首字母小写    例：cCreateuser → createUser
  ^n([A-Z].+)$  →  ${1}     首字母小写    例：nVersion    → version
  ^d([A-Z].+)$  →  ${1}     首字母小写    例：dCreatetime → createTime
```

**应用范围**：默认仅对**响应出参**应用（不动业务 API 入参，避免破坏请求构造）。

#### 5.3.2 全局配置

```yaml
# application.yml
mcp:
  adapter:
    translation:
      fields:
        rename-rules:
          - { pattern: "^c([A-Z].+)$", replace: "${1}", lower-first: true }
          - { pattern: "^n([A-Z].+)$", replace: "${1}", lower-first: true }
          - { pattern: "^d([A-Z].+)$", replace: "${1}", lower-first: true }
        exceptions:                          # 白名单，不重命名
          - cName                            # 字段本身就是 cName（如配置项名称）
          - nCount                           # 字段本身就是 nCount
        apply-to: output                     # output | input | both
```

#### 5.3.3 工具级覆盖

```yaml
# 工具 YAML
translation:
  fields:
    rename-rules: [...]                      # 覆盖全局规则
    # 或追加：
    extra-rules:
      - { pattern: "^c(.+)$", replace: "char_${1}" }
    extra-exceptions:
      - cCustom
```

#### 5.3.4 边界处理

| 场景 | 处理 |
|---|---|
| 字段名本身就是 cName（c 是单词首字母） | 加入 `exceptions` 白名单 |
| 字段是 List/Map 容器 | 递归应用规则到容器内元素 |
| 字段经过 `response.rename` 显式映射 | 显式映射优先（不应用规则） |
| 字段名不符合任何规则 | 保持原名 |

#### 5.3.5 重命名日志

为便于调试，Adapter 启动时打印所有工具的字段重命名映射表：

```
[Tool: qms_listDeviceByFactory] field rename mapping:
  cDevicecode  → deviceCode
  cDevicename  → deviceName
  cFactorycode → factoryCode
  cCreateuser  → createUser        (规则: c-prefix)
  dCreatetime  → createTime        (规则: d-prefix)
```

### 5.4 支柱 3：DTO 嵌套自动包装

#### 5.4.1 问题背景

业务 API 实际入参（QMS 真实样例）：

```json
{
  "qmsDeviceMainDataDto": {
    "pageNo": 1,
    "pageSize": 10,
    "qmsDeviceMainData": {
      "cFactorycode": "F01",
      "cDevicename": "注射机"
    }
  }
}
```

AI 无法可靠地构造这种嵌套结构（命名混乱、嵌套深、字段语义不清）。

#### 5.4.2 解决方案：AI 传扁平，Adapter 包装

工具 YAML 声明 `wrap-to` 模板（带变量占位符）：

```yaml
params:
  - { name: factoryCode, type: string, required: true }
  - { name: deviceName,  type: string }
  - { name: pageNo,      type: integer, default: 1 }
  - { name: pageSize,    type: integer, default: 10 }

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
```

Adapter 工作流：

```
1. AI 传扁平参数：{ factoryCode: "F01", deviceName: "注射机", pageNo: 1, pageSize: 10 }
2. Adapter 校验参数（必填、类型、范围）
3. 用 wrap-to 模板做字符串替换，生成最终请求体 JSON
4. POST 到业务 API
5. 响应走 Result 解包 + 字段重命名
```

#### 5.4.3 `wrap-to` 模板语法

- `${paramName}`：变量替换（必填参数缺失则报错）
- `${paramName:default}`：带默认值
- `${paramName??null}`：可选，未传则替换为 null（字段从请求中保留键）
- 支持 JSON 字面量（数字、字符串、布尔、null）

#### 5.4.4 边界处理

| 场景 | 处理 |
|---|---|
| AI 未传可选参数 | 该变量替换为 null 或省略键（按 `??null` 语法决定） |
| AI 传了未声明的参数 | 忽略（不进 wrap-to） |
| 必填参数缺失 | 校验失败，返 4xx 给 AI |
| 业务 API 入参就是扁平（不嵌套） | `wrap-to` 可省略，Adapter 直接序列化参数为 JSON |

---

## 6. 共享库设计

三组 Maven 库发布到集团 Maven 私服。

### 6.1 `mcp-common`

```
共享 DTO、UserContext、常量、错误码
约 5-10 个类，稳定后极少改动
```

### 6.2 `mcp-auth-filter`

```
业务系统引入的鉴权 filter
识别 X-MCP-Service-Token、透传 X-User-Id 到 ThreadLocal
约 3-5 个类
```

**与 sunny-auth-client 的协作方式**（待 sunny-auth-client 源码确认后细化）：

- 不替代 sunny-auth-client
- 仅识别"MCP 服务账号"身份，放行 MCP 调用
- 把真实用户身份（X-User-Id / X-User-Roles / X-User-Dept）注入 ThreadLocal，供业务权限框架使用
- 业务系统原有 sunny-auth-client 鉴权流程不变

### 6.3 `mcp-adapter-starter`（核心 IP）

```
mcp-adapter-starter/
├── autoconfigure/
│   ├── McpServerAutoConfiguration          ← MCP 协议端点
│   ├── ToolLoaderAutoConfiguration         ← 声明式工具加载
│   ├── TranslationEngineAutoConfiguration  ← 智能翻译层（核心）
│   ├── FieldRenamerAutoConfiguration       ← 字段重命名规则引擎
│   ├── ResultUnwrapperAutoConfiguration    ← Result 自动解包
│   ├── DtoWrapperAutoConfiguration         ← DTO 嵌套包装
│   ├── GovernanceAutoConfiguration         ← 授权、审计、限流
│   └── DataCompensationAutoConfiguration   ← 字段裁剪、脱敏
├── core/
│   ├── ToolLoader                          ← 启动时加载 tools/*.yml
│   ├── ToolInvoker                         ← 按 backend 定义发 HTTP
│   ├── TranslationEngine                   ← 翻译层总调度
│   ├── FieldRenamer                        ← 字段重命名引擎
│   ├── ResultUnwrapper                     ← Result 解包
│   ├── DtoWrapper                          ← DTO 包装
│   └── FieldMasker                         ← 字段脱敏
├── annotation/
│   ├── @EnableMcpAdapter                   ← 启动开关
│   └── @McpTool                            ← 逃生通道：手写复杂工具
└── resources/
    ├── default-translation.yml             ← 默认翻译规则
    └── default-result-success-codes.yml    ← 默认成功码列表
```

---

## 7. 工具生命周期

### 7.1 工具生命周期阶段

```
设计 → 评审 → 上线 → 变更 → 下线

1. 设计：IT 部（联合业务侧）撰写 tools/*.yml
2. 评审：YAML 校验、字段映射 review、安全 review（脱敏、行级权限）
3. 上线：随 Adapter 发版生效；或运行时热加载（阶段 3 支持）
4. 变更：改 YAML → Adapter 发版（或热加载）
5. 下线：enabled: false 或删除 YAML
```

### 7.2 工具评审清单

```
□ 工具名符合命名规范（{namespace}_{verb}{Object}）
□ 工具描述充分（何时用/何时不用/参数语义/返回内容）
□ 必填参数标注清晰、含格式说明
□ backend.url 已联调通过
□ translation.request.wrap-to 模板正确
□ translation.response 配置正确（是否解包 Result）
□ response.pick 不包含敏感字段
□ response.rename 字段对 AI 友好
□ auth.field_mask 覆盖所有 PII（手机号/邮箱/身份证/客户信息）
□ auth.row_filter 与业务部门确认数据范围
□ 工具授权角色已配置
□ 集成测试通过、契约测试通过
```

### 7.3 工具变更管理

| 变更类型 | 处理 |
|---|---|
| 工具描述优化 | 改 YAML → Adapter 发版 |
| 增加新参数 | 改 YAML（含 `wrap-to`）→ Adapter 发版 |
| 业务 API 入参变化 | 改 `wrap-to` 与 `params` → Adapter 发版 |
| 业务 API 路径变化 | 改 `backend.url` → Adapter 发版 |
| 工具下线 | `enabled: false`（保留 YAML 便于恢复）或删除文件 |

**热加载**（阶段 3 支持）：Adapter 监听 `tools/` 目录变化，文件保存即生效，无需重启。

---

## 8. 可视化工具编辑器（阶段 3 交付）

### 8.1 目标

让 IT 部或业务侧"工具设计师"角色通过 Web UI 创建/维护工具，不写 YAML。

### 8.2 核心功能

| 功能 | 说明 |
|---|---|
| 工具新建/编辑表单 | 字段映射到 YAML schema，可视化录入 |
| 业务 API 联调 | 输入测试参数，实时看 wrap-to 构造的请求与响应翻译结果 |
| 字段映射可视化 | 拖拽连接 AI 参数 ↔ 业务 API 字段 |
| 工具版本管理 | 保存历史版本，支持回滚 |
| 工具评审流程 | 工具设计师提交 → 评审者审核 → 上线 |
| 工具市场 | 已上线的工具按业务域分组展示 |

### 8.3 后端实现

- 复用 `mcp-adapter-starter` 的工具加载与翻译引擎
- 新增 `mcp-tool-designer` 模块（独立 Spring Boot 服务，集中部署）
- 工具定义仍以 YAML 形式存储（Git 仓库或数据库）
- 多 Adapter 共享同一编辑器

---

## 9. 安全与权限模型

### 9.1 身份链路

```
[员工] → [AI 平台登录签 JWT] → [Adapter]
                                  │
                                  ├─ MCP filter 验签 JWT，提取 user ctx
                                  ├─ 查 mcp_tool_grant 表
                                  │   ├─ deny 或无记录 → 403
                                  │   └─ allow → 继续
                                  ├─ 调用业务 API 时 Header 透传：
                                  │   X-User-Id / X-User-Roles / X-User-Dept
                                  │   X-MCP-Service-Token / X-Trace-Id
                                  ▼
                              [业务系统 mcp-auth-filter]
                                  │
                                  └─ 识别服务账号 + 把 X-User-Id 放 ThreadLocal
                                     供 sunny-auth-client 使用
```

### 9.2 数据库表（每个 Adapter 本地维护）

**`mcp_tool_grant`**（工具授权表）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT PK | |
| user_id | VARCHAR | 员工 ID（与 role_id 二选一） |
| role_id | VARCHAR | 角色 ID |
| tool_name | VARCHAR | 工具名（含命名空间） |
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
| called_at | DATETIME | |

> 工具元数据不需要表（在 `tools/*.yml` 文件中，启动时加载到内存）。

### 9.3 授权策略

- 默认拒绝；deny 优先；角色批量授权；临时授权
- 每 Adapter 自带轻量授权管理页面（starter 提供）

### 9.4 脱敏策略

| 字段类型 | 策略 |
|---|---|
| 手机号/邮箱/身份证 | Adapter 输出前脱敏（前 3 后 4） |
| 客户信息/成本/金额 | YAML `field_mask` 默认不返回 |
| 备注/自由文本 | 长度截断（500 字） |
| 大结果集 | 分页强制（单次最多 100 条） |
| 审计参数 | 只存 hash |

### 9.5 安全基线

| 链路 | 措施 |
|---|---|
| AI 平台 ↔ Adapter | HTTPS + JWT 验签 |
| Adapter ↔ 业务系统 | HTTPS + 服务账号 token |
| Adapter ↔ DB | 内网 + 最小权限账号 |
| 敏感操作（未来开放写） | YAML 标 `require_approval: true` |

---

## 10. 技术选型

### 10.1 技术栈

| 组件 | 选型 | 备注 |
|---|---|---|
| 框架 | Spring Boot 3.2.x | Java 17 LTS |
| MCP SDK | `io.modelcontextprotocol.sdk:mcp` | Adapter 直接依赖 |
| HTTP 客户端 | OkHttp 4 / Spring WebClient | 调业务 API |
| YAML 解析 | SnakeYAML | 工具定义解析 |
| 模板引擎 | 自研轻量（基于字符串占位符）或 FreeMarker | `wrap-to` 模板 |
| JSON Path | Jayway JsonPath | Result 解包路径 |
| 数据库 | MySQL 8.x | 复用集团现有 |
| 缓存 | Caffeine 本地 | 工具元数据、授权决策 |
| 限流熔断 | Resilience4j | starter 内置 |
| 可观测 | Micrometer + Prometheus + Grafana | 复用集团现有 |
| 日志 | SLF4J + Logback（结构化 JSON） | traceId 贯穿 |
| 部署 | Docker + 内网 K8s | Adapter 与业务同命名空间 |

### 10.2 代码仓库与部署

| 系统 | 仓库 | 部署位置 |
|---|---|---|
| QMS Adapter | `harness-qms-adapter` | `qms` 命名空间 |
| MES Adapter | `harness-mes-adapter` | `mes` 命名空间 |
| WMS Adapter | `harness-wms-adapter` | `wms` 命名空间 |
| EMS Adapter | `harness-ems-adapter` | `ems` 命名空间 |
| 工具编辑器（阶段 3） | `harness-mcp-tool-designer` | `mcp-tools` 命名空间 |

共享库（Maven 私服）：

| 模块 | 说明 |
|---|---|
| `mcp-common` | 稳定后极少改动 |
| `mcp-auth-filter` | 业务系统引入 |
| `mcp-adapter-starter` | 核心库，按季度迭代新能力 |

### 10.3 部署拓扑

```
namespace: qms
  ├── qms-business-pod   (业务系统原样)
  └── qms-adapter-pod    (Adapter，暴露 /mcp)

namespace: mes
  ├── mes-business-pod
  └── mes-adapter-pod

namespace: mcp-tools                    ← 阶段 3
  └── mcp-tool-designer-pod

namespace: wms / ems / ...
```

---

## 11. 实施路线图

### 11.1 里程碑

| 阶段 | 周期 | 交付物 | 验收 |
|---|---|---|---|
| **阶段 1：starter 骨架 + 翻译层** | 第 1-5 周 | 三组共享库；starter 实现 MCP 协议端点、声明式工具加载、**智能翻译层三大支柱**（Result 解包 + 字段重命名 + DTO 包装）、治理下沉 | Mock 业务系统验证：声明工具 → 调用 → 翻译正确 |
| **阶段 2：QMS POC（缩小范围）** | 第 6-10 周 | `harness-qms-adapter` 落地 8-12 个工具（覆盖 `deviceMainData` + `inspectionTask` 两模块）；QMS 引入 `mcp-auth-filter`；权限/审计/限流联调；字段重命名规则在 QMS 实际字段上验证 | 选 1 个质量部门试点上线 |
| **阶段 3：可视化编辑器 + 工具运营** | 第 11-18 周 | `mcp-tool-designer` 落地；YAML 热加载；QMS 工具数扩到 30+（覆盖更多模块）；管理后台完善 | 工具设计师可独立上线新工具，不依赖开发者 |
| **阶段 4：横向铺开** | 第 19-26 周 | 按模板复制到 MES / WMS / EMS；红蓝对抗；运维 Runbook；性能压测 | 4 个 Adapter 上线 |
| **阶段 5：演进** | 持续 | 业务系统重构达标后切到 v2 自动发现模式（按 `2026-07-24-future-system-refactor-blueprint.md`） | — |

### 11.2 关键节点

- **第 5 周末**：starter + 翻译层跑通——技术风险消除
- **第 10 周末**：QMS POC 上线——业务价值验证
- **第 18 周末**：可视化编辑器上线——运营门槛降低
- **第 26 周末**：4 个 Adapter 全部上线——规模化复制成功

### 11.3 POC 范围（阶段 2）

**建议范围**：QMS 中 `deviceMainData` + `inspectionTask` 两个模块，8-12 个工具。

**为什么选这两个**：
- `deviceMainData`：CRUD 经典模式，验证翻译层基础能力
- `inspectionTask`：查询场景丰富（检验单查询、批次检验、不合格统计），适合 AI 助手

**POC 验证项**：
1. Result 自动解包在 sunny `Result<?>` 实际结构下工作
2. c/n/d 字段重命名规则在 QMS 字段上准确（无例外误伤）
3. DTO 嵌套包装对 `QmsDeviceMainDataDto` 这类典型 DTO 工作正常
4. mcp-auth-filter 与 sunny-auth-client 协作正常
5. AI 真实提问的调用成功率 > 80%

### 11.4 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| sunny-auth-client 集成方式不明确 | 高 | 高 | 阶段 1 前与 sunny 平台团队对齐，获取源码与文档 |
| 字段重命名规则误伤（cName 等例外） | 中 | 中 | exceptions 白名单；POC 期间打印重命名映射日志，逐工具核对 |
| wrap-to 模板语法不够灵活 | 中 | 中 | 阶段 1 设计 API 时预留扩展；必要时引入 FreeMarker |
| 工具描述质量不达标，AI 调用准确率低 | 高 | 高 | 提供描述模板；工具评审清单；上线后根据审计日志优化 |
| 单 Adapter 工具数爆炸（QMS 可能 100+） | 中 | 中 | 工具分组（group）；tools/list 支持按 group 过滤 |
| 质量数据合规风险 | 中 | 高 | 严格 `field_mask` + 角色授权 + 合规部门确认 |
| starter bug 影响所有 Adapter | 中 | 高 | 严格测试 + 灰度发布 + 版本锁定 |
| 工具设计师角色缺位 | 中 | 中 | 阶段 3 落地前明确角色与培训 |

### 11.5 成功度量

- **覆盖**：26 周内接入 4+ 子系统
- **声明效率**：声明一个新工具平均 10-20 行 YAML
- **稳定**：Adapter SLA 99.5%+，P95 延迟 < 1s（不含业务 API）
- **安全**：0 起权限越权审计事件
- **效率**：新 Adapter ≤ 3 周（POC 后）
- **AI 准确率**：试点部门 AI 调用成功率 > 80%
- **工具运营**：阶段 3 后，工具设计师独立上线工具数占比 > 50%

---

## 12. 测试策略

### 12.1 测试分层

| 层级 | 范围 | 工具 |
|---|---|---|
| 单元测试 | 翻译引擎、字段重命名、Result 解包、DTO 包装、wrap-to 模板解析 | JUnit 5 + Mockito，覆盖率 ≥ 80% |
| 契约测试 | 工具 YAML ↔ 业务 API 字段约定；MCP 协议响应 | Spring Cloud Contract |
| 集成测试 | Adapter ↔ Mock 业务系统全链路；翻译层端到端 | Testcontainers |
| 翻译专项 | Result 多形态、字段重命名例外、DTO 深嵌套、wrap-to 边界 | 专项测试集 |
| 安全测试 | 未授权调用、越权参数、PII 必脱敏 | OWASP ZAP + 红蓝对抗 |
| 性能测试 | 单 Adapter：500 QPS `tools/list`、100 QPS `tools/call`；P95 < 1s | JMeter / k6 |
| AI 端到端 | AI 真实提问 → 工具调用 → 正确结果 | 固定 prompt 集 |

### 12.2 工具上线准入清单

```
□ 工具 YAML 通过 schema 校验
□ 工具描述符合质量要求（含何时用/何时不用/参数语义/返回）
□ backend.url 已联调通过
□ translation.request.wrap-to 与业务 API 实际入参一致
□ translation.response 配置正确（Result 解包）
□ response.pick 不包含敏感字段
□ response.rename 字段对 AI 友好
□ auth.field_mask 覆盖所有 PII
□ auth.row_filter 与业务部门确认数据范围
□ 工具授权角色已配置
□ 集成测试通过
□ 审计日志可追溯、traceId 贯穿
□ Runbook 已写
□ 灰度方案已定
```

### 12.3 验收标准

- **功能**：4 个 Adapter 上线，AI 平台真实可用
- **翻译质量**：AI 看到的字段 100% 是语义化命名（无 c/n/d 前缀）
- **性能**：Adapter P95 < 1s
- **安全**：0 高危漏洞；100% 工具走授权表；100% 调用有审计
- **AI 准确率**：试点部门 > 80%

---

## 13. 附录

### 13.1 与 v1/v2 的对照

| 维度 | v1 | v2 | **v3** |
|---|---|---|---|
| 架构 | Gateway + Adapter 两层 | Adapter-only | **Adapter-only** |
| 工具来源 | YAML + 注解 | OpenAPI 自动发现 | **YAML 显式声明** |
| 业务 API 依赖 | 部分 | 强依赖（文档质量） | **不依赖** |
| 核心 IP | OpenAPI 解析器 | OpenAPI 解析器 | **智能翻译层** |
| 业务系统改动 | mcp-auth-filter | mcp-auth-filter + SpringDoc | **仅 mcp-auth-filter** |
| 单工具配置量 | 30-50 行 | 10-50 行（+ override） | **10-20 行** |
| 适配老系统 | 部分适配 | 困难 | **专为老系统设计** |
| 未来业务系统重构达标后 | — | 推荐 | **可平滑切换到 v2** |

### 13.2 术语

| 术语 | 含义 |
|---|---|
| MCP | Model Context Protocol |
| Streamable HTTP | MCP 2025-06-18 规范传输，本方案用纯 JSON 模式 |
| Adapter | 把某业务系统能力包装成 MCP 工具的服务 |
| 智能翻译层 | Adapter 内置的"参数包装 + 响应解包 + 字段重命名"层 |
| 工具设计师 | 负责声明与维护工具的角色（IT 部或业务侧） |
| starter | Spring Boot 启动器模块 |

### 13.3 待业务/平台团队澄清的问题

1. **sunny-auth-client 鉴权细节**：token 载体、用户身份获取 API、角色信息、服务账号概念
2. **`@Authignore` 语义**：是"忽略鉴权"还是"标记权限点"
3. **`Result<?>` 结构标准**：字段（code/msg/data）、成功码清单、是否有 i18n
4. **字段重命名例外清单**：QMS 中不以 c/n/d 开头的字段、或字段名本身就是 cXxx 的清单
5. **集团 Maven 私服**：上传权限、申请流程
6. **AI 平台多 MCP Server 接入**：是否支持、配置方式、数量限制
7. **SSO 公钥获取**：JWKS endpoint 或静态公钥
8. **K8s 命名空间申请**：流程
9. **质量部门试点范围**：用户范围、培训计划
10. **敏感数据脱敏规则**：客户投诉、不合格率等数据的具体规则（合规部门确认）

### 13.4 附录 B：大数据场景与聚合工具治理

> 来源：2026-07-29 讨论补充
> 背景：业务系统已有 LIST + byId 两类 API。AI 面对跨多天 / 多维度的"分析型"提问时，单纯暴露原 API 会导致 token 爆炸或调用次数失控。本节定义 Adapter 如何治理此类场景。

#### 13.4.1 工具契约原则：返回小数据 AI 可消费

工具的本质契约：**单次调用返回的数据量必须在 AI 单轮上下文窗口可消费范围内**。

| 工具类型 | 单次返回规模 | 适用场景 |
|---|---|---|
| 点查询（byId） | 1 条记录详情 | 已知 ID 查详情 |
| 列表查询（list） | ≤ 50 条 | 找具体几条记录 |
| 统计查询（stat） | 1-N 个聚合数字 | 数总量、看占比 |
| 聚合查询（aggregate） | ≤ 200 条分组结果 | 按维度分组分析 |

**反模式**：让 AI 反复调 list 翻页累积数据，再让大模型在内存里做分析——token 浪费 + 容易丢页 + 准确率低。

#### 13.4.2 聚合优先原则

暴露"统计 / 聚合工具"，而非"全量列表工具 + AI 自己算"。

| 业务需求 | 不当方式 | 推荐方式 |
|---|---|---|
| 统计本月不合格率 | 调 list 拉全部检验单 → AI 算 | 暴露 `qms_statInspectionRate` 工具 |
| 按工厂对比订单量 | 多工厂各调 list → AI 合并 | 暴露 `qms_aggregateOrders` 工具 |
| 找 Top 10 缺陷 | 全量拉取 → AI 排序 | 暴露 `qms_topDefects` 工具 |

#### 13.4.3 Adapter 安全边界（全局配置）

无论哪个演进阶段，所有 Adapter 都强制配置安全边界：

```yaml
# application.yml - 所有 Adapter 共用
mcp:
  adapter:
    safety:
      # 单次调用限制
      max-items-per-call: 50              # 工具单次返回最多 50 条记录
      max-fields-per-item: 30             # 单条记录最多 30 个字段
      truncate-text-length: 500           # 单字段长文本超过 500 字截断

      # 响应体积限制
      response-size-warning-kb: 50        # 超过 50KB 写 warning 日志
      response-size-hard-limit-kb: 200    # 超过 200KB 拒绝并返回错误

      # 调用频率限制（每用户）
      rate-limit:
        calls-per-minute: 60              # 单用户每分钟最多 60 次调用

      # 超时
      default-timeout-ms: 8000
      max-timeout-ms: 30000
```

**触发边界时的行为**：

| 边界 | 行为 |
|---|---|
| 单次返回超 50 条 | 截断到 50 条 + 返回 `hasMore: true` 提示 AI 翻页 |
| 响应超 200KB | 拒绝 + 错误信息建议改用聚合工具 |
| 频率超限 | 429 + Retry-After header |
| 超时 | 504 + 错误信息 |

工具级可覆盖（如聚合工具可放宽到 200）：

```yaml
tool:
  name: qms_aggregate
  safety:
    max-items-per-call: 200
```

#### 13.4.4 三阶段聚合 API 演进策略

##### 演进阶段 1（Demo 期，第 1-4 周）：分页 + 安全边界

不新增聚合 API。仅暴露 list / byId 工具，依赖 Adapter 安全边界控制数据量。

业务方提出"分析近一个月订单"等大需求时，IT 部**手工写 SQL 报表 + 通过 Adapter 包装成工具**临时满足。

##### 演进阶段 2（试运行期，第 5-16 周）：审计驱动 + 按需声明

**核心思路**：IT 部和业务部门都不主动"想清楚需要什么聚合"，改为**让 AI 与用户的真实交互告诉我们要什么**。

**反馈循环流程**：

```
用户提问 → AI 调用现有工具（多次翻页 / 合并）→ 审计日志记录
                                              ↓
                                  周度审计分析会议
                                              ↓
                                  识别"高频聚合模式"
                                              ↓
                                  新建专用聚合工具
                                              ↓
                                  工具上线，AI 不再翻页
```

**审计信号识别表**：

| 审计信号 | 含义 | 行动 |
|---|---|---|
| 同一用户 + 同一工具 + 翻页 ≥ 3 次 | AI 在累积数据 | 新建聚合工具 |
| 同一会话内连续调用 list + list + byId × N | AI 在做 JOIN | 新建带明细的聚合工具 |
| 工具调用参数高度相似（hash 重复） | 缓存命中差 | 考虑缓存或聚合 |
| 调用失败率 > 10% | 业务 API 不支持该查询模式 | 新建专用查询 |
| 用户提问 vs 工具调用差距大 | AI 找不到合适工具 | 新工具或优化描述 |

##### 演进阶段 3（成熟期，第 17 周起）：半通用聚合工具

不再每个分析需求都写专用工具，而是提供**一个半通用聚合工具**，业务方 / AI 提交维度组合 + 指标，服务端执行 group by。

**设计要点**：
- **不开放任意 SQL**（防止 SQL 注入 + 性能失控）
- **白名单维度**：业务系统预先声明可聚合的维度组合
- **白名单指标**：仅允许预定义的聚合函数（count / sum / avg / rate）
- **行级权限下推**：where 条件自动注入用户权限范围
- **结果上限**：topN ≤ 200 条

**YAML 模板**：

```yaml
tool:
  name: qms_aggregate
  description: |
    数据聚合查询工具。AI 提交"数据集 + 分组维度 + 指标 + 过滤"，服务端执行 group by。
    仅支持白名单内的维度与指标组合。结果按指定指标排序，返回 topN 条。

    何时用：用户要"按 XX 维度统计 / 对比 / 排名 / TopN"，如"各工厂本月合格率对比"
    何时不用：用户要查具体记录详情（用 byId 工具），或要列出所有记录（用 list 工具）

    数据集与可用维度：
      - orders（订单）: 维度 factory/product/customer/month/week
      - inspections（检验单）: 维度 factory/line/inspector/month
      - defects（缺陷）: 维度 factory/defectType/product/month

    指标：count / sum:{field} / avg:{field} / rate:{passField}/{totalField}
  backend:
    method: POST
    url: http://qms-intra/api/aggregate
  params:
    - name: dataset
      type: string
      required: true
      enum: [orders, inspections, defects]
    - name: groupBy
      type: array
      required: true
      description: 分组维度组合（必须全部在 dataset 对应白名单内）
    - name: metrics
      type: array
      required: true
      description: 聚合指标（白名单内）
    - name: filter
      type: object
      description: 过滤条件（与 list 工具一致）
    - name: orderBy
      type: string
      default: "${metrics[0]} DESC"
    - name: topN
      type: integer
      default: 100
      maximum: 200
  translation:
    request:
      wrap-to: |
        { "aggregateQuery": ${...} }
    response:
      unwrap-result: true
  auth:
    row_filter: auto
  safety:
    max-items-per-call: 200
```

> **注意**：半通用聚合工具的设计前提是业务系统暴露 `/api/aggregate` 端点。当前 v3 老系统一般没有，需 IT 部针对高频需求先手动写 SQL 报表工具。半通用工具的完整落地依赖业务系统重构（见蓝图文档新增的 3.8 节）。

#### 13.4.5 三阶段演进流程图

```
┌──────────────────────────────────────────────────┐
│ 演进阶段 1（Demo 期）：分页 + 安全边界               │
│   - max-items-per-call: 50                          │
│   - response-size-hard-limit: 200KB                 │
│   - 仅暴露 list/byId 工具                            │
│   - 业务方有大数据需求时 IT 临时写 SQL 报表          │
└────────────────────┬─────────────────────────────┘
                     │
                     │ 同类需求高频出现 / 审计信号明显
                     ▼
┌──────────────────────────────────────────────────┐
│ 演进阶段 2（试运行期）：审计驱动 → 声明专用聚合工具  │
│   - 周会复盘审计日志                                │
│   - 识别高频聚合模式                                │
│   - 新建 stat/aggregate 工具（experimental）       │
│   - 走生命周期 experimental → stable                │
└────────────────────┬─────────────────────────────┘
                     │
                     │ 聚合工具数量 > 10 个 / 业务系统提供 /api/aggregate
                     ▼
┌──────────────────────────────────────────────────┐
│ 演进阶段 3（成熟期）：半通用聚合工具 + 白名单维度    │
│   - qms_aggregate（dataset + groupBy + metrics）  │
│   - 业务系统暴露 /api/aggregate 端点               │
│   - 专用聚合工具逐步 deprecated                    │
└──────────────────────────────────────────────────┘
```

#### 13.4.6 工具运营周会

**频率**：每周一次（建议周一 14:00）

**参与方**：IT 部、业务部门代表、AI 平台代表

**议题模板**：

```
1. 复盘上周 mcp_audit_log（聚合统计）
   - 调用最多的 5 个工具
   - 失败率最高的 5 个工具
   - 翻页最多的 5 个调用会话
   - AI 调用准确率最低的 5 个工具

2. 识别需要新建 / 优化的工具
   - 高频翻页 → 新建聚合工具（进入 experimental）
   - 高失败率 → 优化工具描述 / 修 wrap-to
   - 低准确率 → 改工具描述 + 增加 example

3. 推进工具生命周期
   - experimental → beta：满足 7 天无 critical
   - beta → stable：满足 30 天成功率 ≥ 90%
   - stable → deprecated：被替代或业务 API 下线
   - deprecated → offline：sunset 到期

4. 分配本周工具设计师任务
```

**度量指标**（每周观察）：

| 指标 | 目标 |
|---|---|
| 工具总数 | 演进阶段 2 起每周 +1-3 个 |
| stable 工具占比 | ≥ 60% |
| 平均翻页次数 | < 2（说明聚合工具到位） |
| AI 调用准确率 | ≥ 80% |
| 工具描述平均长度 | 100-300 字 |

---

### 13.5 附录 C：工具生命周期治理

> 工具不是"上线就完事"。引入正式的生命周期管理，让工具质量随时间持续提升，旧工具能有序退场。

#### 13.5.1 生命周期阶段

```
experimental → beta → stable → deprecated → offline
    ↑            ↑        ↑          ↑            ↑
   试点        公测     主流        警告       下线
```

| 状态 | 含义 | 触发条件 | 行为 |
|---|---|---|---|
| experimental | 试验期 | 新工具首次上线，或大改后 | 仅小范围用户授权；AI 描述标 `[试验]` |
| beta | 公测期 | experimental 1-2 周无 critical bug | 扩大用户范围；AI 描述标 `[公测]` |
| stable | 稳定期 | beta 4 周无重大问题 | 全员可用；描述去掉标签 |
| deprecated | 弃用期 | 业务系统 API 即将下线 / 工具被替代 | 调用时返告警 header `Sunset: <date>`（RFC 8594） |
| offline | 下线 | deprecated 满 4 周 / 业务 API 已下线 | YAML 标 `enabled: false`，从 tools/list 移除 |

#### 13.5.2 工具 YAML 增加 lifecycle 字段

```yaml
tool:
  name: qms_listDeviceByFactory
  lifecycle:
    stage: stable                    # experimental | beta | stable | deprecated | offline
    since: 2026-08-01                # 进入当前阶段日期
    sunset:                          # 仅 deprecated 时填
      date: 2026-12-31
      reason: "被 qms_aggregate 替代"
      migrate-to: qms_aggregate
```

#### 13.5.3 生命周期变更触发规则

| 触发 | 自动动作 |
|---|---|
| 新工具上线 | 默认 `experimental` |
| 7 天无 critical bug | 自动升级到 `beta`（可配置） |
| 30 天 AI 调用成功率 ≥ 90% | 自动升级到 `stable`（可配置） |
| 业务 API 计划下线 | IT 手动改为 `deprecated` + sunset 字段 |
| sunset 到期 | 自动改为 `offline` |

#### 13.5.4 工具描述与 lifecycle 标签

Adapter 在 tools/list 返回工具描述时，根据 lifecycle 自动追加标签：

```json
{
  "name": "qms_listDeviceByFactory",
  "description": "按工厂代码分页查询设备主数据清单... [试验]"
}
```

deprecated 工具的 tools/call 响应附加 Sunset header（RFC 8594）：

```
Sunset: Wed, 31 Dec 2026 23:59:59 GMT
Deprecation: true
Link: <https://wiki.example.com/mcp-migration>; rel="deprecation"
```

#### 13.5.5 工具生命周期与聚合策略的关系

演进阶段 2 的"按需声明聚合工具"高度依赖生命周期管理：

```
新需求识别 → 新建聚合工具（experimental）
                ↓
            小范围试用 OK
                ↓
            扩大授权（beta）
                ↓
            达稳定（stable，AI 主用）
                ↓
            半通用工具出现（演进阶段 3）
                ↓
            标 deprecated（AI 描述里建议改用 qms_aggregate）
                ↓
            sunset 到期 → offline
```

没有正式的生命周期，工具一旦上线就难以退场，会导致工具数量膨胀、AI 选择困难、维护成本失控。

---

### 13.6 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v3.0 | 2026-07-24 | 针对老业务系统现状重写：声明式工具 + 智能翻译层 |
| v3.1 | 2026-07-29 | 追加附录 B（大数据场景与聚合工具治理）、附录 C（工具生命周期治理） |
