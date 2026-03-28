#!/bin/bash
# Regression tests derived from successful autoresearch experiments
# Each test case corresponds to a pattern that was validated through
# the self-critique loop (50→100) and 15 experiment iterations.
#
# Usage: bash scripts/test-success-cases.sh
# Output: pass/fail per case, exit code = number of failures
set -uo pipefail

SKILL_DIR="skills/autoresearch"
REF_DIR="$SKILL_DIR/references"
SCRIPT_DIR="$SKILL_DIR/scripts"

passed=0
failed=0

pass() { echo "  PASS: $1"; passed=$((passed + 1)); }
fail() { echo "  FAIL: $1"; failed=$((failed + 1)); }

# Safe grep count — always returns a clean integer
count_matches() { grep -c "$@" 2>/dev/null | tr -d '[:space:]' || printf '0'; }
count_files()   { grep -rl "$@" 2>/dev/null | wc -l | tr -d '[:space:]' || printf '0'; }

# ============================================================================
# Case 1: Document compression preserved protocol completeness
# Source: 14 experiment commits (ship/security/plan/core/pivot/loop compression)
# Lesson: 75-84% size reduction is safe IF structural elements survive
# ============================================================================
echo "Case 1: Protocol completeness after compression"

# 1a. autonomous-loop-protocol.md — all 8 phases present
for phase in "Phase 0" "Phase 1" "Phase 2" "Phase 3" "Phase 4" "Phase 5" "Phase 6" "Phase 7"; do
  desc="autonomous-loop-protocol has $phase"
  if grep -q "$phase" "$REF_DIR/autonomous-loop-protocol.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi
done

# 1b. Also check Phase 5.5 (Guard) and Phase 8 (Repeat) — non-standard numbering
desc="autonomous-loop-protocol has Phase 5.5 Guard"
if grep -qE '5\.5.*Guard|Guard.*5\.5' "$REF_DIR/autonomous-loop-protocol.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

desc="autonomous-loop-protocol has Phase 8 Repeat"
if grep -qE 'Phase 8|## Repeat' "$REF_DIR/autonomous-loop-protocol.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

# 1c. core-principles.md — all 7 principles (format: "## N. Title")
count=$(count_matches "^## [0-9]\." "$REF_DIR/core-principles.md")
desc="core-principles has 7 principles (found $count)"
if [ "$count" -ge 7 ]; then pass "$desc"; else fail "$desc"; fi

# 1d. pivot-protocol.md — 4 escalation levels
count=$(count_matches "^### Level" "$REF_DIR/pivot-protocol.md")
desc="pivot-protocol has 4 escalation levels (found $count)"
if [ "$count" -ge 4 ]; then pass "$desc"; else fail "$desc"; fi

# 1e. plan-workflow.md — 7 wizard steps
count=$(count_matches "^## Step\|^### Step" "$REF_DIR/plan-workflow.md")
desc="plan-workflow has 7 steps (found $count)"
if [ "$count" -ge 7 ]; then pass "$desc"; else fail "$desc"; fi

# 1f. security-workflow.md — STRIDE and OWASP frameworks preserved
desc="security-workflow has STRIDE threat model"
if grep -qE 'STRIDE|Spoofing' "$REF_DIR/security-workflow.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

desc="security-workflow has OWASP Top 10"
if grep -qE 'OWASP|A01|Broken Access' "$REF_DIR/security-workflow.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

# 1g. ship-workflow.md — all shipment types
desc="ship-workflow covers PR/pull request"
if grep -qiE 'code-pr|pull.request|PR' "$REF_DIR/ship-workflow.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

desc="ship-workflow covers release/tag"
if grep -qiE 'code-release|release|tag' "$REF_DIR/ship-workflow.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

desc="ship-workflow covers deployment"
if grep -qiE 'deploy' "$REF_DIR/ship-workflow.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

desc="ship-workflow covers content/publish"
if grep -qiE 'content|publish' "$REF_DIR/ship-workflow.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

# 1h. Total line budget — compressed from 5149 to under 2600
total_lines=$(wc -l "$SKILL_DIR/SKILL.md" $REF_DIR/*.md $SCRIPT_DIR/*.sh 2>/dev/null | tail -1 | awk '{print $1}')
desc="total lines under 2600 budget (currently $total_lines)"
if [ "$total_lines" -le 2600 ]; then pass "$desc"; else fail "$desc"; fi

# ============================================================================
# Case 2: Script hardening patterns
# Source: 5 experiment commits (dependency checks, eval removal, var defaults)
# Lesson: defensive shell coding prevents silent failures
# ============================================================================
echo ""
echo "Case 2: Script hardening patterns"

for script in "$SCRIPT_DIR"/metric-*.sh; do
  name=$(basename "$script")

  # 2a. Has dependency check (command -v or which)
  desc="$name has dependency check (command -v)"
  if grep -qE 'command -v|which ' "$script" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

  # 2b. Has strict error mode
  desc="$name has strict error mode (set -e or set -euo)"
  if grep -qE 'set -[euo]' "$script" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi

  # 2c. No eval usage (replaced with bash -c)
  eval_count=$(count_matches '\beval\b' "$script")
  desc="$name has no eval usage (found $eval_count)"
  if [ "$eval_count" -eq 0 ]; then pass "$desc"; else fail "$desc"; fi

  # 2d. Has usage/description comment at top
  desc="$name has usage comment in header"
  if head -5 "$script" | grep -qiE 'metric|composite|score|usage'; then pass "$desc"; else fail "$desc"; fi
done

# ============================================================================
# Case 3: Cross-reference consistency (SKILL.md ↔ references/)
# Source: validate-skill.sh checks, multiple cleanup commits
# Lesson: mode routing table must stay in sync with actual files
# ============================================================================
echo ""
echo "Case 3: Cross-reference consistency"

# 3a. Every file referenced in SKILL.md exists
while IFS= read -r ref; do
  desc="referenced file exists: $ref"
  if [ -f "$SKILL_DIR/$ref" ]; then pass "$desc"; else fail "$desc"; fi
done < <(grep -oE 'references/[a-z-]+\.md' "$SKILL_DIR/SKILL.md" 2>/dev/null | sort -u)

# 3b. Every reference file is referenced in SKILL.md
for f in "$REF_DIR"/*.md; do
  name=$(basename "$f")
  desc="$name is referenced in SKILL.md"
  if grep -q "$name" "$SKILL_DIR/SKILL.md" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi
done

# 3c. Every reference file has a top-level heading
for f in "$REF_DIR"/*.md; do
  name=$(basename "$f")
  desc="$name has top-level # heading"
  if head -3 "$f" | grep -q '^# '; then pass "$desc"; else fail "$desc"; fi
done

# 3d. Script templates exist
count=$(ls "$SCRIPT_DIR"/metric-*.sh 2>/dev/null | wc -l | tr -d '[:space:]')
desc="at least 1 metric script template exists (found $count)"
if [ "$count" -ge 1 ]; then pass "$desc"; else fail "$desc"; fi

# ============================================================================
# Case 4: Portability lessons from reverted experiments
# Source: 2 revert commits (1e4894e, b330a22)
# Lesson: avoid GNU-only grep -P, broken glob in [ -f ], over-formatting
# ============================================================================
echo ""
echo "Case 4: Portability (lessons from reverts)"

# 4a. No grep -P (GNU-only, fails on macOS BSD grep)
for script in "$SCRIPT_DIR"/metric-*.sh; do
  name=$(basename "$script")
  gp_count=$(count_matches 'grep.*-[a-zA-Z]*P' "$script")
  desc="$name has no grep -P (GNU-only) usage"
  if [ "$gp_count" -eq 0 ]; then pass "$desc"; else fail "$desc"; fi
done

# 4b. No sed -i without '' (macOS requires sed -i '')
for script in "$SCRIPT_DIR"/metric-*.sh; do
  name=$(basename "$script")
  bare_sed=$(count_matches "sed -i [^']" "$script")
  desc="$name has no bare sed -i (GNU-only)"
  if [ "$bare_sed" -eq 0 ]; then pass "$desc"; else fail "$desc"; fi
done

# 4c. Decision tree in metric-design.md has no empty branches
#     (regression from revert 1e4894e — empty └── lines)
empty_branches=$(count_matches '^\s*[└├]──\s*$' "$REF_DIR/metric-design.md")
desc="metric-design.md has no empty tree branches (found $empty_branches)"
if [ "$empty_branches" -eq 0 ]; then pass "$desc"; else fail "$desc"; fi

# ============================================================================
# Case 5: Single source of truth (no cross-file duplication)
# Source: 4 redundancy removal commits (Git as Memory, Noise Handling, etc.)
# Lesson: same content in 2 places = guaranteed divergence
# ============================================================================
echo ""
echo "Case 5: Single source of truth (no duplication)"

# 5a. "Git as Memory" lives in core-principles only, not duplicated in loop protocol
git_memory_in_core=$(count_matches "Git.*[Mm]emory\|git.*memory" "$REF_DIR/core-principles.md")
git_memory_section_in_loop=$(count_matches "^## .*Git.*Memory\|^### .*Git.*Memory" "$REF_DIR/autonomous-loop-protocol.md")
desc="Git as Memory owned by core-principles (${git_memory_in_core}), no section in loop (${git_memory_section_in_loop})"
if [ "$git_memory_in_core" -gt 0 ] && [ "$git_memory_section_in_loop" -eq 0 ]; then pass "$desc"; else fail "$desc"; fi

# 5b. Noise handling lives in metric-design only
noise_in_metric=$(count_matches "[Nn]oise\|[Ff]laky\|[Vv]ariance" "$REF_DIR/metric-design.md")
noise_section_in_loop=$(count_matches "^## .*Noise\|^### .*Noise" "$REF_DIR/autonomous-loop-protocol.md")
desc="Noise handling owned by metric-design (${noise_in_metric}), no section in loop (${noise_section_in_loop})"
if [ "$noise_in_metric" -gt 0 ] && [ "$noise_section_in_loop" -eq 0 ]; then pass "$desc"; else fail "$desc"; fi

# 5c. No deprecated terms in SKILL.md and loop protocol
#     (baseline_metric in session-resume state schema is valid — excluded)
dep_skill=$(count_matches "metric_cmd\|old_metric" "$SKILL_DIR/SKILL.md")
dep_loop=$(count_matches "update_baseline\|old_metric" "$REF_DIR/autonomous-loop-protocol.md")
dep_total=$((dep_skill + dep_loop))
desc="no deprecated terms in SKILL.md + loop protocol (found $dep_total)"
if [ "$dep_total" -eq 0 ]; then pass "$desc"; else fail "$desc"; fi

# 5d. No TODO/FIXME/HACK markers left
marker_files=$(count_files "TODO\|FIXME\|HACK\|XXX" "$SKILL_DIR" --include="*.md")
desc="no TODO/FIXME/HACK markers in skill files (found in $marker_files files)"
if [ "$marker_files" -eq 0 ]; then pass "$desc"; else fail "$desc"; fi

# ============================================================================
# Summary
# ============================================================================
echo ""
total=$((passed + failed))
echo "Results: $passed/$total passed, $failed failed"
exit "$failed"
