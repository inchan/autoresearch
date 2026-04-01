---
name: autoresearch
description: Autonomous Goal-directed Iteration — modify, verify, keep/discard, repeat
version: 0.0.1
---

# Autoresearch

Autonomous goal-directed iteration for any domain with a measurable metric.

**Core concept:** The LLM agent is the mutation function. Each iteration: modify code -> verify with a mechanical metric -> keep if improved, discard otherwise -> repeat. Git is the memory. The human sets direction; the agent executes.

---

## Mode Routing

The first argument determines the operating mode. If no mode is given, default to the main autonomous loop.

| Mode | References to load | Description |
|---|---|---|
| *(none)* | `references/autonomous-loop-protocol.md` + `references/results-logging.md` + `references/core-principles.md` | Main autonomous loop |
| `plan` | `references/plan-workflow.md` | Interactive goal -> config wizard |
| `debug` | `references/debug-workflow.md` + `references/results-logging.md` | Scientific debugging loop |
| `fix` | `references/fix-workflow.md` + `references/results-logging.md` | Iterative error repair |
| `security` | `references/security-workflow.md` + `references/results-logging.md` | STRIDE + OWASP security audit |
| `ship` | `references/ship-workflow.md` + `references/results-logging.md` | Universal shipping workflow |
| `update` | *(none)* | Check for updates and install latest version |
| `update install` | *(none)* | Install the latest version |

When mode is `update` or `update install`, skip all setup gates. Run the update script:

```bash
bash "$(dirname "${SKILL_FILE}")/scripts/update.sh" check   # for "update"
bash "$(dirname "${SKILL_FILE}")/scripts/update.sh" install  # for "update install"
```

Show the output to the user verbatim. No further action needed.

Supporting protocols (loaded on-demand):

| Reference | When loaded |
|---|---|
| `references/metric-design.md` | During setup (metric selection) and when metric issues arise |
| `references/pivot-protocol.md` | When consecutive discards accumulate |
| `references/session-resume.md` | When resuming a previous run |
| `references/lessons-protocol.md` | At run start and during ideation |

---

## Mandatory Interactive Setup Gate

Before entering the autonomous loop, ALL five configuration parameters MUST be present. Parse them from the user's invocation arguments.

### Required Parameters

| Parameter | Format | Example |
|---|---|---|
| **Goal** | Free text describing the objective | "Increase test coverage to 90%" |
| **Scope** | File glob or explicit file list | "src/utils/*.ts" |
| **Verify** | Shell command to run verification | `pytest --tb=short 2>&1` |
| **Direction** | `higher` or `lower` | "higher" |

### Semi-Required Parameters

| Parameter | Format | Default | Example |
|---|---|---|---|
| **Metric** | Extraction pipeline applied to Verify output to produce a single number | Auto-extract last number from Verify output | `grep -c passed` |

**Metric vs Verify relationship:**
- **Verify** = the command that runs. Its full output is used for context and error diagnosis.
- **Metric** = how to extract the single optimization number from Verify's output. If omitted, the agent extracts the last number from the last line of Verify output.
- When both are provided, the effective command is: `eval "$verify_cmd" 2>&1 | $metric_extraction`
- When Metric is omitted, the agent uses: `eval "$verify_cmd" 2>&1 | grep -oE '[0-9]+\.?[0-9]*' | tail -1`
- They CAN be merged into one command: if the user provides a Verify command that already outputs a single number, no separate Metric is needed.

### Optional Parameters

| Parameter | Format | Default |
|---|---|---|
| **Support** | File glob for limited-write files (imports, types, configs) | None |
| **Context** | File glob for read-only reference files | None |
| **Iterations** | Integer N for bounded runs | Unbounded (infinite) |
| **Guard** | Shell command returning 0 on pass | None |
| **MinDelta** | Minimum metric change to count as improvement | 0 |

### 3-Tier Scope Model

- **Scope (Core)**: full read/write — all experiments happen here.
- **Support**: limited write — only to enable Core changes (add exports, types, imports). Never change business logic. Auto-detected from Core imports if not specified.
- **Context**: read-only — for understanding, never modified.

### Missing Parameter Protocol

If ANY required parameter is missing from the invocation:

1. Check if `autoresearch-state.json` exists for session resume (see `references/session-resume.md`)
2. If no state file, prompt the user for EACH missing parameter using clear, specific questions
3. Suggest reasonable defaults based on codebase analysis when possible
4. Do NOT proceed to the loop until all five required parameters are confirmed

Example interaction for missing parameters:
```
I need a few details before starting the autonomous loop:

Goal: What are you trying to achieve? (e.g., "Reduce bundle size", "Increase test pass rate")
Scope: Which files should I modify? (e.g., "src/**/*.ts", "lib/parser.py")
Verify: What command runs verification? (e.g., "pytest --tb=short 2>&1")
Direction: Should the metric go "higher" or "lower"?

Optional (I'll auto-detect if omitted):
Support: Files I can minimally adjust to support Scope changes? (e.g., "src/types.ts")
Metric: How to extract the number from Verify output? (default: last number)
```

Once all parameters are confirmed, proceed to the Setup Phase. After setup completes and the user confirms, the agent becomes **fully autonomous**. NEVER pause mid-loop to ask questions.

---

## Setup Phase (do quickly — save context budget for the loop)

1. **Read** scope files. If Support scope not specified, auto-detect from imports and confirm.
2. **Baseline**: run verify_cmd, extract metric, log as iteration 0 in `autoresearch-results.tsv`.
3. **State**: write `autoresearch-state.json` with config + initial state.
4. **Confirm**: display 1-line summary → "Starting autonomous loop. I will not ask further questions."

---

## The Autonomous Loop

After setup, execute this loop. Each iteration has 4 steps. Full details in `references/autonomous-loop-protocol.md`.

**IMPORTANT: This is a loop. You execute Steps 1-4 repeatedly until the iteration limit is reached. Do NOT stop after one iteration.**

### Loop Steps (execute repeatedly)

```
iteration = 1

STEP 1 — PLAN: Read git log --oneline -10, read scope files (changed only after iter 1), read results log tail.
             Pick next hypothesis: Exploit recent keeps > Explore new ideas > Combine near-misses.
             If 3+ consecutive discards: REFINE. If 5+: PIVOT (see references/pivot-protocol.md).

STEP 2 — DO:  Make ONE atomic change (describable in one sentence).
             git add <scope files> && git commit -m "experiment(<scope>): <description>"

STEP 3 — CHECK: Run verify_cmd, extract metric.
              If improved: keep (update current_best).
              If equal + simpler code: keep (simplicity override).
              If no improvement or crash: git revert HEAD --no-edit, mark discard.
              If guard_cmd defined and fails: max 2 rework attempts, then discard.
              Append result to autoresearch-results.tsv. Update autoresearch-state.json.

STEP 4 — NEXT: iteration += 1.
              If iteration > max_iterations: print summary and stop.
              Otherwise: GO TO STEP 1. Do NOT output text. Do NOT stop.
```

### safe_revert Function
```
Try: git revert HEAD --no-edit
If revert conflicts:
  git revert --abort
  git reset HEAD~1
  git checkout HEAD -- $SCOPE_FILES   (restore ONLY scope files, not entire tree)
Verify scope files match pre-change state.
Never use `git checkout -- .` — it destroys unrelated working tree changes.
```

---

## Critical Rules

1. **Loop Until Done** — NEVER stop. NEVER ask "should I continue?" Run until iteration limit or user interrupt. One iteration is not a loop.
2. **Read Before Write** — always read files before modifying.
3. **One Change Per Iteration** — if description needs "and", split it.
4. **Commit Before Verify** — enables clean `git revert HEAD --no-edit` on failure.
5. **Mechanical Metric Only** — run command, extract number. No subjective judgment.
6. **Auto-rollback** — discard/crash → `git revert HEAD --no-edit`. Never leave failed code.
7. **Simplicity Wins** — same metric + less code = keep.
8. **When Stuck** — 3+ discards: REFINE. 5+: PIVOT. See `references/pivot-protocol.md`.
9. **Persist State** — update `autoresearch-state.json` after every iteration.
10. **Save Context** — read only changed files after iter 1. Minimal output. ~80% full → save state and exit.
