#!/usr/bin/env bash
# harness-infra/uninstall-harness-infra.sh
# 移除 Harness V2 基础建设（保留业务文档）
#
# 用法：
#   ./uninstall-harness-infra.sh           # 交互式（默认）
#   ./uninstall-harness-infra.sh --yes     # 跳过确认
#   ./uninstall-harness-infra.sh --purge   # 连业务文档一起删（谨慎）
#   ./uninstall-harness-infra.sh --help

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/.harness-uninstall-backup-$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=0
PURGE=0

log_info()  { echo -e "\033[32m[INFO]\033[0m  $*"; }
log_warn()  { echo -e "\033[33m[WARN]\033[0m  $*"; }
log_step()  { echo -e "\033[36m[STEP]\033[0m  $*"; }

die() { echo -e "\033[31m[ERROR]\033[0m $*" >&2; exit 1; }

# Harness 直接管理的目录/文件（默认删除）
HARNESS_PATHS=(
    ".claude"
    "openspec"
    "superpowers"
    "docs/harness"
    "docs/help"
    ".hyperspec-state.yaml"
    ".harness-install.log"
)

# 业务文档（默认保留，--purge 时才删）
BUSINESS_PATHS=(
    "AGENTS.md"
    "CLAUDE.md"
    "REVIEW.md"
    "docs/architecture"
    "docs/database"
    "docs/standards"
)

# npm 全局工具（默认保留，避免影响其他项目）
NPM_GLOBAL_TOOLS=("@anthropic-ai/claude-code" "@fission-ai/openspec")

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y) ASSUME_YES=1; shift ;;
            --purge)  PURGE=1; shift ;;
            --help|-h)
                cat <<EOF
用法：uninstall-harness-infra.sh [选项]

选项：
  --yes, -y    跳过确认提示
  --purge      连业务文档（AGENTS.md/CLAUDE.md/REVIEW.md/docs/architecture 等）一起删除
  --help, -h   显示此帮助

默认行为：
  - 删除 Harness 直接管理的目录（.claude/ openspec/ superpowers/ 等）
  - 保留业务文档和 docs/architecture、docs/database、docs/standards
  - 保留 npm 全局工具（避免影响其他项目）
  - 所有删除前先备份到 .harness-uninstall-backup-{date}/
EOF
                exit 0
                ;;
            *) die "未知选项：$1" ;;
        esac
    done
}

backup_path() {
    local src="$1"
    [[ -e "$src" ]] || return 0
    local rel="${src#./}"
    local dst="${BACKUP_DIR}/${rel}"
    mkdir -p "$(dirname "$dst")"
    if [[ -d "$src" ]]; then
        cp -r "$src" "$dst"
    else
        cp -p "$src" "$dst"
    fi
}

remove_path() {
    local src="$1"
    [[ -e "$src" ]] || { log_info "  已不存在：$src"; return; }
    rm -rf "$src"
    log_info "  已删除：$src"
}

main() {
    parse_args "$@"

    [[ -d ".git" ]] || log_warn "当前目录无 .git，可能不是项目根"

    echo
    echo "⚠️  即将移除 Harness V2 基础建设"
    echo "────────────────────────────────────────────────────────────"
    echo "将删除（Harness 直接管理）："
    printf '  - %s\n' "${HARNESS_PATHS[@]}"
    echo
    echo "将保留："
    printf '  - %s（业务文档）\n' "${BUSINESS_PATHS[@]}"
    echo "  - npm 全局工具（避免影响其他项目）"
    if [[ $PURGE -eq 1 ]]; then
        echo
        echo "🔴 --purge 模式：业务文档也会删除"
    fi
    echo "────────────────────────────────────────────────────────────"
    echo "所有删除内容会备份到：${BACKUP_DIR#$PROJECT_ROOT/}"
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
    for p in "${HARNESS_PATHS[@]}"; do
        backup_path "$p"
    done
    if [[ $PURGE -eq 1 ]]; then
        for p in "${BUSINESS_PATHS[@]}"; do
            backup_path "$p"
        done
    fi
    log_info "备份完成：${BACKUP_DIR#$PROJECT_ROOT/}"

    log_step "删除 Harness 路径"
    for p in "${HARNESS_PATHS[@]}"; do
        remove_path "$p"
    done

    if [[ $PURGE -eq 1 ]]; then
        log_step "删除业务文档（--purge）"
        for p in "${BUSINESS_PATHS[@]}"; do
            remove_path "$p"
        done
    fi

    echo
    echo "============================================================"
    echo "✅ Harness V2 基础建设已移除"
    echo "============================================================"
    echo
    echo "📦 备份：${BACKUP_DIR#$PROJECT_ROOT/}"
    echo "🔑 npm 全局工具保留（如需卸载：npm uninstall -g ${NPM_GLOBAL_TOOLS[*]})"
    if [[ $PURGE -eq 0 ]]; then
        echo "📄 业务文档保留：${BUSINESS_PATHS[*]}"
    fi
}

main "$@"
