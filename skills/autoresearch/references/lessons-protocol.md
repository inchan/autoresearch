# Lessons Protocol

Cross-run learning persistence. **File:** `autoresearch-lessons.md` (project root, gitignored).

---

## Lesson Structure

```markdown
### Lesson: <title>
- **Strategy:** <what was tried>
- **Outcome:** keep | discard | pivot
- **Insight:** <why it worked/failed>
- **Context:** Goal=<goal>, Scope=<scope>, Metric=<metric direction>
- **Iteration:** N | **Run:** <run_tag> | **Timestamp:** <ISO>
---
```

---

## When to Extract

| Trigger | Condition | Lesson Type |
|---|---|---|
| After keep | Delta above average, novel strategy, or generalizable | Positive |
| After PIVOT | Always (mandatory) | Negative — what failed and why |
| Run completion | Summary of most/least effective strategies, limitations | Summary |

---

## Reading Lessons

**At run start:** read all, filter by relevance (same goal > same scope > same metric > same language).

**During ideation:** check for failed strategies (avoid), successful strategies (try first), prerequisites (address first), structural limitations (set expectations).

**After PIVOT:** re-read for pivot-specific insights — what worked after similar pivots.

---

## Capacity Management

- **Max 50 lessons**. When full, remove oldest first (stale >90 days → old 30-90 → recent 7-30). Keep summary-type and unique-insight lessons longer.
- **Deduplication:** same strategy + outcome + context → merge (keep newer timestamp, combine insights).

---

## File Format

Header: title + last updated + total count. Body: lessons separated by `---`. Footer: capacity counter.

---

## Integration

- **Results TSV** provides raw data; lessons add interpretation and context
- **Pivot protocol**: every PIVOT generates a lesson; lessons inform future pivot choices (Run 1: fail A → pivot to B. Run 2: skip A, start with B)
- **Session resume**: lessons persist across sessions, bridging memory gap between agent instances
- **Manual curation**: users can add domain knowledge, remove bad lessons, pin important ones (`pinned: true` prevents auto-removal)
