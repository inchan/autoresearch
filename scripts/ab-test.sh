#!/bin/bash
# ab-test.sh — Run N trials for a given SKILL.md version and collect metrics
# Usage: bash scripts/ab-test.sh <skill_file> <label> <n_trials>

set -uo pipefail

SKILL_FILE="${1:?Usage: ab-test.sh <skill_file> <label> <n_trials>}"
LABEL="${2:?}"
N="${3:-5}"
VERIFY_SCRIPT="/Users/inchan/workspace/autoresearch/scripts/verify-loop-continuation.sh"
SKILL_DST="/Users/inchan/.codex/skills/autoresearch/SKILL.md"
RESULTS_FILE="/tmp/ab-test-${LABEL}.tsv"

echo "trial	experiment_commits	total_commits	final_tests" > "$RESULTS_FILE"

for i in $(seq 1 "$N"); do
  echo "[${LABEL}] Trial ${i}/${N} starting..."

  # Install this version's SKILL.md
  cp "$SKILL_FILE" "$SKILL_DST"

  # Run verify and capture output
  OUTPUT=$(bash "$VERIFY_SCRIPT" gpt-5.4 300 5 2>&1)

  # Extract metrics
  EC=$(echo "$OUTPUT" | grep "^EXPERIMENT_COMMITS=" | head -1 | cut -d= -f2 | tr -d '[:space:]')
  TC=$(echo "$OUTPUT" | grep "^TOTAL_COMMITS=" | head -1 | cut -d= -f2 | tr -d '[:space:]')
  FT=$(echo "$OUTPUT" | grep "^FINAL_TESTS=" | head -1 | cut -d= -f2 | tr -d '[:space:]')

  EC=${EC:-0}
  TC=${TC:-0}
  FT=${FT:-0}

  echo "${i}	${EC}	${TC}	${FT}" >> "$RESULTS_FILE"
  echo "[${LABEL}] Trial ${i}/${N}: experiment_commits=${EC}, total_commits=${TC}, final_tests=${FT}"
done

echo ""
echo "=== ${LABEL} Results (${N} trials) ==="
cat "$RESULTS_FILE"
echo ""

# Calculate stats
METRICS=$(tail -n +2 "$RESULTS_FILE" | cut -f2)
SUM=0
COUNT=0
MIN=999
MAX=0
for m in $METRICS; do
  SUM=$((SUM + m))
  COUNT=$((COUNT + 1))
  [ "$m" -lt "$MIN" ] && MIN=$m
  [ "$m" -gt "$MAX" ] && MAX=$m
done

if [ "$COUNT" -gt 0 ]; then
  AVG_X10=$((SUM * 10 / COUNT))
  AVG_INT=$((AVG_X10 / 10))
  AVG_DEC=$((AVG_X10 % 10))
  echo "SUMMARY: n=${COUNT} avg=${AVG_INT}.${AVG_DEC} min=${MIN} max=${MAX} sum=${SUM}"
fi
