#!/usr/bin/env bash
# Runs one headless Godot test scene. On failure, the interesting lines are
# also printed as GitHub error annotations so they are readable from the PR /
# check-runs API even when the raw log is not available.
#   tools/ci_test.sh res://tests/smoke.tscn
scene="$1"
log="$(mktemp)"
cd "${PROJECT_PATH:-game}" || exit 2
godot --headless "$scene" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
if [ "$code" -ne 0 ]; then
  msg="$(grep -E "ERROR|SCRIPT|Parse Error|FAIL|Failed|Invalid|Cannot|Condition|Node not found|====" "$log" | head -25 | sed 's/%/%25/g' | awk '{printf "%s%%0A", $0}')"
  echo "::error title=$scene exit=$code::${msg}"
fi
exit "$code"
