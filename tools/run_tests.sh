#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="${CRYOVANTA_TEST_LOG_DIR:-$ROOT/build/test-logs}"
MANIFEST="$ROOT/tests/manifest.txt"
mkdir -p "$LOG_DIR"

python3 "$ROOT/tools/validate_test_manifest.py"
"$GODOT_BIN" --headless --editor --quit --path "$ROOT" >"$LOG_DIR/import.log" 2>&1 || {
  cat "$LOG_DIR/import.log"
  exit 1
}

total_assertions=0
suite_count=0
failed=0
summary="$LOG_DIR/summary.tsv"
printf 'suite\texit\ttotal\tpassed\tfailed\n' >"$summary"

while IFS= read -r suite || [[ -n "$suite" ]]; do
  [[ -z "$suite" || "$suite" == \#* ]] && continue
  log="$LOG_DIR/${suite%.gd}.log"
  echo "=== $suite ==="
  set +e
  "$GODOT_BIN" --headless --path "$ROOT" -s "res://$suite" -- --direct-regression >"$log" 2>&1
  exit_code=$?
  set -e

  suite_total="$(python3 "$ROOT/tools/parse_test_summary.py" "$log" total)"
  suite_passed="$(python3 "$ROOT/tools/parse_test_summary.py" "$log" passed)"
  suite_failed="$(python3 "$ROOT/tools/parse_test_summary.py" "$log" failed)"
  printf '%s\t%d\t%s\t%s\t%s\n' "$suite" "$exit_code" "$suite_total" "$suite_passed" "$suite_failed" >>"$summary"

  if [[ "$exit_code" -ne 0 ]]; then
    failed=1
    echo "FAIL: $suite exited $exit_code"
    tail -40 "$log"
  else
    echo "PASS: $suite (${suite_passed}/${suite_total} assertions)"
    total_assertions=$((total_assertions + suite_total))
  fi
  suite_count=$((suite_count + 1))
done <"$MANIFEST"

echo "Suites executed once: $suite_count"
echo "Reported assertions passed: $total_assertions"
echo "Logs: $LOG_DIR"
exit "$failed"
