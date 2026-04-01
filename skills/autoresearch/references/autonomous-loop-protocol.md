# Autonomous Loop Protocol

Details that supplement the 4-step loop in SKILL.md.

---

## Phase 0: Preconditions (run once before loop)

1. Verify git repo (`git rev-parse --git-dir`). If missing, `git init`.
2. Dirty tree → ask user to commit or stash.
3. Ensure `.gitignore` has: `autoresearch-results.tsv`, `autoresearch-state.json`, `autoresearch-state.json.tmp`, `autoresearch-lessons.md`.
4. If `autoresearch-state.json` exists → load `references/session-resume.md` for recovery.

---

## Context-Efficient Reading (STEP 1)

- **Iteration 1 or post-PIVOT**: read ALL scope files fully.
- **Iteration 2+**: read only changed files (`git diff HEAD~1 --name-only`), skip unchanged.
- Support scope: skim interfaces/exports only. Context scope: re-read only when needed.

---

## Hypothesis Priority (STEP 1)

1. **Exploit**: extend a recent keep strategy.
2. **Explore**: try something new (check git log to confirm not tried before).
3. **Combine**: merge two near-miss ideas.
4. **Revisit**: retry discarded idea with a substantive twist. NEVER repeat exact same change.

---

## Commit Format (STEP 2)

```
git add <scope_files>   # NEVER git add -A
git commit -m "experiment(<scope>): <one-sentence description>"
```

Hook failure: read error, fix, re-stage, NEW commit (never amend). 3 failures → `hook-blocked`, revert, continue.

---

## Metric Extraction (STEP 3)

Run `verify_cmd`, extract metric via `metric_extraction` pipeline.
- Auto-extract: `grep -oE '[0-9]+\.?[0-9]*' | tail -1`
- No number found → crash.
- Exit code != 0 but metric extractable → use it.
- Timeout: 5min default. Timeout → crash.

---

## Guard Failure Recovery (STEP 3)

If `guard_cmd` defined and fails:
1. Read guard output, make targeted fix.
2. Commit: `experiment(<scope>): rework — fix <issue>`
3. Re-run guard. If pass → keep (reworked).
4. Max 2 rework attempts. Still failing → revert all, discard.

---

## Decision Logic (STEP 3)

```python
def decide(new_metric, current_best, direction, min_delta, guard_passed, code_delta):
    if crash or timeout:      return "crash", safe_revert()
    if not guard_passed:      return "discard", safe_revert()

    improved = (new_metric - current_best >= min_delta) if direction == "higher" \
          else (current_best - new_metric >= min_delta)

    if improved:              return "keep", set_current_best(new_metric)
    if code_delta < 0:        return "keep", note("simplicity override")
    return "discard", safe_revert()
```

---

## safe_revert()

```bash
# Try clean revert first (preserves history)
git revert HEAD --no-edit 2>/dev/null && return 0

# Revert conflicts — abort and reset
git revert --abort 2>/dev/null
git reset HEAD~1
git checkout HEAD -- $SCOPE_FILES   # ONLY scope files, never `git checkout -- .`
```

---

## Results Log Format

**File:** `autoresearch-results.tsv` — append-only, tab-separated, gitignored.

Header: `iteration	commit	metric	delta	guard	status	description`

Statuses: `baseline` | `keep` | `keep (reworked)` | `discard` | `crash` | `no-op` | `hook-blocked`

At Review, extract: current best, trend, consecutive discards, strategy patterns.

---

## State File Update (STEP 3)

Write `autoresearch-state.json` atomically (tmp + rename) after every iteration:
`iteration`, `metric`, `consecutive_discards`, `pivot_count`, `last_status`, `updated_at`.

---

## Core Principles (guiding all decisions)

1. **One metric** drives ALL decisions. No ambiguity.
2. **Mechanical measurement** only — no subjective judgment.
3. **Fast verification** enables more iterations. < 30s ideal.
4. **Commit before verify** — enables clean rollback.
5. **Simplicity wins** — same metric + less code = keep.
6. **Git is memory** — `git log` is the primary context source.
7. **Bold experiments are cheap** — they cost exactly one iteration if they fail.

---

## STEP 4: Loop Continuation

**Unbounded**: NEVER STOP. NEVER ask "should I continue?" Run until user interrupts or context ~80% full.
**Bounded**: if `iteration >= max_iterations` → print summary (K/D/C, baseline→final, top 3 changes) and stop. Otherwise → GO TO STEP 1.

**Context checkpoint**: if ~80% full, save state and print: `[autoresearch] Context checkpoint at iteration N. Resume with: /autoresearch`

---

## Status Output (minimal — save context)

- Every 5 iters: `[autoresearch] iter N/∞ | metric: X (±Y) | K:a D:b`
- On PIVOT: `[autoresearch] PIVOT@N: "old" → "new"`
- NEVER ask questions or suggest stopping during the loop.
