# Fix Workflow

Iterative error repair for `/autoresearch:fix`. Treats error repair as optimization: metric = error count, direction = lower, loop until zero.

**Input:** Target (tests/types/lint/build) and optional scope
**Output:** All errors fixed, verified, committed

---

## Phase 1: Error Inventory

Run target command, parse errors (file, line, severity, message, category). Print inventory with breakdown by category and total count as baseline.

| Target | Typical Command | Error Format |
|---|---|---|
| Tests | `pytest --tb=short` | Test name + assertion + traceback |
| Types | `mypy --strict src/` | file:line: error: message |
| Lint | `eslint src/ --format compact` | file:line:col: severity message |
| Build | `npm run build` | Varies by tool |

---

## Phase 2: Prioritization

Fix order: **Build → Syntax → Import → Type → Test → Lint → Warnings**

### Cascade Detection
Fix UPSTREAM errors first — a missing import causes type errors AND test failures. Signals: multiple errors in same file (fix topmost), same symbol (fix definition), imported modules (fix source).

### Blocking Errors
An error is "blocking" if it prevents build/tests from running or causes >3 downstream symptoms. Always fix first.

---

## Phase 3: One Fix Per Iteration

1. Select highest-priority unfixed error
2. Read file(s) at error location, understand root cause
3. Implement minimal fix
4. Commit: `fix(<scope>): <description>`
5. Re-run target, get new error count
6. Keep (count decreased) or discard (no improvement/regression)

One fix = one logical issue. May touch multiple files. If fixing error A resolves B and C, that's one iteration eliminating three errors.

---

## Phase 4: Verify + Guard

After each fix: re-run target. If count decreased → keep. If same → check if specific error transformed. If increased → discard immediately.

Cross-check: after test fix run type checker, after type fix run tests.

---

## Phase 5: Compound Fix Detection

If fixing A introduces B and fixing B introduces A (oscillation), they must be fixed together. Relax one-fix rule, commit as compound fix, verify count decreases by >= group size.

---

## Completion

**Zero errors**: confirm with final run, print summary (starting/final counts, iterations, K/D breakdown by category).

**Partial progress**: after 3 failed attempts on same error, mark "blocked" and continue. Report blocked errors with likely causes at end.

### Metric
Error count. Direction: lower. Guard: none (verify IS the guard). Min delta: 1.

### Integration
Invocable directly, from main loop on crash, or from debug workflow. Feeds back into main loop with cleaner codebase.
