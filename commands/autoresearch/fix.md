---
description: Iterative error repair
argument-hint: "[Target: <test|type|lint|build|all>] [Scope: <glob>]"
---

Parse the user's arguments for: Target (what to fix) and optional Scope.

Load the following skill files:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` — for critical rules and git conventions
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/fix-workflow.md` — full iterative fix protocol
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — for logging fix results

Execute the iterative fix loop:
1. Error Inventory — collect all errors from the target command
2. Prioritization — blocking errors first, cascade detection
3. One Fix Per Iteration — select highest priority, fix, commit, verify
4. Verify Fix + Guard — confirm error count decreased, no regressions
5. Compound Fix Detection — handle circular dependencies between errors
6. Repeat until zero errors or all remaining errors are blocked

Metric: error count (direction: lower)
Stop condition: zero errors or all remaining marked as blocked

$ARGUMENTS
