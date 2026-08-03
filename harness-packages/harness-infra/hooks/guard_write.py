#!/usr/bin/env python3
# guard_write.py — PreWrite Hook
# 拦截对保护目录/文件的写入，防止 AI 误改配置文件、SQL 脚本、生产数据
#
# 触发：每次 Edit / Write 工具调用前
# 返回：非零退出码则阻止写入

import json
import os
import re
import sys
from pathlib import Path

# 保护清单（相对项目根，支持 glob）
PROTECTED_PATTERNS = [
    r"^application\.yml$",
    r"^application-.+\.yml$",
    r"^application\.properties$",
    r"^application-.+\.properties$",
    r"^db/.*$",
    r"^sql/.*$",
    r"^.*\.env$",
    r"^.*\.env\.local$",
    r"^.*credentials.*$",
    r"^.*secrets.*$",
    r"^.?pem$",
    r"^id_rsa.*$",
]

# 当前脚本所在推算项目根
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent


def normalize_path(file_path: str) -> str:
    """将传入路径归一化为相对项目根的 POSIX 路径"""
    p = Path(file_path)
    if not p.is_absolute():
        p = (PROJECT_ROOT / p).resolve()
    try:
        rel = p.relative_to(PROJECT_ROOT)
    except ValueError:
        return str(p)
    return rel.as_posix()


def is_protected(rel_path: str) -> bool:
    for pattern in PROTECTED_PATTERNS:
        if re.match(pattern, rel_path):
            return True
    return False


def main():
    # Hook 协议：从 stdin 读 JSON
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        # 非 JSON 输入，放行（开发期调试友好）
        sys.exit(0)

    file_path = payload.get("file_path") or payload.get("path") or ""
    if not file_path:
        sys.exit(0)

    rel = normalize_path(file_path)

    if is_protected(rel):
        # 输出到 stderr 给 Claude Code 显示
        msg = (
            f"\n🛡️  guard_write 拦截：{rel}\n"
            f"    此路径受 Harness 安全保护层保护。\n"
            f"    如需修改，请：\n"
            f"      1. 在 openspec/changes/ 下创建变更工单\n"
            f"      2. 显式声明修改此文件的理由\n"
            f"      3. 由人类审核后执行\n"
        )
        print(msg, file=sys.stderr)
        # 非零退出码阻止写入
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
