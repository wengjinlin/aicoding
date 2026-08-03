#!/usr/bin/env python3
# ensure_change_context.py — PreBash Hook
# 阻止在"无活跃变更"状态下执行风险命令（写代码/跑迁移/改 db）
#
# 设计理由：
#   Harness 的 L1 规范层要求先有变更工单（openspec/changes/<id>/）再动代码。
#   防止 AI"裸跑"——没有 change 上下文就写生产代码。

import json
import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
CHANGES_DIR = PROJECT_ROOT / "openspec" / "changes"

# 需要活跃 change 才能跑的命令模式
RISKY_PATTERNS = [
    r"\bgit\s+push\b",
    r"\bgit\s+reset\s+--hard\b",
    r"\bgit\s+clean\s+-[a-z]*f",
    r"\bmvn\s+deploy\b",
    r"\bmvn\s+release:",
    r"\bdocker\s+push\b",
    r"\bkubectl\s+apply\b",
    r"\bdrop\s+table\b",
    r"\btruncate\s+table\b",
    r"\bdelete\s+from\b",
]


def has_active_change() -> bool:
    """检测 openspec/changes/ 下是否有非空变更目录"""
    if not CHANGES_DIR.exists():
        return False
    for entry in CHANGES_DIR.iterdir():
        if entry.is_dir():
            # 目录里有 .md 文件视为活跃
            if any(entry.glob("*.md")):
                return True
    return False


def is_risky(command: str) -> bool:
    low = command.lower()
    for pattern in RISKY_PATTERNS:
        if re.search(pattern, low):
            return True
    return False


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    command = payload.get("command") or payload.get("bash_command") or ""
    if not command:
        sys.exit(0)

    # 安全放行只读命令
    if not is_risky(command):
        sys.exit(0)

    if has_active_change():
        sys.exit(0)

    msg = (
        f"\n🚫 ensure_change_context 拦截：当前无活跃变更工单\n"
        f"    命令：{command[:200]}{'...' if len(command) > 200 else ''}\n"
        f"    Harness L1 规范层要求：动代码前先创建变更工单。\n"
        f"    流程：\n"
        f"      1. /opsx:propose \"<变更描述>\"   生成 proposal/specs/design/tasks\n"
        f"      2. 人类审核 proposal\n"
        f"      3. /opsx:apply 或 /hyperspec     在 change 上下文下执行\n"
        f"    跳过此限制（仅紧急情况）：HARNESS_BYPASS=1 <原命令>\n"
    )
    print(msg, file=sys.stderr)

    # 检查环境变量 bypass
    if os.environ.get("HARNESS_BYPASS") == "1":
        print("⚠️  HARNESS_BYPASS=1 已设置，放行（请记录原因）。", file=sys.stderr)
        sys.exit(0)

    sys.exit(2)


if __name__ == "__main__":
    main()
