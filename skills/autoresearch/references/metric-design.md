# Metric Design Guide

A good metric is the single most important factor in a successful run.

---

## Quality Levels

### Level 1: Direct
Goal IS a number. `pytest | grep -c passed`, `du -sb dist/`, `hyperfine './bench'`. Ideal — high correlation, fast, easy to validate.

### Level 2: Proxy
Goal is subjective → find a mechanical proxy that correlates.

| Goal | Bad Proxy | Good Proxy |
|---|---|---|
| Code readability | Line count | Cognitive complexity |
| Test quality | Test count | Mutation testing score |
| API robustness | Test pass count | Fault injection pass rate |

Evaluate: would gaming this proxy still improve the goal? Does improving it ALWAYS help? Is it sensitive to meaningful changes?

### Level 3: Composite
Multiple concerns → single score: `score = w1*A + w2*B + w3*C` (weights sum to 1.0). Normalize sub-metrics to 0-100 scale.

---

## Composite Templates

| Script | Measures | Direction |
|---|---|---|
| `scripts/metric-test-quality.sh` | Pass rate + coverage (0-100) | higher |
| `scripts/metric-code-health.sh` | Type errors + lint + tests (100 base) | higher |
| `scripts/metric-perf-score.sh` | Latency benchmark (0-100) | higher |

---

## Anti-Gaming: 3-Layer Defense

### Layer 1: Guard Command
Catches regressions the metric doesn't measure (e.g., type safety while optimizing test count). Only catches what guard checks — does not catch semantic gaming.

### Layer 2: Sanity Check
- Single-iteration jump > 3x average delta → re-verify, flag as `keep (flagged)`
- Post-revert metric check to detect incomplete rollbacks
- Decreasing keep deltas → diminishing returns, consider PIVOT

### Layer 3: Structural Guard
Pre-flight diff analysis in Phase 3:
- **Test deletion blocked**: if metric involves tests AND change deletes test functions → auto-DISCARD
- **Function deletion checked**: only allowed if function has no callers in scope
- **Coverage preservation**: guard catches coverage regressions

---

## Validation During Setup

Run verify 3 times. Check variance (low <5% median, moderate <20%, high → unreliable). Check extractability. Check range (0 baseline, >10000 noise risk). Check speed (<30s ideal, >5min → consider faster proxy).

Auto-detect direction from keywords: passed/coverage/score → higher. error/fail/size/latency → lower.

---

## Domain Recommendations

| Domain | Fast Metric | Guard | Direction | Notes |
|---|---|---|---|---|
| Backend | `pytest \| grep -c passed` | `mypy --strict` | higher | min_delta: 1 |
| Frontend | `du -sb dist/ \| cut -f1` | `tsc --noEmit && npm test` | lower | min_delta: 1024 |
| ML | `python eval.py --metric accuracy` | `python prepare.py` | higher | min_delta: 0.5, bounded 10-20, timeout 30min |
| DevOps | `time make build` | `make test` | lower | min_delta: 1.0s |

---

## Choosing Level

Goal directly measurable as single number? → **Direct**. Otherwise, one good proxy? → **Proxy**. Otherwise, 2-3 sub-metrics? → **Composite**. Otherwise, break goal into sub-goals.

Validation: "If the agent maximizes this by ANY means, would I be happy?" Yes → good. "Yes if X preserved" → add X as guard. "No, could game by Y" → add structural guard or better proxy.
