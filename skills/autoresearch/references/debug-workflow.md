# Debug Workflow

Scientific debugging for `/autoresearch:debug`. Same modify-verify-keep/discard loop, but metric = bug reproduction and goal = root cause → verified fix.

**Input:** Symptom description and optional scope
**Output:** Verified fix with regression test

---

## Phase 1: Symptom Capture

Collect: what happens, what should happen, when (always/intermittent), error messages, environment. Reproduce before debugging — a bug you can't reproduce can't be verified fixed.

Distill reproduction to simplest possible command. This becomes the verify command for the debug loop.

---

## Phase 2: Hypothesis Formation

Generate candidates ranked by probability. Template per hypothesis:

```
H<N>: <one-sentence cause>
Evidence for/against: ...
Test: <how to confirm/refute>
Priority: high/medium/low
```

Categories to consider: input validation, state management, type mismatch, concurrency, configuration, dependency, edge case.

Rank by: proximity to error > simplicity (Occam) > consistency with repro conditions > git history.

---

## Phase 3: Evidence Collection

Read ONLY files/lines needed for current hypothesis. No shotgun debugging. Evidence types: code reading, git history, runtime observation, input tracing, state inspection, dependency check.

---

## Phase 4: Hypothesis Testing

Test ONE hypothesis at a time following autoresearch pattern:
1. Make ONE diagnostic change to confirm/refute
2. Run reproduction script
3. Observe: bug gone (cause found) / persists (refuted) / changed (partial) / new bug (revert)
4. Commit diagnostic: `debug(<scope>): test H<N> — <description>`
5. Revert diagnostic (temporary)
6. Log result, proceed to next hypothesis or fix

---

## Phase 5: Fix Implementation

State root cause in one sentence. Implement minimal fix (root cause, not symptom). Commit: `fix(<scope>): <description>`.

Verify: reproduction passes AND test suite passes. If either fails, iterate.

---

## Phase 6: Regression Check

Run full test suite + type checker + linter. Max 3 adjustment attempts if regressions found. Test edge cases related to the bug (empty, null, max values, concurrency).

---

## Phase 7: Results Logging

Log as `debug-N` iterations. Metric: 0 (bug present) or 1 (fixed). Direction: higher.

Print summary: symptom, root cause, fix, hypotheses tested, files modified, regression check status.

---

## Timeboxing

- 10 hypothesis tests without cause → summarize and suggest expanding scope
- 5 fix attempts without clean fix → suggest `/autoresearch:fix` for larger refactor

### Integration
On 3+ consecutive crashes in main loop, suggest `/autoresearch:debug`. Debug feeds back: structural issue found → fix applied → main loop resumes.
