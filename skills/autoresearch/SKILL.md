---
name: autoresearch
description: Autonomous Goal-directed Iteration — modify, verify, keep/discard, repeat
version: 2.0.0
---

# Autoresearch

LLM agent as mutation function. Modify → verify → keep/discard → repeat. Git is memory.

## Modes

| Mode | Load |
|---|---|
| *(default)* | `references/autonomous-loop-protocol.md` + `references/results-logging.md` + `references/core-principles.md` |
| `plan` | `references/plan-workflow.md` |
| `debug` | `references/debug-workflow.md` + `references/results-logging.md` |
| `fix` | `references/fix-workflow.md` + `references/results-logging.md` |
| `security` | `references/security-workflow.md` + `references/results-logging.md` |
| `ship` | `references/ship-workflow.md` + `references/results-logging.md` |
| `update` | Run: `bash "$(dirname "${SKILL_FILE}")/scripts/update.sh" check` |

On-demand: `references/metric-design.md`, `references/pivot-protocol.md`, `references/session-resume.md`, `references/lessons-protocol.md`

## Parameters

Required: **Goal** (text), **Scope** (files to modify), **Verify** (shell command), **Direction** (higher/lower).
Optional: **Metric** (extraction, default: last number from Verify output), **Support** (limited-write files), **Iterations** (default: ∞), **Guard** (pass/fail check), **MinDelta** (default: 0).

Metric extracts a number from Verify output: `eval "$verify_cmd" 2>&1 | $metric_extraction`. Default: `grep -oE '[0-9]+\.?[0-9]*' | tail -1`.

### 3-Tier Scope Model

```
┌─────────────────────────────────────────────────┐
│  Tier 1: Scope (Core)  — full read/write        │
│  The primary files the agent modifies freely.    │
│  All experiment changes happen here.             │
├─────────────────────────────────────────────────┤
│  Tier 2: Support       — limited write           │
│  Files modified ONLY to enable Core changes.     │
│  Allowed: add exports, adjust types, fix imports │
│  Blocked: logic changes, feature changes         │
├─────────────────────────────────────────────────┤
│  Tier 3: Context       — read-only               │
│  Files read for understanding but NEVER modified. │
└─────────────────────────────────────────────────┘
```

If Support not specified, auto-detect from Core's imports.

If any required parameter is missing: check `autoresearch-state.json` for resume, else ask. Do NOT start until confirmed.

## Setup

1. Read scope files. Auto-detect Support from imports if not specified.
2. Run verify → baseline metric → log iteration 0 in `autoresearch-results.tsv`.
3. Write `autoresearch-state.json` with config + initial state.
4. Print 1-line summary → "Starting autonomous loop. I will not ask further questions."

## The Loop

**This is a loop. Execute Steps 1-4 repeatedly. Do NOT stop after one iteration.**

```
iteration = 1

STEP 1 — PLAN: Run git log --oneline -10. Read scope files (diffs only after iter 1).
             Read results log tail. Pick hypothesis:
             Exploit recent keeps > Explore new ideas > Combine near-misses.
             3+ consecutive discards: REFINE. 5+: PIVOT (references/pivot-protocol.md).

STEP 2 — DO:  ONE atomic change (describable in one sentence).
             Stage ONLY scope files (never git add -A).
             Commit with EXACT format:  git commit -m "experiment(<scope>): <description>"
             Example: git commit -m "experiment(test_math.py): add subtract edge case test"
             Hook failure: fix, re-stage, NEW commit. 3 failures → revert, continue.

STEP 3 — CHECK: Run verify command, extract metric.
              Improved → keep (update current_best).
              Equal + simpler code → keep (simplicity override).
              No improvement or crash → git revert HEAD --no-edit, mark discard.
              On crash: read only tail of output for diagnosis.
              Append result to autoresearch-results.tsv. Update autoresearch-state.json.

STEP 4 — NEXT: iteration += 1.
              If iteration > max_iterations: print summary and stop.
              Otherwise: GO TO STEP 1. Do NOT output text. Do NOT stop.
```

### safe_revert
```
git revert HEAD --no-edit
If conflicts: git revert --abort && git reset HEAD~1 && git checkout HEAD -- <scope files>
```

## Rules

1. **NEVER stop** — run until limit or interrupt. One iteration is not a loop.
2. **Commit before verify** — enables clean revert on failure.
3. **One change per iteration** — if it needs "and", split.
4. **Commit format is `experiment(<scope>): <description>`** — always use this exact prefix.
5. **Same metric + less code = keep.**
6. **Read before write.** Never assume contents from memory.
7. **When stuck** — 3+ discards: REFINE. 5+: PIVOT.
8. **State every iteration** — `autoresearch-state.json` is the checkpoint.
9. **Save context** — minimal output. ~80% context full → save state and exit cleanly.

## Results Log

`autoresearch-results.tsv` — append-only, tab-separated, gitignored:
Header: `iteration	commit	metric	delta	guard	status	description`
Statuses: `baseline` | `keep` | `discard` | `crash` | `no-op` | `hook-blocked`
