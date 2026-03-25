---
description: Autonomous Goal-directed Iteration
argument-hint: "[plan|debug|fix|security|ship] [Goal: <text>] [Scope: <glob>] [Verify: <cmd>]"
---

Load the skill definition first:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` — main skill definition, mode routing, setup gate, critical rules

Parse the first argument to determine the operating mode. See the **Mode Routing** table in SKILL.md for which references to load per mode.

## Mode: (default — no mode keyword)

Load references per Mode Routing table, plus on-demand:
- `references/pivot-protocol.md` — when consecutive_discards >= 3
- `references/session-resume.md` — when autoresearch-state.json exists
- `references/lessons-protocol.md` — when autoresearch-lessons.md exists

Parse arguments for: Goal, Scope, Metric, Direction, Verify, Guard, Iterations, MinDelta.

Execute the workflow:
1. Check for session resume (autoresearch-state.json)
2. If resuming: validate state, continue loop
3. If fresh: run the Mandatory Interactive Setup Gate from SKILL.md
4. Once all parameters confirmed: execute Setup Phase
5. Enter the autonomous 8-phase loop
6. NEVER ask "should I continue?" — loop until done or interrupted

## Mode: plan

Load references per Mode Routing table. Parse arguments for an optional Goal.
Execute the 7-step wizard defined in `references/plan-workflow.md`.

## Mode: debug

Load references per Mode Routing table. Parse arguments for: Issue and optional Scope.
Execute the scientific debug loop defined in `references/debug-workflow.md`.

## Mode: fix

Load references per Mode Routing table. Parse arguments for: Target (test|type|lint|build|all) and optional Scope.
Execute the iterative fix loop defined in `references/fix-workflow.md`.

## Mode: security

Load references per Mode Routing table. Parse arguments for: Scope and optional Depth (default: standard).
Execute the security audit defined in `references/security-workflow.md`.

## Mode: ship

Load references per Mode Routing table. Parse arguments for: Target and optional Type. Also parse flags: --dry-run, --auto, --force, --rollback, --monitor.
Execute the shipping workflow defined in `references/ship-workflow.md`.

$ARGUMENTS
