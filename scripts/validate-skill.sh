#!/bin/bash
# Validation script for autoresearch skill files
# Outputs a single number: total error count (lower = better)
set -uo pipefail

SKILL_DIR="skills/autoresearch"
REF_DIR="$SKILL_DIR/references"
CMD_DIR="commands"
errors=0

safe_count() { grep -c "$@" 2>/dev/null | tr -d '[:space:]' || printf '0'; }

# 1. Check all files referenced in SKILL.md actually exist
while IFS= read -r ref; do
  [ -f "$SKILL_DIR/$ref" ] || errors=$((errors + 1))
done < <(grep -oE 'references/[a-z-]+\.md' "$SKILL_DIR/SKILL.md" 2>/dev/null | sort -u)

# 2. Check main command file exists and references SKILL.md
if [ -f "$CMD_DIR/autoresearch.md" ]; then
  grep -q "SKILL.md\|skills/autoresearch" "$CMD_DIR/autoresearch.md" 2>/dev/null || errors=$((errors + 1))
else
  errors=$((errors + 1))
fi

# 3. Check for deprecated term "metric_cmd" (should be metric_extraction)
c=$(grep -rl "metric_cmd" "$SKILL_DIR" --include="*.md" 2>/dev/null | wc -l | tr -d '[:space:]')
errors=$((errors + c))

# 4. Check dangerous "git checkout -- ." not used operationally
c=$(grep 'git checkout -- \.' "$REF_DIR/autonomous-loop-protocol.md" 2>/dev/null | grep -cv "Never\|never\|NEVER\|destroys" | tr -d '[:space:]')
errors=$((errors + c))

# 5. Check "git add -A" not used operationally
for f in "$SKILL_DIR/SKILL.md" "$REF_DIR/autonomous-loop-protocol.md"; do
  [ -f "$f" ] || continue
  c=$(grep 'git add -A' "$f" 2>/dev/null | grep -cv "never\|Never\|NEVER\|Stage specific\|not\|avoid" | tr -d '[:space:]')
  errors=$((errors + c))
done

# 6. (informational, no error)

# 7. Check PIVOT protocol — SKILL.md should mention REFINE
c=$(safe_count "REFINE" "$SKILL_DIR/SKILL.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 8. Check deprecated terms baseline_metric / update_baseline
c1=$(safe_count "baseline_metric" "$SKILL_DIR/SKILL.md")
c2=$(safe_count "update_baseline" "$REF_DIR/autonomous-loop-protocol.md")
errors=$((errors + c1 + c2))

# 9. Check .gitignore setup mentioned in Phase 0
c=$(safe_count "gitignore\|Gitignore" "$REF_DIR/autonomous-loop-protocol.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 10. Check 3-tier scope model presence
c=$(safe_count "Support.*scope\|support_scope\|Tier 2\|limited.write" "$SKILL_DIR/SKILL.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 11. Check metric-design.md exists and is referenced
[ -f "$REF_DIR/metric-design.md" ] || errors=$((errors + 1))
c=$(safe_count "metric-design" "$SKILL_DIR/SKILL.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 12. Check scripts directory has metric templates
c=$(ls scripts/metric-*.sh 2>/dev/null | wc -l | tr -d '[:space:]')
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 13. Check plugin.json is valid JSON
if [ -f ".claude-plugin/plugin.json" ]; then
  python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))" 2>/dev/null || errors=$((errors + 1))
fi

# 14. Check session-resume.md has support_scope
grep -q "support_scope" "$REF_DIR/session-resume.md" 2>/dev/null || errors=$((errors + 1))

# 15. Check anti-gaming layers documented
c=$(safe_count "Sanity\|sanity\|Structural Guard\|structural guard" "$REF_DIR/metric-design.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

echo "$errors"
