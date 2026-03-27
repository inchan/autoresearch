# Plan Workflow

Interactive 7-step wizard: vague goal → fully specified autoresearch configuration. This is `/autoresearch:plan`.

The plan wizard is the ONLY interactive part. It front-loads all decisions so the loop runs uninterrupted.

**Input:** A rough goal (or nothing)
**Output:** Complete configuration ready for `/autoresearch`

---

## Step 1: Capture Goal

If provided, acknowledge and refine. If not, ask with examples (test coverage, bundle size, latency, complexity, security).

Refine vague goals into measurable ones:
- "Make it faster" → "Reduce p99 latency of /api/users"
- "Better tests" → "Increase passing test count"

Goal must be: **Specific** (which part?), **Measurable** (what number?), **Directional** (up or down?)

---

## Step 2: Analyze Context

Auto-detect from project files:

| Category | Detection Signals |
|---|---|
| Runtime | `package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, `Gemfile` |
| Test framework | `jest.config.*`, `pytest.ini`, `vitest.config.*` |
| Linter | `.eslintrc*`, `.prettierrc*`, `.flake8`, `ruff` in pyproject.toml |
| Type checker | `tsconfig.json`, `mypy` in pyproject.toml |
| Build | `webpack.config.*`, `vite.config.*`, `Makefile` |
| CI | `.github/workflows/*.yml`, `.gitlab-ci.yml` |

Report findings to inform metric/verify suggestions.

---

## Step 3: Define Scope

Suggest file globs based on goal. Validate with `find`. Warn if >20 files.

### 3-Tier Scope
1. **Core** — full read/write (experiment target)
2. **Support** — limited write (exports, types, imports only). Auto-detect from Core imports
3. **Context** — read-only reference

Present tiers and file counts. Let user adjust.

---

## Step 4: Define Metric

See `references/metric-design.md` for full guide.

### Level Detection
- **Direct**: goal IS a number (pass count, error count)
- **Proxy**: qualitative goal needs numeric proxy (readability → complexity)
- **Composite**: multi-dimensional goal → weighted script (offer to generate)

### Common Metrics

| Goal | Metric Command |
|---|---|
| Test pass rate | `pytest --tb=no -q 2>&1 \| grep -oE '[0-9]+ passed' \| grep -oE '[0-9]+'` |
| Bundle size | `du -sb dist/ \| cut -f1` |
| Performance | `hyperfine './bench' --export-json /dev/stdout \| jq '.results[0].mean'` |
| Complexity | `radon cc -a -nc src/ 2>&1 \| grep Average \| grep -oE '[0-9.]+'` |

Dry-run the metric command. Verify a number is extractable. Show baseline value.

---

## Step 5: Define Direction

Auto-detect: passed/coverage/score/test count → higher. failed/size/latency/complexity/errors → lower.

Confirm with user.

---

## Step 6: Define Verify

**Verify command** = full command that runs. **Metric extraction** = optional pipeline to extract number from output. If omitted, auto-extract last number.

### Guard Suggestion

| Tooling | Suggested Guard |
|---|---|
| TypeScript | `npx tsc --noEmit` |
| Python + mypy | `mypy --strict src/` |
| Linter present | `npm run lint` or `ruff check src/` |

Dry-run verify. Warn if >5 minutes.

---

## Step 7: Confirm and Launch

Present config summary (goal, scope, metric, direction, verify, guard, baseline, iterations).

On confirm: write `autoresearch-state.json` + `autoresearch-results.tsv`, print "Starting autonomous loop", hand off to `/autoresearch`.

On change request: loop back to relevant step.

On save-only: write state file, print "Configuration saved. Run /autoresearch to start."

Generate equivalent direct command for future use.
