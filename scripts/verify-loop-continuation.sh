#!/bin/bash
# verify-loop-continuation.sh
# Tests whether codex completes multiple autoresearch iterations with the current skill.
# Returns the number of experiment commits as the metric.
#
# Usage: bash scripts/verify-loop-continuation.sh [model] [timeout_sec] [target_iterations]
# Defaults: model=o4-mini, timeout=180, target_iterations=5

set -uo pipefail

MODEL="${1:-gpt-5.4}"
TIMEOUT="${2:-180}"
TARGET_ITERS="${3:-5}"

# macOS-compatible timeout function
run_with_timeout() {
  local timeout_sec=$1; shift
  "$@" &
  local pid=$!
  ( sleep "$timeout_sec" && kill "$pid" 2>/dev/null ) &
  local watchdog=$!
  wait "$pid" 2>/dev/null
  local exit_code=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return $exit_code
}
TEST_DIR="/tmp/autoresearch-loop-test-$$"
SKILL_SRC="/Users/inchan/workspace/autoresearch/skills/autoresearch"
SKILL_DST="/Users/inchan/.codex/skills/autoresearch"

cleanup() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# 1. Copy current skill files to codex
cp -r "$SKILL_SRC/SKILL.md" "$SKILL_DST/SKILL.md"
cp -r "$SKILL_SRC/references/"* "$SKILL_DST/references/"

# 2. Set up fresh test project
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

cat > math_utils.py << 'PYEOF'
def add(a, b):
    return a + b

def subtract(a, b):
    return a - b

def multiply(a, b):
    return a * b

def divide(a, b):
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b
PYEOF

cat > test_math.py << 'PYEOF'
from math_utils import add

def test_add_positive():
    assert add(1, 2) == 3
PYEOF

git add math_utils.py test_math.py
git commit -q -m "initial: math utils with 1 test"

# 3. Run codex with autoresearch skill
PROMPT="Use the autoresearch skill to improve test coverage.

Goal: Increase the number of passing tests
Scope: test_math.py
Verify: python -m pytest test_math.py -v 2>&1
Metric: grep -c PASSED
Direction: higher
Iterations: ${TARGET_ITERS}

Start the autonomous loop now. Do NOT stop until all ${TARGET_ITERS} iterations are complete."

run_with_timeout "$TIMEOUT" codex exec \
  -m "$MODEL" \
  -C "$TEST_DIR" \
  -s danger-full-access \
  "$PROMPT" 2>&1 | tail -50 || true

# 4. Measure: count experiment commits
cd "$TEST_DIR"
EXPERIMENT_COMMITS=$(git log --oneline 2>/dev/null | grep -c "experiment(" || true)
EXPERIMENT_COMMITS=${EXPERIMENT_COMMITS:-0}
EXPERIMENT_COMMITS=$(echo "$EXPERIMENT_COMMITS" | tr -d '[:space:]')

TOTAL_COMMITS=$(git log --oneline 2>/dev/null | wc -l | tr -d '[:space:]')
TOTAL_COMMITS=${TOTAL_COMMITS:-0}

FINAL_TESTS=$(python3 -m pytest test_math.py -v 2>&1 | grep -c "PASSED" || true)
FINAL_TESTS=${FINAL_TESTS:-0}
FINAL_TESTS=$(echo "$FINAL_TESTS" | tr -d '[:space:]')

echo ""
echo "=== LOOP CONTINUATION METRIC ==="
echo "EXPERIMENT_COMMITS=${EXPERIMENT_COMMITS}"
echo "TOTAL_COMMITS=${TOTAL_COMMITS}"
echo "FINAL_TESTS=${FINAL_TESTS}"
echo "TARGET_ITERATIONS=${TARGET_ITERS}"

# The primary metric: number of experiment commits
echo "${EXPERIMENT_COMMITS}"
