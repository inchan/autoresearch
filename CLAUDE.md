# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

An autoresearch skill for Claude Code, inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) (March 2026). The original is a 630-line Python system for autonomous ML experimentation; this project generalizes the pattern into a Claude Code skill that works on **any domain** with a measurable metric.

**Core loop:** Modify -> Verify -> Keep/Discard -> Repeat. The LLM agent is the mutation function, replacing random search with reasoning-driven hypothesis testing.

## The Karpathy Pattern (Foundational)

The generalizable pattern distilled from autoresearch:

1. **ONE scope** — bounded set of files the agent can modify
2. **ONE metric** — mechanical, command-extractable number
3. **ONE fixed evaluation budget** — makes results directly comparable
4. **Binary keep/discard** — no ambiguity; improved = keep, else revert
5. **Infinite loop** — agent runs until manually stopped; NEVER asks "should I continue?"
6. **Git as memory** — commits preserve successful experiments, reverts preserve failure history
7. **Simplicity criterion** — equal metric + less code = keep; tiny gain + ugly complexity = discard

Three-file architecture: `prepare.py` (fixed eval, read-only), `train.py` (agent-editable), `program.md` (human-written strategy in English). The human writes "research org code" in natural language; the agent translates to code modifications.

## Architecture

This is a Claude Code plugin with skills.

```
.claude-plugin/
  plugin.json                 # Plugin manifest (name, version, metadata)
.claude/
  settings.json               # Project-level Claude Code settings
skills/                       # Skills (plugin root)
  autoresearch/
    SKILL.md                  # Main skill definition + mode routing table
    references/               # Protocol documents (loaded on-demand by mode)
      autonomous-loop-protocol.md   # Full 8-phase loop protocol
      core-principles.md            # 7 universal principles
      results-logging.md            # TSV format and logging functions
      plan-workflow.md              # Goal->config wizard steps
      debug-workflow.md             # Scientific debug loop
      fix-workflow.md               # Iterative fix protocol
      security-workflow.md          # STRIDE+OWASP audit protocol
      ship-workflow.md              # Universal ship workflow
      pivot-protocol.md            # REFINE/PIVOT stuck recovery + scope expansion
      session-resume.md            # Cross-session state recovery
      lessons-protocol.md          # Cross-run learning persistence
      metric-design.md             # Metric design guide, composite templates, anti-gaming
    scripts/                      # Composite metric script templates
      metric-test-quality.sh        # Test quality composite (pass rate + coverage)
      metric-code-health.sh         # Code health composite (errors + lint + tests + complexity)
      metric-perf-score.sh          # Performance composite (latency + memory)
```

### Key Design Decisions

- **Single skill, mode routing** — SKILL.md dispatches to the correct references via mode routing table
- **References are loaded on-demand** — keeps context window lean; only load what the current mode needs
- **State is file-based** — `autoresearch-results.tsv` (append-only log) + `autoresearch-state.json` (atomic snapshot). Both gitignored, never committed
- **Git is the primary memory** — agent reads `git log` and `git diff` every iteration to learn from past experiments. `git revert` preferred over `git reset --hard` to preserve history
- **Two-phase interaction boundary** — all questions happen BEFORE launch. After "go", fully autonomous. NEVER pause mid-loop
- **3-tier scope model** — Core (full read/write), Support (limited write for imports/types), Context (read-only). Auto-detected from import analysis during setup
- **3-level metrics** — Direct (goal IS a number), Proxy (mechanical approximation), Composite (weighted multi-metric script). Anti-gaming via Guard + sanity check + structural guard
- **Scope expansion on PIVOT** — when stuck, automatically checks if scope boundaries are the bottleneck and suggests Support scope additions

### The Autonomous Loop (8 Phases)

```
Phase 0: Preconditions    — git state, dirty tree, hooks, session resume
Phase 1: Review           — read scope files, results log, git history, lessons
Phase 2: Ideate           — pick next change (exploit successes > explore new > combine near-misses)
Phase 3: Modify           — ONE atomic change, describable in one sentence
Phase 4: Commit           — git commit BEFORE verification (enables clean rollback)
Phase 5: Verify           — run mechanical metric extraction command
Phase 5.5: Guard          — regression check (optional pass/fail command)
Phase 6: Decide           — keep/discard/crash with simplicity override
Phase 7: Log              — append to TSV, update JSON state
Phase 8: Repeat           — NEVER STOP (unbounded) or check iteration count (bounded)
```

### Stuck Recovery (PIVOT/REFINE)

- 3 consecutive discards -> REFINE (adjust within current strategy)
- 5 consecutive discards -> PIVOT (abandon strategy, try fundamentally different approach)
- 2 PIVOTs without keep -> web search escalation
- 3 PIVOTs without keep -> soft blocker warning, increasingly bold changes
- Single `keep` resets all escalation counters

## Development

### Testing a skill locally

Install the plugin for local development:

```bash
# Symlink the plugin root into Claude Code's plugin directory
ln -sf "$(pwd)" ~/.claude/plugins/autoresearch-dev
```

### Validating skill structure

```bash
# Check all referenced files exist
grep -roh 'references/[a-z-]*.md' skills/autoresearch/SKILL.md | sort -u | while read f; do
  test -f "skills/autoresearch/$f" || echo "MISSING: $f"
done
```

### Testing the loop

Use a trivial project with a fast metric:

```bash
# Example: optimize a Python function's test count
mkdir /tmp/test-autoresearch && cd /tmp/test-autoresearch
git init
echo 'def add(a, b): return a + b' > math_utils.py
echo 'def test_add(): assert add(1, 2) == 3' > test_math.py
# Then invoke: /autoresearch Goal: increase test coverage Scope: test_math.py Verify: pytest --tb=short 2>&1 | grep -c 'passed'
```

## Key Reference Implementations

These are the primary sources studied and adapted from:

| Implementation | Platform | Stars | Key Innovation |
|---|---|---|---|
| [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | Standalone | 43.3k | Original pattern: one GPU, one file, one metric |
| [uditgoenka/autoresearch](https://github.com/uditgoenka/autoresearch) | Claude Code plugin | 1.5k | 8 slash commands, domain-generic, plugin marketplace |
| [leo-lilinxiao/codex-autoresearch](https://github.com/leo-lilinxiao/codex-autoresearch) | Codex CLI | 305 | Parallel worktrees, cross-run lessons, smart pivot |
| [jmilinovich/goal-md](https://github.com/jmilinovich/goal-md) | Tool-agnostic | 62 | GOAL.md spec: fitness function + action catalog |
| [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch) | pi agent | 2.3k | MCP-style tools (init/run/log), confidence scoring |
| [zkarimi22/autoresearch-anything](https://github.com/zkarimi22/autoresearch-anything) | Any agent | 97 | Setup wizard generator (`npx autoresearch-anything`) |

## Conventions

- **Commit messages** for experiment iterations: `experiment(<scope>): <description>`
- **TSV logging** — tab-separated, never comma-separated (commas break in descriptions)
- **Results file** — `autoresearch-results.tsv`, gitignored, never committed
- **State file** — `autoresearch-state.json`, atomic write via tmp+rename, never committed
- **Lessons file** — `autoresearch-lessons.md`, persists across runs, never committed
- **Rollback** — prefer `git revert HEAD --no-edit` over `git reset --hard`; fall back to reset only on revert conflicts
- **Atomicity** — one logical change per iteration; if description needs "and", split into two iterations
- **No `--no-verify`** — never bypass git hooks; fix the underlying issue instead
- **No `git add -A`** — always stage specific files to avoid leaking secrets or user's unrelated work
