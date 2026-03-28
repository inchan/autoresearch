# Pivot Protocol

Graduated escalation for when the loop gets stuck. Any single `keep` resets ALL counters to zero.

---

## Escalation Levels

### Level 1: REFINE (3 consecutive discards)
Adjust approach without abandoning strategy. Re-read last 3 discards, identify common pattern, hypothesize root cause (too small? wrong target? missing prerequisite? metric insensitive?). Silent — no user message.

### Level 2: PIVOT (5 consecutive discards)
Abandon current strategy completely. Check if scope boundary is the bottleneck — suggest Support scope additions if experiments failed due to out-of-scope files. Brainstorm 3 fundamentally different approaches, pick most promising.
```
[autoresearch] PIVOT@12: "add edge case tests" → "refactor test helpers"
```

### Level 3: Web Search (2 PIVOTs without keep)
Missing domain knowledge. Formulate specific search query for best practices, common patterns, known pitfalls. Apply findings in next iteration.
```
[autoresearch] Researching: "property-based testing python pytest" after 2 pivots
```

### Level 4: Soft Blocker (3 PIVOTs without keep)
Structural issue likely. Diagnose: scope too narrow? metric insensitive? structural ceiling? Print warning, switch to bold exploration (larger structural changes, relaxed one-change rule). Do NOT stop.

---

## Counting Rules

| Status | consecutive_discards | pivot_count |
|---|---|---|
| `keep` / `keep (reworked)` | → 0 | → 0 |
| `discard` / `crash` / `hook-blocked` / `no-op` | +1 | unchanged |

### Threshold Check
```python
if pivot_count >= 3:        return "SOFT_BLOCKER"
elif pivot_count >= 2:      return "WEB_SEARCH"
elif consec_discards >= 5:  pivot_count += 1; consec_discards = 0; return "PIVOT"
elif consec_discards >= 3:  return "REFINE"
```

---

## Integration

- **Lessons**: every PIVOT extracts a lesson (mandatory). Lessons inform future pivot decisions.
- **Scope expansion**: on PIVOT, auto-check if Core files import from out-of-scope files. Suggest Support scope additions.
- **Edge cases**: 3+ consecutive crashes → check infrastructure before escalating. 10+ iterations without metric change → structural ceiling (Level 4). Alternating keep/discard → not stuck, but check metric noise.
