# Metric Design Guide

How to design effective metrics for autoresearch. A good metric is the single most important factor in a successful run — it determines whether the agent optimizes for what you actually want.

---

## Metric Quality Levels

### Level 1: Direct Measurement

The goal IS a number. No translation needed. This is the ideal case.

```
Goal: "increase test pass count"     → pytest --tb=no | grep -c passed
Goal: "reduce build errors to zero"  → tsc --noEmit 2>&1 | grep -c "error TS"
Goal: "reduce bundle size"           → du -sb dist/ | cut -f1
Goal: "decrease p99 latency"         → hyperfine './bench' --export-json - | jq '.results[0].mean'

Characteristics:
  - No proxy needed
  - High correlation with actual goal (1:1)
  - Easy to validate
  - Fast to extract
```

### Level 2: Proxy Measurement

The goal is subjective or complex. Find a mechanical proxy that correlates.

```
Goal: "improve code readability"
  Bad proxy:   line count (shorter ≠ more readable)
  OK proxy:    cyclomatic complexity (radon cc -a src/)
  Good proxy:  cognitive complexity (measures nesting depth, branching patterns)
  Best proxy:  combined cognitive complexity + function length + naming consistency

Goal: "improve test quality"
  Bad proxy:   test count (more tests ≠ better tests)
  OK proxy:    code coverage percent
  Good proxy:  mutation testing score (mutmut, stryker)
  Best proxy:  mutation score + branch coverage + assertion density

Goal: "improve API robustness"
  Bad proxy:   test pass count
  OK proxy:    error handling coverage
  Good proxy:  fault injection pass rate
  Best proxy:  chaos test survival rate + error recovery time

How to evaluate proxy quality:
  1. Would gaming this proxy still improve the real goal?
     If "add 100 trivial tests" would raise the proxy → bad proxy
  2. Does improving this proxy ALWAYS improve the real goal?
     If reducing complexity sometimes removes needed logic → add guard
  3. Is the proxy sensitive to meaningful changes?
     If a major refactor moves the proxy by 0.1 → not sensitive enough
```

### Level 3: Composite Measurement

Multiple concerns combined into a single score. Use when no single metric captures the goal.

```
Formula pattern:
  score = w1 * metric_a + w2 * metric_b + w3 * metric_c
  where w1 + w2 + w3 = 1.0

The weights encode priorities:
  - Higher weight = more important dimension
  - Adjust weights based on which dimension is lagging

Normalization:
  Each sub-metric should be on a comparable scale (0-100 recommended).
  If raw values differ wildly (e.g., 3 errors vs 85% coverage),
  normalize before combining:
    normalized = (raw - min_expected) / (max_expected - min_expected) * 100
```

---

## Composite Metric Templates

### Test Quality Score

```bash
#!/bin/bash
# Measures how good the tests are, not just how many pass
pass_rate=$(pytest --tb=no -q 2>&1 | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
total=$(pytest --tb=no -q 2>&1 | grep -oE '[0-9]+ (passed|failed)' | grep -oE '[0-9]+' | head -1 || echo 1)
pass_pct=$(echo "scale=1; $pass_rate * 100 / $total" | bc 2>/dev/null || echo 0)

coverage=$(pytest --cov=src --cov-report=term 2>&1 | grep 'TOTAL' | grep -oE '[0-9]+%' | grep -oE '[0-9]+' || echo 0)

# Combine: 60% pass rate + 40% coverage
echo "scale=1; 0.6 * $pass_pct + 0.4 * $coverage" | bc
```

### Code Health Score

```bash
#!/bin/bash
# Composite: type errors, lint warnings, complexity, test coverage
type_errors=$(tsc --noEmit 2>&1 | grep -c "error TS" || echo 0)
lint_warnings=$(eslint src/ --format compact 2>&1 | grep -c "Warning" || echo 0)
test_pass=$(npx jest --silent 2>&1 | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
complexity=$(npx ts-complexity src/ 2>&1 | tail -1 | grep -oE '[0-9.]+' || echo 10)

# Score: start at 100, subtract penalties, add bonuses
echo "scale=1; 100 - 3*$type_errors - 1*$lint_warnings - 0.5*$complexity + 0.2*$test_pass" | bc
```

### Performance Score

```bash
#!/bin/bash
# Composite: latency + throughput + memory
latency_ms=$(hyperfine --warmup 3 './bench' --export-json /dev/stdout 2>/dev/null \
  | jq '.results[0].mean * 1000' 2>/dev/null || echo 999)
memory_mb=$(./bench --measure-memory 2>&1 | grep -oE '[0-9.]+' | tail -1 || echo 999)

# Lower is better for both, so invert into a score
# Assumes latency target ~50ms, memory target ~100MB
latency_score=$(echo "scale=1; 100 - ($latency_ms / 50 * 50)" | bc 2>/dev/null || echo 0)
memory_score=$(echo "scale=1; 100 - ($memory_mb / 100 * 50)" | bc 2>/dev/null || echo 0)

# 70% latency, 30% memory
echo "scale=1; 0.7 * $latency_score + 0.3 * $memory_score" | bc
```

### Security Score

Already defined in security-workflow.md:
```
score = (owasp_tested / 10) * 50 + (stride_tested / 6) * 30 + min(findings, 20)
```

---

## Anti-Gaming: 3-Layer Defense

### Layer 1: Guard Command (existing)

The guard command catches regressions that the metric doesn't measure.

```
Metric: test pass count (higher)
Guard:  tsc --noEmit (exit 0 = pass)

What it catches:
  - Agent adds tests that pass but break type safety
  - Agent modifies code in ways that pass tests but violate types

Limitation:
  - Only catches what the guard command checks
  - Does not catch semantic gaming (e.g., trivial tests that inflate count)
```

### Layer 2: Metric Sanity Check (new)

Detect anomalous metric changes that suggest gaming or measurement error.

```
Rules:
1. Single-iteration jump limit:
   If delta > 3x the average keep delta → flag for review
   Mark as "keep (flagged)" instead of "keep"
   Re-run verification to confirm

2. Metric regression on revert:
   After safe_revert(), re-run verify
   If metric != current_best → revert was incomplete or metric is noisy
   Log warning and re-check

3. Monotonicity check (for bounded runs):
   Track the moving average of keep deltas
   If average delta is decreasing → diminishing returns, consider PIVOT
   If average delta suddenly spikes → possible gaming, verify

Implementation in Phase 6 (Decide):
  if status == "keep":
      avg_delta = average(last_5_keep_deltas)
      if delta > 3 * avg_delta and avg_delta > 0:
          # Anomalous jump — re-verify
          re_run_metric = run_verify()
          if abs(re_run_metric - new_metric) > min_delta:
              # Measurement was noisy, use re-run value
              new_metric = re_run_metric
              recalculate decision
          else:
              # Jump is real but suspicious — log flag
              status = "keep (flagged)"
              note = "anomalous delta: {delta} vs avg {avg_delta}"
```

### Layer 3: Structural Guard (new)

Detect changes that "cheat" by removing functionality instead of improving it.

```
Rules:
1. No net function/class deletion:
   If the change deletes a function or class definition without replacing it:
     → Flag as "destructive simplification"
     → Apply only if the deleted code is verified unused (no callers)

2. No test deletion for metric improvement:
   If Metric involves test counts AND the change deletes test functions:
     → Automatic DISCARD (this is always gaming)

3. Coverage preservation:
   If a guard command measures coverage AND the change reduces coverage:
     → Guard failure triggers rework or discard

4. Import preservation:
   If the change removes imports without removing their usage:
     → This causes crashes, catch in guard

Implementation in Phase 3 (Modify) — pre-flight check:
  Before committing, analyze the diff:
    deleted_functions = count functions removed
    deleted_tests = count test functions removed
    deleted_imports = count imports removed

    if deleted_tests > 0 and metric_involves_tests:
        ABORT change, log "structural guard: test deletion blocked"
        Skip to next iteration

    if deleted_functions > 0:
        for each deleted function:
            callers = grep for function name in scope + support files
            if callers exist:
                ABORT change, log "structural guard: function still has callers"
```

---

## Metric Validation During Setup

### Dry-Run Protocol

During the Setup Phase (Step 5: Establish Baseline), validate the metric:

```
1. Run verify_cmd 3 times:
   result_1, result_2, result_3

2. Check consistency:
   variance = max(results) - min(results)
   if variance > 0:
       warn "Metric has variance of {variance}. Consider:"
       if variance < 0.05 * median(results):
           "Low variance — acceptable. Using median as baseline."
       elif variance < 0.20 * median(results):
           "Moderate variance — recommend setting min_delta to {2 * variance}"
       else:
           "High variance — metric is unreliable. Consider:"
           "  - Pinning random seeds"
           "  - Disabling parallel execution"
           "  - Using a more deterministic metric"

3. Check extractability:
   if no number extracted from any run:
       ERROR "Metric extraction failed. Adjust verify_cmd or metric_extraction."

4. Check range:
   if metric == 0:
       warn "Baseline is 0. Direction 'higher' means any positive change is kept."
   if metric > 10000:
       warn "Large metric value. Small changes may be lost in noise."

5. Check speed:
   if avg_time > 300 seconds:
       warn "Verify takes >5 minutes. Consider a faster proxy metric."
   elif avg_time > 30 seconds:
       info "Moderate verify time. Recommend bounded iterations."
   else:
       info "Fast verify ({avg_time}s). Ideal for exploration."
```

### Metric Direction Validation

```
Auto-detect direction by analyzing the metric name/command:

Keywords suggesting "higher":
  passed, coverage, score, count (of good things), rate, success

Keywords suggesting "lower":
  error, fail, size, latency, complexity, warning, time, bytes

If auto-detected direction conflicts with user-specified direction:
  warn "You specified 'higher' but the metric name suggests 'lower'.
        Are you sure? (e.g., 'error count: higher' would be unusual)"
```

---

## Domain-Specific Metric Recommendations

### Backend (Python/Node/Go/Rust)

```
Fast cycle (< 10s):
  Metric: pytest --tb=no -q | grep -c passed
  Guard:  mypy --strict src/ (or tsc --noEmit)
  min_delta: 1

Medium cycle (10-60s):
  Metric: composite (test pass + type errors + lint)
  Guard:  full test suite
  min_delta: 2

Slow cycle (> 60s):
  Metric: integration test pass rate
  Guard:  none (verify IS the guard)
  min_delta: 5
  iterations: bounded (20-30)
```

### Frontend (React/Vue/Svelte)

```
Bundle optimization:
  Metric: du -sb dist/ | cut -f1 (or webpack stats)
  Guard:  npx tsc --noEmit && npm test
  Direction: lower
  min_delta: 1024 (1KB — below this is noise)

Component quality:
  Metric: composite (test pass + type errors + Lighthouse accessibility)
  Guard:  build succeeds
  min_delta: 2
```

### ML / Data Science

```
Model quality:
  Metric: python eval.py --metric accuracy (or loss)
  Guard:  python prepare.py (data integrity check)
  Direction: higher (accuracy) or lower (loss)
  min_delta: 0.5 (below this is training noise)
  iterations: bounded (10-20, each is expensive)
  timeout: 1800 (30 minutes)

Data pipeline:
  Metric: python pipeline.py --count-valid-rows
  Guard:  python validate_schema.py
  Direction: higher
  min_delta: 100
```

### DevOps / Infrastructure

```
Build time:
  Metric: time make build 2>&1 | grep real | grep -oE '[0-9.]+'
  Guard:  make test
  Direction: lower
  min_delta: 1.0 (seconds)

Docker image size:
  Metric: docker build -t tmp . && docker image inspect tmp --format '{{.Size}}'
  Guard:  docker run tmp --healthcheck
  Direction: lower
  min_delta: 1048576 (1MB)
```

---

## Choosing Between Direct, Proxy, and Composite

```
Decision tree:

Is the goal directly measurable as a single number?
├── Yes → Level 1 (Direct). Use it.
└── No
    ├── Can you find ONE proxy that correlates well?
    │   ├── Yes → Level 2 (Proxy). Validate correlation.
    │   └── No
    │       ├── Can you combine 2-3 sub-metrics?
    │       │   ├── Yes → Level 3 (Composite). Write a metric script.
    │       │   └── No → This goal may not be suitable for autoresearch.
    │       │           Consider breaking it into sub-goals that ARE measurable.
    │       └──
    └──

Validation: after choosing, ask yourself:
  "If the agent maximizes this metric by ANY means,
   would I be happy with the result?"

  If yes → good metric.
  If "yes, but only if X is preserved" → add X as guard command.
  If "no, the agent could game it by doing Y" → add structural guard or better proxy.
```
