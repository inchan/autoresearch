# Debug Workflow

Scientific debugging loop for the `/autoresearch:debug` command. Applies the autoresearch iteration pattern to bug hunting: form hypotheses, test them one at a time, converge on the root cause.

---

## Overview

Debugging is research. The same modify-verify-keep/discard loop applies, but the "metric" is bug reproduction and the "goal" is root cause identification followed by a verified fix.

**Input:** A symptom description and optional scope
**Output:** A verified fix with regression test

---

## Phase 1: Symptom Capture

Gather all observable evidence before forming any hypotheses.

### Collect the Symptom

```
From user input, extract:
1. What is happening? (the bug behavior)
2. What should be happening? (expected behavior)
3. When does it happen? (always, intermittently, after specific action)
4. Error messages (exact text, stack traces)
5. Environment (OS, runtime version, configuration)
```

### Reproduce the Symptom

```
BEFORE debugging, confirm the bug is reproducible:
1. Run the failing command/test/action
2. Capture the exact output
3. If not reproducible: note conditions, try to create a reliable reproduction

If the bug cannot be reproduced:
  - Check environment differences
  - Check for race conditions (timing-dependent)
  - Check for state-dependent behavior (run order, cached data)
  - Ask the user for more details if truly stuck

A bug you can't reproduce is a bug you can't verify fixing.
```

### Create a Reproduction Script

```bash
# Distill reproduction to the simplest possible command
# This becomes the "verify command" for the debug loop

# Example:
reproduce_cmd="python -c 'from mylib import parse; parse(\"<invalid>\")' 2>&1"
# Expected: should return None
# Actual: raises TypeError

# This script MUST fail/show the bug currently
# After the fix, it MUST pass/show correct behavior
```

---

## Phase 2: Hypothesis Formation

Generate candidate explanations, ranked by probability.

### Hypothesis Template

```
For each hypothesis:
  H<N>: <one-sentence explanation of the cause>
  Evidence for: <what supports this hypothesis>
  Evidence against: <what contradicts this hypothesis>
  Test: <how to confirm or refute this hypothesis>
  Priority: <high/medium/low based on probability>
```

### Hypothesis Generation Strategy

```
1. Start from the error location (stack trace, error message)
2. Trace data flow backward from the error point
3. Check recent changes (git log -- <relevant files>)
4. Consider categories:
   a. Input validation (bad input reaching code that assumes good input)
   b. State management (stale/corrupt state)
   c. Type mismatch (wrong type passed where another expected)
   d. Concurrency (race condition, deadlock)
   e. Configuration (wrong setting, missing env var)
   f. Dependency (version mismatch, missing package)
   g. Edge case (boundary value, empty input, null)
```

### Prioritization

```
Rank hypotheses by:
1. Proximity to error (closer to the crash = more likely)
2. Simplicity (simpler explanation = more likely, Occam's razor)
3. Reproducibility (consistent with reproduction conditions)
4. History (similar bugs in git history)

Test in priority order: highest probability first.
```

---

## Phase 3: Evidence Collection

Gather TARGETED evidence. Do NOT read the entire codebase.

### Targeted Reading

```
For each hypothesis, identify the minimal set of files/lines to read:
  H1 needs: parser.py lines 45-80, types.py class InputType
  H2 needs: config.py load_config(), .env file
  H3 needs: git log --oneline -10 -- parser.py

Read ONLY what's needed to test the current hypothesis.
Avoid "shotgun debugging" (reading everything and hoping to spot the bug).
```

### Evidence Types

```
1. Code reading: examine the suspected code path
2. Git history: when was this code last changed?
3. Runtime observation: add temporary logging/prints
4. Input tracing: follow the data from entry to error
5. State inspection: check variable values at key points
6. Dependency check: verify versions and compatibility
```

### Anti-Patterns

```
DO NOT:
- Read every file in the project (shotgun approach)
- Add logging everywhere (creates noise)
- Change multiple things at once (can't identify which fixed it)
- Assume the bug is in the most complex code (often it's simple)
- Skip reading the actual error message/stack trace
```

---

## Phase 4: Hypothesis Testing

Test ONE hypothesis at a time. This is the core iteration loop.

### One Variable at a Time

```
For hypothesis H<N>:
1. Make ONE change that would confirm or refute H<N>
2. Run the reproduction script
3. Observe the result:
   - Bug gone -> H<N> is likely the cause (proceed to fix)
   - Bug persists -> H<N> is refuted (try next hypothesis)
   - Bug changed -> Partial cause found (refine hypothesis)
   - New bug -> Unrelated issue introduced (revert, rethink)
```

### Testing Methods

```
Diagnostic techniques (one at a time):
1. Add an assertion before the error point
2. Add a type check / guard clause
3. Log the value of a suspected variable
4. Substitute a known-good value for a suspected-bad input
5. Disable a suspected code path (comment out, feature flag)
6. Run with a different configuration
7. Bisect: git bisect to find the introducing commit
```

### Iteration Protocol

```
Each hypothesis test follows the autoresearch pattern:
1. Hypothesis = the "ideation" phase
2. Diagnostic change = the "modify" phase
3. Commit diagnostic: "debug(<scope>): test H<N> — <description>"
4. Run reproduction = the "verify" phase
5. Decide: confirmed, refuted, or partial
6. Revert diagnostic change (it's temporary)
7. Log result
8. Move to next hypothesis or proceed to fix
```

---

## Phase 5: Fix Implementation

Once the root cause is identified, implement the fix.

### Fix Protocol

```
1. State the root cause in one sentence:
   "The bug occurs because <function> does not handle <condition>,
    causing <error> when <input>."

2. Implement the minimal fix:
   - Fix the root cause, not the symptom
   - Prefer the smallest change that resolves the issue
   - Do not refactor unrelated code in the same change

3. Commit the fix:
   "fix(<scope>): <one-sentence description of the fix>"
```

### Fix Verification

```
After implementing the fix:
1. Run the reproduction script -> bug should be gone
2. Run the test suite -> no regressions
3. If both pass -> fix is verified
4. If reproduction still fails -> fix is incomplete, iterate
5. If tests regress -> fix has side effects, iterate
```

---

## Phase 6: Regression Check

Ensure the fix doesn't break anything else.

### Regression Testing

```
1. Run the full test suite (or the guard command if defined)
2. Run any integration tests
3. Check for type errors (if applicable)
4. Check for lint violations (if applicable)

If any regressions:
  1. Understand why the fix caused the regression
  2. Adjust the fix to avoid the regression
  3. Re-verify (both fix and regression test)
  Max 3 adjustment attempts before reporting the conflict
```

### Edge Case Validation

```
After the fix is verified:
1. Test edge cases related to the bug:
   - What about empty input?
   - What about null/undefined?
   - What about maximum values?
   - What about concurrent access?
2. Add test cases for any edge cases that weren't covered
```

---

## Phase 7: Results Logging

Log the debug session results.

### Log Entry Format

```
In autoresearch-results.tsv (if it exists, or create one):
  iteration: debug-1, debug-2, etc.
  commit: the fix commit hash
  metric: 1 (bug fixed) or 0 (bug not fixed)
  delta: 1
  guard: pass/fail
  status: keep (if fixed) or discard (if not)
  description: "fix: <root cause description>"
```

### Debug Report

```
Print a summary at the end:

Debug Summary:
  Symptom: <what was reported>
  Root Cause: <what was found>
  Fix: <what was changed>
  Hypotheses Tested: N
  Files Modified: <list>
  Regression Check: pass/fail

  Commit: <hash> — <message>
```

---

## Metric for Debug Loop

The debug "metric" is binary:
```
0 = bug still present (reproduction script shows the bug)
1 = bug fixed (reproduction script shows correct behavior)

Direction: higher (we want to go from 0 to 1)
```

This makes the keep/discard decision simple:
- Bug is fixed and tests pass -> keep
- Bug persists or tests regress -> discard (revert)

---

## Timeboxing

```
Debug sessions should be timeboxed:
- After 10 hypothesis tests without identifying the cause:
  Print a summary of what's been tried
  Suggest: expand scope, gather more information, or try a different approach

- After 5 fix attempts without a clean fix:
  Print a summary of the constraints
  The fix may require a larger refactor — suggest /autoresearch:fix
```

---

## Integration with Main Loop

```
When /autoresearch encounters a "crash" status:
  If 3+ consecutive crashes on similar changes:
  Suggest: "Consider running /autoresearch:debug to investigate the crash pattern"

The debug workflow can feed back into the main loop:
  1. Debug identifies a structural issue
  2. Fix resolves the issue
  3. Main loop can now make changes that previously crashed
```
