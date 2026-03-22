---
description: Interactive goal-to-config wizard
argument-hint: "[Goal: <text>]"
---

Parse the user's arguments for an optional Goal.

Load the following skill files:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` — for parameter definitions and domain adaptation
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/plan-workflow.md` — full 7-step wizard protocol

Execute the 7-step wizard:
1. Capture Goal (from arguments or ask)
2. Analyze Context (scan codebase for tooling)
3. Define Scope (suggest file globs, validate real files exist)
4. Define Metric (suggest mechanical metric command, dry-run it)
5. Define Direction (higher or lower, auto-detect if possible)
6. Define Verify (construct full verify command, dry-run it)
7. Confirm & Launch (present config summary, offer to launch or save)

After confirmation, either:
- Hand off to `/autoresearch` with the assembled configuration
- Save configuration to autoresearch-state.json for later use

$ARGUMENTS
