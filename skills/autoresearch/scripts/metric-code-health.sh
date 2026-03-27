#!/bin/bash
# Composite metric: Code Health Score
# Combines type errors, lint warnings, test passes, and complexity
# Usage: ./metric-code-health.sh
# Adapts automatically to detected tooling
# Direction: higher

set -euo pipefail

score=100

# --- Type errors (penalty: -3 each) ---
if command -v tsc &>/dev/null && [ -f tsconfig.json ]; then
  type_errors=$(tsc --noEmit 2>&1 | grep -c "error TS" || echo 0)
  score=$(echo "scale=1; $score - 3 * $type_errors" | bc)
elif command -v mypy &>/dev/null; then
  type_errors=$(mypy --no-error-summary src/ 2>&1 | grep -c "error:" || echo 0)
  score=$(echo "scale=1; $score - 3 * $type_errors" | bc)
fi

# --- Lint warnings (penalty: -1 each) ---
if command -v eslint &>/dev/null && ls .eslintrc* eslint.config.* &>/dev/null; then
  lint_issues=$(eslint src/ --format compact 2>&1 | grep -cE "(Warning|Error)" || echo 0)
  score=$(echo "scale=1; $score - 1 * $lint_issues" | bc)
elif command -v ruff &>/dev/null; then
  lint_issues=$(ruff check src/ 2>&1 | grep -c ":" || echo 0)
  score=$(echo "scale=1; $score - 1 * $lint_issues" | bc)
fi

# --- Test passes (bonus: +0.3 each) ---
if command -v pytest &>/dev/null; then
  test_pass=$(pytest --tb=no -q 2>&1 | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1 || echo 0)
  score=$(echo "scale=1; $score + 0.3 * $test_pass" | bc)
elif [ -f package.json ] && grep -q '"test"' package.json 2>/dev/null; then
  test_pass=$(npx jest --silent 2>&1 | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1 || echo 0)
  score=$(echo "scale=1; $score + 0.3 * $test_pass" | bc)
fi

# --- Floor at 0 ---
is_negative=$(echo "$score < 0" | bc)
if [ "$is_negative" -eq 1 ]; then
  score=0
fi

echo "$score"
