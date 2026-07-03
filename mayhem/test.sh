#!/usr/bin/env bash
#
# mayhem/test.sh — RUN vigra's image import/export test suite (test_impex, built by build.sh).
# exit 0 = all tests passed. PATCH-grade oracle: asserts known-good import/export round-trips.
# mayhem/build.sh compiled build-tests/test/impex/test_impex; this script only RUNS it.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# test_impex expects test data files (lenna.xv, etc.) in the current directory.
# cmake's VIGRA_COPY_TEST_DATA copies them to the build binary dir.
BIN="$SRC/build-tests/test/impex/test_impex"
DATA_DIR="$SRC/build-tests/test/impex"
[ -x "$BIN" ] || { echo "missing $BIN — run mayhem/build.sh first" >&2; exit 2; }

# Run from the directory containing the test data
out="$(cd "$DATA_DIR" && "$BIN" 2>&1)"; rc=$?
echo "$out"

# Vigra's custom unit-test framework reports:
#   "All (N) tests passed in test suite <name>"   — all pass
#   "X of N tests failed in test suite <name>"    — some fail
total=$( printf '%s\n' "$out" | grep -oE '([0-9]+) tests? (passed|failed) in test suite' \
           | grep -oE '^[0-9]+' | tail -1)
# Try "All (N)" form first
all_pass=$(printf '%s\n' "$out" | grep -oE 'All \([0-9]+\) tests? passed' | grep -oE '[0-9]+' | tail -1)
if [ -n "$all_pass" ]; then
    total="$all_pass"; failed=0; passed="$all_pass"
else
    # "X of N tests failed" form
    failed=$(printf '%s\n' "$out" | grep -oE '[0-9]+ of [0-9]+ tests? failed' \
              | grep -oE '^[0-9]+' | tail -1)
    total=$( printf '%s\n' "$out" | grep -oE '[0-9]+ of [0-9]+ tests? failed' \
              | grep -oE '[0-9]+$' | tail -1)
    : "${failed:=0}" "${total:=0}"
    passed=$(( total - failed ))
    [ "$passed" -lt 0 ] && passed=0
fi

# Fall through: if we got no output pattern and the binary exited non-zero, count as 1 fail
if [ "${total:-0}" -eq 0 ] && [ "$rc" -ne 0 ]; then
    total=1; failed=1; passed=0
elif [ "${total:-0}" -eq 0 ]; then
    total=1; failed=0; passed=1
fi
: "${failed:=0}" "${passed:=0}"

emit_ctrf "vigra-unittest" "$passed" "$failed"
