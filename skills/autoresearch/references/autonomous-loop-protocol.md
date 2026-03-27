# Autonomous Loop Protocol

Full 8-phase loop specification for the autoresearch autonomous iteration engine.

---

## Phase 0: Precondition Checks

Execute BEFORE entering the loop. All checks must pass.

### Git State
```
Verify:
1. Current directory is inside a git repository (git rev-parse --git-dir)
2. Git is functional (git status returns 0)
3. The default branch exists and has at least one commit
```

If not a git repo, initialize one:
```bash
git init
# Stage specific files — never use `git add -A` (may include secrets or unrelated files)
# Stage scope files + known config files explicitly
git add <scope files> <project config files>
git commit -m "initial commit"
```

### Dirty Tree
```
Check: git status --porcelain
If dirty:
  1. Ask user (during setup only) whether to commit or stash
  2. If committing: git add <relevant files> && git commit -m "experiment(<scope>): pre-autoresearch snapshot"
  3. If stashing: git stash push -m "autoresearch-pre-run"
  4. Record the decision in state file
```

### Hooks
```
Check: ls .git/hooks/pre-commit* .husky/pre-commit* 2>/dev/null
If hooks exist:
  1. Note their presence in state
  2. NEVER use --no-verify
  3. If hooks fail during the loop, fix the underlying issue
```

### Gitignore
```
Ensure autoresearch working files are gitignored.
Check .gitignore for these entries; append any that are missing:

  autoresearch-results.tsv
  autoresearch-state.json
  autoresearch-state.json.tmp
  autoresearch-lessons.md

These are working files — never committed to the repository.
If .gitignore does not exist, create it with these entries.
```

### Session Resume
```
Check: test -f autoresearch-state.json
If state file exists:
  1. Load references/session-resume.md
  2. Follow recovery priority matrix
  3. May skip setup and jump directly into loop
```

---

## Phase 1: Review

Read the current state of the world. This phase is PURE OBSERVATION — no modifications.

### Read Scope Files (Context-Efficient)
```
For iteration 1 or after a PIVOT:
  Read ALL Core scope files fully (cold start needs full context)

For iterations 2+:
  Read only files that changed in the last iteration (use git diff HEAD~1 --name-only)
  Skip unchanged files — their contents are already known from prior reads
  This saves context window budget for long-running sessions

If Support scope is defined:
  Skim support files for interface/export changes since last iteration
  Note: available functions, type signatures, exports

If Context scope is defined:
  Only re-read context files when the current hypothesis requires understanding
  a specific dependency or pattern outside Core+Support
```

### Read Results Log
```
If autoresearch-results.tsv exists:
  Read the last 10-20 entries
  Identify: current best metric, recent trend, recent strategies
  Count: total keeps, total discards, consecutive discards
```

### Read Git History
```
git log --oneline -20
For recent experiment commits:
  Note what was tried, what worked, what didn't
  Identify patterns in successful changes
```

### Read Lessons
```
If autoresearch-lessons.md exists:
  Read lessons relevant to current goal and scope
  Prioritize recent lessons over old ones
  Note anti-patterns to avoid
```

---

## Phase 2: Ideate

Select the next hypothesis. This is the STRATEGIC phase — reasoning about WHAT to try.

### Hypothesis Selection Priority

1. **Exploit** (if recent keeps exist): Extend or deepen a successful strategy.
   - "Last iteration added 3 tests and improved coverage. Add 3 more similar tests."

2. **Explore** (default): Try something not yet attempted.
   - Review git log to confirm the idea hasn't been tried before.
   - Prefer ideas that are orthogonal to recent attempts.

3. **Combine** (if multiple near-misses): Merge two ideas that each almost worked.
   - "Idea A improved metric by 1 (below threshold). Idea B improved by 1. Try A+B together."

4. **Revisit** (if running low on ideas): Retry a discarded idea with a meaningful twist.
   - The twist MUST be substantive, not cosmetic.
   - NEVER retry the exact same change.

### Anti-Patterns to Avoid
- Repeating a discarded change with no meaningful difference
- Making changes outside the defined scope
- Trying overly complex multi-part changes (split them)
- Optimizing for the metric in ways that are clearly gaming it
- Ignoring lessons from previous runs

### Pivot Protocol Integration
```
If consecutive_discards >= 3:
  Load references/pivot-protocol.md
  Follow escalation levels
  Adjust ideation strategy accordingly
```

---

## Phase 3: Modify

Make ONE atomic change. This is the TACTICAL phase — translating a hypothesis into code.

### One Atomic Change
```
Rules:
1. The change MUST be describable in ONE sentence
2. If description needs "and", STOP — split into two iterations
3. Multi-file changes are fine IF they form one logical unit
   Example OK: "Add input validation to the parse function" (touches parser.py + test_parser.py)
   Example NOT OK: "Add validation and refactor error handling" — two changes

Scope tier rules:
  Core files:    modify freely (this is where experiments happen)
  Support files: modify ONLY to enable the Core change
    Allowed: add/modify exports, adjust type signatures, add imports
    Blocked: change business logic, restructure code, add features
    The Support change must be the MINIMUM needed to unblock Core
  Context files: NEVER modify (read-only reference)
```

### One-Sentence Test
```
Before writing code, state the hypothesis in one sentence:
  "If I <change>, then <metric> should <improve/decrease> because <reason>"

This sentence becomes the commit message description.
```

### Multi-File Atomicity
```
When a change spans multiple files:
1. Plan all modifications before writing any
2. Write all modifications
3. Verify they compile/parse together
4. Stage them all in one commit
5. If any file modification fails, revert ALL of them
```

### Read Before Write
```
ALWAYS read the current file contents before modifying.
NEVER assume contents from memory.
Files may have changed from previous iterations.
Always read from disk, not from memory.
```

---

## Phase 4: Commit

Commit BEFORE verification. This is essential for clean rollback.

### Commit Protocol
```bash
# Stage ONLY modified Core + Support files — never use git add -A
# Never stage Context files (they should never be modified)
git add <core_file1> <core_file2> <support_file1> ...

# Commit with experiment prefix
git commit -m "experiment(<scope>): <one-sentence description>"
```

### Commit Message Format
```
experiment(<scope>): <description>

Where:
  <scope> = the primary file or module being modified
  <description> = the one-sentence hypothesis from Phase 3

Examples:
  experiment(parser.py): add input length validation to reduce error rate
  experiment(test_api.ts): add timeout tests for connection handler
  experiment(styles.css): reduce specificity to decrease bundle size
```

### Hook Failure Handling
```
If pre-commit hook fails:
1. Read the hook error output
2. Fix the issue (formatting, lint, type errors)
3. Stage the fixes
4. Create a NEW commit (never amend — amend would modify the previous iteration's commit)
5. If hook fails 3 times: log as "hook-blocked", revert, continue to next iteration
```

---

## Phase 5: Verify

Run the mechanical metric extraction command. PURE MEASUREMENT — no judgment.

### Execution
```bash
# Run the verify command
output=$(eval "$verify_cmd" 2>&1)
exit_code=$?

# Extract the metric (a single number) from the output
if [ -n "$metric_extraction" ]; then
    # User-provided extraction pipeline
    metric=$(echo "$output" | eval "$metric_extraction")
else
    # Auto-extract: last number from the output
    metric=$(echo "$output" | grep -oE '[0-9]+\.?[0-9]*' | tail -1)
fi
```

### Timeout Rules
```
Default timeout: 5 minutes (300 seconds)
For ML domains: configurable up to 30 minutes
For fast domains (content, config): 1 minute

If command times out:
  1. Kill the process
  2. Status = "crash"
  3. Proceed to Phase 6 (Decide) with crash handling
```

### Metric Extraction
```
The verify command MUST produce output containing a number.

If metric_extraction is provided:
  Apply the user's extraction pipeline to verify output.

If metric_extraction is null (auto-extract):
  Strategy: extract ALL numbers from the full output, take the LAST one.
  Command: grep -oE '[0-9]+\.?[0-9]*' | tail -1
  1. If output is a single number, use it directly
  2. If output contains multiple numbers, use the LAST match across all lines
  3. If no number found, status = "crash" with note "metric extraction failed"

NEVER interpret non-numeric output as a metric.
NEVER use subjective assessment as a metric.
```

### Exit Code Handling
```
exit_code == 0: Normal, extract metric
exit_code != 0 AND metric extractable: Use the metric (some test runners exit non-zero on failures)
exit_code != 0 AND no metric: Status = "crash"
```

---

## Phase 5.5: Guard

Optional regression check. Only runs if `guard_cmd` is defined.

### Execution
```bash
guard_output=$(eval "$guard_cmd" 2>&1)
guard_exit=$?

# Guard is pass/fail only
guard_passed = (guard_exit == 0)
```

### Guard Failure Recovery
```
If guard fails:
  rework_count = 0
  while rework_count < 2:
    1. Read guard output to understand the failure
    2. Make a targeted fix (do NOT change the experiment, fix the regression)
    3. Stage and commit: "experiment(<scope>): rework — fix <guard issue>"
    4. Re-run guard_cmd
    5. If guard passes: break, proceed with status "keep (reworked)"
    6. rework_count += 1

  If still failing after 2 reworks:
    safe_revert() all commits since last known-good state
    Status = "discard"
    Note: "guard failure after 2 rework attempts"
```

---

## Phase 6: Decide

Binary decision: keep or discard. No ambiguity.

### Decision Logic
```python
# Terminology:
#   baseline     = the original metric at iteration 0 (never changes)
#   current_best = the best metric achieved so far (updated on each keep)
#   new_metric   = the metric from the current iteration

def decide(new_metric, current_best, direction, min_delta, guard_passed, code_delta):
    if crash or timeout:
        return "crash", safe_revert()

    if not guard_passed:
        return "discard", safe_revert()

    if direction == "higher":
        improved = (new_metric - current_best) >= min_delta
    else:  # lower
        improved = (current_best - new_metric) >= min_delta

    if improved:
        # Sanity check: anomalous jump detection
        avg_delta = average(last_5_keep_deltas)  # 0 if no history
        if avg_delta > 0 and abs(new_metric - current_best) > 3 * avg_delta:
            # Re-verify to confirm this isn't measurement noise
            confirmation = run_verify()
            if abs(confirmation - new_metric) > min_delta:
                new_metric = confirmation  # use confirmed value
                # recalculate improved
            else:
                note = "anomalous delta confirmed"
        return "keep", set_current_best(new_metric)

    # Simplicity override: equal metric but simpler code
    if abs(new_metric - current_best) < min_delta and code_delta < 0:
        return "keep", set_current_best(new_metric)  # simplicity wins

    return "discard", safe_revert()
```

### The safe_revert Function
```bash
safe_revert() {
    # Try clean revert first (preserves history)
    if git revert HEAD --no-edit 2>/dev/null; then
        return 0
    fi

    # Revert had conflicts — abort and use reset
    git revert --abort 2>/dev/null

    # Reset to before the experiment commit (soft: moves HEAD, unstages changes)
    git reset HEAD~1

    # Restore ONLY Core + Support scope files to their pre-experiment state
    # Never use `git checkout -- .` — that destroys ALL working tree changes
    git checkout HEAD -- $CORE_SCOPE_FILES $SUPPORT_SCOPE_FILES

    # Verify scope files are clean
    if git diff --name-only | grep -qF "$SCOPE_FILES"; then
        # Scope files still dirty — something went wrong, log and continue
        echo "[autoresearch] WARNING: scope files still dirty after revert"
    fi
}
```

### Simplicity Override
```
Conditions for simplicity override:
1. Metric is unchanged (within min_delta tolerance)
2. The change REDUCES total code in scope (net negative lines)
3. The change does not remove functionality (no deleted tests, no removed features)

When simplicity override triggers, log status as "keep" with note "simplicity override".
```

---

## Phase 7: Log

Append results to the TSV log. See `references/results-logging.md` for full format.

### Required Fields
```
iteration   commit_hash   metric   delta   guard   status   description
```

### Valid Statuses
| Status | Meaning |
|---|---|
| `baseline` | Iteration 0, initial measurement |
| `keep` | Metric improved, change preserved |
| `keep (reworked)` | Metric improved after guard fix rework |
| `discard` | Metric did not improve, change reverted |
| `crash` | Verify command failed or timed out, change reverted |
| `no-op` | No meaningful change was possible this iteration |
| `hook-blocked` | Pre-commit hook prevented the commit after 3 retries |

### State File Update
```
Write state after every iteration — this is the checkpoint that enables session resume.
Update autoresearch-state.json atomically (write to .tmp, then rename):
- state.iteration = current iteration number
- state.metric = current metric value
- state.consecutive_discards = current streak
- state.pivot_count = current pivot count
- state.last_status = status from this iteration
- state.updated_at = ISO timestamp
Persist every iteration without exception — even on crash or discard.
```

---

## Phase 8: Repeat

### Unbounded Mode
```
NEVER STOP.
NEVER ask "should I continue?"
NEVER print "I'll stop here unless you want me to continue."
Increment iteration counter and return to Phase 1.
The loop runs until the user interrupts (Ctrl+C / Escape).
```

### Bounded Mode
```
if iteration >= max_iterations:
    print_final_summary()
    extract_lessons()
    stop
else:
    increment iteration
    return to Phase 1
```

### Context Checkpoint (Before Phase 1)
```
Before starting the next iteration, check context budget:
If context window is ~80% full (agent-specific detection):
  1. Save state to autoresearch-state.json (emergency checkpoint)
  2. Print: "[autoresearch] Context checkpoint at iteration N. State saved. Resume with: /autoresearch"
  3. Graceful exit — do NOT continue with degraded context
  4. The next session auto-resumes via state file

This prevents mid-iteration corruption from context overflow.
The state file is the contract between sessions — always keep it current.
```

### When Stuck (>5 Consecutive Discards)
```
1. Load references/pivot-protocol.md
2. Follow escalation levels
3. Consider:
   - Are we measuring the right thing?
   - Is the scope too narrow?
   - Is there a fundamental barrier we're not seeing?
4. NEVER give up. NEVER stop. Pivot and try again.
5. If truly stuck after Level 4 escalation, make increasingly bold changes.
```

---

## Noise Handling

Some metrics are inherently noisy (timing, ML training). Use these strategies:

### Multi-Run Averaging
```
If metric variance is high:
  Run verify_cmd 3 times
  Use the median value
  Only apply for timing-based metrics
```

### Minimum Delta (min_delta)
```
Require a minimum improvement threshold.
Changes below this threshold are treated as noise.
Default: 0 (any improvement counts)
Recommended for noisy metrics: set to 2x observed variance
```

### Confirmation Run
```
After a "keep" decision on a noisy metric:
  Re-run verification once more
  If second run contradicts: change to "discard"
  Only use for metrics with known high variance
```

### Environment Pinning
```
For reproducible metrics:
  Pin random seeds where possible
  Disable parallel execution in test runners
  Use consistent hardware (same machine, same load)
  Note environment in state file
```

---

## Communication Rules

### During the Loop
- NEVER ask the user questions
- NEVER request confirmation
- NEVER suggest stopping or pausing
- NEVER say "I'll stop here" or "Let me know if you want me to continue"
- Make all decisions autonomously based on the metric
- Keep output minimal — every token of output consumes context window budget

### Status Updates (Context-Efficient)
```
Keep status output compact to conserve context window budget.

Every 5 iterations, print ONE line only:
[autoresearch] iter 15/∞ | metric: 87.3 (+12.1) | K:8 D:6 | streak: 2K

Every 10 iterations, print a 3-line summary (not a full report):
[autoresearch] === 10-iter summary ===
[autoresearch] best: 87.3 (baseline: 75.0, +12.3) | K:8 D:6 C:1
[autoresearch] top strategy: "add boundary tests" (+5.2)

On PIVOT events (1 line):
[autoresearch] PIVOT@12: "add edge case tests" → "refactor test helpers"

On guard failures (1 line):
[autoresearch] guard fail@9, rework 1/2
```

### Completion (Bounded Mode)
```
Print full summary:
- Iteration count and breakdown (keeps/discards/crashes)
- Starting and ending metric with net change
- Top 3 most impactful changes
- Lessons extracted
- Suggested next steps
```
