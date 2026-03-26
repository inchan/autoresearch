# Session Resume Protocol

Cross-session state recovery for autoresearch runs. Enables resuming interrupted runs without losing progress.

---

## Overview

Long autoresearch runs may be interrupted by:
- User pressing Ctrl+C / Escape
- Agent context window filling up
- System crash or network disconnection
- Intentional session splitting for very long runs

The session resume protocol ensures clean recovery in all cases.

---

## State File Schema

**File:** `autoresearch-state.json`
**Format:** JSON, atomic writes only (write to .tmp, then rename)

```json
{
  "version": "1.0.0",
  "run_tag": "autoresearch-20260320T143022",
  "mode": "loop",
  "config": {
    "goal": "Increase test pass rate to 90%",
    "scope": "tests/**/*.test.ts",
    "support_scope": "src/parser.ts, src/utils.ts, src/types.ts",
    "context_scope": "src/**/*.ts",
    "verify_cmd": "npx jest --silent 2>&1",
    "metric_extraction": "grep -oE '[0-9]+ passed' | grep -oE '[0-9]+'",
    "metric_type": "direct",
    "direction": "higher",
    "guard_cmd": "npx tsc --noEmit",
    "iterations": null,
    "min_delta": 0
  },
  "state": {
    "iteration": 15,
    "metric": 87.5,
    "baseline_metric": 75.0,
    "consecutive_discards": 2,
    "pivot_count": 0,
    "total_keeps": 8,
    "total_discards": 6,
    "total_crashes": 1,
    "last_status": "discard",
    "last_strategy": "add boundary validation tests",
    "escalation_level": 0,
    "updated_at": "2026-03-20T14:45:33Z"
  }
}
```

### Field Descriptions

#### Top-Level Fields

| Field | Type | Description |
|---|---|---|
| `version` | String | Schema version for forward compatibility |
| `run_tag` | String | Unique identifier for this run (timestamp-based) |
| `mode` | String | Current mode: `loop`, `debug`, `fix`, `security`, `ship` |

#### Config Fields

| Field | Type | Description |
|---|---|---|
| `goal` | String | Human-readable goal description |
| `scope` | String | File glob pattern (Core scope — full read/write) |
| `support_scope` | String or null | File glob or list (Support scope — limited write) |
| `context_scope` | String or null | File glob (Context scope — read-only) |
| `verify_cmd` | String | Full verification command |
| `metric_extraction` | String or null | Pipeline to extract metric from verify output (null = auto-extract last number) |
| `metric_type` | String | `direct`, `proxy`, or `composite` |
| `direction` | String | `higher` or `lower` |
| `guard_cmd` | String or null | Guard command or null if not set |
| `iterations` | Integer or null | Max iterations or null for unbounded |
| `min_delta` | Float | Minimum improvement threshold |

#### State Fields

| Field | Type | Description |
|---|---|---|
| `iteration` | Integer | Last completed iteration number |
| `metric` | Float | Current best metric value |
| `baseline_metric` | Float | Original baseline metric value |
| `consecutive_discards` | Integer | Current consecutive discard streak |
| `pivot_count` | Integer | Number of PIVOTs performed |
| `total_keeps` | Integer | Total successful iterations |
| `total_discards` | Integer | Total discarded iterations |
| `total_crashes` | Integer | Total crashed iterations |
| `last_status` | String | Status of the last iteration |
| `last_strategy` | String | Description of the last strategy being pursued |
| `escalation_level` | Integer | Current pivot protocol level (0-4) |
| `updated_at` | String | ISO 8601 timestamp of last update |

---

## Detection Signals

When a new session starts, check for resume signals in this priority order:

### Priority 1: State File
```
Check: test -f autoresearch-state.json

If exists:
  Parse the JSON
  Validate version compatibility
  This is the strongest signal — contains full configuration and state
```

### Priority 2: Results TSV
```
Check: test -f autoresearch-results.tsv

If exists (but no state file):
  Parse the TSV
  Extract: last iteration number, last metric, status history
  Reconstruct partial state from the log
  Missing: config details (goal, scope, verify_cmd, metric_extraction, etc.)
```

### Priority 3: Git History
```
Check: git log --oneline --grep="experiment(" -20

If experiment commits exist (but no state or TSV):
  Extract: experiment descriptions, timeline, scope patterns
  This is a weak signal — only provides strategy context, not config
```

### Priority 4: No Signals
```
If none of the above exist:
  Fresh start — proceed with normal setup
```

---

## Recovery Priority Matrix

| State File | Results TSV | Git History | Recovery Action |
|---|---|---|---|
| Yes | Yes | Yes | **Full Resume** — use state file, validate against TSV |
| Yes | No | Yes | **Full Resume** — use state file, recreate TSV header |
| Yes | Yes | No | **Full Resume** — use state file (git history may have been cleaned) |
| Yes | No | No | **Full Resume** — use state file (fresh git) |
| No | Yes | Yes | **Mini-Wizard** — ask for config, restore state from TSV |
| No | Yes | No | **TSV Fallback** — extract what we can from TSV, ask for config |
| No | No | Yes | **Fresh Start** — only strategy hints from git, full setup needed |
| No | No | No | **Fresh Start** — no previous run detected |

### Full Resume

```
1. Load autoresearch-state.json
2. Validate the state file:
   a. Is version compatible? (must be 1.x.x)
   b. Does the scope glob match existing files?
   c. Does the verify command still work? (dry-run)
   d. Does the TSV exist and match the state iteration count?
3. If validation passes:
   Print: "Resuming autoresearch run '<run_tag>' from iteration <N>"
   Print: "Goal: <goal>"
   Print: "Current metric: <metric> (baseline: <baseline>)"
   Print: "Continuing autonomous loop."
   Set iteration = state.iteration + 1
   Enter loop at Phase 1 (Review)
4. If validation fails:
   Print what failed
   Offer: "Resume with adjustments" or "Start fresh"
```

### Mini-Wizard

```
State file is missing but TSV exists.

1. Parse the TSV to extract:
   - Last iteration number
   - Current metric (last keep or baseline)
   - Status distribution
2. Ask the user for the missing config:
   "I found a previous run's results (N iterations, metric: X).
    To resume, I need:
    - Goal: <ask>
    - Scope: <ask>
    - Metric command: <ask>
    - Direction: <ask>
    - Verify command: <ask>"
3. Once config is provided, reconstruct state file
4. Enter loop at the next iteration
```

### TSV Fallback

```
TSV exists but git history is clean (maybe repo was cloned fresh).

1. Parse the TSV for state information
2. The TSV alone provides:
   - Iteration count
   - Metric progression
   - Strategy descriptions (from description column)
3. Missing: config, git context
4. Ask for full config (like mini-wizard)
5. Note: previous experiment commits are not available for context
```

### Fresh Start

```
No previous run detected.

1. Proceed with normal setup (as defined in SKILL.md)
2. No special recovery actions needed
```

---

## Session Splitting (Context Overflow Handling)

Sessions WILL be split during long runs. This is expected behavior, not an error. The state file makes splits seamless.

### When to Split

```
Split a session when:
- Context window is getting full (~80% capacity) — this is the PRIMARY trigger
- Context compaction has occurred (agent detects summarized/truncated history)
- The agent's response quality is degrading (repetitive, less precise)
- A natural breakpoint occurs (after a PIVOT, after a summary)

Context overflow is the #1 cause of agents stopping mid-loop.
The session split protocol prevents this by saving state BEFORE overflow.
```

### How to Split

```
Before ending the session:
1. Ensure autoresearch-state.json is up to date
2. Ensure autoresearch-results.tsv has the latest entry
3. Print a handoff message:
   "[autoresearch] Session split at iteration N.
    State saved. To resume: /autoresearch
    Current metric: X (baseline: Y, delta: Z)
    Last strategy: <description>"
```

### Resuming After Split

```
The next session:
1. Detects state file (Priority 1)
2. Follows Full Resume path
3. Reads lessons and git history for context
4. Continues from where the previous session left off

The transition should be seamless — the loop continues as if uninterrupted.
```

---

## State File Management

### Atomic Writes

```bash
# Always write atomically to prevent corruption
write_state() {
    local state_json="$1"
    echo "$state_json" > autoresearch-state.json.tmp
    mv autoresearch-state.json.tmp autoresearch-state.json
}
```

### When to Write State

```
Write state after EVERY iteration (Phase 7: Log).
This ensures the state file is always current, even if the session
is interrupted mid-loop.

Also write state:
- After setup completes (before entering the loop)
- After PIVOT events (escalation state changed)
- Before intentional session splits
```

### State File Cleanup

```
After a run completes (bounded mode reaches limit):
1. Keep the state file (useful for future reference)
2. Mark it as completed: add "completed_at" timestamp
3. The next /autoresearch invocation will detect the completed state
   and ask: "Previous run completed. Start a new run?"
```

---

## Edge Cases

### Stale State File

```
If state file exists but is very old (>24 hours):
  Print: "Found state from <timestamp>. The codebase may have changed."
  Offer: "Resume (re-verify baseline first)" or "Start fresh"

If "Resume": re-run verify command, compare to stored metric
  If metric matches (within 5%): safe to resume
  If metric differs significantly: warn, suggest fresh start
```

### Conflicting Signals

```
If state file says iteration 15 but TSV has 20 entries:
  TSV is append-only and more reliable for iteration count
  Use TSV iteration count, but config from state file
  Log: "State file and TSV diverged — using TSV for iteration count"
```

### Corrupt State File

```
If autoresearch-state.json fails to parse:
  1. Move to autoresearch-state.json.corrupt
  2. Fall back to TSV recovery (Mini-Wizard path)
  3. Log: "State file corrupted, falling back to TSV recovery"
```

### Multiple Run Tags

```
If state file has a different run_tag than the TSV entries:
  A new run was started on top of an old one
  Use the state file (it's the most recent intent)
  But read the old TSV entries for historical lessons
```
