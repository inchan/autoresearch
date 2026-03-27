# Lessons Protocol

Cross-run learning persistence. Lessons are extracted from completed runs and applied to future runs to avoid repeating mistakes and accelerate convergence.

---

## Overview

Each autoresearch run generates knowledge:
- Which strategies work for this type of goal
- Which strategies fail and why
- What structural limitations exist
- What prerequisites are needed

The lessons protocol captures this knowledge and makes it available to future runs.

**File:** `autoresearch-lessons.md` (project root, gitignored, persists across runs)

---

## Lesson Structure

Each lesson is a structured Markdown entry:

```markdown
### Lesson: <short title>

- **Strategy:** <what was tried>
- **Outcome:** keep | discard | pivot
- **Insight:** <why it worked or failed>
- **Context:** Goal=<goal>, Scope=<scope>, Metric=<metric direction>
- **Iteration:** <iteration number>
- **Run:** <run_tag>
- **Timestamp:** <ISO 8601>

---
```

### Example Lessons

```markdown
### Lesson: Property-based tests outperform individual edge cases

- **Strategy:** Replace individual edge case tests with hypothesis-based property tests
- **Outcome:** keep
- **Insight:** A single property test covers more cases than 5 individual tests, improving the pass count metric faster per iteration
- **Context:** Goal=increase test coverage, Scope=tests/**/*.test.ts, Metric=pass count (higher)
- **Iteration:** 14
- **Run:** autoresearch-20260320T143022
- **Timestamp:** 2026-03-20T15:12:44Z

---

### Lesson: Adding tests one-by-one hits diminishing returns after ~10

- **Strategy:** Add individual test cases for uncovered code paths
- **Outcome:** pivot
- **Insight:** After 10 individual tests, each new test only increases the metric by 1. Refactoring for testability yields larger gains.
- **Context:** Goal=increase test coverage, Scope=tests/**/*.test.ts, Metric=pass count (higher)
- **Iteration:** 22
- **Run:** autoresearch-20260320T143022
- **Timestamp:** 2026-03-20T15:45:11Z

---

### Lesson: Mocking external APIs causes false positives in coverage metrics

- **Strategy:** Add mock-based tests for API integration points
- **Outcome:** discard
- **Insight:** Mock tests pass but don't improve the actual coverage metric because the coverage tool counts the mock, not the real code path
- **Context:** Goal=increase test coverage, Scope=src/api/**/*.ts, Metric=coverage percent (higher)
- **Iteration:** 8
- **Run:** autoresearch-20260319T091500
- **Timestamp:** 2026-03-19T09:45:22Z

---
```

---

## When to Extract Lessons

### After a Keep

```
When an experiment is kept (status = "keep" or "keep (reworked)"):

Extract a lesson if:
1. The delta is above average (this strategy is notably effective)
2. The strategy is novel (not an incremental extension of a previous keep)
3. The approach is generalizable (would apply to other goals/scopes)

Lesson type: positive (what worked and why)
```

### After a Pivot

```
When a PIVOT occurs (Level 2 escalation):

ALWAYS extract a lesson:
1. What strategy was abandoned
2. How many iterations were wasted
3. Why it failed (if identifiable)
4. What would have been a better starting point

Lesson type: negative (what failed and why)
```

### At Run Completion

```
When a bounded run completes or the user stops the loop:

Extract summary lessons:
1. Overall most effective strategy
2. Overall least effective strategy
3. Any structural limitations discovered
4. Recommended starting strategy for future similar runs

Lesson type: summary (high-level takeaways)
```

---

## Reading Lessons

### At Run Start

```
When a new autoresearch run begins:
1. Check if autoresearch-lessons.md exists
2. If yes, read ALL lessons
3. Filter for relevance:
   a. Same or similar goal? (high relevance)
   b. Same or overlapping scope? (high relevance)
   c. Same metric type? (medium relevance)
   d. Same language/framework? (low relevance)
4. Summarize applicable lessons:
   "Previous runs suggest:
    - Start with property-based tests (effective in 3 previous runs)
    - Avoid individual edge case tests (diminishing returns after ~10)
    - Consider refactoring for testability if coverage plateaus"
```

### During Ideation (Phase 2)

```
Before generating a hypothesis:
1. Check lessons for strategies that failed in this context -> avoid
2. Check lessons for strategies that succeeded -> try first
3. Check lessons for prerequisites -> address first
4. Check lessons for structural limitations -> set expectations

Integration:
  If a lesson says "strategy X failed because Y":
    Do NOT try strategy X unless Y has been resolved
  If a lesson says "strategy A works well for this goal":
    Prioritize strategy A in early iterations
```

### After REFINE/PIVOT

```
When the pivot protocol triggers:
1. Re-read lessons specifically for pivot insights
2. Look for: "what worked after pivoting away from this strategy?"
3. Use pivot lessons to choose the next strategy more wisely
```

---

## Capacity Management

### Cap at 50 Lessons

```
The lessons file should not grow unboundedly.
Maximum: 50 lessons.

When adding a lesson and count >= 50:
1. Apply time decay: remove the oldest lesson
2. Exception: keep "summary" type lessons longer (they're higher value)
3. Exception: keep lessons with unique insights (not duplicated by newer ones)
```

### Time Decay Rules

```
Lesson age categories:
  Fresh (< 7 days):    full weight, never auto-removed
  Recent (7-30 days):  80% weight, removable if redundant
  Old (30-90 days):    50% weight, removable
  Stale (> 90 days):   20% weight, remove first

Weight affects reading priority, not removal order.
Always remove stale lessons first when at capacity.
```

### Deduplication

```
Before adding a new lesson, check for near-duplicates:
  Same strategy + same outcome + same context -> merge

  Merge by:
  1. Keep the more recent timestamp
  2. Combine insights if they differ
  3. Update iteration and run references

  This prevents the lessons file from filling with
  repetitive entries about the same strategy.
```

---

## Lesson File Format

### Header

```markdown
# Autoresearch Lessons

Automatically extracted insights from previous autoresearch runs.
This file is read at the start of each run to inform strategy selection.

Last updated: 2026-03-20T15:45:11Z
Total lessons: 12

---
```

### Body

Each lesson follows the structure defined above, separated by `---` horizontal rules.

### Footer

```markdown
---

<!-- Managed by autoresearch. Do not edit manually unless you know what you're doing. -->
<!-- Capacity: 12/50 lessons -->
```

---

## Integration with Other Protocols

### With Results Logging

```
The results TSV provides the raw data.
Lessons are extracted FROM the TSV data.
The lesson adds interpretation and context that the TSV alone doesn't capture.

TSV says: iteration 14, keep, delta +5.0, "add property-based tests"
Lesson adds: "Property-based tests are highly effective for coverage goals
              because they cover more code paths per test"
```

### With Pivot Protocol

```
Every PIVOT generates a lesson (mandatory).
Lessons inform future PIVOT decisions (what to pivot TO, not just FROM).
This creates a feedback loop:
  Run 1: try A, fail, pivot to B, succeed
  Run 2: skip A, start with B (from lessons)
```

### With Session Resume

```
Lessons persist across sessions (the file is never reset).
When resuming a session, lessons are re-read for fresh context.
This is important because the agent in a new session has no memory
of the previous session's reasoning — only the lessons file bridges that gap.
```

---

## Manual Curation

```
Users CAN manually edit autoresearch-lessons.md:
- Add domain knowledge the agent can't discover on its own
- Remove incorrect or misleading lessons
- Annotate lessons with additional context
- Pin important lessons (add "pinned: true" to prevent auto-removal)

The agent should respect manual additions and not overwrite them.
Detect manual entries by: no "Run:" field, or "pinned: true" marker.
```

