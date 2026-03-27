# Autoresearch

Autonomous goal-directed iteration for any domain with a measurable metric. Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch).

**Core loop:** Modify -> Verify -> Keep/Discard -> Repeat

The LLM agent is the mutation function, replacing random search with reasoning-driven hypothesis testing. The human sets direction; the agent executes.

## Installation

```bash
claude plugin add autoresearch
```

Or use the installer helper (interactive / non-interactive):

```bash
# Interactive mode (skills.sh-style menu flow)
./scripts/install-autoresearch.sh

# Non-interactive mode (CI-friendly)
./scripts/install-autoresearch.sh --action install --source . --yes --non-interactive
```

Full installation scenarios (Korean, all cases):  
`docs/INSTALL_GUIDE_KO.md`

## Cross-Agent Compatibility

This skill is agent-agnostic. It works with any LLM agent that can read files, write files, and run shell commands.

| Agent | Tested | Result |
|-------|--------|--------|
| Claude Code | Yes | 5/5 iterations, all keeps |
| Codex CLI | Yes | 5/5 iterations, all keeps |
| Gemini CLI | Yes | 5/5 iterations, all keeps |

Install the skill for other agents:

```bash
# Codex CLI / Gemini CLI
cp -r skills/autoresearch /path/to/project/.agents/skills/autoresearch
```

## Commands

Single command with mode argument:

| Command | Description |
|---------|-------------|
| `/autoresearch` | Main autonomous optimization loop |
| `/autoresearch plan` | Interactive goal-to-config wizard |
| `/autoresearch debug` | Scientific debugging loop |
| `/autoresearch fix` | Iterative error repair |
| `/autoresearch security` | STRIDE + OWASP security audit |
| `/autoresearch ship` | Universal shipping workflow |

## Quick Start

```
/autoresearch Goal: increase test coverage Scope: test_*.py Metric: pytest --tb=no 2>&1 | grep -c passed Direction: higher Verify: pytest --tb=short
```

Or use the interactive wizard:

```
/autoresearch plan
```

## Parameters

| Parameter | Required | Format | Example |
|-----------|----------|--------|---------|
| Goal | Yes | Free text | "Increase test coverage to 90%" |
| Scope | Yes | File glob | "src/utils/*.ts" |
| Metric | Yes | Shell command outputting a number | `pytest --tb=no 2>&1 \| grep -c passed` |
| Direction | Yes | `higher` or `lower` | "higher" |
| Verify | Yes | Shell command for verification | `npm test 2>&1 \| tail -1` |
| Iterations | No | Integer | 20 (default: unbounded) |
| Guard | No | Shell command (exit 0 = pass) | `mypy --strict` |
| MinDelta | No | Minimum metric change | 0.5 |

## How It Works

Each iteration follows an 8-phase loop:

1. **Review** — Read scope files, results log, git history
2. **Ideate** — Pick next hypothesis (exploit > explore > combine)
3. **Modify** — ONE atomic change, describable in one sentence
4. **Commit** — Git commit before verification (enables clean rollback)
5. **Verify** — Run metric extraction command
6. **Guard** — Regression check (optional)
7. **Decide** — Keep if improved, discard otherwise (simplicity wins ties)
8. **Log & Repeat** — Append to TSV, continue until done

### Stuck Recovery

- 3 consecutive discards -> REFINE (adjust strategy)
- 5 consecutive discards -> PIVOT (fundamentally different approach)
- Single `keep` resets all escalation counters

## License

MIT
