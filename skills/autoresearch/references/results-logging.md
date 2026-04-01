# Results Logging

**File:** `autoresearch-results.tsv` — append-only, tab-separated, gitignored.

## Format

Header: `iteration	commit	metric	delta	guard	status	description`

| Column | Type | Description |
|---|---|---|
| iteration | Integer | 0 = baseline, 1+ = experiments |
| commit | String | Short git hash (7 chars) |
| metric | Float | Extracted metric value |
| delta | Float | Change from current best |
| guard | String | `pass` / `fail` / `skip` |
| status | String | `baseline` / `keep` / `discard` / `crash` / `no-op` / `hook-blocked` |
| description | String | One-sentence change description |

## At Review (STEP 1)

Extract: current best, trend (deltas growing/shrinking?), consecutive discards, strategy patterns (which descriptions correlate with keep vs discard?).

## Baseline

Embed direction: `initial measurement (direction: higher)`. Delta = positive means improvement.
