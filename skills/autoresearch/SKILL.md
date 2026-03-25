---
name: autoresearch
description: Autonomous Goal-directed Iteration — modify, verify, keep/discard, repeat
version: 1.0.0
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

The agent operates within a layered scope:

```
┌─────────────────────────────────────────────────┐
│  Tier 1: Scope (Core)  — full read/write        │
│  The primary files the agent modifies freely.    │
│  All experiment changes happen here.             │
│  Example: tests/*.py                             │
├─────────────────────────────────────────────────┤
│  Tier 2: Support       — limited write           │
│  Files modified ONLY to enable Core changes.     │
│  Allowed: add exports, adjust types, fix imports │
│  Blocked: logic changes, feature changes         │
│  Example: src/parser.py, src/utils.py            │
├─────────────────────────────────────────────────┤
│  Tier 3: Context       — read-only               │
│  Files read for understanding but NEVER modified. │
│  Used during Review and Ideate phases.           │
│  Example: src/**/*.py, config/*, docs/*          │
└─────────────────────────────────────────────────┘
```

**Tier 2 (Support) rules:**
- Changes to Support files MUST be directly required by a Core change
- Support changes are described as part of the same one-sentence hypothesis
- Support changes are committed together with Core changes (one atomic commit)
- If the experiment is discarded, Support changes are reverted along with Core
- Support changes MUST NOT alter business logic — only interface/structural adjustments

**Auto-detection during setup:**
When Support is not specified, the agent analyzes Core scope files:
1. Parse imports/requires/use statements in Core files
2. Identify files outside Core that are imported
3. Suggest these as Support scope
4. User confirms or adjusts

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

## Setup Phase

Execute these steps sequentially after all parameters are confirmed:

### 1. Read Scope Files
```
Read every file matched by the Scope (Core) glob.
Understand the codebase structure, conventions, and dependencies.
Note: if scope matches >20 files, read the most important ones and skim the rest.

If Context scope is defined, skim context files for understanding.
```

### 1.5. Analyze Dependencies and Auto-detect Support Scope
```
If Support scope is NOT specified by the user:
  1. Parse import/require/use statements in Core scope files
  2. Identify external files that Core files depend on
  3. Suggest these as Support scope:
     "Your scope files import from these files outside scope:
       - src/parser.py (imported by tests/test_parser.py)
       - src/utils.py (imported by tests/test_utils.py)
      Add as Support scope? (allows minimal modifications like adding exports)"
  4. User confirms or adjusts
  5. If user declines, note that some experiments may hit scope boundaries

If Support scope IS specified:
  Read Support files for understanding (structure, exports, types)
```

### 2. Define Configuration
```
Assemble the full configuration object:
- goal: <Goal text>
- scope: <Scope glob (Core)>
- support_scope: <Support glob or null>
- context_scope: <Context glob or null>
- verify_cmd: <Verify command>
- metric_extraction: <Metric extraction pipeline or null for auto-extract>
- direction: <higher|lower>
- guard_cmd: <Guard command or null>
- iterations: <N or null for unbounded>
- min_delta: <MinDelta or 0>
- metric_type: <direct|proxy|composite>
- run_tag: autoresearch-<timestamp>
```

### 3. Create Results Log
```
If autoresearch-results.tsv does not exist, create it with the TSV header.
See references/results-logging.md for exact format.
```

### 4. Check for Lessons
```
If autoresearch-lessons.md exists, read it.
Extract applicable lessons for the current goal and scope.
See references/lessons-protocol.md for details.
```

### 5. Establish Baseline
```
Run the Verify command to capture the starting metric value.
Log iteration 0 as status "baseline" in the results TSV.
Commit a snapshot if the working tree is dirty: "experiment(<scope>): baseline snapshot"
```

### 6. Write State File
```
Write autoresearch-state.json with full configuration and initial state.
See references/session-resume.md for schema.
```

### 7. Confirm and Go
```
Display a summary:
  Goal: ...
  Scope: ...
  Metric: ... (baseline: <value>)
  Direction: ...
  Verify: ...
  Guard: ...
  Iterations: N or unbounded

Then say: "Starting autonomous loop. I will not ask further questions."
```

---

## The Autonomous Loop

After setup, execute the 8-phase loop. Full protocol details in `references/autonomous-loop-protocol.md`.

### Loop Pseudocode

```
iteration = 1
consecutive_discards = 0
pivot_count = 0

while should_continue(iteration):

    # Phase 1: Review
    Read scope files (latest versions)
    Read results log tail (last 10 entries)
    Read recent git history (last 10 commits)
    Read lessons if available

    # Phase 2: Ideate
    Select next hypothesis using priority order:
      1. Exploit: extend/deepen a recent "keep" strategy
      2. Explore: try something new not yet attempted
      3. Combine: merge two near-miss ideas
      4. Revisit: retry a discarded idea with a twist
    Check pivot-protocol:
      3+ consecutive discards -> REFINE (adjust within current strategy)
      5+ consecutive discards -> PIVOT (abandon strategy entirely)

    # Phase 3: Modify
    Make ONE atomic change to scope files
    The change MUST be describable in one sentence
    If description needs "and", split into two iterations

    # Phase 4: Commit
    Stage only modified scope files (never git add -A)
    Commit: "experiment(<scope>): <one-sentence description>"
    If pre-commit hook fails: fix the issue, re-stage, NEW commit

    # Phase 5: Verify
    Run verify_cmd
    Extract numeric metric from output
    Timeout: 5 minutes max (configurable)

    # Phase 5.5: Guard (if guard_cmd defined)
    Run guard_cmd
    If exit code != 0: mark as guard failure
    Max 2 rework attempts before discard

    # Phase 6: Decide
    # Terminology: baseline = original start value, current_best = best metric so far
    delta = new_metric - current_best (adjusted for direction)
    if metric improved by >= min_delta AND guard passed:
        STATUS = "keep"
        consecutive_discards = 0
        pivot_count = 0
        current_best = new_metric
    elif metric unchanged AND code is simpler:
        STATUS = "keep" (simplicity override)
        consecutive_discards = 0
    elif crash or timeout:
        STATUS = "crash"
        safe_revert()
        consecutive_discards += 1
    else:
        STATUS = "discard"
        safe_revert()
        consecutive_discards += 1

    # Phase 7: Log
    Append to autoresearch-results.tsv
    Update autoresearch-state.json
    Extract lessons if applicable

    # Phase 8: Repeat
    iteration += 1
    # NEVER ask "should I continue?"
    # NEVER stop unless iterations limit reached or user interrupts
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

These rules are non-negotiable. Violating any of them breaks the loop's correctness guarantees.

### 1. Loop Until Done
- Unbounded mode: NEVER stop. NEVER ask "should I continue?" Run until interrupted.
- Bounded mode: Run exactly N iterations, then stop and summarize.
- The only valid stop conditions: iteration limit reached, user interrupt, unrecoverable crash.

### 2. Read Before Write
- ALWAYS read a file's current contents before modifying it.
- NEVER assume file contents from memory — they may have changed.

### 3. One Change Per Iteration
- Each iteration makes ONE atomic modification.
- If a change requires modifying 3 files to work, that's fine — it's still ONE logical change.
- If the description needs "and", it's two changes. Split them.

### 4. Mechanical Verification Only
- The metric MUST come from running a command and extracting a number.
- NEVER use subjective judgment ("this looks better") as a metric.
- NEVER approximate or estimate metrics — always measure.

### 5. Automatic Rollback
- Failed experiments are ALWAYS reverted via `safe_revert()`.
- NEVER leave failed experiment code in the working tree.
- NEVER skip rollback because "the next iteration will fix it."

### 6. Simplicity Wins
- Equal metric + less code = KEEP the simpler version.
- Tiny metric gain + significant complexity = DISCARD.
- When in doubt, prefer the version with fewer lines changed.

### 7. Git as Memory
- Commit BEFORE verification (Phase 4 before Phase 5).
- This enables clean rollback regardless of what verification does.
- Read `git log` and `git diff` as primary context sources.
- Never use `--no-verify` on commits. Fix hook issues instead.

### 8. When Stuck, Think Harder
- After 3+ consecutive discards: REFINE — adjust approach within current strategy.
- After 5+ consecutive discards: PIVOT — abandon strategy, try fundamentally different approach.
- Read `references/pivot-protocol.md` for full graduated escalation (REFINE → PIVOT → Web Search → Soft Blocker).
- NEVER repeat the exact same change that was already discarded.
- NEVER give up. Pivot to a fundamentally different strategy.

---

## Bounded Iterations

When `Iterations: N` is specified:

```
After iteration N completes:
1. Stop the loop
2. Print final summary:
   - Total iterations: N
   - Keeps: X
   - Discards: Y
   - Crashes: Z
   - Starting metric: <baseline>
   - Final metric: <current>
   - Net improvement: <delta> (<direction>)
3. List the top 3 most impactful changes (by delta)
4. Extract lessons to autoresearch-lessons.md
```

---

## Domain Adaptation

The core loop is domain-agnostic. Adapt these defaults based on detected domain:

| Domain | Typical Metric | Typical Verify | Typical Guard | Iteration Speed |
|---|---|---|---|---|
| **Backend** | Test pass count, latency (ms) | `pytest --tb=short` | `mypy --strict` | Fast (seconds) |
| **Frontend** | Lighthouse score, bundle size (KB) | `npm run build 2>&1 \| grep size` | `npx tsc --noEmit` | Medium (10-30s) |
| **ML** | Validation loss, accuracy (%) | `python train.py --eval-only` | `python prepare.py` | Slow (minutes) |
| **Content** | Word count, readability score | `wc -w < doc.md` | `markdownlint doc.md` | Fast (seconds) |
| **Performance** | Execution time (ms), memory (MB) | `hyperfine './bench'` | `cargo test` | Medium (10-30s) |
| **Refactoring** | Complexity score, line count | `radon cc -a src/` | `pytest` | Fast (seconds) |
| **Security** | Findings count, coverage % | `semgrep --config auto` | `npm audit` | Medium (10-30s) |

### Domain Detection Heuristics

When the user doesn't specify a domain, detect from:
- `package.json` -> Frontend/Backend JS/TS
- `requirements.txt` / `pyproject.toml` -> Python (Backend/ML)
- `Cargo.toml` -> Rust (Performance/Backend)
- `go.mod` -> Go (Backend)
- `*.md` majority in scope -> Content
- Test file patterns -> Testing domain

Adapt metric suggestions, verify commands, and guard commands accordingly during the Plan wizard.

---

## Communication Protocol

### During Setup (Interactive)
- Ask clear, specific questions for missing parameters
- Suggest defaults based on codebase analysis
- Confirm all parameters before launching

### During Loop (Autonomous)
- NEVER ask questions. Make decisions autonomously.
- Print a brief 1-line status every 5 iterations:
  ```
  [autoresearch] iteration 15/∞ | metric: 87.3 (+12.1) | keeps: 8 | discards: 6 | streak: 2 keeps
  ```
- Print a detailed summary block every 10 iterations (see results-logging.md).
- On PIVOT events, print a 1-line notice:
  ```
  [autoresearch] PIVOT at iteration 12: switching from "add edge case tests" to "refactor test helpers"
  ```
- On completion (bounded), print the full summary

### On Error
- Crashes: log, revert, continue
- Unrecoverable: stop loop, print diagnostic, suggest `/autoresearch debug`

---

## File References

All reference documents are in `references/` relative to this SKILL.md:

- `references/autonomous-loop-protocol.md` — Full 8-phase loop with all edge cases
- `references/core-principles.md` — 7 universal principles grounding the approach
- `references/metric-design.md` — Metric design guide, composite templates, anti-gaming defense
- `references/results-logging.md` — TSV format specification and logging functions
- `references/plan-workflow.md` — Interactive wizard for goal -> config
- `references/pivot-protocol.md` — Graduated stuck recovery protocol
- `references/session-resume.md` — Cross-session state recovery
- `references/lessons-protocol.md` — Cross-run learning and persistence
- `references/debug-workflow.md` — Scientific debugging loop
- `references/fix-workflow.md` — Iterative error repair protocol
- `references/security-workflow.md` — STRIDE + OWASP audit protocol
- `references/ship-workflow.md` — Universal shipping workflow
