#!/bin/bash
# Deep validation: cross-reference consistency, missing protocols, structural issues
set -uo pipefail

SKILL_DIR="skills/autoresearch"
REF_DIR="$SKILL_DIR/references"
CMD_DIR="commands"
errors=0

safe_count() { local c; c=$(grep -c "$@" 2>/dev/null | tr -d '[:space:]') || true; echo "${c:-0}"; }

# === CROSS-FILE TERM CONSISTENCY ===

# 1. "current_best" should be used in decide logic, not "old_metric"
c=$(safe_count "old_metric" "$REF_DIR/autonomous-loop-protocol.md")
errors=$((errors + c))

# 2. All references to verify_cmd should exist (not just metric_cmd)
c=$(safe_count "verify_cmd" "$SKILL_DIR/SKILL.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 3. safe_revert function body should reference SCOPE_FILES (not "git checkout -- .")
c=$(safe_count 'SCOPE_FILES\|CORE_SCOPE_FILES' "$REF_DIR/autonomous-loop-protocol.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# === PROTOCOL COMPLETENESS ===

# 4. Phase 5 should mention metric_extraction conditional
c=$(safe_count "metric_extraction" "$REF_DIR/autonomous-loop-protocol.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 5. Phase 6 should have sanity check / anomalous jump detection
c=$(safe_count "anomalous\|sanity\|3.*avg_delta\|re.verify" "$REF_DIR/autonomous-loop-protocol.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 6. Phase 0 should mention .gitignore auto-setup
c=$(safe_count "Gitignore\|gitignore" "$REF_DIR/autonomous-loop-protocol.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 7. Pivot protocol should mention scope expansion
c=$(safe_count "scope.*expand\|Support scope\|scope.*boundary" "$REF_DIR/pivot-protocol.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 8. Plan workflow should mention composite metric
c=$(safe_count "composite\|Composite\|Level 3" "$REF_DIR/plan-workflow.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 9. Plan workflow should mention Support scope auto-detection
c=$(safe_count "Support scope\|import.*analysis\|Auto.*detect.*Support" "$REF_DIR/plan-workflow.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# === STRUCTURAL CHECKS ===

# 10. Every reference file should have a top-level # heading
for f in "$REF_DIR"/*.md; do
  [ -f "$f" ] || continue
  head -3 "$f" | grep -q '^# ' || errors=$((errors + 1))
done

# 11. Every command file should have YAML frontmatter
for cmd in "$CMD_DIR"/autoresearch.md "$CMD_DIR"/autoresearch/*.md; do
  [ -f "$cmd" ] || continue
  head -1 "$cmd" | grep -q '^---' || errors=$((errors + 1))
done

# 12. SKILL.md should have all 8 critical rules
c=$(safe_count '### [0-9]\.' "$SKILL_DIR/SKILL.md")
[ "$c" -ge 8 ] || errors=$((errors + 1))

# 13. Results logging should define all valid statuses
for status in "baseline" "keep" "discard" "crash" "no-op" "hook-blocked"; do
  c=$(safe_count "$status" "$REF_DIR/results-logging.md")
  [ "$c" -gt 0 ] || errors=$((errors + 1))
done

# 14. Session resume should have recovery priority matrix
c=$(safe_count "Priority.*Matrix\|recovery.*matrix\|Recovery.*Priority" "$REF_DIR/session-resume.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 15. Lessons protocol should have capacity management
c=$(safe_count "50.*[Ll]essons\|[Cc]apacity\|[Tt]ime.*[Dd]ecay" "$REF_DIR/lessons-protocol.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# === DOCUMENTATION QUALITY ===

# 16. Each workflow should have an Overview section
for f in "$REF_DIR"/{debug,fix,security,ship}-workflow.md; do
  [ -f "$f" ] || continue
  c=$(safe_count "## Overview" "$f")
  [ "$c" -gt 0 ] || errors=$((errors + 1))
done

# 17. SKILL.md Domain Adaptation table should exist
c=$(safe_count "Domain Adaptation\|domain-agnostic" "$SKILL_DIR/SKILL.md")
[ "$c" -gt 0 ] || errors=$((errors + 1))

# 18. Core principles should have all 7 principles
c=$(safe_count "## Principle" "$REF_DIR/core-principles.md")
[ "$c" -ge 7 ] || errors=$((errors + 1))

# 19. Pivot protocol escalation levels should be 4
c=$(safe_count "### Level" "$REF_DIR/pivot-protocol.md")
[ "$c" -ge 4 ] || errors=$((errors + 1))

# 20. Check no TODO/FIXME/HACK markers left in skill files
c=$(grep -rl "TODO\|FIXME\|HACK\|XXX" "$SKILL_DIR" --include="*.md" 2>/dev/null | wc -l | tr -d '[:space:]')
errors=$((errors + c))

echo "$errors"
