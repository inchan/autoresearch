# Fix Workflow

Iterative error repair protocol for the `/autoresearch:fix` command. Systematically fixes all errors from tests, types, lint, and build in priority order.

---

## Overview

The fix workflow treats error repair as an optimization problem: the metric is the error count, the direction is lower, and the loop runs until zero errors remain.

**Input:** A target (test suite, type checker, linter, build) and optional scope
**Output:** All errors fixed, verified, and committed

---

## Phase 1: Error Inventory

Collect ALL errors from the specified target.

### Error Collection

```bash
# Run the target command and capture all errors
errors_output=$(eval "$target_cmd" 2>&1)
exit_code=$?

# Parse errors into a structured list
# Each error has: file, line, severity, message
```

### Supported Targets

| Target | Typical Command | Error Format |
|---|---|---|
| Tests | `pytest --tb=short` | Test name + assertion + traceback |
| Types | `mypy --strict src/` | file:line: error: message |
| Lint | `eslint src/ --format compact` | file:line:col: severity message |
| Build | `npm run build` | Varies by build tool |
| All | Run all of the above | Combined list |

### Error Parsing

```
For each error, extract:
  file: the file path where the error occurs
  line: the line number (if available)
  severity: error | warning | info
  message: the error description
  category: test | type | lint | build | runtime

Sort by severity: errors first, then warnings, then info.
```

### Initial Error Count

```
Print the inventory:
  Error Inventory:
    Tests:  12 failures
    Types:   8 errors
    Lint:    5 errors, 3 warnings
    Build:   0 errors
    Total:  25 errors, 3 warnings

  This is the baseline metric: 25 (errors only; warnings tracked separately)
```

---

## Phase 2: Prioritization

Fix errors in an order that maximizes progress and minimizes wasted work.

### Priority Order

```
1. Build errors (nothing works if it doesn't build)
2. Syntax errors (may cause cascading type/test failures)
3. Import/dependency errors (may cause cascading failures)
4. Type errors (may cause runtime test failures)
5. Test failures (the most specific errors)
6. Lint errors (lowest priority, least impact)
7. Warnings (fix after all errors are resolved)
```

### Cascade Detection

```
Some errors are CAUSED by other errors:
  - A missing import causes type errors AND test failures
  - A syntax error causes everything downstream to fail
  - A type mismatch may cause multiple test failures

Fix UPSTREAM errors first:
  1. If fixing error A resolves errors B, C, D -> one fix, four errors gone
  2. If you fix B first, then A, then realize B was a symptom -> wasted iteration

Detection:
  - Multiple errors in the same file -> fix the earliest (topmost) first
  - Multiple errors mentioning the same symbol -> fix the definition first
  - Errors in imported modules -> fix the import source first
```

### Blocking Error Detection

```
An error is "blocking" if:
1. It prevents the build from completing
2. It prevents tests from running at all
3. It causes >3 other errors as downstream symptoms

Always fix blocking errors first, regardless of category.
```

---

## Phase 3: One Fix Per Iteration

Apply the autoresearch loop pattern to error fixing.

### Iteration Protocol

```
For each iteration:
1. Select the highest-priority unfixed error
2. Read the relevant file(s) at the error location
3. Understand the root cause (not just the symptom)
4. Implement the minimal fix
5. Stage and commit: "fix(<scope>): <description>"
6. Re-run the target command to get the new error count
7. Decide: keep (error count decreased) or discard (no improvement or regression)
8. Log the result
```

### Fix Sizing

```
One fix per iteration means:
- Fix ONE error (or one cluster of related errors)
- The fix may touch multiple files if needed
- But it addresses ONE logical issue

Example — one fix, multiple files:
  Error: "UserService uses undefined type 'AuthResult'"
  Fix: add AuthResult type definition (types.ts) + import (UserService.ts)
  This is ONE fix (resolve the undefined type) even though 2 files changed.

Example — must split:
  Error 1: "missing return type on getUser()"
  Error 2: "unused variable 'temp' in processData()"
  These are TWO fixes. Do them in separate iterations.
```

---

## Phase 4: Verify Fix + Guard

After each fix, verify it resolved the error AND didn't introduce new ones.

### Verification

```bash
# Re-run the target command
new_output=$(eval "$target_cmd" 2>&1)
new_error_count=<extract count>

# Compare
if new_error_count < old_error_count:
    # Fix worked — keep
    old_error_count = new_error_count
elif new_error_count == old_error_count:
    # Fix didn't help — the error may have transformed
    # Check if the SPECIFIC error is gone
    if specific_error_gone(new_output, target_error):
        # Error transformed into a different one — net neutral
        # Keep if the new error is easier to fix, discard otherwise
    else:
        # Fix didn't work — discard
elif new_error_count > old_error_count:
    # Fix introduced new errors — discard immediately
```

### Guard Check

```
After fixing a test error, also run:
- Type checker (did the fix break types?)
- Linter (did the fix violate style rules?)

After fixing a type error, also run:
- Tests (did the type fix break behavior?)

After fixing a lint error:
- Usually no guard needed (lint fixes are low-risk)
- But run tests if the lint fix changed logic (e.g., unused variable removal)
```

---

## Phase 5: Compound Fix Detection

Some errors can only be fixed together.

### Detection

```
A compound fix is needed when:
1. Fixing error A introduces error B, and fixing B introduces A
   (circular dependency between fixes)
2. Two errors share a root cause that can only be addressed atomically
3. A refactor is needed that touches multiple error sites at once

Detection signals:
- Fix A -> discard (introduces B)
- Fix B -> discard (introduces A)
- This oscillation means A and B must be fixed together
```

### Handling Compound Fixes

```
When compound fix detected:
1. Identify all errors in the compound group
2. Plan a single fix that addresses all of them
3. Implement as ONE iteration (relaxing the one-fix rule)
4. Commit: "fix(<scope>): resolve compound issue — <description>"
5. Verify: total error count must decrease by >= group size
6. If it doesn't: revert and try a different approach

Document compound fixes in the commit message:
  "fix(auth): resolve circular type dependency between User and Session

   Fixes 3 related errors:
   - TS2305: User references Session before declaration
   - TS2305: Session references User before declaration
   - TS7006: implicit any on mutual reference"
```

---

## Completion

### Zero Errors

```
When error count reaches 0:
1. Run the full target command one more time to confirm
2. Print summary:

   Fix Summary:
     Starting errors: 25
     Final errors: 0
     Iterations: 18
     Keeps: 14
     Discards: 4
     Compound fixes: 1

     Breakdown:
       Build:  0 fixed
       Type:   8 fixed (iterations 1-6, 12)
       Test:  12 fixed (iterations 7-11, 13-17)
       Lint:   5 fixed (iteration 18)

3. Commit a summary: "fix(<scope>): all errors resolved"
```

### Partial Progress

```
If some errors cannot be fixed:
1. After 3 failed attempts on the same error:
   Mark as "blocked" and move to the next error
2. Print blocked errors at the end:

   Fix Summary:
     Starting errors: 25
     Fixed: 22
     Blocked: 3 (could not resolve)

     Blocked errors:
       1. types.ts:45 — TS2339: Property 'x' does not exist on type 'Y'
          Attempts: 3, all reverted
          Likely cause: requires upstream API change
       2. ...
```

---

## Metric Configuration

```
Metric: error count from the target command
Direction: lower
Verify: the target command itself
Guard: none (the verify IS the guard — any new errors show up in the count)
Min delta: 1 (must fix at least one error per iteration)
```

---

## Integration with Main Loop

```
The fix workflow can be invoked:
1. Directly: /autoresearch:fix target: pytest scope: src/
2. From the main loop: when a "crash" reveals multiple errors
3. From the debug workflow: when the root cause requires fixing related issues

After fix completes, the main loop can resume with a cleaner codebase.
```

---

## Error Category Strategies

### Test Failures

```
Common causes and fixes:
- Assertion mismatch -> update expected value or fix the code
- Missing fixture -> add the fixture or mock
- Import error -> fix the import path
- Timeout -> increase timeout or optimize the test
- Flaky test -> add retry or fix the race condition
```

### Type Errors

```
Common causes and fixes:
- Missing type annotation -> add the annotation
- Type mismatch -> fix the value or widen the type
- Missing property -> add the property or make it optional
- Undefined reference -> add import or declaration
- Generic constraint -> add or fix type parameters
```

### Lint Errors

```
Common causes and fixes:
- Formatting -> run the formatter (prettier, black, rustfmt)
- Unused variable -> remove it or prefix with underscore
- Missing semicolon -> add it
- Naming convention -> rename to match convention
- Complexity -> extract function or simplify logic
```

### Build Errors

```
Common causes and fixes:
- Missing dependency -> install it
- Version conflict -> resolve version constraints
- Configuration error -> fix the config file
- Missing file -> create it or fix the reference
- Platform incompatibility -> add platform check or polyfill
```
