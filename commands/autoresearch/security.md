---
description: STRIDE + OWASP security audit
argument-hint: "[Scope: <glob>] [Depth: quick|standard|deep]"
---

Parse the user's arguments for: Scope and optional Depth (default: standard).

Load the following skill files:
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` — for critical rules and git conventions
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/security-workflow.md` — full STRIDE+OWASP protocol
- `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/results-logging.md` — for logging audit results

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

$ARGUMENTS
