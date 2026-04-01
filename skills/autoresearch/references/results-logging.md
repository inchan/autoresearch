# Results Logging

TSV format for the autoresearch results log — the canonical record of every iteration.

**File:** `autoresearch-results.tsv` (project root, gitignored, append-only, UTF-8, LF, tab-separated)

---

## Format

### Header
```
iteration	commit	metric	delta	guard	status	description
```

| Column | Type | Description |
|---|---|---|
| iteration | Integer | 0 = baseline, 1+ = experiments |
| commit | String | Short git hash (7 chars) |
| metric | Float | Extracted metric value |
| delta | Float | Change from current best (positive = improvement for the configured direction) |
| guard | String | `pass` / `fail` / `skip` |
| status | String | See status table below |
| description | String | One-sentence change description |

---

## Valid Statuses

| Status | Meaning | Reverted? |
|---|---|---|
| `baseline` | Iteration 0 initial measurement | No |
| `keep` | Metric improved >= min_delta | No |
| `keep (reworked)` | Improved after guard fix | No |
| `discard` | No improvement | Yes |
| `crash` | Verify failed/timed out | Yes |
| `no-op` | No meaningful change possible | No |
| `hook-blocked` | Pre-commit failed 3x | Yes |

### Decision Tree
```
Committed? → No (3x hook fail) → hook-blocked
           → Yes → Verify OK? → No → crash
                              → Yes → Improved? → Yes → Guard pass? → Yes → keep
                                                                     → No → Rework OK? → keep (reworked) / discard
                                                → No → Simpler code? → keep (simplicity) / discard
```

---

## Reading the Log

At Phase 1 (Review), extract from the log:
- **Current best**: metric from most recent keep/baseline
- **Trend**: are keep deltas growing or shrinking?
- **Consecutive discards**: count since last keep
- **Strategy patterns**: which descriptions correlate with keep vs discard?
- **Crash patterns**: what changes cause crashes?

---

## Summary (Bounded Mode)

At completion, print: baseline → final metric (+delta), breakdown (K/D/C/%), top 3 changes by delta, pivot count, lessons extracted.

## Direction in Baseline
Embed in baseline description: `initial measurement (direction: higher)`. Delta always displayed as positive = improvement.

## Safety
- Append-only (never modify existing rows)
- Both `autoresearch-results.tsv` and `autoresearch-state.json` are gitignored working files
- State file: atomic write (tmp + rename). TSV append: inherently atomic
