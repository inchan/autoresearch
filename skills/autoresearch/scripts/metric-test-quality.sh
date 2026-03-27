#!/bin/bash
# Composite metric: Test Quality Score
# Combines pass rate + coverage into a single 0-100 score
# Usage: ./metric-test-quality.sh
# Requires: pytest, pytest-cov
# Direction: higher

set -euo pipefail

# --- Dependency check ---
for cmd in pytest bc; do
  command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found" >&2; echo 0; exit 1; }
done

# --- Configuration (adjust for your project) ---
TEST_CMD="pytest --tb=no -q"
COV_CMD="pytest --cov=src --cov-report=term-missing --tb=no -q"
WEIGHT_PASS=0.6
WEIGHT_COV=0.4
# ------------------------------------------------

# Measure pass rate
test_output=$($TEST_CMD 2>&1) || true
passed=$(echo "$test_output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1 || true)
passed=${passed:-0}
failed=$(echo "$test_output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1 || true)
failed=${failed:-0}
total=$((passed + failed))

if [ "$total" -eq 0 ]; then
  pass_pct=0
else
  pass_pct=$(echo "scale=1; $passed * 100 / $total" | bc)
fi

# Measure coverage
cov_output=$($COV_CMD 2>&1) || true
coverage=$(echo "$cov_output" | grep 'TOTAL' | grep -oE '[0-9]+%' | grep -oE '[0-9]+' || true)
coverage=${coverage:-0}

# Composite score
score=$(echo "scale=1; $WEIGHT_PASS * $pass_pct + $WEIGHT_COV * $coverage" | bc)

echo "$score"
