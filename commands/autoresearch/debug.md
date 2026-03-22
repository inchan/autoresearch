---
description: Scientific debugging loop
argument-hint: "[Issue: <description>] [Scope: <glob>]"
---

Parse the user's arguments for: Issue (symptom description) and optional Scope.

Load the following skill files:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` — for critical rules and git conventions
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/debug-workflow.md` — full scientific debug protocol
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — for logging debug results

Execute the scientific debug loop:
1. Symptom Capture — collect evidence, reproduce the bug
2. Hypothesis Formation — generate ranked candidate explanations
3. Evidence Collection — targeted reading, not shotgun
4. Hypothesis Testing — one variable at a time, commit-verify-decide
5. Fix Implementation — minimal fix for the root cause
6. Regression Check — ensure fix doesn't break other things
7. Results Logging — log the debug session outcome

Key rules:
- Test ONE hypothesis per iteration
- Commit diagnostic changes for clean rollback
- Revert diagnostics after testing (they're temporary)
- Timebox: escalate after 10 hypothesis tests without root cause

$ARGUMENTS
