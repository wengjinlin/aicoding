#!/usr/bin/env bash
# harness-infra/init-harness-infra.sh
# Harness V2 基础建设包 — 一键安装脚本（默认保守模式）
#
# 用法：
#   ./init-harness-infra.sh                # 默认：保守模式
#   ./init-harness-infra.sh --force        # 强制覆盖（自动备份）
#   ./init-harness-infra.sh --dry-run      # 预演，不写文件
#   ./init-harness-infra.sh --verbose      # 详细日志
#   ./init-harness-infra.sh --yes          # 跳过确认提示
#   ./init-harness-infra.sh --help
#
# 设计原则：
#   1. 默认保守：只创建缺失的，不动已有的
#   2. 配置文件深度合并，保留用户自定义
#   3. 团队文档（AGENTS.md/CLAUDE.md/REVIEW.md）非空则跳过
#   4. 运行时状态（.hyperspec-state.yaml/instincts/）绝不覆盖
#   5. native 安装的 Claude Code 不动

set -uo pipefail

# =============================================================================
# 常量
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"
BACKUP_ROOT="${PROJECT_ROOT}/.harness-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${PROJECT_ROOT}/.harness-install.log"

# 期望版本（最低要求）
EXPECTED_CLAUDE_MAJOR=2
EXPECTED_NODE_MAJOR=18

# 组件清单
GLOBAL_TOOLS=("claude-code" "openspec")
PROJECT_SKILLS=("superpowers" "gstack" "HyperSpec" "ecc")
INFRA_DIRS=(
    ".claude"
    ".claude/hooks"
    ".claude/commands/opsx"
    ".claude/skills"
    ".claude/instincts"
    "openspec"
    "openspec/changes"
    "openspec/archive"
    "superpowers/plans"
    "docs/architecture"
    "docs/database"
    "docs/standards"
    "docs/harness"
    "docs/help"
)
DOC_FILES=("AGENTS.md" "CLAUDE.md" "REVIEW.md")
HOOK_FILES=("guard_write.py" "ensure_change_context.py" "run_checks.sh")

# =============================================================================
# 运行时状态
# =============================================================================
MODE="conservative"     # conservative | force | dryrun
VERBOSE=0
ASSUME_YES=0
BACKUP_DIR=""

# 决策记录：每个组件 → 动作（INSTALL/SKIP/MERGE/BACKUP_OVERWRITE/PRESERVE）
declare -A DECISIONS
# 备份清单：源文件 → 备份目标
declare -A BACKUP_MANIFEST

# =============================================================================
# 工具函数
# =============================================================================
log_info()    { echo -e "\033[32m[INFO]\033[0m  $*"; }
log_warn()    { echo -e "\033[33m[WARN]\033[0m  $*"; }
log_error()   { echo -e "\033[31m[ERROR]\033[0m $*"; }
log_step()    { echo -e "\033[36m[STEP]\033[0m  $*"; }
log_verbose() { [[ $VERBOSE -eq 1 ]] && echo -e "\033[90m[DEBUG]\033[0m $*" || true; }

die() {
    log_error "$*"
    echo "详细日志见：$LOG_FILE"
    exit 1
}

# 写日志文件
write_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# 检查命令是否存在
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# 检查文件非空
is_nonempty_file() {
    [[ -f "$1" && -s "$1" ]]
}

# 检查 JSON 配置文件是否有内容（且可解析）
is_valid_json() {
    [[ -f "$1" ]] && has_cmd jq && jq empty "$1" >/dev/null 2>&1
}

# 备份文件
backup_file() {
    local src="$1"
    local rel="${src#$PROJECT_ROOT/}"
    local dst="${BACKUP_DIR}/${rel}"
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    BACKUP_MANIFEST["$rel"]="${dst}"
    log_verbose "已备份：$rel → ${dst#$PROJECT_ROOT/}"
}

# =============================================================================
# 参数解析
# =============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                MODE="force"
                shift
                ;;
            --dry-run)
                MODE="dryrun"
                shift
                ;;
            --verbose|-v)
                VERBOSE=1
                shift
                ;;
            --yes|-y)
                ASSUME_YES=1
                shift
                ;;
            --help|-h)
                cat <<EOF
用法：init-harness-infra.sh [选项]

选项：
  --force         强制覆盖已存在内容（自动备份到 .harness-backup-{date}/）
  --dry-run       预演模式：只打印决策，不写任何文件
  --verbose, -v   详细日志
  --yes, -y       跳过确认提示
  --help, -h      显示此帮助

默认（无选项）：保守模式，只创建缺失的，不动已有的。
EOF
                exit 0
                ;;
            *)
                die "未知选项：$1（用 --help 查看用法）"
                ;;
        esac
    done

    if [[ "$MODE" == "dryrun" ]]; then
        ASSUME_YES=1
    fi
}

# =============================================================================
# 预检：扫描所有组件，记录决策
# =============================================================================
preflight_check() {
    log_step "预检：扫描系统状态"

    # 1. 全局工具
    if has_cmd claude; then
        local v
        v=$(claude --version 2>/dev/null | head -n1 || echo "unknown")
        if [[ "$MODE" == "force" ]]; then
            DECISIONS[claude-code]="BACKUP_OVERWRITE"
        else
            DECISIONS[claude-code]="SKIP"
        fi
        log_verbose "claude-code: $v"
    else
        DECISIONS[claude-code]="INSTALL"
    fi

    if has_cmd openspec; then
        if [[ "$MODE" == "force" ]]; then
            DECISIONS[openspec]="BACKUP_OVERWRITE"
        else
            DECISIONS[openspec]="SKIP"
        fi
    else
        DECISIONS[openspec]="INSTALL"
    fi

    if ! has_cmd node; then
        log_warn "未检测到 node — npm 全局工具安装将失败"
    fi

    # 2. 项目级 skills
    for skill in "${PROJECT_SKILLS[@]}"; do
        local path=".claude/skills/${skill,,}"
        if [[ -d "$path" ]]; then
            if [[ "$MODE" == "force" ]]; then
                DECISIONS["skill:$skill"]="BACKUP_OVERWRITE"
            else
                DECISIONS["skill:$skill"]="SKIP"
            fi
        else
            DECISIONS["skill:$skill"]="INSTALL"
        fi
    done

    # quick-review 是本包内置 skill，单独处理
    if [[ -d ".claude/skills/quick-review" ]]; then
        DECISIONS["skill:quick-review"]="BACKUP_OVERWRITE"
    else
        DECISIONS["skill:quick-review"]="INSTALL"
    fi

    # 3. 目录骨架
    for d in "${INFRA_DIRS[@]}"; do
        if [[ -d "$d" ]]; then
            DECISIONS["dir:$d"]="SKIP"
        else
            DECISIONS["dir:$d"]="INSTALL"
        fi
    done

    # 4. Hooks（标准件，统一版本）
    for h in "${HOOK_FILES[@]}"; do
        DECISIONS["hook:$h"]="BACKUP_OVERWRITE_IF_EXISTS"
    done

    # 5. 配置文件 settings.local.json
    if [[ -f ".claude/settings.local.json" ]]; then
        DECISIONS["settings.local.json"]="MERGE"
    else
        DECISIONS["settings.local.json"]="INSTALL"
    fi

    # 6. 文档文件
    for f in "${DOC_FILES[@]}"; do
        if is_nonempty_file "$f"; then
            if [[ "$MODE" == "force" ]]; then
                DECISIONS["doc:$f"]="BACKUP_OVERWRITE"
            else
                DECISIONS["doc:$f"]="SKIP"
            fi
        else
            DECISIONS["doc:$f"]="INSTALL"
        fi
    done

    # 7. openspec/config.yaml
    if is_nonempty_file "openspec/config.yaml"; then
        if [[ "$MODE" == "force" ]]; then
            DECISIONS["openspec/config.yaml"]="BACKUP_OVERWRITE"
        else
            DECISIONS["openspec/config.yaml"]="SKIP"
        fi
    else
        DECISIONS["openspec/config.yaml"]="INSTALL"
    fi

    # 8. HyperSpec 状态（绝不覆盖）
    if [[ -f ".hyperspec-state.yaml" ]]; then
        if [[ "$MODE" == "force" ]]; then
            DECISIONS[".hyperspec-state.yaml"]="BACKUP_OVERWRITE"
        else
            DECISIONS[".hyperspec-state.yaml"]="PRESERVE"
        fi
    else
        DECISIONS[".hyperspec-state.yaml"]="INSTALL"
    fi
}

# =============================================================================
# 打印预检报告
# =============================================================================
print_preflight_report() {
    echo
    echo "🔍 预检报告（模式：${MODE}）"
    echo "────────────────────────────────────────────────────────────"

    local will_do=0 will_skip=0 will_backup=0

    # 全局工具
    for tool in "${GLOBAL_TOOLS[@]}"; do
        local action="${DECISIONS[$tool]:-?}"
        case "$action" in
            SKIP)              echo "✅ $tool 已安装（跳过）";   ((will_skip++)) ;;
            INSTALL)           echo "🆕 $tool 将安装";          ((will_do++)) ;;
            BACKUP_OVERWRITE)  echo "🔄 $tool 将升级（备份后）"; ((will_backup++)) ;;
        esac
    done

    # Skills
    for key in "${!DECISIONS[@]}"; do
        [[ "$key" == skill:* ]] || continue
        local skill="${key#skill:}"
        local action="${DECISIONS[$key]}"
        case "$action" in
            SKIP)              echo "✅ skill/$skill 已存在（跳过）";   ((will_skip++)) ;;
            INSTALL)           echo "🆕 skill/$skill 将安装";          ((will_do++)) ;;
            BACKUP_OVERWRITE)  echo "🔄 skill/$skill 将重装（备份后）"; ((will_backup++)) ;;
        esac
    done

    # 目录
    for key in "${!DECISIONS[@]}"; do
        [[ "$key" == dir:* ]] || continue
        local d="${key#dir:}"
        local action="${DECISIONS[$key]}"
        case "$action" in
            SKIP)    echo "✅ 目录 $d 已存在";     ((will_skip++)) ;;
            INSTALL) echo "🆕 目录 $d 将创建";    ((will_do++)) ;;
        esac
    done

    # Hooks
    for key in "${!DECISIONS[@]}"; do
        [[ "$key" == hook:* ]] || continue
        local h="${key#hook:}"
        local action="${DECISIONS[$key]}"
        if [[ -f ".claude/hooks/$h" ]]; then
            echo "🔄 hook $h 将覆盖到统一版本（备份后）"; ((will_backup++))
        else
            echo "🆕 hook $h 将安装"; ((will_do++))
        fi
    done

    # 配置
    local action="${DECISIONS[settings.local.json]}"
    case "$action" in
        MERGE)   echo "🔀 .claude/settings.local.json 将深度合并"; ((will_do++)) ;;
        INSTALL) echo "🆕 .claude/settings.local.json 将创建";     ((will_do++)) ;;
    esac

    # 文档
    for key in "${!DECISIONS[@]}"; do
        [[ "$key" == doc:* ]] || continue
        local f="${key#doc:}"
        local action="${DECISIONS[$key]}"
        case "$action" in
            SKIP)             echo "🔴 $f 非空（跳过，请手动 review 模板）"; ((will_skip++)) ;;
            INSTALL)          echo "🆕 $f 将创建（模板）";                  ((will_do++)) ;;
            BACKUP_OVERWRITE) echo "🔄 $f 将覆盖（备份后）";                ((will_backup++)) ;;
        esac
    done

    # openspec config
    action="${DECISIONS[openspec/config.yaml]}"
    case "$action" in
        SKIP)             echo "🔴 openspec/config.yaml 已存在（跳过）"; ((will_skip++)) ;;
        INSTALL)          echo "🆕 openspec/config.yaml 将创建";        ((will_do++)) ;;
        BACKUP_OVERWRITE) echo "🔄 openspec/config.yaml 将覆盖（备份后）"; ((will_backup++)) ;;
    esac

    # HyperSpec 状态
    action="${DECISIONS[.hyperspec-state.yaml]}"
    case "$action" in
        INSTALL)          echo "🆕 .hyperspec-state.yaml 将初始化";    ((will_do++)) ;;
        PRESERVE)         echo "🔒 .hyperspec-state.yaml 已存在（绝不覆盖）"; ((will_skip++)) ;;
        BACKUP_OVERWRITE) echo "🔄 .hyperspec-state.yaml 将备份后覆盖"; ((will_backup++)) ;;
    esac

    echo "────────────────────────────────────────────────────────────"
    echo "将执行 $will_do 项操作，跳过 $will_skip 项，备份覆盖 $will_backup 项。"

    if [[ "$MODE" == "dryrun" ]]; then
        echo "🧪 dry-run 模式：不会写任何文件。"
    fi
}

# =============================================================================
# 用户确认
# =============================================================================
confirm_to_continue() {
    [[ "$ASSUME_YES" -eq 1 ]] && return 0
    echo
    read -r -p "继续？[y/N] " ans
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) echo "已取消。"; exit 0 ;;
    esac
}

# =============================================================================
# 初始化备份目录（仅在 --force 或有 BACKUP_OVERWRITE 时）
# =============================================================================
init_backup_dir() {
    local need_backup=0
    for key in "${!DECISIONS[@]}"; do
        case "${DECISIONS[$key]}" in
            BACKUP_OVERWRITE|BACKUP_OVERWRITE_IF_EXISTS) need_backup=1; break ;;
        esac
    done
    if [[ $need_backup -eq 1 ]]; then
        BACKUP_DIR="$BACKUP_ROOT"
        mkdir -p "$BACKUP_DIR"
        log_info "备份目录：${BACKUP_DIR#$PROJECT_ROOT/}"
    fi
}

# =============================================================================
# 执行：全局工具
# =============================================================================
install_global_tools() {
    log_step "处理全局工具（npm）"

    if ! has_cmd npm; then
        log_warn "npm 未安装，跳过全局工具。请手动安装：claude-code, openspec"
        return
    fi

    if [[ "${DECISIONS[claude-code]}" == "INSTALL" ]]; then
        npm install -g "@anthropic-ai/claude-code"
        log_info "已安装 claude-code"
    else
        log_info "claude-code：${DECISIONS[claude-code]}"
    fi

    if [[ "${DECISIONS[openspec]}" == "INSTALL" ]]; then
        npm install -g "@fission-ai/openspec"
        log_info "已安装 openspec"
    else
        log_info "openspec：${DECISIONS[openspec]}"
    fi
}

# =============================================================================
# 执行：项目级 skills
# =============================================================================
install_project_skills() {
    log_step "处理项目级 skills"

    # 外部 skills（来自社区）
    declare -A SKILL_SOURCES=(
        [superpowers]="obra/superpowers"
        [gstack]="garrytan/gstack"
        [HyperSpec]="wind7rui/HyperSpec"
        [ecc]="affaan-m/ecc"
    )

    for skill in "${!SKILL_SOURCES[@]}"; do
        local key="skill:$skill"
        local action="${DECISIONS[$key]}"
        local src="${SKILL_SOURCES[$skill]}"
        local target=".claude/skills/${skill,,}"

        case "$action" in
            SKIP)
                log_info "$skill：跳过（已存在）"
                ;;
            INSTALL)
                if has_cmd npx; then
                    npx skills add "$src" -y || log_warn "$skill 安装失败，请手动执行：npx skills add $src"
                else
                    log_warn "npx 不可用，请手动执行：npx skills add $src"
                fi
                ;;
            BACKUP_OVERWRITE)
                if [[ -n "$BACKUP_DIR" && -d "$target" ]]; then
                    cp -r "$target" "$BACKUP_DIR/${target#$PROJECT_ROOT/}"
                fi
                rm -rf "$target"
                if has_cmd npx; then
                    npx skills add "$src" -y || log_warn "$skill 重装失败"
                fi
                ;;
        esac
    done

    # quick-review 是本包内置 skill
    install_quick_review_skill
}

install_quick_review_skill() {
    local key="skill:quick-review"
    local action="${DECISIONS[$key]}"
    local target=".claude/skills/quick-review"
    local src="${SCRIPT_DIR}/skills/quick-review"

    case "$action" in
        INSTALL)
            mkdir -p "$target"
            if [[ -d "$src" ]]; then
                cp -r "$src/." "$target/"
                log_info "quick-review：已安装"
            else
                log_warn "quick-review 源文件缺失（$src 不存在）"
            fi
            ;;
        BACKUP_OVERWRITE)
            [[ -n "$BACKUP_DIR" && -d "$target" ]] && cp -r "$target" "$BACKUP_DIR/${target#$PROJECT_ROOT/}"
            rm -rf "$target"
            mkdir -p "$target"
            [[ -d "$src" ]] && cp -r "$src/." "$target/"
            log_info "quick-review：已更新到统一版本"
            ;;
    esac
}

# =============================================================================
# 执行：目录骨架
# =============================================================================
create_directory_skeleton() {
    log_step "创建目录骨架"
    for d in "${INFRA_DIRS[@]}"; do
        local key="dir:$d"
        [[ "${DECISIONS[$key]}" == "INSTALL" ]] || continue
        mkdir -p "$d"
        log_verbose "创建目录：$d"
    done
}

# =============================================================================
# 执行：Hooks（标准件，覆盖到统一版本）
# =============================================================================
install_hooks() {
    log_step "安装 Hooks（标准件，统一版本）"
    local src_dir="${SCRIPT_DIR}/hooks"
    local dst_dir="${PROJECT_ROOT}/.claude/hooks"
    mkdir -p "$dst_dir"

    for h in "${HOOK_FILES[@]}"; do
        local src="${src_dir}/${h}"
        local dst="${dst_dir}/${h}"

        if [[ ! -f "$src" ]]; then
            log_warn "Hook 源文件缺失：$src"
            continue
        fi

        if [[ -f "$dst" ]]; then
            [[ -n "$BACKUP_DIR" ]] && backup_file "$dst"
        fi

        cp -p "$src" "$dst"
        chmod +x "$dst" 2>/dev/null || true
        log_info "Hook：$h 已安装"
    done
}

# =============================================================================
# 执行：配置文件（深度合并）
# =============================================================================
install_settings() {
    log_step "配置 .claude/settings.local.json"
    local dst=".claude/settings.local.json"
    local action="${DECISIONS[settings.local.json]}"

    case "$action" in
        INSTALL)
            cat > "$dst" <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(mvn:*)",
      "Bash(npm:*)",
      "Read(**)",
      "Grep(**)",
      "Glob(**)"
    ],
    "deny": [
      "Write(./application.yml)",
      "Write(./application-*.yml)",
      "Write(./db/**)",
      "Write(./sql/**)"
    ]
  },
  "hooks": {
    "PreWrite": [
      { "type": "command", "command": "python .claude/hooks/guard_write.py" }
    ],
    "PreBash": [
      { "type": "command", "command": "python .claude/hooks/ensure_change_context.py" }
    ],
    "PostWrite": [
      { "type": "command", "command": "bash .claude/hooks/run_checks.sh", "matcher": "\\.java$" }
    ]
  },
  "mcpServers": {}
}
EOF
            log_info "settings.local.json：已创建"
            ;;
        MERGE)
            [[ -n "$BACKUP_DIR" ]] && backup_file "$dst"
            if has_cmd jq; then
                # 深度合并：保留用户键，缺失的键从模板补齐
                local tmp="${dst}.merged.$$"
                local template_json
                template_json=$(cat <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(mvn:*)",
      "Bash(npm:*)",
      "Read(**)",
      "Grep(**)",
      "Glob(**)"
    ],
    "deny": [
      "Write(./application.yml)",
      "Write(./application-*.yml)",
      "Write(./db/**)",
      "Write(./sql/**)"
    ]
  },
  "hooks": {
    "PreWrite": [
      { "type": "command", "command": "python .claude/hooks/guard_write.py" }
    ],
    "PreBash": [
      { "type": "command", "command": "python .claude/hooks/ensure_change_context.py" }
    ],
    "PostWrite": [
      { "type": "command", "command": "bash .claude/hooks/run_checks.sh", "matcher": "\\.java$" }
    ]
  },
  "mcpServers": {}
}
EOF
)
                # 用 jq 做深度合并（*.local.json + 模板）
                jq -s '.[0] as $a | .[1] as $b | $a * $b' "$dst" <(echo "$template_json") > "$tmp" \
                    && mv "$tmp" "$dst" \
                    || { rm -f "$tmp"; log_warn "jq 合并失败，保留原文件未改动"; }
                log_info "settings.local.json：已深度合并"
            else
                log_warn "jq 未安装，无法深度合并。原文件保留，请手动合并模板。"
            fi
            ;;
    esac
}

# =============================================================================
# 执行：项目文档
# =============================================================================
generate_project_docs() {
    log_step "生成项目文档"
    for f in "${DOC_FILES[@]}"; do
        local key="doc:$f"
        local action="${DECISIONS[$key]}"
        local src="${SCRIPT_DIR}/templates/${f}.template"

        case "$action" in
            INSTALL)
                if [[ -f "$src" ]]; then
                    cp -p "$src" "$f"
                    log_info "$f：已创建（模板）"
                else
                    log_warn "$f 模板缺失：$src"
                fi
                ;;
            SKIP)
                log_warn "$f：已存在且非空，跳过。模板见 ${src#$PROJECT_ROOT/}"
                ;;
            BACKUP_OVERWRITE)
                [[ -n "$BACKUP_DIR" ]] && backup_file "$f"
                [[ -f "$src" ]] && cp -p "$src" "$f"
                log_info "$f：已备份并覆盖为模板"
                ;;
        esac
    done
}

# =============================================================================
# 执行：openspec/config.yaml
# =============================================================================
generate_openspec_config() {
    log_step "生成 openspec/config.yaml"
    local dst="openspec/config.yaml"
    local action="${DECISIONS[$dst]}"
    local src="${SCRIPT_DIR}/config/openspec-config.yaml"

    case "$action" in
        INSTALL)
            if [[ -f "$src" ]]; then
                cp -p "$src" "$dst"
                log_info "$dst：已创建（请在 Claude Code 内让 AI 根据项目实际补全）"
            else
                log_warn "$src 模板缺失"
            fi
            ;;
        SKIP)
            log_warn "$dst：已存在，跳过。模板见 ${src#$PROJECT_ROOT/}"
            ;;
        BACKUP_OVERWRITE)
            [[ -n "$BACKUP_DIR" ]] && backup_file "$dst"
            [[ -f "$src" ]] && cp -p "$src" "$dst"
            log_info "$dst：已备份并覆盖"
            ;;
    esac
}

# =============================================================================
# 执行：HyperSpec 状态文件初始化
# =============================================================================
init_hyperspec_state() {
    log_step "初始化 HyperSpec 状态"
    local dst=".hyperspec-state.yaml"
    local action="${DECISIONS[$dst]}"

    case "$action" in
        INSTALL)
            cat > "$dst" <<'EOF'
# HyperSpec 运行时状态文件
# 此文件由 HyperSpec 自动维护，请勿手动编辑
version: 1
current_checkpoint: ""
current_phase: ""
history: []
EOF
            log_info "$dst：已初始化"
            ;;
        PRESERVE)
            log_info "$dst：已存在，保留运行时状态"
            ;;
        BACKUP_OVERWRITE)
            [[ -n "$BACKUP_DIR" ]] && backup_file "$dst"
            cat > "$dst" <<'EOF'
version: 1
current_checkpoint: ""
current_phase: ""
history: []
EOF
            log_info "$dst：已备份并重置"
            ;;
    esac
}

# =============================================================================
# 注册 MCP（OMC LSP/AST 工具）
# =============================================================================
register_mcp() {
    log_step "注册 OMC MCP（L5 工具精度层）"
    local dst=".claude/settings.local.json"

    if [[ -f "$dst" ]] && has_cmd jq; then
        # 检查是否已注册
        if jq -e '.mcpServers["oh-my-claudecode"]' "$dst" >/dev/null 2>&1; then
            log_info "OMC MCP 已注册，跳过"
            return
        fi

        if [[ "$MODE" == "dryrun" ]]; then
            echo "  [dryrun] 将向 $dst 追加 OMC MCP 配置"
            return
        fi

        local tmp="${dst}.tmp.$$"
        jq '.mcpServers["oh-my-claudecode"] = {
            "command": "omc",
            "args": ["serve"]
        }' "$dst" > "$tmp" && mv "$tmp" "$dst"
        log_info "OMC MCP 配置已追加"
        log_warn "请确保已运行 omc setup（详见 oh-my-claudecode 文档）"
    else
        log_warn "无法注册 MCP（$dst 不存在或 jq 不可用）"
    fi
}

# =============================================================================
# 总结报告
# =============================================================================
print_summary() {
    echo
    echo "============================================================"
    echo "✅ Harness V2 基础建设安装完成"
    echo "============================================================"
    echo
    echo "下一步："
    echo "  1. 启动 Claude Code：claude"
    echo "  2. 验证安装：/hyperspec --help"
    echo "  3. 让 AI 补全项目文档（AGENTS.md/CLAUDE.md/REVIEW.md/openspec/config.yaml）"
    echo
    if [[ -n "$BACKUP_DIR" ]]; then
        echo "📦 本次备份：${BACKUP_DIR#$PROJECT_ROOT/}"
        echo "   30 天后自动清理（编辑脚本 BACKUP_RETENTION_DAYS 调整）"
        echo
    fi
    if [[ "$MODE" == "dryrun" ]]; then
        echo "🧪 这是 dry-run，未实际写文件。去掉 --dry-run 重新执行以真正安装。"
    fi
    echo "📝 详细日志：${LOG_FILE#$PROJECT_ROOT/}"
}

write_backup_manifest() {
    [[ -z "$BACKUP_DIR" ]] && return
    local manifest="${BACKUP_DIR}/backup-manifest.json"
    {
        echo "{"
        echo "  \"backup_at\": \"$(date -Iseconds)\","
        echo "  \"backup_dir\": \"${BACKUP_DIR#$PROJECT_ROOT/}\","
        echo "  \"files\": ["
        local first=1
        for src in "${!BACKUP_MANIFEST[@]}"; do
            local dst="${BACKUP_MANIFEST[$src]}"
            if [[ $first -eq 1 ]]; then first=0; else echo ","; fi
            printf '    {"src": "%s", "dst": "%s"}' "$src" "${dst#$PROJECT_ROOT/}"
        done
        echo
        echo "  ]"
        echo "}"
    } > "$manifest"
}

# =============================================================================
# 主流程
# =============================================================================
main() {
    parse_args "$@"

    # 必须在项目根执行（检测 git）
    [[ -d ".git" ]] || [[ -f "AGENTS.md" ]] || {
        log_warn "当前目录不像项目根（无 .git 或 AGENTS.md）"
        read -r -p "仍要继续？[y/N] " ans
        [[ "$ans" =~ ^[yY] ]] || exit 0
    }

    # 清空日志
    : > "$LOG_FILE"
    write_log "==== 启动 init-harness-infra.sh ===="
    write_log "模式：$MODE  详细：$VERBOSE  自动确认：$ASSUME_YES"

    preflight_check
    print_preflight_report

    [[ "$MODE" == "dryrun" ]] && {
        echo
        echo "🧪 dry-run 完成，未执行任何写操作。"
        exit 0
    }

    confirm_to_continue

    init_backup_dir

    install_global_tools
    create_directory_skeleton
    install_project_skills
    install_hooks
    install_settings
    generate_project_docs
    generate_openspec_config
    init_hyperspec_state
    register_mcp

    write_backup_manifest
    write_log "==== 完成 ===="
    print_summary
}

main "$@"
