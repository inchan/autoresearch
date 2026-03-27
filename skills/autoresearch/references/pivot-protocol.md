# Pivot Protocol

Graduated escalation for when the autonomous loop gets stuck. Each level represents an increasingly dramatic change in strategy.

---

## Overview

Getting stuck is normal. Not every hypothesis works. The pivot protocol ensures the agent recovers systematically rather than repeating failed approaches.

**Trigger:** Consecutive discards (experiments that didn't improve the metric)
**Reset:** Any single `keep` resets ALL escalation counters to zero

---

## Escalation Levels

### Level 1: REFINE (3 consecutive discards)

The current strategy isn't working in its current form. Adjust the approach without abandoning it.

```
Trigger: consecutive_discards >= 3

Actions:
1. Re-read the last 3 discard descriptions
2. Identify what they have in common (same strategy, different details)
3. Ask: "Why isn't this strategy working?"
4. Hypothesize a root cause:
   - Too small a change? (increase magnitude)
   - Wrong target within the scope? (shift focus to different files)
   - Missing prerequisite? (add a foundation change first)
   - Metric doesn't capture this improvement? (reconsider approach)
5. Make the NEXT experiment address the identified root cause
6. Log: "[REFINE] adjusted approach: <reason>"

Example:
  Discards: "add test for edge case A", "add test for edge case B", "add test for edge case C"
  REFINE insight: "Edge cases aren't the bottleneck — missing test infrastructure is"
  Next try: "Add test helper that enables testing multiple edge cases at once"
```

### Level 2: PIVOT (5 consecutive discards)

The current strategy is exhausted. Abandon it completely and try something fundamentally different.

```
Trigger: consecutive_discards >= 5

Actions:
1. Re-read ALL discard descriptions since the last keep
2. Identify the strategy being used (what theme connects them?)
3. Explicitly ABANDON that strategy
4. **Scope boundary check:**
   - Were any discards caused by needing to modify files outside Core scope?
   - If yes: analyze whether expanding Support scope would unblock progress
   - Suggest Support scope additions:
     "[PIVOT] Some experiments failed because they needed changes in files
      outside scope. Expanding Support scope to include <files> may help."
   - Auto-expand Support scope if the needed files are already imported by Core
5. Brainstorm 3 fundamentally different approaches
6. Pick the most promising one
7. Log: "[PIVOT] abandoning '<old strategy>', switching to '<new strategy>'"

Example:
  Old strategy: "adding individual test cases one by one"
  PIVOT options:
    a. Refactor the code-under-test to be more testable
    b. Add property-based testing that generates many cases
    c. Split a complex function into smaller testable units
  Chosen: option b (property-based testing)

What makes a PIVOT different from a REFINE:
  REFINE: same strategy, different execution
  PIVOT: completely different strategy

  REFINE: "try a different edge case"
  PIVOT: "stop testing edge cases, start refactoring for testability"
```

### Level 3: Web Search (2 PIVOTs without a keep)

Two full strategy changes haven't worked. The agent may be missing domain knowledge.

```
Trigger: pivot_count >= 2 AND no keep since last reset

Actions:
1. Formulate a specific search query based on the goal and current blockers
2. Use web search to find:
   - Best practices for the type of optimization being attempted
   - Common patterns that achieve similar goals
   - Known pitfalls or limitations of the current approach
3. Incorporate findings into the next hypothesis
4. Log: "[WEB SEARCH] researched: '<query>', found: '<key insight>'"

Search Query Templates:
  "how to improve <metric> in <framework/language>"
  "best practices for <goal type> in <domain>"
  "<specific error or limitation> workaround"
  "optimize <metric> <language> techniques"

Important:
  - Search for SPECIFIC information, not general advice
  - Look for concrete techniques, not theory
  - Apply findings in the next iteration
```

### Level 4: Soft Blocker (3 PIVOTs without a keep)

Three fundamentally different strategies have all failed. Something may be structurally wrong.

```
Trigger: pivot_count >= 3 AND no keep since last reset

Actions:
1. Print a warning (but do NOT stop):
   "[autoresearch] SOFT BLOCKER: 3 pivots without improvement.
    Possible causes:
    - Metric may not be sensitive to code changes in scope
    - Scope may be too narrow (the bottleneck is elsewhere)
    - Metric may have hit a structural ceiling
    Escalating to increasingly bold changes."

2. Diagnose root cause of stuckness:
   a. Scope issue? — re-analyze imports, suggest Support scope expansion
   b. Metric issue? — is the metric sensitive to changes in scope?
      Run verify without any changes 3 times to check variance.
      If metric is noisy, suggest increasing min_delta.
      If metric is at structural ceiling, suggest metric change.
   c. Strategy issue? — all reasonable approaches exhausted in this scope

3. Switch to bold exploration mode:
   - Try larger, more structural changes
   - Consider changes that affect the test/build infrastructure
   - Try combined multi-part changes (relax the one-change rule slightly)
   - If Support scope exists, allow broader changes to Support files
   - Continue the loop — do NOT stop. The human can interrupt if needed.

4. Log: "[SOFT BLOCKER] entering bold exploration mode"
```

---

## Counting Rules

### What Increments consecutive_discards

| Status | Increments? |
|---|---|
| `discard` | Yes (+1) |
| `crash` | Yes (+1) |
| `hook-blocked` | Yes (+1) |
| `no-op` | Yes (+1) |
| `keep` | No (resets to 0) |
| `keep (reworked)` | No (resets to 0) |
| `baseline` | No (N/A) |

### What Resets Counters

A single `keep` or `keep (reworked)` resets ALL counters:
```
consecutive_discards = 0
pivot_count = 0
```

A keep after PIVOT confirms the new strategy works. Clean slate — new strategy is validated.

### What Increments pivot_count

```
pivot_count increments by 1 each time Level 2 (PIVOT) triggers.
It does NOT increment on REFINE (Level 1).
It resets to 0 on any keep.
```

---

## Status-by-Status Behavior Table

| Status | consecutive_discards | pivot_count | Escalation Check |
|---|---|---|---|
| `baseline` | 0 (initial) | 0 (initial) | None |
| `keep` | -> 0 | -> 0 | All counters reset |
| `keep (reworked)` | -> 0 | -> 0 | All counters reset |
| `discard` | +1 | unchanged | Check thresholds |
| `crash` | +1 | unchanged | Check thresholds |
| `no-op` | +1 | unchanged | Check thresholds |
| `hook-blocked` | +1 | unchanged | Check thresholds |

### Threshold Check After Increment

```python
def check_escalation(consecutive_discards, pivot_count):
    if pivot_count >= 3:
        return "SOFT_BLOCKER"  # Level 4
    elif pivot_count >= 2:
        return "WEB_SEARCH"    # Level 3
    elif consecutive_discards >= 5:
        pivot_count += 1
        consecutive_discards = 0  # Reset after PIVOT
        return "PIVOT"            # Level 2
    elif consecutive_discards >= 3:
        return "REFINE"           # Level 1
    else:
        return None               # No escalation needed
```

---

## Integration with Lessons

### Extracting Lessons from Pivots

When a PIVOT occurs, extract a lesson:

```
Lesson:
  strategy: <the abandoned strategy>
  outcome: "Exhausted after N discards without improvement"
  insight: <why it failed, if identifiable>
  context: <goal, scope, metric>
  iteration: <current iteration>
  timestamp: <ISO timestamp>
```

### Reading Lessons Before Ideation

Before generating a hypothesis, check lessons for:
```
1. Strategies that failed in similar contexts -> avoid
2. Strategies that succeeded in similar contexts -> try first
3. Pivot reasons -> understand structural limitations
```

### Cross-Run Benefit

```
Run 1: PIVOT away from "adding individual tests" -> lesson recorded
Run 2: Reads lessons, skips "adding individual tests" entirely
  -> Starts with more promising strategies
  -> Fewer wasted iterations
  -> Faster convergence
```

---

## Communication During Escalation

### REFINE (Level 1) — Silent
```
No user-facing message. The agent quietly adjusts its approach.
Internal log only.
```

### PIVOT (Level 2) — Brief Notice
```
[autoresearch] PIVOT at iteration 12: abandoning "add edge case tests", switching to "refactor test helpers"
```

### Web Search (Level 3) — Brief Notice
```
[autoresearch] Researching: "property-based testing python pytest" after 2 pivots
```

### Soft Blocker (Level 4) — Warning
```
[autoresearch] WARNING: 3 pivots without improvement. Possible structural blocker. Entering bold exploration mode.
```

---

## Edge Cases

### Rapid Crash Loop
```
If 3+ consecutive crashes occur:
  Before escalating to REFINE, check:
  1. Is the verify command itself broken?
  2. Is there a dependency issue?
  3. Did a previous revert leave dirty state?

  Fix infrastructure issues before retrying experiments.
```

### Metric Plateau
```
If metric hasn't changed in 10+ iterations (all discards, no crashes):
  This is likely a structural ceiling.
  Level 4 (soft blocker) applies.

  Consider suggesting to the user (in the warning):
  - Expand the scope
  - Change the metric
  - Accept the current level as optimal
```

### Alternating Keep/Discard
```
If pattern is keep-discard-keep-discard-keep-discard:
  This is NOT stuck — it's progress, just noisy.
  consecutive_discards never reaches 3.
  No escalation needed.

  But consider: is the metric noisy?
  If so, suggest increasing min_delta.
```
