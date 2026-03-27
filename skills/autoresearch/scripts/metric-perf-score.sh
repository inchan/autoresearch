#!/bin/bash
# Composite metric: Performance Score
# Combines latency and (optionally) memory into a single 0-100 score
# Usage: ./metric-perf-score.sh <benchmark-command>
# Example: ./metric-perf-score.sh "./run-bench"
# Direction: higher

set -euo pipefail

# --- Dependency check ---
for cmd in python3 bc; do
  command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found" >&2; echo 0; exit 1; }
done

BENCH_CMD="${1:?Usage: metric-perf-score.sh <benchmark-command>}"

# --- Configuration (adjust for your project) ---
LATENCY_TARGET_MS=50      # target latency in ms (100 = score 50 at 2x target)
WEIGHT_LATENCY=1.0        # adjust if adding memory dimension
RUNS=3                    # number of runs for median
# ------------------------------------------------

# Portable millisecond timer (works on macOS and Linux)
now_ms() {
  python3 -c 'import time; print(int(time.time() * 1000))'
}

# Run benchmark multiple times, collect timings
timings=""
for i in $(seq 1 $RUNS); do
  start_ms=$(now_ms)
  eval "$BENCH_CMD" >/dev/null 2>&1 || true
  end_ms=$(now_ms)
  elapsed_ms=$(( end_ms - start_ms ))
  timings="${timings}${elapsed_ms}\n"
done

# Sort and take median
sorted=$(echo -e "$timings" | grep -v '^$' | sort -n)
line_count=$(echo "$sorted" | wc -l | tr -d '[:space:]')
median_idx=$(( (line_count + 1) / 2 ))
[ "$median_idx" -lt 1 ] && median_idx=1
latency_ms=$(echo "$sorted" | sed -n "${median_idx}p")
[ -z "$latency_ms" ] && { echo "ERROR: no timing data collected" >&2; echo 0; exit 1; }

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
