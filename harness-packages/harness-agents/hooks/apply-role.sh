#!/usr/bin/env bash
# apply-role.sh — 角色加载器（被 SessionStart + PostToolUse hook 调用）
# 根据 .hyperspec-state.yaml 的 checkpoint 字段，加载对应角色配置
#
# 触发：
#   1. SessionStart（会话启动）— 由 settings.local.json 中 hooks.SessionStart 直接调用
#   2. PostToolUse(Write|Edit)（HyperSpec 改 .hyperspec-state.yaml 时）
#      — 由 on-state-change.sh 内部 basename 过滤后调用
#
# 设计理由：
#   Claude Code 没有 PreCheckpointAdvance 事件。HyperSpec skill 推进 checkpoint
#   时用 Edit 工具改 .hyperspec-state.yaml，这会触发 PostToolUse(Write|Edit)
#   原生事件。on-state-change.sh 利用该事件作为"checkpoint 切换信号"。
#
# 行为：
#   1. 读 .hyperspec-state.yaml 的 checkpoint（兼容旧字段 current_checkpoint）
#   2. 查 .claude/team-roles/checkpoint-map.yaml 得到 current_role
#   3. 读 .claude/team-roles/permissions.json 得到该角色的权限/技能/模型
#   4. 读 .claude/agents/{role}.md 作为 system prompt override
#   5. 写角色切换日志 .claude/logs/role-switch.log
#   6. 输出 stdout 给 Claude Code（注入 system 提示）

set -uo pipefail

PROJECT_ROOT="$(pwd)"
STATE_FILE="${PROJECT_ROOT}/.hyperspec-state.yaml"
CHECKPOINT_MAP="${PROJECT_ROOT}/.claude/team-roles/checkpoint-map.yaml"
PERMISSIONS="${PROJECT_ROOT}/.claude/team-roles/permissions.json"
ROLE_PROMPT_DIR="${PROJECT_ROOT}/.claude/agents"
LOG_FILE="${PROJECT_ROOT}/.claude/logs/role-switch.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [apply-role] $*" >> "$LOG_FILE"
}

die_silent() {
    log "ERROR: $*"
    # hook 失败不阻塞会话，只记日志
    exit 0
}

# =============================================================================
# 工具检测
# =============================================================================
YAML_TOOL=""
if command -v yq >/dev/null 2>&1; then
    YAML_TOOL="yq"
elif command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
    YAML_TOOL="python-yaml"
else
    # 无 YAML 解析器，做最简单的 grep 提取（兜底）
    YAML_TOOL="grep"
    echo "[apply-role] WARN: yq 与 python3-yaml 均不可用，走 grep/awk 兜底。" >> "$LOG_FILE"
    echo "[apply-role]        建议装 yq（winget install MikeFarah.yq）或 pip install pyyaml，" >> "$LOG_FILE"
    echo "[apply-role]        否则 task-N-complete 等 pattern 匹配可能失效。" >> "$LOG_FILE"
fi

read_yaml_field() {
    local file="$1"
    local path="$2"
    case "$YAML_TOOL" in
        yq)
            yq -r "$path" "$file" 2>/dev/null
            ;;
        python-yaml)
            # 注意1：Windows 上 python3 多为 pyenv-win shim (.bat 文件)，
            #         多行 `python3 -c "..."` 会被 batch 解析器破坏。
            # 注意2：Windows Python 不认 MSYS 风格路径 (/e/foo/bar)，
            #         必须用 cygpath -m 转成 C:/foo/bar 形式。
            # 解决：写 .py 文件 + 路径转换。
            local py_file="$file"
            if command -v cygpath >/dev/null 2>&1; then
                py_file=$(cygpath -m "$file" 2>/dev/null || echo "$file")
            fi
            local tmp_py="${TMPDIR:-/tmp}/harness-yaml-$$.py"
            cat > "$tmp_py" <<PY
import yaml
with open('$py_file', encoding='utf-8') as f:
    data = yaml.safe_load(f)
path = '$path'.lstrip('.')
parts = []
for chunk in path.split('.'):
    if len(chunk) >= 2 and chunk[0] == '"' and chunk[-1] == '"':
        parts.append(chunk[1:-1])
    else:
        parts.append(chunk)
cursor = data
for part in parts:
    if cursor is None:
        break
    cursor = cursor.get(part) if isinstance(cursor, dict) else None
print('' if cursor is None else cursor)
PY
            python3 "$tmp_py" 2>/dev/null
            rm -f "$tmp_py"
            ;;
        grep)
            # 最简单的兜底：取顶层 key
            local key="${path##*.}"
            grep -E "^${key}:" "$file" 2>/dev/null | head -1 | sed -E 's/^[^:]+:\s*(.*)$/\1/' | tr -d '"'
            ;;
    esac
}

# =============================================================================
# 读 hook 输入
# =============================================================================
INPUT="$(cat)"
log "input: ${INPUT:0:200}"

# =============================================================================
# 读当前 checkpoint
# =============================================================================
if [[ ! -f "$STATE_FILE" ]]; then
    log "state 文件不存在 — 默认 developer 角色"
    CURRENT_CHECKPOINT=""
else
    # HyperSpec SKILL.md 标准字段是 checkpoint，旧版本用 current_checkpoint。
    # 优先读 checkpoint，没有再回退到 current_checkpoint。
    CURRENT_CHECKPOINT="$(read_yaml_field "$STATE_FILE" '.checkpoint')"
    if [[ -z "$CURRENT_CHECKPOINT" || "$CURRENT_CHECKPOINT" == "null" ]]; then
        CURRENT_CHECKPOINT="$(read_yaml_field "$STATE_FILE" '.current_checkpoint')"
    fi
    log "checkpoint=${CURRENT_CHECKPOINT:-（空）}"
fi

# =============================================================================
# 查 checkpoint-map 得到角色
# =============================================================================
CURRENT_ROLE="developer"
if [[ -n "$CURRENT_CHECKPOINT" && -f "$CHECKPOINT_MAP" ]]; then
    # 尝试精确匹配
    ROLE_FOUND=""
    # 通用 awk：解析 checkpoint 块取 role 字段
    _awk_lookup() {
        local key="$1"
        awk -v cp="$key" '
            BEGIN { in_block=0 }
            /^checkpoints:/ { in_checkpoints=1; next }
            in_checkpoints && /^  [a-zA-Z][^:]*:$/ { current=$1; sub(/:$/,"",current); in_block=(current==cp) ? 1 : 0 }
            in_block && /^    role:/ { sub(/^.*role:[[:space:]]*/,""); gsub(/["'"'"']/,""); print; exit }
        ' "$CHECKPOINT_MAP"
    }
    if [[ "$YAML_TOOL" == "grep" ]]; then
        # 兜底：awk 精确匹配
        ROLE_FOUND="$(_awk_lookup "$CURRENT_CHECKPOINT")"
        # task-N-complete pattern 兜底（与 YAML 分支对齐）
        if [[ -z "$ROLE_FOUND" && "$CURRENT_CHECKPOINT" =~ ^task-[0-9]+-complete$ ]]; then
            ROLE_FOUND="$(_awk_lookup "task-N-complete")"
        fi
    else
        # 正经 YAML 解析
        ROLE_FOUND=$(read_yaml_field "$CHECKPOINT_MAP" ".checkpoints.${CURRENT_CHECKPOINT}.role")
        # 处理 task-N-complete 这类 pattern
        if [[ -z "$ROLE_FOUND" || "$ROLE_FOUND" == "null" ]]; then
            if [[ "$CURRENT_CHECKPOINT" =~ ^task-[0-9]+-complete$ ]]; then
                ROLE_FOUND=$(read_yaml_field "$CHECKPOINT_MAP" ".checkpoints.\"task-N-complete\".role")
            fi
        fi
    fi
    [[ -n "$ROLE_FOUND" && "$ROLE_FOUND" != "null" ]] && CURRENT_ROLE="$ROLE_FOUND"
fi

log "resolved role=${CURRENT_ROLE}"

# 空 checkpoint 或 done 状态
if [[ -z "$CURRENT_CHECKPOINT" || "$CURRENT_CHECKPOINT" == "done" ]]; then
    log "无活跃 checkpoint 或流程已结束 — 不注入角色"
    exit 0
fi

# =============================================================================
# 读角色权限/模型
# =============================================================================
if [[ ! -f "$PERMISSIONS" ]]; then
    die_silent "permissions.json 缺失"
fi

if ! command -v jq >/dev/null 2>&1; then
    die_silent "jq 不可用 — 无法解析 permissions.json"
fi

MODEL=$(jq -r --arg r "$CURRENT_ROLE" '.roles[$r].model // "sonnet"' "$PERMISSIONS")
ALLOW_COUNT=$(jq -r --arg r "$CURRENT_ROLE" '.roles[$r].permissions.allow | length' "$PERMISSIONS")
DENY_COUNT=$(jq -r --arg r "$CURRENT_ROLE" '.roles[$r].permissions.deny | length' "$PERMISSIONS")
SKILLS_COUNT=$(jq -r --arg r "$CURRENT_ROLE" '.roles[$r].skills_active | length' "$PERMISSIONS")
ROLE_DESC=$(jq -r --arg r "$CURRENT_ROLE" '.roles[$r].description // ""' "$PERMISSIONS")

log "model=$MODEL allow=$ALLOW_COUNT deny=$DENY_COUNT skills=$SKILLS_COUNT"

# =============================================================================
# 加载角色 prompt
# =============================================================================
ROLE_PROMPT_FILE="${ROLE_PROMPT_DIR}/${CURRENT_ROLE}.md"
ROLE_PROMPT_CONTENT=""
if [[ -f "$ROLE_PROMPT_FILE" ]]; then
    # 限制 prompt 大小，避免过长（取前 6KB）
    ROLE_PROMPT_CONTENT=$(head -c 6144 "$ROLE_PROMPT_FILE")
    log "loaded prompt: ${ROLE_PROMPT_FILE#$PROJECT_ROOT/} ($(wc -c <"$ROLE_PROMPT_FILE") bytes)"
else
    log "WARN: prompt 文件不存在：$ROLE_PROMPT_FILE"
fi

# =============================================================================
# 输出给 Claude Code（注入到 system context）
# =============================================================================
cat <<EOF

============================================================
🎭 当前角色：${CURRENT_ROLE}（${ROLE_DESC}）
   checkpoint：${CURRENT_CHECKPOINT}
   模型：${MODEL}
   权限：allow ${ALLOW_COUNT} 项 / deny ${DENY_COUNT} 项
   激活技能：${SKILLS_COUNT} 个
============================================================

${ROLE_PROMPT_CONTENT}

------------------------------------------------------------
角色提示：
- 你现在以「${CURRENT_ROLE}」视角工作
- 只关注本角色的职责，无关上下文已隔离
- 工件通过 .hyperspec-state.yaml 和 openspec/changes/ 传递
- 完成本 checkpoint 后由 HyperSpec 推进到下一个角色
------------------------------------------------------------

EOF

# 输出 stderr 给日志（不污染 Claude 的 stdout）
echo "[$(date '+%H:%M:%S')] active role: ${CURRENT_ROLE} @ ${CURRENT_CHECKPOINT}" >&2

exit 0
