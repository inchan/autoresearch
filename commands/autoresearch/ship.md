---
description: Universal shipping workflow
argument-hint: "[Target: <branch|version|env>] [Type: code-pr|code-release|deployment|content]"
---

Parse the user's arguments for: Target and optional Type. Also parse flags: --dry-run, --auto, --force, --rollback, --monitor.

Load the following skill files:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` — for critical rules and git conventions
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/ship-workflow.md` — full 8-phase ship protocol
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — for logging ship results

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
