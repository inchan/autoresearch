# Session Resume Protocol

Cross-session state recovery. Enables resuming interrupted runs (Ctrl+C, context overflow, system crash, intentional split).

---

## State File Schema

**File:** `autoresearch-state.json` — atomic writes only (write `.tmp`, then rename)

```json
{
  "version": "1.0.0",
  "run_tag": "autoresearch-20260320T143022",
  "mode": "loop",
  "config": {
    "goal": "...", "scope": "...", "support_scope": "...", "context_scope": "...",
    "verify_cmd": "...", "metric_extraction": "...", "metric_type": "direct|proxy|composite",
    "direction": "higher|lower", "guard_cmd": "...", "iterations": null, "min_delta": 0
  },
  "state": {
    "iteration": 15, "metric": 87.5, "baseline_metric": 75.0,
    "consecutive_discards": 2, "pivot_count": 0,
    "total_keeps": 8, "total_discards": 6, "total_crashes": 1,
    "last_status": "discard", "last_strategy": "...",
    "escalation_level": 0, "updated_at": "2026-03-20T14:45:33Z"
  }
}
```

---

## Detection & Recovery Matrix

| State File | Results TSV | Git History | Action |
|---|---|---|---|
| Yes | * | * | **Full Resume** — load state, validate scope+verify, continue |
| No | Yes | * | **Mini-Wizard** — restore state from TSV, ask for missing config |
| No | No | experiment commits | **Fresh Start** — only strategy hints available |
| No | No | No | **Fresh Start** — no previous run |

### Full Resume
1. Load + validate state (version, scope matches files, verify dry-run, TSV consistency)
2. Print: "Resuming from iteration N, metric: X (baseline: Y)"
3. Enter loop at Phase 1

### Mini-Wizard
Parse TSV for last iteration/metric/status. Ask user for missing config (goal, scope, verify, direction). Reconstruct state file.

---

## Session Splitting

Split when context ~80% full or quality degrading. Before ending: ensure state file + TSV current, print handoff message with iteration/metric/strategy.

Next session auto-detects state file → Full Resume → seamless continuation.

---

## State File Management

- Write after EVERY iteration, after setup, after PIVOT, before splits
- Atomic write: `echo > .tmp && mv .tmp state.json`
- On completion: add `completed_at` timestamp

## Edge Cases

- **Stale state (>24h):** re-verify baseline, warn if metric diverged
- **State/TSV diverge:** trust TSV for iteration count, state for config
- **Corrupt state:** rename to `.corrupt`, fall back to Mini-Wizard
- **Different run_tag:** use state file (latest intent), read old TSV for lessons
