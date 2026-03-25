# Plan Workflow

Interactive 7-step wizard that guides the user from a vague goal to a fully specified autoresearch configuration. This is the `/autoresearch plan` command.

---

## Overview

The plan wizard is the ONLY interactive part of autoresearch. It front-loads all human decision-making so the autonomous loop can run without interruption.

**Input:** A rough goal (or nothing at all)
**Output:** A complete configuration ready for `/autoresearch`

---

## Step 1: Capture Goal

### If Goal Is Provided
```
User said: "I want to improve test coverage"

Acknowledge and refine:
  "Goal: Improve test coverage.
   Let me analyze your codebase to suggest a concrete configuration."
```

### If No Goal Is Provided
```
Ask:
  "What would you like to improve? Examples:
   - Increase test pass rate
   - Reduce bundle size
   - Improve API response time
   - Add missing test coverage
   - Reduce code complexity
   - Fix security vulnerabilities"
```

### Goal Refinement
```
Transform vague goals into measurable ones:
  "Make it faster" -> "Reduce p99 latency of the /api/users endpoint"
  "Better tests"   -> "Increase the number of passing test cases"
  "Cleaner code"   -> "Reduce average cyclomatic complexity across src/"

The refined goal should be:
1. Specific (which part of the system?)
2. Measurable (what number changes?)
3. Directional (up or down?)
```

---

## Step 2: Analyze Context

Scan the codebase to understand the tooling and conventions.

### Automated Detection

```bash
# Package manager and runtime
test -f package.json    && echo "node project"
test -f requirements.txt && echo "python project"
test -f pyproject.toml  && echo "python project (modern)"
test -f Cargo.toml      && echo "rust project"
test -f go.mod          && echo "go project"
test -f Gemfile         && echo "ruby project"

# Test framework
test -f jest.config.*    && echo "jest"
test -f pytest.ini       && echo "pytest"
test -f .pytest_cache    && echo "pytest"
test -f vitest.config.*  && echo "vitest"
grep -q "mocha" package.json 2>/dev/null && echo "mocha"

# Linter / formatter
test -f .eslintrc*       && echo "eslint"
test -f .prettierrc*     && echo "prettier"
test -f .flake8          && echo "flake8"
test -f pyproject.toml   && grep -q "ruff" pyproject.toml && echo "ruff"
test -f rustfmt.toml     && echo "rustfmt"

# Type checker
test -f tsconfig.json    && echo "typescript"
grep -q "mypy" pyproject.toml 2>/dev/null && echo "mypy"

# Build system
test -f webpack.config.* && echo "webpack"
test -f vite.config.*    && echo "vite"
test -f Makefile         && echo "make"

# CI
test -f .github/workflows/*.yml && echo "github actions"
test -f .gitlab-ci.yml   && echo "gitlab ci"
```

### Report Findings

```
Detected environment:
  Runtime: Node.js (package.json)
  Test framework: Jest (jest.config.ts)
  Type checker: TypeScript (tsconfig.json)
  Linter: ESLint (.eslintrc.json)
  Build: Vite (vite.config.ts)

This informs metric and verify suggestions in the next steps.
```

---

## Step 3: Define Scope

Suggest file globs based on the goal, then validate.

### Scope Suggestion

```
Based on goal and context, suggest a scope:

Goal: "increase test coverage"
  Suggested scope: "src/**/*.test.ts" or "tests/**/*.ts"

Goal: "reduce bundle size"
  Suggested scope: "src/**/*.ts" (exclude tests)

Goal: "improve API performance"
  Suggested scope: "src/api/**/*.ts" or "src/routes/**/*.py"

Goal: "reduce complexity"
  Suggested scope: "src/core/**/*.ts" (the most complex module)
```

### Validate Real Files

```bash
# Verify the scope matches actual files
matched_files=$(find . -path "./$scope_glob" -type f 2>/dev/null | head -30)

if [ -z "$matched_files" ]; then
    echo "Warning: No files match '$scope_glob'"
    echo "Available directories:"
    find . -type d -maxdepth 3 | head -20
    # Ask user to adjust
fi

file_count=$(echo "$matched_files" | wc -l)
echo "Scope matches $file_count files"

# Warn if too many files
if [ "$file_count" -gt 20 ]; then
    echo "Warning: Large scope ($file_count files). Consider narrowing."
    echo "This may slow down iterations and make changes less focused."
fi
```

### Auto-detect Support Scope

```
After Core scope is confirmed, analyze dependencies:

1. Parse imports in Core scope files:
   tests/parser.test.ts → imports from src/parser.ts
   tests/validator.test.ts → imports from src/validator.ts
   tests/api.test.ts → imports from src/api.ts, src/types.ts

2. Suggest Support scope:
   "Your test files import from these source files:
     - src/parser.ts
     - src/validator.ts
     - src/api.ts
     - src/types.ts

    Add as Support scope? This allows minimal modifications
    (adding exports, adjusting types) to enable test changes.
    Support files will NOT have logic changes."

3. Suggest Context scope:
   "Other files in the project (not imported by tests):
     - src/config.ts, src/middleware/*.ts, docs/*

    Add as Context scope? (read-only, for understanding only)"
```

### Present to User

```
Scope configuration:
  Core:    tests/**/*.test.ts (12 files) — full read/write
  Support: src/parser.ts, src/validator.ts, src/api.ts, src/types.ts — limited write
  Context: src/**/*.ts (remaining) — read-only

Does this look right? Adjust any tier, or proceed.
```

---

## Step 4: Define Metric

Suggest a mechanical metric command based on the goal and detected tooling.
See `references/metric-design.md` for full metric design guide.

### Metric Level Detection

```
Assess the goal to determine metric level:

Level 1 (Direct): Goal IS a number
  "increase test pass count" → direct: pass count
  "reduce error count to 0" → direct: error count

Level 2 (Proxy): Goal is qualitative, needs a proxy
  "improve code readability" → proxy: cognitive complexity
  "improve test quality" → proxy: mutation testing score

Level 3 (Composite): Goal is multi-dimensional
  "improve overall code health" → composite: errors + lint + tests + complexity
  "improve test quality AND coverage" → composite: pass rate + coverage + mutation

For Level 3, offer to generate a metric script:
  "Your goal spans multiple dimensions. I can create a composite metric script
   that combines them into a single score. Want me to generate one?

   Proposed formula:
     score = 0.4 * pass_rate + 0.3 * coverage + 0.3 * mutation_score

   This will be saved as metric.sh in your project root."
```

### Metric Suggestions by Goal Type

```
Goal: "increase test coverage/pass rate"
  Metric: pytest --tb=no -q 2>&1 | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+'
  Metric: npx jest --silent 2>&1 | grep -oE 'Tests:.*[0-9]+ passed' | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+'

Goal: "reduce bundle size"
  Metric: npm run build 2>&1 | grep -oE '[0-9.]+ kB' | head -1 | grep -oE '[0-9.]+'
  Metric: du -sb dist/ | cut -f1

Goal: "improve performance"
  Metric: hyperfine --warmup 3 './bench' --export-json /dev/stdout | jq '.results[0].mean'
  Metric: python bench.py 2>&1 | tail -1

Goal: "reduce complexity"
  Metric: npx ts-complexity src/ 2>&1 | tail -1 | grep -oE '[0-9.]+'
  Metric: radon cc -a -nc src/ 2>&1 | grep 'Average' | grep -oE '[0-9.]+'

Goal: "increase test count"
  Metric: pytest --co -q 2>&1 | tail -1 | grep -oE '[0-9]+'
  Metric: npx jest --listTests 2>&1 | wc -l
```

### Validate Metric Extraction

```bash
# Dry-run: run verify command, then apply metric extraction
echo "Testing verify command + metric extraction..."
output=$(eval "$verify_cmd" 2>&1)
exit_code=$?

echo "Verify output (last 5 lines):"
echo "$output" | tail -5
echo "Exit code: $exit_code"

# Apply metric extraction (or auto-extract)
if [ -n "$metric_extraction" ]; then
    number=$(echo "$output" | eval "$metric_extraction")
else
    number=$(echo "$output" | grep -oE '[0-9]+\.?[0-9]*' | tail -1)
fi

if [ -z "$number" ]; then
    echo "ERROR: Could not extract a number from the output."
    echo "Provide a metric extraction pipeline or adjust the verify command."
    # Ask user to adjust
else
    echo "Extracted metric: $number"
    echo "This will be the baseline value."
fi
```

### Present to User

```
Suggested verify command:
  npx jest --silent 2>&1
Metric extraction:
  grep -oE '[0-9]+ passed' | grep -oE '[0-9]+'

Dry-run result:
  Output: 42
  Baseline metric: 42

This command takes ~3 seconds to run.
Accept this metric, or specify a different command?
```

---

## Step 5: Define Direction

Determine whether the metric should go higher or lower.

### Auto-Detection

```
Most metrics have obvious directions:
  "passed" count     -> higher
  "failed" count     -> lower
  "coverage" percent -> higher
  "bundle size"      -> lower
  "latency"          -> lower
  "complexity"       -> lower
  "test count"       -> higher
  "error count"      -> lower
  "score"            -> higher
```

### Confirm with User

```
Based on your goal, the metric should go HIGHER (more passed tests = better).
Confirm: higher or lower?
```

---

## Step 6: Define Verify

Construct the full verification command. This may be the same as the metric command, or it may include additional steps.

### Verify vs Metric Extraction

```
Verify command: the full command that runs (produces raw output)
Metric extraction: optional pipeline to extract a single number from Verify output

If Metric extraction is omitted: auto-extract the last number from Verify output.
If provided: applied as `eval "$verify_cmd" 2>&1 | $metric_extraction`

Often they can be combined:
  Verify: pytest --tb=no -q 2>&1
  Metric extraction: grep -oE '[0-9]+ passed' | grep -oE '[0-9]+'

Sometimes verify is a single pipeline that already outputs a number:
  Verify: pytest --tb=no 2>&1 | grep -c passed
  Metric extraction: (omitted — output is already a number)
```

### Suggest Guard Command

```
Based on detected tooling, suggest a guard:

TypeScript project:
  Guard: npx tsc --noEmit
  (Ensures type safety is maintained)

Python with mypy:
  Guard: mypy --strict src/
  (Ensures type annotations are maintained)

Any project with linting:
  Guard: npm run lint (or) ruff check src/
  (Ensures code style is maintained)

No guard needed:
  If the verify command already catches regressions, guard is optional.
```

### Dry-Run the Verify Command

```bash
echo "Testing verify command..."
time_start=$(date +%s)
output=$(eval "$verify_cmd" 2>&1)
exit_code=$?
time_end=$(date +%s)
duration=$((time_end - time_start))

echo "Verify command completed in ${duration}s (exit code: $exit_code)"
echo "Output (last 5 lines):"
echo "$output" | tail -5

# Extract metric
metric=$(echo "$output" | grep -oE '[0-9]+\.?[0-9]*' | tail -1)
echo "Extracted metric: $metric"

if [ "$duration" -gt 300 ]; then
    echo "WARNING: Verify takes >5 minutes. Consider a faster command."
fi
```

---

## Step 7: Confirm and Launch

Present the complete configuration and get final confirmation.

### Configuration Summary

```
======================================================
  autoresearch configuration
======================================================
  Goal:       Increase test pass rate
  Scope:      tests/**/*.test.ts (12 files)
  Metric:     npx jest --silent | extract pass count
  Direction:  higher
  Verify:     npx jest --silent 2>&1
  Guard:      npx tsc --noEmit
  Baseline:   42
  Iterations: unbounded
  Min delta:  0 (any improvement counts)
======================================================

Ready to launch? After confirmation, I will run autonomously.
You can stop me at any time with Ctrl+C / Escape.
```

### On Confirmation

```
If user confirms:
  1. Write autoresearch-state.json with full configuration
  2. Create autoresearch-results.tsv with header and baseline
  3. Print: "Starting autonomous loop. I will not ask further questions."
  4. Hand off to the main /autoresearch loop

If user wants changes:
  Loop back to the relevant step

If user wants to save config without running:
  Write autoresearch-state.json
  Print: "Configuration saved. Run /autoresearch to start."
```

### Launch Command Generation

```
Generate the equivalent direct command for future use:

/autoresearch Goal: Increase test pass rate Scope: tests/**/*.test.ts Metric: npx jest --silent 2>&1 | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' Direction: higher Verify: npx jest --silent 2>&1 Guard: npx tsc --noEmit
```
