---
name: autoresearch
description: Autonomous Goal-directed Iteration — modify, verify, keep/discard, repeat
version: 0.0.2
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
Optional: **Metric** (extraction, default: last number from Verify output), **Support** (limited-write files, auto-detected from imports), **Iterations** (default: ∞), **Guard** (pass/fail check), **MinDelta** (default: 0).

Metric extracts a number from Verify output: `eval "$verify_cmd" 2>&1 | $metric_extraction`. Default: `grep -oE '[0-9]+\.?[0-9]*' | tail -1`.

Scope tiers: **Core** (full read/write) → **Support** (imports/types/exports only, never business logic) → **Context** (read-only).

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
             git add <scope files> && git commit -m "experiment(<scope>): <description>"

STEP 3 — CHECK: Run verify command. Redirect verbose output to file if needed.
              Extract metric number from output.
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
4. **Same metric + less code = keep.**
5. **Read before write.** Never assume contents from memory.
6. **When stuck** — 3+ discards: REFINE. 5+: PIVOT.
7. **State every iteration** — `autoresearch-state.json` is the checkpoint.
8. **Save context** — minimal output. ~80% context full → save state and exit cleanly.

## Results Log

`autoresearch-results.tsv` — append-only, tab-separated, gitignored:
Header: `iteration	commit	metric	delta	guard	status	description`
Statuses: `baseline` | `keep` | `discard` | `crash` | `no-op` | `hook-blocked`
