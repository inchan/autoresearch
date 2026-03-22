---
description: Autonomous Goal-directed Iteration
argument-hint: "[Goal: <text>] [Scope: <glob>] [Metric: <text>] [Verify: <cmd>]"
---

Parse the user's arguments for: Goal, Scope, Metric, Direction, Verify, Guard, Iterations, MinDelta.

Load the following skill files for protocol instructions:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` — main skill definition, setup gate, critical rules
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/autonomous-loop-protocol.md` — full 8-phase loop
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — TSV format and logging
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/core-principles.md` — grounding principles

Load on-demand during the loop:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/pivot-protocol.md` — when consecutive_discards >= 3
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/session-resume.md` — when autoresearch-state.json exists
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/lessons-protocol.md` — when autoresearch-lessons.md exists

Execute the workflow:
1. Check for session resume (autoresearch-state.json)
2. If resuming: validate state, continue loop
3. If fresh: run the Mandatory Interactive Setup Gate from SKILL.md
4. Once all parameters confirmed: execute Setup Phase
5. Enter the autonomous 8-phase loop
6. NEVER ask "should I continue?" — loop until done or interrupted

$ARGUMENTS
