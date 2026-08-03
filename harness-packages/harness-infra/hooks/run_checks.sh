#!/usr/bin/env bash
# run_checks.sh — PostWrite Hook
# Java 文件保存后自动编译检查（仅当改动 .java 文件时）
#
# 触发：Edit / Write 工具调用后，matcher 配置为 \.java$
# 行为：跑 mvn compile，编译失败时输出到 stderr（不阻塞会话）

set -uo pipefail

# 接收 hook 输入（Claude Code 把 payload 从 stdin 传入）
PAYLOAD="$(cat)"
FILE_PATH="$(echo "$PAYLOAD" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("file_path",""))' 2>/dev/null || echo "")"

# 非 .java 文件放行
[[ "$FILE_PATH" == *.java ]] || exit 0

# 找 Maven 可执行（按优先级）
MVN=""
for candidate in \
    "mvnw" \
    "mvnw.cmd" \
    "/c/Program Files/JetBrains/IntelliJ IDEA 2025.3/plugins/maven/lib/maven3/bin/mvn.cmd" \
    "mvn"; do
    if command -v "$candidate" >/dev/null 2>&1 || [[ -x "./$candidate" ]]; then
        MVN="$candidate"
        break
    fi
done

if [[ -z "$MVN" ]]; then
    # 没装 Maven 也算正常，跳过
    exit 0
fi

# JAVA_HOME 检查
if [[ -z "${JAVA_HOME:-}" ]]; then
    # 提示但放行
    echo "[run_checks] JAVA_HOME 未设置，跳过编译检查" >&2
    exit 0
fi

export JAVA_HOME

# 跑编译（静默模式，只关心失败）
OUTPUT="$("$MVN" -q -o compile 2>&1 || true)"

if echo "$OUTPUT" | grep -qE "BUILD FAILURE|ERROR"; then
    echo "[run_checks] 编译失败：$FILE_PATH" >&2
    echo "$OUTPUT" | grep -E "ERROR|error:" | head -20 >&2
    echo "" >&2
    echo "请修复编译错误后再继续。" >&2
    # 不 exit 非零——PostWrite hook 阻塞会打断 AI 思路
    # 仅提示，由 verification-before-completion 关卡把关
fi

exit 0
