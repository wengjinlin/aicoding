---
name: quick-review
description: 轻量 3 关审查 — 适用于小改动（task ≤ 3、单模块、无 DDL）。耗时约 2 分钟。
trigger: /quick-review 命令，或 HyperSpec 自动路由
---

# quick-review

## 何时用

**触发条件（全部满足才走 quick-review，否则走 full-review）**：

- task 数量 ≤ 3
- 涉及模块 ≤ 1
- 无 DDL 变更（CREATE/ALTER/DROP TABLE）
- 无跨服务调用变更

或用户显式 `/quick-review` 强制走轻量审查。

## 3 关流水线

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│   第 1 关       │     │   第 2 关      │     │   第 3 关       │
│  spec-align    │────→│  risk-check    │────→│  archive       │
│  规范对齐       │      │  风险检查       │     │  归档          │
└────────────────┘     └────────────────┘     └────────────────┘
```

**关键约束**：每关失败必须修完才能进下一关。

## 第 1 关 — spec-align（规范对齐 + 工程质量）

| 检查项 | 具体内容 |
|--------|----------|
| 规范对齐 | 代码与 `tasks.md` 逐条对齐，无遗漏无多余 |
| Spring 分层 | Controller 不直接操作 DAO；Service 继承 `BaseServiceManager` |
| DTO 规范 | 单一 DTO 不拆分；Controller 层只用 DTO 不用 Entity |
| Entity 规范 | 禁用 Lombok；手写 getter/setter |
| 平台包使用 | 优先 `sunny-base-*`，不引重叠依赖 |
| 通用质量 | 无死代码、无 console.log、无 TODO、import 干净 |

**通过条件**：所有项 ✓。失败：列出具体违规项，AI 自动修复后重审。

## 第 2 关 — risk-check（风险检查）

| 检查项 | 具体内容 |
|--------|----------|
| SQL 安全 | 参数化查询、无拼接 SQL、无 SELECT * |
| 空值处理 | 新字段可空性、前端空值展示、接口返回 null 安全 |
| 索引感知 | 新增 WHERE 条件是否走索引、避免全表扫描 |
| 隐性约定 | 已查 `docs/architecture/implicit-contracts.md` |
| 接口兼容 | 不破坏已有接口契约、字段新增而非修改 |
| 数据兼容 | DDL 变更对存量数据的处理（默认值、迁移脚本） |

**通过条件**：所有项 ✓。

## 第 3 关 — archive（归档）

复用 `/opsx:archive`：

- 工件完整：`openspec/changes/<id>/` 下 proposal/specs/design/tasks 齐全
- `tasks.md` 全部 checkbox 打勾
- 移入 `openspec/archive/<date>-<id>/`
- 更新 `openspec/specs/` 合并新规格

## 输出格式

```markdown
# quick-review 报告

## change-id: <id>
## 时间: <YYYY-MM-DD HH:MM>

### 第 1 关 spec-align
- [✓] 规范对齐
- [✓] Spring 分层
- [✗] DTO 规范：UserController 用了 Entity（违规）
- ...

**结论：打回，修复后重审。**

### 修复建议
1. UserController.login 返回 UserDTO 而非 User entity
2. ...
```

报告写入 `openspec/changes/<id>/review-reports/quick-review-<timestamp>.md`。

## 模型路由建议

- 第 1 关：sonnet（标准审查）
- 第 2 关：sonnet（标准审查）+ LSP/AST 工具辅助
- 第 3 关：haiku（机械归档）
