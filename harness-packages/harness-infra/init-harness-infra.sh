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

# GitHub 网络重试参数（应对国内网络抖动，时通时不通）
# 默认值：探测 5 次/单次 4s 超时/间隔 1s — 最坏总耗时约 25s
# 实测在 20% 成功率的网络下，5 次尝试全失败概率约 33%（vs 3 次的 51%）
# 如果你的网络特别差，可在脚本开头改大 GITHUB_PROBE_MAX_ATTEMPTS
GITHUB_PROBE_MAX_ATTEMPTS=5      # 探测最大尝试次数
GITHUB_PROBE_TIMEOUT=4           # 单次探测超时（秒）
GITHUB_PROBE_INTERVAL=1          # 探测失败后等待间隔（秒）
SKILLS_INSTALL_MAX_ATTEMPTS=3    # 单 skill 克隆最大尝试次数（克隆较慢，3 次足够）
SKILLS_INSTALL_INTERVAL=3        # 克隆失败后等待间隔（秒）

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

# GitHub 探测相关状态
GITHUB_REACHABLE=0             # 0=未知/不通  1=可达
GITHUB_SKIPPED=0               # 0=未跳过     1=用户选择跳过 skills
GITHUB_SKIPPED_SKILLS=()       # 待人工拷贝的 skill 名称列表

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
# GitHub 连通性探测：skills 通过 git clone 装，npm 镜像管不到
# 策略：N 次探测全部通过才算"稳定可达"，直接继续；
#       任一次失败即视为"波动"，弹菜单让用户选择（默认：忽略波动继续装）
# =============================================================================
check_github_connectivity() {
    log_step "测试 GitHub 连通性（共 $GITHUB_PROBE_MAX_ATTEMPTS 次，全部通过才算稳定）"

    if ! has_cmd curl; then
        log_warn "未检测到 curl — 跳过 GitHub 连通性测试。如后续 skills 安装失败，请检查网络。"
        GITHUB_SKIPPED=1
        GITHUB_SKIPPED_SKILLS=("${PROJECT_SKILLS[@]}")
        return 1
    fi

    local passed=0 failed=0
    local attempt=0
    local http_code="000"

    while [[ $attempt -lt $GITHUB_PROBE_MAX_ATTEMPTS ]]; do
        attempt=$((attempt + 1))
        # curl 失败（超时/DNS 解析失败）时 -w 仍会输出 "000"
        http_code=$(curl -sI -o /dev/null -w "%{http_code}" --max-time "$GITHUB_PROBE_TIMEOUT" https://github.com 2>/dev/null)
        http_code="${http_code:-000}"

        local is_ok=0
        case "$http_code" in
            200|301|302|307|308)
                passed=$((passed + 1))
                is_ok=1
                log_verbose "第 $attempt/$GITHUB_PROBE_MAX_ATTEMPTS 次：✅ HTTP $http_code"
                ;;
            *)
                failed=$((failed + 1))
                log_warn "第 $attempt/$GITHUB_PROBE_MAX_ATTEMPTS 次：❌ HTTP $http_code"
                ;;
        esac

        # 失败后等待网络恢复；成功立即继续下一次（节省时间）
        [[ $is_ok -eq 0 && $attempt -lt $GITHUB_PROBE_MAX_ATTEMPTS ]] && sleep "$GITHUB_PROBE_INTERVAL"
    done

    # 全通才算稳定可达
    if [[ $failed -eq 0 ]]; then
        log_info "✅ GitHub 稳定可达（$passed/$GITHUB_PROBE_MAX_ATTEMPTS 次全通过）"
        GITHUB_REACHABLE=1
        return 0
    fi

    # 有波动
    log_warn "🌐 GitHub 连通性波动：$GITHUB_PROBE_MAX_ATTEMPTS 次中通过 $passed 次，失败 $failed 次"
    log_warn "网络不稳定，部分 skill 克隆可能失败。请选择处理方式。"
    prompt_github_fallback "$passed" "$failed"
    return $?
}

# GitHub 不通或波动时的交互菜单（三选一）
# 参数：$1=passed  $2=failed  （用于显示波动程度）
prompt_github_fallback() {
    local passed="${1:-0}"
    local failed="${2:-0}"

    # dryrun 模式：只打印决策不交互；默认按选项 3 模拟（不跳过）
    if [[ "$MODE" == "dryrun" ]]; then
        echo "  [dryrun] 实际运行会弹菜单（默认选项 3：忽略波动继续安装）"
        return 0
    fi

    # 非交互模式（--yes）：默认选项 3（推荐项）
    if [[ "$ASSUME_YES" -eq 1 ]]; then
        log_warn "非交互模式（--yes）：默认选择「忽略波动继续安装」"
        log_warn "失败的 skill 将在末尾列入待拷贝清单"
        return 0
    fi

    cat <<EOF

  ┌──────────────────────────────────────────────────────────┐
  │  GitHub 网络波动（通过 $passed 次 / 失败 $failed 次），请选择：│
  ├──────────────────────────────────────────────────────────┤
  │  1) 配置 HTTPS_PROXY 环境变量（当前会话有效）              │
  │     → 输入代理地址，自动 export，重新探测（严格判定）       │
  │  2) 跳过 skills 安装，继续装其他组件                       │
  │     → 后期手动从其他机器拷贝 skills 目录                   │
  │  3) 忽略波动继续安装（推荐）                               │
  │     → 直接尝试克隆；失败的单个 skill 自动重试 3 次后入清单  │
  └──────────────────────────────────────────────────────────┘
EOF

    local choice
    while true; do
        read -r -p "请选择 [1/2/3，默认 3]: " choice
        choice="${choice:-3}"
        case "$choice" in
            1)
                if prompt_proxy_and_export; then
                    # 用新代理严格重测（必须全部通过才算稳定）
                    log_info "使用新代理重测 GitHub（共 $GITHUB_PROBE_MAX_ATTEMPTS 次，全部通过才算稳定）..."
                    local probe_passed=0 probe_failed=0
                    local probe_attempt=0
                    local probe_code="000"
                    while [[ $probe_attempt -lt $GITHUB_PROBE_MAX_ATTEMPTS ]]; do
                        probe_attempt=$((probe_attempt + 1))
                        probe_code=$(curl -sI -o /dev/null -w "%{http_code}" --max-time "$GITHUB_PROBE_TIMEOUT" https://github.com 2>/dev/null)
                        probe_code="${probe_code:-000}"
                        case "$probe_code" in
                            200|301|302|307|308)
                                probe_passed=$((probe_passed + 1))
                                log_verbose "代理后第 $probe_attempt/$GITHUB_PROBE_MAX_ATTEMPTS 次：✅ HTTP $probe_code"
                                ;;
                            *)
                                probe_failed=$((probe_failed + 1))
                                log_warn "代理后第 $probe_attempt/$GITHUB_PROBE_MAX_ATTEMPTS 次：❌ HTTP $probe_code"
                                [[ $probe_attempt -lt $GITHUB_PROBE_MAX_ATTEMPTS ]] && sleep "$GITHUB_PROBE_INTERVAL"
                                ;;
                        esac
                    done

                    if [[ $probe_failed -eq 0 ]]; then
                        log_info "✅ 代理后稳定可达（$probe_passed/$GITHUB_PROBE_MAX_ATTEMPTS 全通过），继续安装"
                        GITHUB_REACHABLE=1
                        return 0
                    fi

                    log_warn "代理生效后仍波动（通过 $probe_passed 次，失败 $probe_failed 次）"
                    log_warn "返回主菜单，可选择 3 忽略波动继续"
                    # 回到主菜单循环
                    continue
                fi
                # 用户取消了代理输入，循环回主菜单
                ;;
            2)
                log_info "已跳过 GitHub skills 安装。其他组件（hooks/配置/文档）继续。"
                GITHUB_SKIPPED=1
                GITHUB_SKIPPED_SKILLS=("${PROJECT_SKILLS[@]}")
                return 1
                ;;
            3)
                log_info "忽略波动，继续尝试安装 skills。"
                log_info "每个 skill 自动重试 $SKILLS_INSTALL_MAX_ATTEMPTS 次；仍失败的将列入末尾的待拷贝清单。"
                # 不设 GITHUB_SKIPPED=1，进入正常安装流程
                return 0
                ;;
            *)
                echo "请输入 1、2 或 3"
                ;;
        esac
    done
}

# 让用户输入代理地址并自动 export
prompt_proxy_and_export() {
    while true; do
        echo
        echo "代理地址格式：http://host:port 或 https://host:port"
        echo "示例："
        echo "  http://proxy.company.com:8080"
        echo "  http://127.0.0.1:7890       (Clash 默认)"
        echo "  http://127.0.0.1:10809      (V2Ray 默认)"
        echo "  http://127.0.0.1:1080       (SS/SSR 默认)"
        read -r -p "代理地址（直接回车取消）: " proxy

        if [[ -z "$proxy" ]]; then
            log_warn "已取消代理输入，返回主菜单"
            return 1
        fi

        # 校验：必须以 http:// 或 https:// 开头
        if [[ ! "$proxy" =~ ^https?://[A-Za-z0-9._-]+:[0-9]+$ ]]; then
            log_warn "格式不对，应为 http://host:port 或 https://host:port"
            continue
        fi

        # 设置环境变量（仅当前 shell 会话有效）
        export HTTPS_PROXY="$proxy"
        export HTTP_PROXY="$proxy"
        log_info "已 export HTTPS_PROXY=$proxy"
        log_info "已 export HTTP_PROXY=$proxy"
        log_warn "注意：仅当前 shell 会话有效，关闭终端后失效。如需永久生效请用 git config --global http.proxy"
        return 0
    done
}

# =============================================================================
# 预检：扫描所有组件，记录决策
# =============================================================================
preflight_check() {
    log_step "预检：扫描系统状态"

    # 0. 硬依赖：jq（settings.local.json 深度合并、OMC MCP 注册都依赖）
    #    dryrun 模式只 warn（不写文件，让用户先看完整预检报告），其他模式直接 die
    if ! has_cmd jq; then
        local jq_install_hint="未检测到 jq — settings.local.json 深度合并、OMC MCP 注册都依赖它。

安装方式：
  Windows (Git Bash): winget install jqlang.jq --source winget
                     或 scoop install jq
                     或从 https://github.com/jqlang/jq/releases 下载 jq-windows-amd64.exe，
                       重命名 jq.exe 放到 PATH 中（如 C:\\Users\\<你>\\bin\\）
  macOS (Homebrew):   brew install jq
  Linux (Debian):     sudo apt-get install jq
  Linux (RHEL/Fedora): sudo dnf install jq"

        if [[ "$MODE" == "dryrun" ]]; then
            log_warn "$jq_install_hint"
        else
            die "$jq_install_hint"
        fi
    fi

    # 0.5 软依赖：python（hooks 调用 .claude/hooks/*.py 需要）。脚本本身不调用，只 warn
    if ! has_cmd python && ! has_cmd python3; then
        log_warn "未检测到 python — Hooks (guard_write.py / ensure_change_context.py) 需要 Python 才能运行。请安装 Python 3.x 并确保在 PATH 中。"
    fi

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

    # 9. GitHub 连通性探测（skills 克隆依赖；失败只 warn，让用户决定）
    check_github_connectivity
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
# 单 skill 克隆（封装重试逻辑，应对网络抖动）
# 用法：install_skill_via_npx <skill_name> <github_source>
# 返回：0=成功（含已存在的逻辑）  1=失败（已重试 SKILLS_INSTALL_MAX_ATTEMPTS 次仍失败）
# =============================================================================
install_skill_via_npx() {
    local skill="$1"
    local src="$2"

    if ! has_cmd npx; then
        log_warn "npx 不可用，请手动执行：npx skills add $src"
        return 1
    fi

    # 慢网优化（仅当前 shell 会话有效，不污染用户 git 全局配置）
    # - http.lowSpeedLimit=0 + http.lowSpeedTime=999999：关闭"低速持续 N 秒就断开"
    # - http.postBuffer=524288000（500MB）：增大 POST 缓冲，降低大仓库握手被截断概率
    # npx skills add 内部调用 git clone，会继承这些环境变量
    export GIT_CONFIG_PARAMETERS="'http.lowSpeedLimit=0' 'http.lowSpeedTime=999999' 'http.postBuffer=524288000'"

    local attempt=0
    while [[ $attempt -lt $SKILLS_INSTALL_MAX_ATTEMPTS ]]; do
        attempt=$((attempt + 1))
        if [[ $attempt -eq 1 ]]; then
            log_info "$skill：克隆中（来源 $src）..."
        else
            log_info "$skill：第 $attempt/$SKILLS_INSTALL_MAX_ATTEMPTS 次尝试..."
        fi
        if npx skills add "$src" -y; then
            if [[ $attempt -gt 1 ]]; then
                log_info "$skill：✅ 第 $attempt 次尝试成功"
            fi
            return 0
        fi
        if [[ $attempt -lt $SKILLS_INSTALL_MAX_ATTEMPTS ]]; then
            log_warn "$skill 第 $attempt 次克隆失败，${SKILLS_INSTALL_INTERVAL}s 后重试..."
            sleep "$SKILLS_INSTALL_INTERVAL"
        fi
    done

    log_warn "$skill：连续 $SKILLS_INSTALL_MAX_ATTEMPTS 次克隆失败"
    return 1
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

        # 用户选择跳过 GitHub skills：直接跳过；仅未安装的才列入待拷贝清单
        if [[ "$GITHUB_SKIPPED" -eq 1 ]]; then
            if [[ "$action" == "INSTALL" ]]; then
                log_warn "$skill：跳过（用户选择跳过 GitHub skills）— 后期手动拷贝"
                GITHUB_SKIPPED_SKILLS+=("$skill")
            else
                log_info "$skill：已存在，无需拷贝"
            fi
            continue
        fi

        case "$action" in
            SKIP)
                log_info "$skill：跳过（已存在）"
                ;;
            INSTALL)
                if install_skill_via_npx "$skill" "$src"; then
                    :
                else
                    GITHUB_SKIPPED_SKILLS+=("$skill")
                fi
                ;;
            BACKUP_OVERWRITE)
                if [[ -n "$BACKUP_DIR" && -d "$target" ]]; then
                    local bdst="$BACKUP_DIR/${target#$PROJECT_ROOT/}"
                    mkdir -p "$(dirname "$bdst")"
                    cp -r "$target" "$bdst"
                fi
                rm -rf "$target"
                # 本地版本已删除，重装；失败则加入清单（用户需重装）
                if install_skill_via_npx "$skill" "$src"; then
                    :
                else
                    log_warn "$skill：本地已删除但重装失败，已加入待拷贝清单"
                    GITHUB_SKIPPED_SKILLS+=("$skill")
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
            if [[ -n "$BACKUP_DIR" && -d "$target" ]]; then
                local bdst="$BACKUP_DIR/${target#$PROJECT_ROOT/}"
                mkdir -p "$(dirname "$bdst")"
                cp -r "$target" "$bdst"
            fi
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
    "PreToolUse": [
      {
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
          { "type": "command", "command": "python .claude/hooks/guard_write.py" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "python .claude/hooks/ensure_change_context.py" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/run_checks.sh" }
        ]
      }
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
    "PreToolUse": [
      {
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
          { "type": "command", "command": "python .claude/hooks/guard_write.py" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "python .claude/hooks/ensure_change_context.py" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/run_checks.sh" }
        ]
      }
    ]
  },
  "mcpServers": {}
}
EOF
)
                # 用 jq 做深度合并（*.local.json + 模板）
                # 注意：原写法 `jq ... <(echo "$template_json")` 用了进程替换，
                # Windows 原生 jq 不识别 MSYS 的 /proc/<pid>/fd/63 伪路径，会报错。
                # 改成 mktemp 写入临时文件再读取，跨平台兼容。
                local tmpl_file
                tmpl_file=$(mktemp)
                printf '%s' "$template_json" > "$tmpl_file"
                jq -s '.[0] as $a | .[1] as $b | $a * $b' "$dst" "$tmpl_file" > "$tmp" \
                    && { rm -f "$tmpl_file"; mv "$tmp" "$dst"; } \
                    || { rm -f "$tmpl_file" "$tmp"; log_warn "jq 合并失败，保留原文件未改动"; }
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
    echo "==================== 复制下面整段 prompt 粘贴到 Claude Code 执行 ===================="
    echo
    cat <<'PROMPT_EOF'
请按本项目实际补全 4 个文档：AGENTS.md / CLAUDE.md / REVIEW.md / openspec/config.yaml

步骤：
1. 探测技术栈：检查根目录 pom.xml/build.gradle/package.json/go.mod 等确定语言、构建工具、ORM、测试框架；扫描 src/ 主要包结构；读 README.md（如有）
2. 按每个文件顶部的模板注释逐个补全：
   - AGENTS.md / CLAUDE.md / REVIEW.md：填项目名、构建命令、测试命令、关键目录、协作规则
   - openspec/config.yaml：补全 project.*、tech_stack.*（model_routing.* 保持模板默认即可）
3. 要求：只填 TODO 或空字段，不重写已存在内容；探测不到的字段保留空字符串或 TODO，不要瞎猜；完成后用一段话总结每个文件改了哪些字段
4. 如关键信息探测不到（根目录无任何构建文件），先问我项目类型再继续，不要凭空猜测
PROMPT_EOF
    echo
    echo "==================================== 复制结束 ===================================="
    echo
    if [[ -n "$BACKUP_DIR" ]]; then
        echo "📦 本次备份：${BACKUP_DIR#$PROJECT_ROOT/}"
        echo "   30 天后自动清理（编辑脚本 BACKUP_RETENTION_DAYS 调整）"
        echo
    fi

    # 待人工拷贝的 skills 清单（用户选跳过或安装失败导致）
    if [[ ${#GITHUB_SKIPPED_SKILLS[@]} -gt 0 ]]; then
        local -A src_to_skill=(
            [superpowers]="obra/superpowers"
            [gstack]="garrytan/gstack"
            [HyperSpec]="wind7rui/HyperSpec"
            [ecc]="affaan-m/ecc"
        )

        echo "⚠️  待人工处理的 skills（共 ${#GITHUB_SKIPPED_SKILLS[@]} 个）：$(IFS=,; echo "${GITHUB_SKIPPED_SKILLS[*]}")"
        echo "────────────────────────────────────────────────────────────"
        echo "原因：GitHub 不可达或克隆失败（多次重试后）。"
        echo

        echo "  详细信息："
        for skill in "${GITHUB_SKIPPED_SKILLS[@]}"; do
            local src="${src_to_skill[$skill]:-unknown}"
            local lower="${skill,,}"
            echo "    • $skill"
            echo "      GitHub : https://github.com/$src"
            echo "      目标路径: .claude/skills/$lower/"
        done
        echo

        echo "═══════════════════════════════════════════════════════════"
        echo "🚀 方案 A：修复网络后在本项目根一键重装（推荐）"
        echo "═══════════════════════════════════════════════════════════"
        echo
        echo "  # 1. 进入项目根（当前你已经在：${PROJECT_ROOT#$PROJECT_ROOT/..\/}）"
        echo "  cd \"${PROJECT_ROOT}\""
        echo
        echo "  # 2. 如需代理（公司内网）：取消下面一行注释并改地址"
        echo "  # export HTTPS_PROXY=http://your-proxy:port"
        echo "  # export HTTP_PROXY=http://your-proxy:port"
        echo
        echo "  # 3. 慢网优化（应对抖动网络）"
        echo "  export GIT_CONFIG_PARAMETERS=\"'http.lowSpeedLimit=0' 'http.lowSpeedTime=999999' 'http.postBuffer=524288000'\""
        echo
        echo "  # 4. 逐个安装失败的 skills"
        for skill in "${GITHUB_SKIPPED_SKILLS[@]}"; do
            local src="${src_to_skill[$skill]:-unknown}"
            echo "  npx skills add $src -y"
        done
        echo
        echo "  # 5. 验证（每个应输出 OK）"
        for skill in "${GITHUB_SKIPPED_SKILLS[@]}"; do
            local lower="${skill,,}"
            echo "  ls .claude/skills/$lower/SKILL.md >/dev/null 2>&1 && echo \"$skill OK\" || echo \"$skill MISSING\""
        done
        echo
        echo "═══════════════════════════════════════════════════════════"
        echo "📦 方案 B：从已装好的机器拷贝（公司禁 GitHub 时用）"
        echo "═══════════════════════════════════════════════════════════"
        echo
        echo "  # 在源机器（已装好 harness-infra 的项目）执行："
        echo "  cd <源项目根>"
        local tar_targets=""
        for skill in "${GITHUB_SKIPPED_SKILLS[@]}"; do
            local lower="${skill,,}"
            tar_targets="$tar_targets $lower"
        done
        echo "  tar czf skills.tar.gz -C .claude/skills$tar_targets"
        echo
        echo "  # 拷贝 skills.tar.gz 到本项目根后解压："
        echo "  cd \"${PROJECT_ROOT}\""
        echo "  tar xzf skills.tar.gz -C .claude/skills/"
        echo "  rm skills.tar.gz"
        echo
        echo "  # 重启 Claude Code 会话验证：claude → /<skill-name> --help"
        echo "────────────────────────────────────────────────────────────"
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
