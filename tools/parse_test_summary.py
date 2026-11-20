#!/usr/bin/env python3
"""Extract the final assertion counters from the repository's test summaries."""

from pathlib import Path
import re
import sys


def parse(text: str) -> tuple[int, int, int]:
    patterns = [
        r"Total Tests Run:\s*(\d+)\s+Passed Assertions:\s*(\d+)\s+Failed Assertions:\s*(\d+)",
        r"Total Assertions:\s*(\d+)\s+Passed Assertions:\s*(\d+)\s+Failed Assertions:\s*(\d+)",
        r"SUMMARY:\s*(\d+) total assertions,\s*(\d+) passed,\s*(\d+) failed",
        r"SUMMARY:\s*(\d+)/(\d+) assertions passed",
    ]
    for pattern in patterns:
        matches = list(re.finditer(pattern, text, re.IGNORECASE | re.DOTALL))
        if not matches:
            continue
        groups = matches[-1].groups()
        if len(groups) == 3:
            total, passed, failed = map(int, groups)
        else:
            passed, total = map(int, groups)
            failed = total - passed
        return total, passed, failed
    return 0, 0, 0


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print("usage: parse_test_summary.py LOG [total|passed|failed]", file=sys.stderr)
        return 2
    total, passed, failed = parse(Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"))
    field = sys.argv[2] if len(sys.argv) == 3 else "all"
    values = {"total": total, "passed": passed, "failed": failed}
    if field == "all":
        print(f"{total}\t{passed}\t{failed}")
    elif field in values:
        print(values[field])
    else:
        print(f"unknown field: {field}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
