---
description: Autonomous Goal-directed Iteration
argument-hint: "[plan|debug|fix|security|ship] [Goal: <text>] [Scope: <glob>] [Verify: <cmd>]"
---

Load the skill definition first:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` — main skill definition, mode routing, setup gate, critical rules

Parse the first argument to determine the operating mode. See the **Mode Routing** table in SKILL.md.

## Mode: (default — no mode keyword)

Load references:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/autonomous-loop-protocol.md` — full 8-phase loop
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — TSV format and logging
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/core-principles.md` — grounding principles

Load on-demand during the loop:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/pivot-protocol.md` — when consecutive_discards >= 3
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/session-resume.md` — when autoresearch-state.json exists
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/lessons-protocol.md` — when autoresearch-lessons.md exists

Parse arguments for: Goal, Scope, Metric, Direction, Verify, Guard, Iterations, MinDelta.

Execute the workflow:
1. Check for session resume (autoresearch-state.json)
2. If resuming: validate state, continue loop
3. If fresh: run the Mandatory Interactive Setup Gate from SKILL.md
4. Once all parameters confirmed: execute Setup Phase
5. Enter the autonomous 8-phase loop
6. NEVER ask "should I continue?" — loop until done or interrupted

## Mode: plan

Load references:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/plan-workflow.md` — full 7-step wizard protocol

Parse arguments for an optional Goal.

Execute the 7-step wizard:
1. Capture Goal (from arguments or ask)
2. Analyze Context (scan codebase for tooling)
3. Define Scope (suggest file globs, validate real files exist)
4. Define Metric (suggest mechanical metric command, dry-run it)
5. Define Direction (higher or lower, auto-detect if possible)
6. Define Verify (construct full verify command, dry-run it)
7. Confirm & Launch (present config summary, offer to launch or save)

## Mode: debug

Load references:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/debug-workflow.md` — full scientific debug protocol
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — for logging debug results

Parse arguments for: Issue (symptom description) and optional Scope.

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

## Mode: fix

Load references:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/fix-workflow.md` — full iterative fix protocol
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — for logging fix results

Parse arguments for: Target (what to fix — test|type|lint|build|all) and optional Scope.

Execute the iterative fix loop:
1. Error Inventory — collect all errors from the target command
2. Prioritization — blocking errors first, cascade detection
3. One Fix Per Iteration — select highest priority, fix, commit, verify
4. Verify Fix + Guard — confirm error count decreased, no regressions
5. Compound Fix Detection — handle circular dependencies between errors
6. Repeat until zero errors or all remaining errors are blocked

Metric: error count (direction: lower)
Stop condition: zero errors or all remaining marked as blocked

## Mode: security

Load references:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/security-workflow.md` — full STRIDE+OWASP protocol
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — for logging audit results

Parse arguments for: Scope and optional Depth (default: standard).

Execute the security audit:
1. Codebase Reconnaissance — identify tech stack and architecture
2. Asset Identification — classify data and resources by sensitivity
3. Trust Boundary Mapping — identify where trust levels change
4. STRIDE Threat Model — enumerate threats per component
5. Attack Surface Map — map against OWASP Top 10
6. Autonomous Testing Loop — test each threat systematically
7. Generate Report — findings, coverage matrix, recommendations

Composite metric: (owasp_tested/10)*50 + (stride_tested/6)*30 + min(findings, 20)
Direction: higher
Bounded iterations: quick=15, standard=30, deep=60

## Mode: ship

Load references:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/ship-workflow.md` — full 8-phase ship protocol
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — for logging ship results

Parse arguments for: Target and optional Type. Also parse flags: --dry-run, --auto, --force, --rollback, --monitor.

Execute the shipping workflow:
1. Identify — determine what's being shipped and how (auto-detect if not specified)
2. Inventory — catalog all changes that will be shipped
3. Checklist — run pre-flight checks (skip with --force)
4. Prepare — build artifacts, generate PR body / release notes
5. Dry-Run — simulate the ship (skip with --auto)
6. Ship — execute the actual shipment
7. Verify — confirm the shipment succeeded
8. Log — record the result

If --rollback: reverse the last shipment instead of shipping.
If --monitor: watch post-ship health for 5 minutes after shipping.

$ARGUMENTS
