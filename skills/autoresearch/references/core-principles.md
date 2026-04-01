# Core Principles

Seven non-negotiable axioms grounding autoresearch. Every protocol decision traces to one or more.

---

## 1. Constraint = Enabler

- **Bounded scope**: agent operates within defined files. Without it, changes cascade unpredictably and rollback breaks. With it, progress is linear and measurable.
- **Fixed iteration cost**: one hypothesis, one modification, one verification, one decision. Bold experiments are cheap (just one iteration if they fail).
- **Single metric**: ONE number drives ALL decisions. Multiple metrics create ambiguity ("A improved but B regressed — now what?"). For multi-dimensional goals, create a composite.

---

## 2. Separate Strategy from Tactics

**Human provides**: goal (WHAT), scope (WHERE), metric (HOW to measure), direction (WHICH WAY), stopping condition (WHEN).
**Agent provides**: hypothesis selection (WHAT to try), implementation (HOW), keep/discard decision (WHETHER), pivot timing (WHEN to change strategy), crash recovery (HOW to handle errors).

Humans are good at objectives and value judgments. Agents are good at generating variations, mechanical measurement, and tireless iteration.

---

## 3. Metrics Must Be Mechanical

A valid metric: extractable by shell command, deterministic, directional, no human judgment needed.

Subjective goals need mechanical proxies:
- "cleaner code" → cyclomatic complexity
- "faster API" → p99 latency from benchmark
- "better tests" → mutation testing score

A mechanical imperfect metric beats a subjective perfect one — the agent iterates 100 times in the time a human evaluates once.

---

## 4. Verification Must Be Fast

Speed enables more iterations. More iterations enable better results.

| Speed | Strategy | Explore/Exploit |
|---|---|---|
| < 30s (cheap) | Aggressive exploration, bold ideas | 70/30 |
| 30s–5min (moderate) | Balanced, extend successes then explore | 50/50 |
| > 5min (expensive) | Conservative exploitation, tight bounds | 30/70 |

Choose the FASTEST trustworthy verification. Use guard commands for slow regression checks. Default timeout: 5 minutes. Always handle timeout as "crash".

---

## 5. Iteration Cost Shapes Behavior

Design verification to be cheap (<30s ideal). Narrow scope to reduce cost. Use the guard command for broader but slower checks. When expensive, use bounded iterations with careful hypothesis selection.

---

## 6. Git as Memory and Audit Trail

- **Commit before verify**: enables clean rollback (`git revert HEAD --no-edit`), atomic state, diffable experiments
- **Revert on failure**: accumulating failed changes corrupts baseline and breaks metric comparison
- **History as context**: agent reads `git log` each iteration to learn what worked/failed. Combined with `autoresearch-lessons.md`, it's smarter across runs
- **Audit trail**: `autoresearch-results.tsv` for the story, `git log` for the sequence, `git show` for any experiment, `git diff` for net effect

---

## 7. Simplicity Is A Tiebreaker

Same metric + less code = **KEEP** the simpler version. Measure by net line count (negative = simpler).

**Complexity ratchet** over many iterations:
- Improve metric + add complexity → keep
- Improve metric + reduce complexity → keep (even better)
- Same metric + reduce complexity → keep (simplicity override)
- Same metric + add complexity → **discard**

Net effect: complexity only increases when it buys metric improvement.

Do NOT apply when metric change is significant, or when "simpler" removes functionality/tests.
