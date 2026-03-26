#!/bin/bash
# Cross-agent compatibility metric for autoresearch skill
# Scores presence of features enabling Codex/Gemini to complete full loops
# Direction: higher = better
set -uo pipefail

SKILL="skills/autoresearch/SKILL.md"
LOOP="skills/autoresearch/references/autonomous-loop-protocol.md"
RESUME="skills/autoresearch/references/session-resume.md"
score=0

count_matches() { grep -ci "$1" "$2" 2>/dev/null | head -1 | tr -d '[:space:]' || printf '0'; }

# 1. Context management guidance (2 pts)
grep -qi "context.*window\|context.*budget\|context.*limit\|context.*compact" "$SKILL" && score=$((score + 1))
grep -qi "context.*window\|context.*budget\|context.*limit\|context.*compact" "$LOOP" && score=$((score + 1))

# 2. NEVER STOP reinforcement strength (2 pts)
c=$(count_matches "NEVER.*stop\|NEVER.*ask.*continue\|NEVER.*pause\|NEVER.*halt\|do.not.stop" "$SKILL")
[ "$c" -ge 3 ] && score=$((score + 1))
[ "$c" -ge 5 ] && score=$((score + 1))

# 3. Agent-agnostic language — no Claude-specific terms in SKILL.md body (2 pts)
c=$(sed '1,/^---$/d' "$SKILL" | sed '/^---$/,/^---$/d' | grep -ci "claude" 2>/dev/null | head -1 | tr -d '[:space:]' || echo 0)
[ "$c" -le 2 ] && score=$((score + 1))
[ "$c" -eq 0 ] && score=$((score + 1))

# 4. Session resume in Critical Rules (1 pt)
grep -A100 "Critical Rules" "$SKILL" | grep -qi "resume\|state.*file\|session.*state" && score=$((score + 1))

# 5. Review phase efficiency — skip unchanged files (1 pt)
grep -qi "unchanged\|skip.*unmodif\|diff.*only\|changed.*only\|delta.*read" "$LOOP" && score=$((score + 1))

# 6. Output compression guidance (1 pt)
grep -qi "brief\|concise\|compact.*output\|minimal.*output\|1-line" "$LOOP" && score=$((score + 1))

# 7. Progressive/lazy reference loading (1 pt)
grep -qi "on-demand\|load.*only.*when\|load.*if.*needed\|lazy" "$SKILL" && score=$((score + 1))

# 8. Cross-agent compatibility markers (1 pt)
grep -qi "cross.*agent\|agent.*agnostic\|platform.*agnostic\|any.*agent\|codex\|gemini" "$SKILL" && score=$((score + 1))

# 9. Context overflow / session split in SKILL.md (1 pt)
grep -qi "session.*split\|context.*overflow\|context.*full\|window.*full\|compaction" "$SKILL" && score=$((score + 1))

# 10. Emergency checkpoint / graceful exit (2 pts)
grep -qi "checkpoint\|graceful.*exit\|save.*state.*before\|emergency" "$LOOP" && score=$((score + 1))
grep -qi "checkpoint\|graceful.*exit\|save.*state.*before\|emergency" "$SKILL" && score=$((score + 1))

# 11. Per-iteration state persistence emphasis (1 pt)
grep -qi "write.*state.*every\|update.*state.*every\|persist.*every\|save.*after.*every" "$LOOP" && score=$((score + 1))

# 12. Structural integrity from validate-skill.sh (2 pts)
if [ -f "scripts/validate-skill.sh" ]; then
  v=$(bash scripts/validate-skill.sh 2>/dev/null || echo "99")
  [ "$v" -eq 0 ] && score=$((score + 2))
fi

# 13. Explicit iteration batching / chunking guidance (1 pt)
grep -qi "batch\|chunk\|split.*session\|break.*session\|context.*budget" "$SKILL" && score=$((score + 1))

echo "$score"
