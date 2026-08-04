#!/usr/bin/env bash
# on-state-change.sh — PostToolUse Hook (matcher: Write|Edit)
# 监听 .hyperspec-state.yaml 改动，触发 apply-role.sh 重新注入角色
#
# 触发：每次 Write/Edit 工具调用后（settings.local.json 中 hooks.PostToolUse）
# 行为：
#   1. 读 PostToolUse payload 的 tool_input.file_path
#   2. basename 是 .hyperspec-state.yaml → 调 apply-role.sh，stdout 透传给 Claude Code
#   3. 其它文件 → 静默放行
#
# 设计理由：
#   HyperSpec skill 推进 checkpoint 时用 Edit 工具改 .hyperspec-state.yaml，
#   这会触发 PostToolUse(Write|Edit) 事件。本 hook 利用这个原生事件作为
#   "checkpoint 切换信号"，无需 HyperSpec 上游配合，也不依赖 Claude Code
#   不存在的 PreCheckpointAdvance 事件。

set -uo pipefail

PAYLOAD="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
    # 无 jq 无法解析 payload，放行（apply-role.sh 仍由 SessionStart 兜底）
    exit 0
fi

FILE_PATH="$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$FILE_PATH" ]] && exit 0

BASENAME="$(basename "$FILE_PATH")"
if [[ "$BASENAME" != ".hyperspec-state.yaml" ]]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 透传 apply-role.sh 的 stdout — 它会被 Claude Code 当作 PostToolUse 反馈注入
bash "${SCRIPT_DIR}/apply-role.sh"

exit 0
