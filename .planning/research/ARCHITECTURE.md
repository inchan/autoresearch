# Architecture Research

**Domain:** Multi-agent CLI skill — platform adapter pattern
**Researched:** 2026-03-24
**Confidence:** HIGH (Claude Code), MEDIUM (Codex CLI Skills), HIGH (Gemini CLI Extensions)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         MONOREPO ROOT                                 │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                    COMMON CORE (platform-agnostic)               │  │
│  │                                                                   │  │
│  │  skills/autoresearch/SKILL.md       — setup gate, loop pseudocode│  │
│  │  skills/autoresearch/references/    — 12 protocol documents      │  │
│  │  scripts/metric-*.sh                — composite metric templates │  │
│  └──────────────────────────────┬────────────────────────────────── ┘  │
│                                  │  (read by all platform adapters)    │
│  ┌─────────────┐  ┌─────────────┴──┐  ┌────────────────────────────┐  │
│  │ CLAUDE CODE │  │   CODEX CLI    │  │      GEMINI CLI             │  │
│  │  ADAPTER    │  │   ADAPTER      │  │      ADAPTER                │  │
│  │             │  │                │  │                              │  │
│  │.claude-plugin│  │ .agents/skills │  │ .gemini/extensions/          │  │
│  │  plugin.json │  │ /autoresearch/ │  │  autoresearch/               │  │
│  │             │  │   SKILL.md     │  │   gemini-extension.json      │  │
│  │ commands/   │  │   agents/      │  │   commands/                  │  │
│  │  *.md       │  │    openai.yaml │  │    *.toml                    │  │
│  │             │  │   references/  │  │   references/                │  │
│  │             │  │   scripts/     │  │   scripts/                   │  │
│  └─────────────┘  └────────────────┘  └────────────────────────────┘  │
│                                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                   INSTALLER (scripts/install.sh)                  │  │
│  │  detect platform → copy/symlink adapter files → verify install   │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Platform |
|-----------|----------------|----------|
| `skills/autoresearch/SKILL.md` | Setup gate, loop logic, critical rules, subcommand routing | All (source of truth) |
| `skills/autoresearch/references/*.md` | 12 protocol documents, on-demand loaded | All (source of truth) |
| `scripts/metric-*.sh` | Composite metric script templates | All (source of truth) |
| `commands/*.md` | Thin dispatchers — parse args, load files via `${CLAUDE_PLUGIN_ROOT}` | Claude Code only |
| `.claude-plugin/plugin.json` | Plugin manifest for Claude Code marketplace | Claude Code only |
| `.agents/skills/autoresearch/SKILL.md` | Codex adapter SKILL.md — wraps common core with Codex invocation | Codex only |
| `.agents/skills/autoresearch/agents/openai.yaml` | Codex UI metadata, invocation policy, `$autoresearch` trigger | Codex only |
| `.gemini/extensions/autoresearch/gemini-extension.json` | Gemini extension manifest | Gemini only |
| `.gemini/extensions/autoresearch/commands/*.toml` | TOML command definitions for Gemini slash commands | Gemini only |
| `scripts/install.sh` | Interactive multi-platform installer with platform detection | All |

## Recommended Project Structure

```
autoresearch/                          (monorepo root)
├── skills/
│   └── autoresearch/
│       ├── SKILL.md                   # SOURCE OF TRUTH — never platform-specific
│       └── references/                # SOURCE OF TRUTH — all 12 protocol docs
│           ├── autonomous-loop-protocol.md
│           ├── core-principles.md
│           ├── results-logging.md
│           ├── plan-workflow.md
│           ├── debug-workflow.md
│           ├── fix-workflow.md
│           ├── security-workflow.md
│           ├── ship-workflow.md
│           ├── pivot-protocol.md
│           ├── session-resume.md
│           ├── lessons-protocol.md
│           └── metric-design.md
│
├── scripts/
│   ├── metric-test-quality.sh         # SOURCE OF TRUTH
│   ├── metric-code-health.sh          # SOURCE OF TRUTH
│   ├── metric-perf-score.sh           # SOURCE OF TRUTH
│   └── install.sh                     # NEW — multi-platform interactive installer
│
├── adapters/
│   ├── claude/                        # Claude Code adapter
│   │   ├── plugin.json                # Plugin manifest (EXISTING: .claude-plugin/plugin.json)
│   │   └── commands/                  # Thin dispatchers (EXISTING: commands/)
│   │       ├── autoresearch.md
│   │       └── autoresearch/
│   │           ├── plan.md
│   │           ├── debug.md
│   │           ├── fix.md
│   │           ├── security.md
│   │           └── ship.md
│   │
│   ├── codex/                         # Codex CLI adapter
│   │   ├── SKILL.md                   # NEW — Codex-specific SKILL.md wrapper
│   │   └── agents/
│   │       └── openai.yaml            # NEW — invocation metadata
│   │
│   └── gemini/                        # Gemini CLI adapter
│       ├── gemini-extension.json      # NEW — extension manifest
│       └── commands/                  # NEW — TOML command definitions
│           ├── autoresearch.toml
│           ├── plan.toml
│           ├── debug.toml
│           ├── fix.toml
│           ├── security.toml
│           └── ship.toml
│
├── .claude-plugin/                    # EXISTING (backward compat — symlink or copy from adapters/claude/)
│   └── plugin.json
├── commands/                          # EXISTING (backward compat — symlink or copy from adapters/claude/commands/)
│   └── ...
├── .claude/
│   └── settings.json
├── .planning/
└── docs/
```

### Structure Rationale

- **`skills/` stays as source of truth:** SKILL.md + references are the protocol definition layer. Every platform adapter reads from here. No duplication.
- **`adapters/` layer is new:** Platform-specific wiring. Thin files that only contain platform invocation syntax + paths pointing back to `skills/`.
- **`commands/` root-level preserved:** Backward compatibility for existing Claude Code users. Symlink or copy from `adapters/claude/commands/` at install time.
- **No `build/` step required:** All three platforms read the same `skills/` files at runtime. Adapters are thin enough to be authored directly — no code generation needed.
- **`scripts/install.sh` replaces `scripts/install-autoresearch.sh`:** The new installer handles platform detection and multi-target installation.

## Architectural Patterns

### Pattern 1: Thin Adapter with Shared Core

**What:** Platform-specific adapter files contain only the minimum syntax needed to invoke the common core. All business logic lives in `skills/autoresearch/`.

**When to use:** When the same protocol needs to run on N platforms with different invocation conventions.

**Trade-offs:** Adapters become trivially small (5-20 lines) but the install step must correctly wire paths. Path resolution differs per platform — Codex uses absolute `$HOME/.agents/skills/autoresearch/` paths, Gemini uses relative paths within the extension directory.

**Example — Claude Code (existing pattern):**
```markdown
---
description: Autonomous Goal-directed Iteration
argument-hint: "[Goal: <text>] [Scope: <glob>] [Metric: <text>] [Verify: <cmd>]"
---
Load: `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md`
Load: `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/references/autonomous-loop-protocol.md`
$ARGUMENTS
```

**Example — Codex adapter SKILL.md:**
```markdown
---
name: autoresearch
description: Autonomous goal-directed iteration for any domain with a measurable metric
---
Load the following files for protocol instructions:
- `references/autonomous-loop-protocol.md`
- `references/results-logging.md`
- `references/core-principles.md`

$autoresearch [Goal: <text>] [Scope: <glob>] [Verify: <cmd>]
```

**Example — Gemini TOML command:**
```toml
description = "Autonomous goal-directed iteration — modify, verify, keep/discard, repeat"
prompt = """
Load @{GEMINI_EXTENSION_PATH/../../skills/autoresearch/SKILL.md} for protocol.
Load @{GEMINI_EXTENSION_PATH/../../skills/autoresearch/references/autonomous-loop-protocol.md}

User arguments: <args>
Execute the autonomous loop as defined in SKILL.md.
"""
```

### Pattern 2: Path Resolution per Platform

**What:** Each platform has a different mechanism for resolving paths to shared files. The adapter must translate between the platform's path variable and the actual filesystem location.

**When to use:** Whenever the adapter needs to load files from the common core at runtime.

**Trade-offs:** Path resolution is the #1 source of installation errors. Absolute paths (written at install time by the installer) are more reliable than relative paths. The installer should emit the resolved absolute path into adapter files during installation.

**Platform path mechanisms:**

| Platform | Variable/Mechanism | Example |
|----------|--------------------|---------|
| Claude Code | `${CLAUDE_PLUGIN_ROOT}` — env var set by Claude Code | `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/SKILL.md` |
| Codex CLI | Relative paths from skill root OR absolute paths | `references/autonomous-loop-protocol.md` (relative) |
| Gemini CLI | `@{path}` file injection — paths relative to extension dir | `@{../../skills/autoresearch/SKILL.md}` |

**Installer strategy:** At install time, write absolute paths into adapter files. This avoids runtime path resolution failures entirely.

```bash
CORE_PATH="$(realpath skills/autoresearch)"
# Substitute into adapter templates before copying
sed "s|{{CORE_PATH}}|$CORE_PATH|g" adapters/codex/SKILL.md.template > ~/.agents/skills/autoresearch/SKILL.md
```

### Pattern 3: Subcommand Namespacing per Platform

**What:** The 6 commands (`autoresearch`, `plan`, `debug`, `fix`, `security`, `ship`) map to platform-specific invocation syntax.

**When to use:** Required for all three platforms.

**Mapping table:**

| Command | Claude Code | Codex CLI | Gemini CLI |
|---------|-------------|-----------|------------|
| main loop | `/autoresearch` | `$autoresearch` | `/autoresearch` |
| plan wizard | `/autoresearch:plan` | `$autoresearch:plan` | `/autoresearch:plan` |
| debug | `/autoresearch:debug` | `$autoresearch:debug` | `/autoresearch:debug` |
| fix | `/autoresearch:fix` | `$autoresearch:fix` | `/autoresearch:fix` |
| security | `/autoresearch:security` | `$autoresearch:security` | `/autoresearch:security` |
| ship | `/autoresearch:ship` | `$autoresearch:ship` | `/autoresearch:ship` |

**Notes:**
- Claude Code: subdirectory structure in `commands/autoresearch/` maps to `:` namespace automatically
- Codex CLI: `$skill-name` invocation; subcommands via `$autoresearch:plan` syntax (verify this works — MEDIUM confidence)
- Gemini CLI: TOML files in `commands/autoresearch/plan.toml` → `/autoresearch:plan` via directory namespacing (confirmed by docs)

## Data Flow

### Installation Flow

```
User runs: curl -fsSL install.sh | bash
    |
    v
Detect installed CLIs (claude, codex, gemini in PATH)
    |
    v
Prompt: "Install for which platform(s)? [1] Claude [2] Codex [3] Gemini [4] All"
    |
    v
For each selected platform:
    |
    +-- Claude: claude plugin add <path>
    |     (uses existing plugin.json + commands/ structure)
    |
    +-- Codex: mkdir -p ~/.agents/skills/autoresearch
    |     cp adapters/codex/SKILL.md -> ~/.agents/skills/autoresearch/SKILL.md
    |     cp adapters/codex/agents/openai.yaml -> ~/.agents/skills/autoresearch/agents/openai.yaml
    |     (with CORE_PATH substituted as absolute path to skills/)
    |
    +-- Gemini: gemini extensions install <path>
          (reads adapters/gemini/gemini-extension.json + commands/)
          (GEMINI.md contextFileName points to skills/autoresearch/SKILL.md)
```

### Runtime Flow (All Platforms)

```
User invokes command (e.g., /autoresearch:plan)
    |
    v
Platform dispatcher (commands/*.md OR TOML OR SKILL.md routing)
    |
    v
Load skills/autoresearch/SKILL.md  [COMMON CORE]
    |
    v
Load skills/autoresearch/references/<workflow>.md  [ON-DEMAND]
    |
    v
Agent executes protocol from SKILL.md
    |
    v
State written to: autoresearch-state.json, autoresearch-results.tsv
    |
    v
Git operations (commit/revert) — identical on all platforms
```

### Key Data Flows

1. **File loading:** Platform adapter → SKILL.md → references/*.md (on-demand). Only one level of indirection; references are never loaded by references.
2. **State persistence:** All platforms write to the same files (`autoresearch-state.json`, `autoresearch-results.tsv`, `autoresearch-lessons.md`). These are gitignored and platform-agnostic.
3. **Git as memory:** All platforms execute the same git commands (`git log`, `git revert`, `git commit`). Git is the cross-platform state that survives sessions.

## Integration Points

### New vs Modified Components

| Component | Status | Notes |
|-----------|--------|-------|
| `skills/autoresearch/SKILL.md` | **UNCHANGED** | Source of truth; must not gain platform-specific content |
| `skills/autoresearch/references/*.md` | **UNCHANGED** | Source of truth; all 12 files stay as-is |
| `scripts/metric-*.sh` | **UNCHANGED** | Platform-agnostic shell scripts |
| `commands/*.md` | **UNCHANGED** | Claude Code adapters stay identical for backward compat |
| `.claude-plugin/plugin.json` | **UNCHANGED** | Claude Code manifest unchanged |
| `adapters/codex/SKILL.md` | **NEW** | Codex-specific wrapper pointing to common core |
| `adapters/codex/agents/openai.yaml` | **NEW** | Codex invocation metadata |
| `adapters/gemini/gemini-extension.json` | **NEW** | Gemini extension manifest |
| `adapters/gemini/commands/*.toml` | **NEW** | 6 TOML files for Gemini slash commands |
| `scripts/install.sh` | **REPLACE** `scripts/install-autoresearch.sh` | Multi-platform interactive installer |
| `.claude/settings.json` | **UNCHANGED** | Claude Code project settings |

### Platform Integration Points

| Boundary | Integration | Notes |
|----------|-------------|-------|
| SKILL.md → Codex | Codex reads SKILL.md from `.agents/skills/autoresearch/` at `$autoresearch` invocation | Codex loads full SKILL.md only on activation (progressive disclosure) |
| SKILL.md → Gemini | Gemini loads `GEMINI.md` (= SKILL.md via `contextFileName`) on extension activation | Always loaded at session start, not on-demand — may increase context usage |
| commands/ → Claude | `${CLAUDE_PLUGIN_ROOT}` resolved at load time by Claude Code | No change from v1.0 |
| commands/ → Gemini | `.gemini/commands/*.toml` with `@{path}` file injection | Gemini's `@{path}` resolves relative to the TOML file's location |
| Installer → Codex | Writes to `~/.agents/skills/autoresearch/` (global) or `.agents/skills/autoresearch/` (project) | Project-level preferred: lets users check skill into their repo |
| Installer → Gemini | Runs `gemini extensions install <path>` — installs to `~/.gemini/extensions/autoresearch/` | Official install command; handles path setup automatically |

### Gemini-Specific: GEMINI.md Context Loading

Gemini's `contextFileName: "GEMINI.md"` loads the file at session start (always), unlike Claude Code's on-demand loading. Options:

1. **Use SKILL.md as GEMINI.md directly** — set `contextFileName` to the path of SKILL.md. Risk: SKILL.md is too long; Gemini loads it every session.
2. **Create a thin GEMINI.md** — a short context file that says "use the autoresearch extension commands". SKILL.md content is loaded via `@{path}` injection inside each TOML command. **This is the right approach.**

### Codex-Specific: Skills vs Custom Prompts

Codex custom prompts (deprecated) use `~/.codex/prompts/*.md` with `$ARGUMENTS` placeholder — identical to Claude Code's `commands/*.md` format. However, **Skills are the current path** and are not deprecated. The adapter should use the Skills path (`.agents/skills/autoresearch/SKILL.md`) rather than custom prompts.

## Scaling Considerations

This is a developer tool skill — "scaling" means "supports more platforms and more users installing it", not traffic volume.

| Growth Stage | Architecture Adjustments |
|--------------|--------------------------|
| 3 platforms (current goal) | Monorepo with `adapters/` layer; single `install.sh` |
| 5+ platforms (future: Cursor, Copilot, etc.) | Each new platform adds one directory under `adapters/`; core unchanged |
| Community contributions | `adapters/` makes the contribution boundary obvious: "add a directory, don't touch `skills/`" |

### Scaling Priority

1. **First concern:** Path resolution at install time. Absolute paths written by installer are more reliable than runtime relative path resolution.
2. **Second concern:** GEMINI.md context size. Gemini loads context file every session; keep thin GEMINI.md, load SKILL.md per-command via `@{path}`.

## Anti-Patterns

### Anti-Pattern 1: Duplicating Protocol Content into Adapters

**What people do:** Copy SKILL.md content into each platform adapter so each adapter is "self-contained."

**Why it's wrong:** 3 copies of protocol docs diverge immediately. Fixing a bug in `autonomous-loop-protocol.md` requires updating 3 places. This is the #1 rewrite cause in multi-platform skills.

**Do this instead:** Keep SKILL.md + references as the single source of truth. Adapters load them via path references. Accept the path resolution complexity as a one-time install-time problem.

### Anti-Pattern 2: Platform-Specific Logic in SKILL.md

**What people do:** Add `if platform == codex then ... elif platform == gemini then ...` branching into SKILL.md to handle platform differences.

**Why it's wrong:** SKILL.md becomes unreadable and fragile. The 8-phase loop is platform-agnostic; it should stay that way.

**Do this instead:** Platform differences (invocation syntax, path variables, context loading) belong exclusively in adapter files. SKILL.md should be readable without knowing which platform runs it.

### Anti-Pattern 3: Relative Paths in Adapter Files

**What people do:** Reference `../../skills/autoresearch/SKILL.md` in adapter files, relying on the relative path being correct at runtime.

**Why it's wrong:** Path resolution depends on the working directory, which differs between Claude Code (`${CLAUDE_PLUGIN_ROOT}` resolves correctly), Codex (resolves from skill root), and Gemini (`@{path}` resolves from TOML file location). Relative paths work in development but fail after `gemini extensions install` copies files to `~/.gemini/extensions/`.

**Do this instead:** Have `install.sh` substitute absolute paths at install time. Templates use `{{CORE_PATH}}` placeholder; installer replaces with `$(realpath skills/autoresearch)`.

### Anti-Pattern 4: One Installer Per Platform

**What people do:** Create `install-claude.sh`, `install-codex.sh`, `install-gemini.sh` as separate scripts.

**Why it's wrong:** Users need to know which script to run. New platform additions require a new script and documentation update.

**Do this instead:** Single `install.sh` with interactive platform selection (like Vercel's `skills.sh` pattern). Platform detection as default: check `which claude`, `which codex`, `which gemini` and pre-select found platforms.

## Build Order

Dependencies between components determine implementation order:

```
1. Common Core verification (UNCHANGED — just validate existing files)
       |
       v
2. adapters/gemini/gemini-extension.json  (no deps on other new code)
   adapters/gemini/commands/*.toml        (no deps on other new code)
       |
       v
3. adapters/codex/agents/openai.yaml      (no deps on other new code)
       |
       v
4. adapters/codex/SKILL.md               (depends on understanding Codex $skill syntax)
       |
       v
5. scripts/install.sh                    (depends on adapter structure being finalized)
       |
       v
6. End-to-end test: each platform invokes /autoresearch with trivial project
```

**Rationale:**
- Steps 2-3 are independent and can be built in parallel.
- Step 4 (Codex SKILL.md) needs Step 3 done first (openai.yaml defines invocation policy).
- Step 5 (installer) must come last — it needs final paths for all adapters.
- Common core (Step 1) is never modified; it just needs a path validation pass.

## Sources

- [Custom instructions with AGENTS.md – Codex](https://developers.openai.com/codex/guides/agents-md) — HIGH confidence (official)
- [Agent Skills – Codex](https://developers.openai.com/codex/skills) — MEDIUM confidence (official but newer feature)
- [Custom Prompts – Codex CLI](https://developers.openai.com/codex/custom-prompts) — HIGH confidence (official; deprecated in favor of Skills)
- [Gemini CLI Custom Commands](https://google-gemini.github.io/gemini-cli/docs/cli/custom-commands.html) — HIGH confidence (official)
- [Gemini CLI Extensions](https://google-gemini.github.io/gemini-cli/docs/extensions/) — HIGH confidence (official)
- [Codex CLI Slash Commands](https://developers.openai.com/codex/cli/slash-commands) — MEDIUM confidence (built-in slash commands differ from skill invocation)
- Codex subcommand syntax (`$autoresearch:plan`) — LOW confidence; `$skill` invocation is confirmed, `:subcommand` namespacing needs verification against [openai/codex issue #15167](https://github.com/openai/codex/issues/15167)

---
*Architecture research for: autoresearch multi-agent CLI support (v1.1)*
*Researched: 2026-03-24*
