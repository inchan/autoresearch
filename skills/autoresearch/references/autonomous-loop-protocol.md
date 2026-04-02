# Autonomous Loop Protocol

Supplements the loop in SKILL.md with edge-case details.

## Preconditions (once before loop)

1. `git rev-parse --git-dir` — if missing, `git init`.
2. Dirty tree → commit or stash.
3. `.gitignore` must have: `autoresearch-results.tsv`, `autoresearch-state.json`, `autoresearch-state.json.tmp`, `autoresearch-lessons.md`.
4. If `autoresearch-state.json` exists → load `references/session-resume.md`.

## Reading Efficiency

- Iter 1 or post-PIVOT: read ALL scope files.
- Iter 2+: read only changed files (`git diff HEAD~1 --name-only`).

## Hypothesis Priority

1. **Exploit** recent keep. 2. **Explore** something new. 3. **Combine** near-misses. 4. **Revisit** with twist. Never repeat exact same change.

## Guard Failure

If `guard_cmd` fails: fix, recommit, re-run. Max 2 rework attempts. Still failing → revert all, discard.

## Decision Logic

```
improved = (new - best >= min_delta) if higher else (best - new >= min_delta)
if crash/timeout     → crash, revert
if !guard            → discard, revert
if improved          → keep
if code_delta < 0    → keep (simplicity)
else                 → discard, revert
```

## Loop Continuation

**Unbounded**: NEVER stop. Run until interrupt or context ~80% full.
**Bounded**: iteration >= max → summary (K/D/C, baseline→final, top 3). Else → STEP 1.
**Context checkpoint**: ~80% full → save state → `[autoresearch] Context checkpoint at iter N. Resume with: /autoresearch`

## Status Output

Every 5 iters: `[autoresearch] iter N/∞ | metric: X (±Y) | K:a D:b`
On PIVOT: `[autoresearch] PIVOT@N: "old" → "new"`
NEVER ask questions or suggest stopping.
