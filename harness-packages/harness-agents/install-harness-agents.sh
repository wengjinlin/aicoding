#!/usr/bin/env bash
# harness-agents/install-harness-agents.sh
# Harness V2 Agent 角色包 — 一键安装（基于 harness-infra 之上）
#
# 用法：
#   ./install-harness-agents.sh                # 默认：保守模式
#   ./install-harness-agents.sh --force        # 强制覆盖（自动备份）
#   ./install-harness-agents.sh --dry-run      # 预演
#   ./install-harness-agents.sh --verbose      # 详细日志
#   ./install-harness-agents.sh --yes          # 跳过确认
#
# 前置条件：harness-infra 已安装（.claude/skills/hyperspec 存在）

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"
BACKUP_ROOT="${PROJECT_ROOT}/.harness-agents-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${PROJECT_ROOT}/.harness-agents-install.log"

# 7 个角色 prompt
ROLE_AGENTS=(pm architect tech-lead developer reviewer tester devops)

# 配置文件
TEAM_ROLE_CONFIGS=(permissions.json checkpoint-map.yaml hyperspec-extend.yaml)

# 角色切换 hook
ROLE_HOOK="apply-role.sh"

MODE="conservative"
VERBOSE=0
ASSUME_YES=0
BACKUP_DIR=""

declare -A DECISIONS
declare -A BACKUP_MANIFEST

log_info()    { echo -e "\033[32m[INFO]\033[0m  $*"; }
log_warn()    { echo -e "\033[33m[WARN]\033[0m  $*"; }
log_error()   { echo -e "\033[31m[ERROR]\033[0m $*"; }
log_step()    { echo -e "\033[36m[STEP]\033[0m  $*"; }
log_verbose() { [[ $VERBOSE -eq 1 ]] && echo -e "\033[90m[DEBUG]\033[0m $*" || true; }

die() { log_error "$*"; exit 1; }

write_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

backup_file() {
    local src="$1"
    local rel="${src#$PROJECT_ROOT/}"
    local dst="${BACKUP_DIR}/${rel}"
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    BACKUP_MANIFEST["$rel"]="$dst"
}

# =============================================================================
# 参数解析
# =============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)    MODE="force"; shift ;;
            --dry-run)  MODE="dryrun"; ASSUME_YES=1; shift ;;
            --verbose|-v) VERBOSE=1; shift ;;
            --yes|-y)   ASSUME_YES=1; shift ;;
            --help|-h)
                cat <<EOF
用法：install-harness-agents.sh [选项]

选项：
  --force         强制覆盖（自动备份）
  --dry-run       预演，不写文件
  --verbose, -v   详细日志
  --yes, -y       跳过确认
  --help, -h      显示帮助

前置条件：harness-infra 已安装（.claude/skills/ 下有 hyperspec）
EOF
                exit 0
                ;;
            *) die "未知选项：$1" ;;
        esac
    done
}

# =============================================================================
# 前置检测：harness-infra 是否已装
# =============================================================================
check_infra_installed() {
    log_step "前置检测：harness-infra"

    local infra_ok=0
    # 检查 HyperSpec skill 是否存在（多种可能路径）
    for p in ".claude/skills/hyperspec" ".claude/skills/HyperSpec" ".claude/skills/wind7rui-hyperspec"; do
        if [[ -d "$p" ]]; then infra_ok=1; break; fi
    done
    # 备用检查：AGENTS.md 存在说明 infra 已初始化
    [[ $infra_ok -eq 0 && -f "AGENTS.md" ]] && infra_ok=2

    if [[ $infra_ok -eq 0 ]]; then
        die "未检测到 harness-infra。请先运行 ./harness-infra/init-harness-infra.sh"
    fi
    [[ $infra_ok -eq 2 ]] && log_warn "HyperSpec skill 路径未确认（但 AGENTS.md 存在）。建议确认 infra 完整安装后再继续。"

    log_info "harness-infra 已就绪"
}

# =============================================================================
# 预检
# =============================================================================
preflight() {
    log_step "预检：扫描角色配置"

    # 7 个角色 prompt
    for role in "${ROLE_AGENTS[@]}"; do
        local target=".claude/agents/${role}.md"
        if [[ -f "$target" ]]; then
            if [[ "$MODE" == "force" ]]; then
                DECISIONS["agent:$role"]="BACKUP_OVERWRITE"
            else
                DECISIONS["agent:$role"]="SKIP"
            fi
        else
            DECISIONS["agent:$role"]="INSTALL"
        fi
    done

    # team-roles 配置（标准件，每次覆盖）
    for cfg in "${TEAM_ROLE_CONFIGS[@]}"; do
        local target=".claude/team-roles/${cfg}"
        if [[ -f "$target" ]]; then
            DECISIONS["config:$cfg"]="BACKUP_OVERWRITE"
        else
            DECISIONS["config:$cfg"]="INSTALL"
        fi
    done

    # apply-role.sh hook（标准件，每次覆盖）
    local hook_target=".claude/hooks/${ROLE_HOOK}"
    if [[ -f "$hook_target" ]]; then
        DECISIONS["hook:${ROLE_HOOK}"]="BACKUP_OVERWRITE"
    else
        DECISIONS["hook:${ROLE_HOOK}"]="INSTALL"
    fi

    # settings.local.json 注入 SessionStart hook
    if [[ -f ".claude/settings.local.json" ]]; then
        DECISIONS["settings.local.json"]="MERGE"
    else
        # infra 未创建 settings.local.json 说明 infra 没装完整
        die ".claude/settings.local.json 不存在 — harness-infra 未完整安装"
    fi
}

print_preflight_report() {
    echo
    echo "🔍 预检报告（模式：${MODE}）"
    echo "────────────────────────────────────────────────────────────"

    local will_do=0 will_skip=0 will_backup=0

    # 角色
    for role in "${ROLE_AGENTS[@]}"; do
        local action="${DECISIONS[agent:$role]}"
        case "$action" in
            INSTALL)          echo "🆕 agent/${role}.md 将安装";       ((will_do++)) ;;
            SKIP)             echo "✅ agent/${role}.md 已存在（跳过）"; ((will_skip++)) ;;
            BACKUP_OVERWRITE) echo "🔄 agent/${role}.md 将覆盖（备份后）"; ((will_backup++)) ;;
        esac
    done

    # 配置
    for cfg in "${TEAM_ROLE_CONFIGS[@]}"; do
        local action="${DECISIONS[config:$cfg]}"
        case "$action" in
            INSTALL)          echo "🆕 team-roles/${cfg} 将创建";       ((will_do++)) ;;
            BACKUP_OVERWRITE) echo "🔄 team-roles/${cfg} 将覆盖（备份后）"; ((will_backup++)) ;;
        esac
    done

    # Hook
    local action="${DECISIONS[hook:${ROLE_HOOK}]}"
    case "$action" in
        INSTALL)          echo "🆕 hooks/${ROLE_HOOK} 将安装";       ((will_do++)) ;;
        BACKUP_OVERWRITE) echo "🔄 hooks/${ROLE_HOOK} 将覆盖（备份后）"; ((will_backup++)) ;;
    esac

    # settings.local.json
    echo "🔀 .claude/settings.local.json 将追加 SessionStart hook（深度合并）"; ((will_do++))

    echo "────────────────────────────────────────────────────────────"
    echo "将执行 $will_do 项，跳过 $will_skip 项，备份覆盖 $will_backup 项。"

    [[ "$MODE" == "dryrun" ]] && echo "🧪 dry-run：不会写任何文件。"
}

confirm_to_continue() {
    [[ $ASSUME_YES -eq 1 ]] && return 0
    echo
    read -r -p "继续？[y/N] " ans
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) echo "已取消。"; exit 0 ;;
    esac
}

init_backup_dir() {
    local need_backup=0
    for key in "${!DECISIONS[@]}"; do
        [[ "${DECISIONS[$key]}" == "BACKUP_OVERWRITE" ]] && { need_backup=1; break; }
    done
    if [[ $need_backup -eq 1 ]]; then
        BACKUP_DIR="$BACKUP_ROOT"
        mkdir -p "$BACKUP_DIR"
        log_info "备份目录：${BACKUP_DIR#$PROJECT_ROOT/}"
    fi
}

# =============================================================================
# 安装 7 个角色 prompt
# =============================================================================
install_role_agents() {
    log_step "安装角色 prompt"
    local src_dir="${SCRIPT_DIR}/agents"
    local dst_dir="${PROJECT_ROOT}/.claude/agents"
    mkdir -p "$dst_dir"

    for role in "${ROLE_AGENTS[@]}"; do
        local src="${src_dir}/${role}.md"
        local dst="${dst_dir}/${role}.md"
        local action="${DECISIONS[agent:$role]}"

        [[ "$action" == "SKIP" ]] && { log_info "${role}.md：跳过"; continue; }

        if [[ ! -f "$src" ]]; then
            log_warn "${role}.md 源文件缺失：$src"
            continue
        fi

        if [[ -f "$dst" ]]; then
            [[ -n "$BACKUP_DIR" ]] && backup_file "$dst"
        fi

        cp -p "$src" "$dst"
        log_info "${role}.md：$action"
    done
}

# =============================================================================
# 安装 team-roles 配置
# =============================================================================
install_team_role_configs() {
    log_step "安装 team-roles 配置"
    local src_dir="${SCRIPT_DIR}/team-roles"
    local dst_dir="${PROJECT_ROOT}/.claude/team-roles"
    mkdir -p "$dst_dir"

    for cfg in "${TEAM_ROLE_CONFIGS[@]}"; do
        local src="${src_dir}/${cfg}"
        local dst="${dst_dir}/${cfg}"
        local action="${DECISIONS[config:$cfg]}"

        if [[ ! -f "$src" ]]; then
            log_warn "${cfg} 源文件缺失：$src"
            continue
        fi

        if [[ -f "$dst" ]]; then
            [[ -n "$BACKUP_DIR" ]] && backup_file "$dst"
        fi

        cp -p "$src" "$dst"
        log_info "team-roles/${cfg}：$action"
    done
}

# =============================================================================
# 安装 apply-role.sh hook
# =============================================================================
install_role_hook() {
    log_step "安装 apply-role.sh hook"
    local src="${SCRIPT_DIR}/hooks/${ROLE_HOOK}"
    local dst="${PROJECT_ROOT}/.claude/hooks/${ROLE_HOOK}"

    if [[ ! -f "$src" ]]; then
        die "源 hook 缺失：$src"
    fi

    if [[ -f "$dst" ]]; then
        [[ -n "$BACKUP_DIR" ]] && backup_file "$dst"
    fi

    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    chmod +x "$dst" 2>/dev/null || true
    log_info "${ROLE_HOOK}：已安装"
}

# =============================================================================
# 修改 settings.local.json：注入 SessionStart hook
# =============================================================================
inject_session_start_hook() {
    log_step "注入 SessionStart hook（深度合并 settings.local.json）"
    local dst=".claude/settings.local.json"

    [[ ! -f "$dst" ]] && die "$dst 不存在"

    if ! has_cmd jq; then
        log_warn "jq 不可用，无法自动注入。请手动在 $dst 添加 SessionStart hook 调用 apply-role.sh"
        return
    fi

    if [[ "$MODE" == "dryrun" ]]; then
        echo "  [dryrun] 将向 $dst 追加 SessionStart hook 配置"
        return
    fi

    [[ -n "$BACKUP_DIR" ]] && backup_file "$dst"

    local tmp="${dst}.tmp.$$"
    # 在 hooks.SessionStart 数组中追加 apply-role.sh（若已存在则不重复）
    jq '
      .hooks = (.hooks // {})
      | .hooks.SessionStart = ((.hooks.SessionStart // []) + [{
          "type": "command",
          "command": "bash .claude/hooks/apply-role.sh"
        }])
      | .hooks.SessionStart |= unique_by(.command)
    ' "$dst" > "$tmp" && mv "$tmp" "$dst" || {
        rm -f "$tmp"
        log_warn "jq 注入失败，请手动添加"
        return
    }

    log_info "SessionStart hook 已注入（幂等，重跑不会重复）"
}

# =============================================================================
# 总结
# =============================================================================
print_summary() {
    echo
    echo "============================================================"
    echo "✅ Harness V2 Agent 角色包安装完成"
    echo "============================================================"
    echo
    echo "下一步："
    echo "  1. 启动 Claude Code：claude"
    echo "  2. 运行 /hyperspec — 每个 checkpoint 会自动切换角色"
    echo "  3. 查看角色切换日志：.claude/logs/role-switch.log"
    echo
    echo "已安装："
    echo "  • 7 个角色 prompt：.claude/agents/{pm,architect,tech-lead,developer,reviewer,tester,devops}.md"
    echo "  • 配置文件：.claude/team-roles/{permissions.json,checkpoint-map.yaml,hyperspec-extend.yaml}"
    echo "  • 角色切换 hook：.claude/hooks/apply-role.sh"
    echo "  • SessionStart hook 已注入 .claude/settings.local.json"
    echo
    [[ -n "$BACKUP_DIR" ]] && echo "📦 本次备份：${BACKUP_DIR#$PROJECT_ROOT/}"
    [[ "$MODE" == "dryrun" ]] && echo "🧪 dry-run 未写文件，去掉 --dry-run 重新执行以安装。"
    echo "📝 详细日志：${LOG_FILE#$PROJECT_ROOT/}"
}

main() {
    parse_args
    : > "$LOG_FILE"
    write_log "==== 启动 install-harness-agents.sh ===="

    check_infra_installed
    preflight
    print_preflight_report

    [[ "$MODE" == "dryrun" ]] && { echo; echo "🧪 dry-run 完成。"; exit 0; }

    confirm_to_continue

    init_backup_dir
    install_role_agents
    install_team_role_configs
    install_role_hook
    inject_session_start_hook

    write_log "==== 完成 ===="
    print_summary
}

main "$@"
