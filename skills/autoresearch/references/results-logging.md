# Results Logging

TSV format specification for the autoresearch results log. The results file is the canonical record of every iteration's outcome.

---

## File Format

**File:** `autoresearch-results.tsv` (project root)
**Format:** Tab-separated values (TSV)
**Encoding:** UTF-8
**Line endings:** LF (Unix)
**Never use commas** — descriptions may contain commas; tabs are unambiguous.

### Header Row

```
iteration	commit	metric	delta	guard	status	description
```

### Column Definitions

| Column | Type | Description |
|---|---|---|
| `iteration` | Integer | Iteration number (0 = baseline, 1+ = experiments) |
| `commit` | String | Short git commit hash (7 chars) from `git rev-parse --short HEAD` |
| `metric` | Float | The metric value extracted from the verify command |
| `delta` | Float | Change from current best metric (new_metric - current_best; positive = improvement for "higher", negative = improvement for "lower") |
| `guard` | String | `pass`, `fail`, `skip` (skip if no guard command defined) |
| `status` | String | One of the valid statuses (see below) |
| `description` | String | One-sentence description of the change (from commit message) |

---

## Setup and Initialization

### Creating the Results File

```bash
# Create the header if the file doesn't exist
if [ ! -f autoresearch-results.tsv ]; then
    printf 'iteration\tcommit\tmetric\tdelta\tguard\tstatus\tdescription\n' > autoresearch-results.tsv
fi
```

### Recording the Baseline (Iteration 0)

```bash
# Run the verify command to get baseline metric
baseline_metric=$(eval "$verify_cmd" 2>&1 | grep -oE '[0-9]+\.?[0-9]*' | tail -1)
commit_hash=$(git rev-parse --short HEAD)

# Log the baseline
printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    0 "$commit_hash" "$baseline_metric" "0" "skip" "baseline" "initial measurement" \
    >> autoresearch-results.tsv
```

---

## Logging Function

### log_iteration

Use this function to append a result after every iteration:

```bash
log_iteration() {
    local iteration="$1"
    local commit="$2"
    local metric="$3"
    local delta="$4"
    local guard="$5"
    local status="$6"
    local description="$7"

    # Sanitize description: replace tabs with spaces, strip newlines
    description=$(echo "$description" | tr '\t\n' '  ')

    # Append to TSV
    printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$iteration" "$commit" "$metric" "$delta" "$guard" "$status" "$description" \
        >> autoresearch-results.tsv
}
```

### Example Log Entries

```
iteration	commit	metric	delta	guard	status	description
0	a1b2c3d	75.0	0	skip	baseline	initial measurement
1	e4f5g6h	78.0	3.0	pass	keep	add edge case tests for parser
2	i7j8k9l	77.5	-0.5	pass	discard	refactor test helper to reduce duplication
3	m0n1o2p	80.0	2.0	pass	keep	add boundary value tests for validator
4	q3r4s5t	0.0	-80.0	skip	crash	restructure test file imports (syntax error)
5	u6v7w8x	80.0	0.0	pass	discard	add logging to test setup
6	y9z0a1b	82.0	2.0	fail	discard	add integration test (breaks type check)
7	c2d3e4f	81.5	1.5	pass	keep	add property-based tests for serializer
```

---

## Reading and Pattern Recognition

### Reading the Log for Context

At the start of each iteration (Phase 1: Review), read the results log to understand:

```
1. Current metric value: the metric from the most recent "keep" or "baseline" entry
2. Trend: are keeps getting larger or smaller deltas?
3. Consecutive discards: count entries since the last "keep"
4. Strategy patterns: what descriptions correlate with "keep" vs "discard"?
5. Crash patterns: what kinds of changes cause crashes?
```

### Parsing the Log

```bash
# Get the current best metric (last keep or baseline — this is "current_best", not the original baseline)
current_best=$(awk -F'\t' '$6 == "keep" || $6 == "baseline" {m=$3} END {print m}' autoresearch-results.tsv)

# Count consecutive discards from the end
consecutive_discards=$(awk -F'\t' '
    NR > 1 {
        if ($6 == "keep" || $6 == "keep (reworked)" || $6 == "baseline") count = 0
        else count++
    }
    END {print count}
' autoresearch-results.tsv)

# Count total keeps and discards
total_keeps=$(awk -F'\t' '$6 ~ /keep/ {c++} END {print c+0}' autoresearch-results.tsv)
total_discards=$(awk -F'\t' '$6 == "discard" {c++} END {print c+0}' autoresearch-results.tsv)

# Get last 10 entries for context
tail -10 autoresearch-results.tsv
```

### Pattern Recognition

Look for these patterns when reading the log:

```
Successful Pattern:
  Multiple "keep" entries with similar descriptions
  -> Continue this strategy (exploit)

Failure Cluster:
  Multiple "discard" entries with similar descriptions
  -> Abandon this approach (pivot away)

Diminishing Returns:
  "keep" entries with decreasing deltas
  -> Strategy is running out of steam, explore something new

Crash Pattern:
  Multiple "crash" entries after similar changes
  -> There's a structural issue; investigate before retrying

Oscillation:
  Alternating keep/discard on similar changes
  -> Metric is noisy; increase min_delta or use confirmation runs
```

---

## Valid Statuses

| Status | When Used | Metric Changed? | Code Changed? |
|---|---|---|---|
| `baseline` | Iteration 0 only | N/A (first measurement) | No (or pre-snapshot commit) |
| `keep` | Metric improved by >= min_delta | Yes (improved) | Yes (preserved) |
| `keep (reworked)` | Metric improved after guard fix | Yes (improved) | Yes (modified + fixed) |
| `discard` | Metric did not improve | No (or worse) | No (reverted) |
| `crash` | Verify command failed or timed out | N/A (no valid metric) | No (reverted) |
| `no-op` | No meaningful change was possible | No | No |
| `hook-blocked` | Pre-commit hook failed 3 times | N/A (never committed) | No (reverted) |

### Status Decision Tree

```
Was the change committed successfully?
+-- No (hook failed 3x) -> hook-blocked
+-- Yes
    +-- Did verify complete successfully?
        +-- No (crash/timeout) -> crash, revert
        +-- Yes
            +-- Did metric improve by >= min_delta?
                +-- Yes
                |   +-- Did guard pass (or no guard)?
                |       +-- Yes -> keep
                |       +-- No
                |           +-- Did rework fix guard?
                |               +-- Yes -> keep (reworked)
                |               +-- No -> discard, revert
                +-- No
                    +-- Is code simpler AND metric unchanged?
                        +-- Yes -> keep (simplicity override)
                        +-- No -> discard, revert
```

---

## Summary Reporting

### Every 10 Iterations

Print a summary block every 10 iterations:

```
======================================================
  autoresearch summary — iterations 1-10
======================================================
  Baseline metric:  75.0
  Current metric:   84.5  (+9.5, higher is better)
  Keeps:            4
  Discards:         5
  Crashes:          1
  Best single delta: +5.0 (iteration 3)
  Current streak:   2 keeps
======================================================
```

### Final Summary (Bounded Mode)

Print at the end of a bounded run:

```
======================================================
  autoresearch COMPLETE — 50 iterations
======================================================
  Baseline: 75.0 -> Final: 94.2  (+19.2)
  Direction: higher is better

  Breakdown:
    keep:           22 (44%)
    discard:        24 (48%)
    crash:           3 (6%)
    hook-blocked:    1 (2%)

  Top 3 changes:
    1. +5.0  add property-based tests (iter 7)
    2. +3.2  add boundary validation tests (iter 14)
    3. +2.8  add error handling tests (iter 22)

  Pivots: 1 (at iteration 18)
  Lessons extracted: 5
======================================================
```

---

## Metric Direction Comment

The first line after the header should be a comment indicating the metric direction. Since TSV doesn't support comments natively, embed it in the baseline description:

```
0	a1b2c3d	75.0	0	skip	baseline	initial measurement (direction: higher)
```

This allows any tool reading the log to determine which direction is "better" without external configuration.

When computing delta for display:
- If direction is "higher": delta = new - old (positive = improvement)
- If direction is "lower": delta = old - new (positive = improvement)

Always display delta with the sign that indicates improvement as positive, regardless of direction.

---

## File Safety

### Append-Only
```
The results TSV is APPEND-ONLY. Never modify or delete existing rows.
This ensures:
- Full audit trail
- Crash recovery (last line is always the most recent)
- Reproducibility (anyone can replay the history)
```

### Atomic Writes
```
For the state file (autoresearch-state.json), use atomic writes:
  1. Write to autoresearch-state.json.tmp
  2. Rename autoresearch-state.json.tmp -> autoresearch-state.json

For the TSV log, append is inherently atomic on most filesystems
(single printf with newline to a file opened in append mode).
```

### Gitignore
```
Both files are gitignored:
  autoresearch-results.tsv
  autoresearch-state.json
  autoresearch-lessons.md

They are working files, not part of the project's source code.
The git commit history IS the permanent record.
```
