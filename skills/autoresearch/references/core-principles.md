# Core Principles

Seven universal principles that ground the autoresearch approach. These are non-negotiable design axioms — every protocol decision traces back to one or more of these principles.

---

## Principle 1: Constraint = Enabler

Constraints are not limitations — they are the mechanism that makes autonomous operation possible.

### Bounded Scope
```
The agent MUST operate within a defined set of files (the scope).
Without a scope boundary:
- The agent wastes iterations exploring irrelevant code
- Changes cascade unpredictably through the codebase
- Rollback becomes unreliable (what exactly to revert?)
- The human loses the ability to reason about what the agent is doing

With a scope boundary:
- Every iteration targets the same files
- Changes are contained and reviewable
- Rollback is always clean
- Progress is linear and measurable
```

### Fixed Iteration Cost
```
Each iteration has a bounded cost:
- One hypothesis
- One modification
- One verification
- One decision

This fixed cost means:
- Bold experiments are cheap (just one iteration if they fail)
- The agent can afford to explore broadly
- Failures don't compound (each is cleanly reverted)
- Total cost is predictable: N iterations * cost_per_iteration
```

### Single Metric
```
ONE number drives ALL decisions.
Multiple metrics create ambiguity:
  "Metric A improved but Metric B regressed — what do we do?"
  Answer: there is no answer. The agent is stuck.

Single metric eliminates this:
  "The number went up. Keep."
  "The number went down. Discard."
  No ambiguity. No judgment calls. No stuck states.

If you need multiple metrics, create a composite:
  composite = 0.6 * metric_a + 0.4 * metric_b
  Now it's one number again.
```

---

## Principle 2: Separate Strategy from Tactics

The human provides DIRECTION. The agent provides EXECUTION.

### Human Responsibilities
```
- Define WHAT to optimize (the goal)
- Define WHERE to optimize (the scope)
- Define HOW to measure (the metric)
- Define WHICH WAY is better (the direction)
- Define WHEN to stop (iteration limit or manual interrupt)

The human NEVER specifies:
- Which specific code changes to make
- What order to try things in
- When to pivot strategies
- How to handle failures
```

### Agent Responsibilities
```
- Decide WHAT to try each iteration (hypothesis generation)
- Decide HOW to implement each hypothesis (code modifications)
- Decide WHETHER to keep or discard (metric comparison)
- Decide WHEN to pivot (consecutive discard detection)
- Decide HOW to recover from errors (crash handling)

The agent NEVER decides:
- What metric to optimize (human's job)
- Whether to continue or stop (human's job, via iteration limit or interrupt)
- Whether the goal is worth pursuing (human's job)
```

### Why This Separation Works
```
Humans are good at:
  - Defining objectives
  - Judging value
  - Setting boundaries
  - Strategic thinking

Agents are good at:
  - Generating variations
  - Mechanical measurement
  - Tireless iteration
  - Remembering everything tried

The separation plays to both strengths.
```

---

## Principle 3: Metrics Must Be Mechanical

If a human must interpret the result, it is not a valid metric.

### Valid Metrics
```
A valid metric is a number that:
1. Can be extracted by running a shell command
2. Is deterministic (same code -> same number, or close enough)
3. Has a clear direction (higher is better, or lower is better)
4. Is available without human judgment

Examples:
  pytest --tb=no | grep -c "passed"           -> integer, higher = better
  du -sb dist/ | cut -f1                       -> integer bytes, lower = better
  hyperfine './bench' --export-json /dev/stdout -> float seconds, lower = better
  python -c "import ast; print(len(ast.dump(ast.parse(open('x.py').read()))))"
                                                -> integer complexity, lower = better
```

### Invalid Metrics
```
NOT valid:
  "The code looks cleaner"          -> subjective
  "The API is more intuitive"       -> requires human judgment
  "Performance feels faster"        -> not measured
  "Test quality improved"           -> not a number

These can be GOALS (expressed in English) but not METRICS (expressed as commands).
The human's job is to find a mechanical proxy for subjective goals.
```

### Proxy Metrics
```
When the true goal is subjective, find a mechanical proxy:
  Goal: "cleaner code"      -> Metric: cyclomatic complexity (radon, lizard)
  Goal: "faster API"        -> Metric: p99 latency from benchmark
  Goal: "better tests"      -> Metric: mutation testing score (mutmut)
  Goal: "more readable"     -> Metric: Flesch-Kincaid score (textstat)

Proxy metrics are imperfect. That's fine.
A mechanical imperfect metric beats a subjective perfect one,
because the agent can iterate 100 times in the time a human evaluates once.
```

---

## Principle 4: Verification Must Be Fast

The fastest trustworthy check wins. Speed enables more iterations. More iterations enable better results.

### Speed Hierarchy
```
Prefer faster verification when it's trustworthy:

1. Syntax check (instant)          — catches obvious breaks
2. Type check (seconds)            — catches structural errors
3. Unit tests (seconds-minutes)    — catches behavioral regressions
4. Integration tests (minutes)     — catches system-level issues
5. Full test suite (minutes-hours) — catches everything

Use the FASTEST level that catches what matters for the metric.
The guard command can run a broader check for regressions.
```

### Iteration Economics
```
If verification takes 5 seconds:
  100 iterations = ~8 minutes of verification time
  -> Agent can explore broadly, try bold ideas

If verification takes 5 minutes:
  100 iterations = ~8 hours of verification time
  -> Agent should be more conservative, exploit more than explore

If verification takes 30 minutes:
  100 iterations = ~50 hours of verification time
  -> Consider: is there a faster proxy metric?
  -> Use bounded iterations (10-20) with careful hypothesis selection
```

### Timeout Policy
```
Default timeout: 5 minutes
If a verify command consistently takes >5 minutes:
  1. Find a faster proxy metric
  2. Or increase timeout (up to 30 minutes for ML)
  3. Or reduce scope to make verification faster

NEVER let a hanging verify command block the loop indefinitely.
Always set a timeout. Always handle timeout as "crash".
```

---

## Principle 5: Iteration Cost Shapes Behavior

When iterations are cheap, the agent should be bold. When expensive, conservative.

### Cheap Iterations (< 30 seconds)
```
Strategy: Explore aggressively
- Try bold, unconventional ideas
- Don't overthink hypotheses
- Let the metric sort winners from losers
- High exploration ratio (70% explore, 30% exploit)
- Failures are cheap — the cost of a discard is one rollback

This is the sweet spot. Design metrics and verification to be cheap.
```

### Moderate Iterations (30 seconds - 5 minutes)
```
Strategy: Balanced explore/exploit
- Think more carefully about hypotheses
- Extend successful strategies before exploring new ones
- 50% explore, 50% exploit
- Use lessons from previous runs to prune bad ideas early
```

### Expensive Iterations (> 5 minutes)
```
Strategy: Conservative exploitation
- Carefully reason about each hypothesis before trying
- Heavily exploit successful strategies
- 30% explore, 70% exploit
- Use bounded iterations with a tight limit
- Consider if there's a faster proxy metric
```

### Implication for Design
```
When setting up an autoresearch run:
- Choose the FASTEST verification that's still trustworthy
- Narrow the scope to reduce verification time
- Use guard commands for slow checks (they only run on promising changes)
- The verify command should ideally complete in <30 seconds
```

---

## Principle 6: Git as Memory and Audit Trail

Git is not just version control — it is the agent's memory system and the human's audit trail.

### Commit Before Verify
```
Why commit BEFORE running verification:
1. Clean rollback: git revert HEAD --no-edit
   vs. trying to manually undo scattered file changes
2. Atomic state: the experiment is captured as a single commit
3. Diffable: git diff HEAD^..HEAD shows exactly what was tried
4. History: git log shows the full sequence of experiments
5. Resumable: if the agent crashes, the state is in git
```

### Revert on Failure
```
Why revert instead of just "fixing it next iteration":
1. Accumulating failed changes corrupts the codebase
2. The next iteration's baseline is wrong
3. Metric comparison becomes unreliable
4. The human can't tell what's experimental vs. intentional

After revert:
  The codebase is in exactly the same state as before the experiment.
  The next iteration starts clean.
  The git history shows what was tried and discarded.
```

### History as Context
```
The agent reads git history at the start of each iteration:
- Recent experiments (tried strategies, outcomes)
- Successful changes (what worked, patterns)
- Failed changes (what to avoid, anti-patterns)
- Revert patterns (which strategies keep failing)

This makes the agent smarter over time within a single run.
Combined with autoresearch-lessons.md, it's smarter across runs too.
```

### Audit Trail
```
A human reviewing an autoresearch run can:
1. Read autoresearch-results.tsv for the high-level story
2. git log --oneline for the experiment sequence
3. git show <commit> for any specific experiment's changes
4. git diff <start>..<end> for the net effect of the entire run

Full transparency. Full reproducibility. Full accountability.
```

---

## Principle 7: Simplicity Is A Tiebreaker

When two approaches yield the same metric, the simpler one wins.

### The Simplicity Override
```
Condition:
  new_metric ~ old_metric (within min_delta)
  AND new_code is simpler than old_code (fewer lines, less complexity)

Decision: KEEP the simpler version.

Rationale:
  Simpler code is:
  - Easier to understand and maintain
  - Less likely to have bugs
  - Easier for future iterations to modify
  - A better foundation for further improvements
```

### Measuring Simplicity
```
Proxy measures for simplicity:
1. Net lines changed (negative = simpler)
2. Cyclomatic complexity delta (lower = simpler)
3. Number of branches/conditionals (fewer = simpler)
4. Nesting depth (shallower = simpler)

Use the simplest measure available: net line count.
If the change removes lines without removing functionality -> simpler.
```

### When NOT to Apply
```
Do NOT apply simplicity override when:
- The metric change is significant (above min_delta)
- The "simpler" version removes functionality
- The "simpler" version removes test coverage
- The "simpler" version introduces technical debt

Simplicity is a TIEBREAKER, not a primary objective.
The metric is always the primary objective.
```

### Complexity Ratchet
```
Over many iterations, the simplicity override creates a "complexity ratchet":
- Changes that improve the metric AND add complexity: KEEP
- Changes that improve the metric AND reduce complexity: KEEP (even better)
- Changes that maintain the metric AND reduce complexity: KEEP
- Changes that maintain the metric AND add complexity: DISCARD

The net effect: complexity only increases when it buys metric improvement.
Gratuitous complexity is filtered out. The codebase gets cleaner over time.
```
