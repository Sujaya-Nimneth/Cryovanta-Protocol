#!/usr/bin/env python3
"""Validate that every root-level Godot test suite is registered exactly once."""

from pathlib import Path
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    manifest = root / "tests" / "manifest.txt"
    if not manifest.is_file():
        print(f"Missing test manifest: {manifest}", file=sys.stderr)
        return 1

    registered = [
        line.strip()
        for line in manifest.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    discovered = sorted(path.name for path in root.glob("test_*.gd"))
    duplicates = sorted({name for name in registered if registered.count(name) > 1})
    missing = sorted(set(discovered) - set(registered))
    extra = sorted(set(registered) - set(discovered))

    if duplicates or missing or extra:
        for label, names in (("duplicate", duplicates), ("missing", missing), ("extra", extra)):
            for name in names:
                print(f"{label}: {name}", file=sys.stderr)
        return 1

    print(f"Test manifest valid: {len(registered)} suites, each registered once.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
