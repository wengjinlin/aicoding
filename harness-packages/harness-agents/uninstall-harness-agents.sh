#!/usr/bin/env bash
# harness-agents/uninstall-harness-agents.sh
# 仅移除角色配置，保留 harness-infra 不动
#
# 用法：
#   ./uninstall-harness-agents.sh          # 交互式
#   ./uninstall-harness-agents.sh --yes    # 跳过确认
#   ./uninstall-harness-agents.sh --help

set -uo pipefail

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/.harness-agents-uninstall-backup-$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=0

log_info() { echo -e "\033[32m[INFO]\033[0m  $*"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m  $*"; }
log_step() { echo -e "\033[36m[STEP]\033[0m  $*"; }
die() { echo -e "\033[31m[ERROR]\033[0m $*" >&2; exit 1; }

# 包 B 添加的路径
AGENTS_PATHS=(
    ".claude/agents"
    ".claude/team-roles"
    ".claude/hooks/apply-role.sh"
    ".claude/logs/role-switch.log"
)

# 包 B 在 settings.local.json 注入的 SessionStart hook 命令
SESSIONSTART_TOKEN="apply-role.sh"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y) ASSUME_YES=1; shift ;;
            --help|-h)
                cat <<EOF
用法：uninstall-harness-agents.sh [选项]

选项：
  --yes, -y    跳过确认
  --help, -h   显示帮助

行为：
  - 删除 .claude/agents/、.claude/team-roles/、.claude/hooks/apply-role.sh
  - 从 .claude/settings.local.json 移除 SessionStart hook 中的 apply-role.sh
  - 保留 harness-infra 的所有内容（HyperSpec 仍可用，退化为无角色模式）
  - 删除前先备份
EOF
                exit 0
                ;;
            *) die "未知选项：$1" ;;
        esac
    done
}

backup_path() {
    [[ -e "$1" ]] || return 0
    local rel="${1#./}"
    local dst="${BACKUP_DIR}/${rel}"
    mkdir -p "$(dirname "$dst")"
    [[ -d "$1" ]] && cp -r "$1" "$dst" || cp -p "$1" "$dst"
}

remove_path() {
    [[ -e "$1" ]] || return 0
    rm -rf "$1"
    log_info "  已删除：$1"
}

remove_sessionstart_hook() {
    local dst=".claude/settings.local.json"
    [[ -f "$dst" ]] || return 0

    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq 不可用 — 请手动从 $dst 移除 SessionStart 数组中含 apply-role.sh 的项"
        return
    fi

    # 过滤掉 SessionStart 中 command 含 apply-role.sh 的项
    local tmp="${dst}.tmp.$$"
    if jq '
      if (.hooks.SessionStart // []) | length > 0
      then
        .hooks.SessionStart = ([.hooks.SessionStart[] | select(.command | test("apply-role.sh") | not)])
      else . end
    ' "$dst" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$dst"
        log_info "  已从 settings.local.json 移除 apply-role.sh"
    else
        rm -f "$tmp"
        log_warn "  修改 settings.local.json 失败（保留原文件）"
    fi
}

main() {
    parse_args

    echo
    echo "⚠️  即将移除 Harness Agent 角色包"
    echo "────────────────────────────────────────────────────────────"
    echo "将删除（仅角色包相关）："
    printf '  - %s\n' "${AGENTS_PATHS[@]}"
    echo "将从 .claude/settings.local.json 移除 SessionStart 中的 apply-role.sh"
    echo
    echo "保留（不动 harness-infra）："
    echo "  - .claude/skills/、.claude/hooks/{guard_write.py, ensure_change_context.py, run_checks.sh}"
    echo "  - openspec/、superpowers/、HyperSpec"
    echo "  - HyperSpec 仍可用，退化为无角色模式"
    echo "────────────────────────────────────────────────────────────"
    echo "备份：${BACKUP_DIR#$PROJECT_ROOT/}"
    echo

    if [[ $ASSUME_YES -eq 0 ]]; then
        read -r -p "确认卸载？[y/N] " ans
        case "$ans" in
            y|Y|yes|YES) ;;
            *) echo "已取消"; exit 0 ;;
        esac
    fi

    mkdir -p "$BACKUP_DIR"
    log_step "备份"
    for p in "${AGENTS_PATHS[@]}"; do
        backup_path "$p"
    done
    backup_path ".claude/settings.local.json"
    log_info "备份完成"

    log_step "删除角色包路径"
    for p in "${AGENTS_PATHS[@]}"; do
        remove_path "$p"
    done

    log_step "清理 settings.local.json"
    remove_sessionstart_hook

    echo
    echo "============================================================"
    echo "✅ Harness Agent 角色包已移除"
    echo "============================================================"
    echo
    echo "📦 备份：${BACKUP_DIR#$PROJECT_ROOT/}"
    echo "📄 HyperSpec 仍可用，/hyperspec 退化为无角色模式"
    echo "   如需完全卸载 Harness，再运行：./harness-infra/uninstall-harness-infra.sh"
}

main "$@"
