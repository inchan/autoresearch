#!/bin/bash
# Composite metric: Performance Score
# Combines latency and (optionally) memory into a single 0-100 score
# Usage: ./metric-perf-score.sh <benchmark-command>
# Example: ./metric-perf-score.sh "./run-bench"
# Direction: higher

set -euo pipefail

BENCH_CMD="${1:?Usage: metric-perf-score.sh <benchmark-command>}"

# --- Configuration (adjust for your project) ---
LATENCY_TARGET_MS=50      # target latency in ms (100 = score 50 at 2x target)
WEIGHT_LATENCY=1.0        # adjust if adding memory dimension
RUNS=3                    # number of runs for median
# ------------------------------------------------

# Run benchmark multiple times, collect timings
declare -a timings
for i in $(seq 1 $RUNS); do
  start_ns=$(date +%s%N)
  eval "$BENCH_CMD" >/dev/null 2>&1 || true
  end_ns=$(date +%s%N)
  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  timings+=("$elapsed_ms")
done

# Sort and take median
IFS=$'\n' sorted=($(sort -n <<<"${timings[*]}")); unset IFS
median_idx=$(( RUNS / 2 ))
latency_ms=${sorted[$median_idx]}

# Convert to score: 100 at target, 0 at 4x target, linear
if [ "$latency_ms" -le "$LATENCY_TARGET_MS" ]; then
  latency_score=100
else
  max_ms=$((LATENCY_TARGET_MS * 4))
  if [ "$latency_ms" -ge "$max_ms" ]; then
    latency_score=0
  else
    latency_score=$(echo "scale=1; 100 * ($max_ms - $latency_ms) / ($max_ms - $LATENCY_TARGET_MS)" | bc)
  fi
fi

score=$(echo "scale=1; $WEIGHT_LATENCY * $latency_score" | bc)

echo "$score"
