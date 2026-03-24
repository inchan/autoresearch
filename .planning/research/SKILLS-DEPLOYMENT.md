# Skills-Only Architecture for Multi-Platform CLI Agent Distribution

> Research date: 2026-03-24
> Goal: Determine whether converting ALL commands to skills eliminates platform-specific adapters

---

## 1. Agent Skills Open Standard (agentskills.io)

### 1.1 Subcommands / Sub-skills

**Finding:** The Agent Skills spec does NOT currently support colon-namespaced subcommands at the spec level. The `name` field is restricted to `[a-z0-9-]+` (kebab-case only, no colons). However, the colon syntax (`plugin:skill`) is a **Claude Code plugin-layer feature**, not an Agent Skills spec feature.

- Issue [#143](https://github.com/agentskills/agentskills/issues/143) proposes directory grouping with colon-separated invocation (`deploy:staging`, `test:unit`), citing Claude Code plugins as prior art. **Status: open proposal, not merged into spec.**
- Current workaround: naming prefixes (`autoresearch-plan`, `autoresearch-debug`) as flat siblings.
- Claude Code plugins get the colon syntax automatically: `plugin.json` `name` field becomes the namespace prefix, so `autoresearch` plugin with a `plan` skill becomes `/autoresearch:plan`.

**Confidence: HIGH** (spec text is unambiguous; issue #143 confirms the gap)

### 1.2 Invocation by Users on Each Platform

| Platform | Skill Invocation | Slash Command |
|---|---|---|
| **Claude Code** | Auto-matched by description OR explicit `$skill-name` OR `/skill-name` (skills and commands merged since v2.1.3) | `/command-name` (merged with skills) |
| **Codex CLI** | Implicit (prompt matches description) OR explicit `$[skill-name]`. Slash commands (`/foo`) are reserved for built-in Codex commands only; custom skill `/foo` is [rejected](https://github.com/openai/codex/issues/15167) | Built-in only (`/clear`, `/permissions`) |
| **Gemini CLI** | Auto-activated via `activate_skill` tool when prompt matches description. No user-facing `/` syntax for custom skills | Built-in only |
| **Cursor** | Auto-loaded by description match | `@skill-name` mention |
| **VS Code Copilot** | Auto-loaded by description match | Not applicable |

**Key insight:** Only Claude Code supports user-initiated `/slash-command` for custom skills. On Codex and Gemini, skills are **model-invoked** (the AI decides when to load them based on semantic matching). This means the `/autoresearch:plan` UX is **Claude Code-specific** and won't translate to other platforms.

**Confidence: HIGH**

### 1.3 Namespacing Mechanism

- **Spec level:** None. Flat namespace, kebab-case names only.
- **Claude Code plugins:** Automatic `plugin-name:skill-name` namespacing via `plugin.json`.
- **Codex/Gemini/Cursor:** No namespacing. Name collisions resolved by precedence (workspace > user > extension).
- **Proposal:** Issue #143 would add `group/` directories with colon invocation, but not yet adopted.

**Confidence: HIGH**

---

## 2. `npx skills` (vercel-labs/skills) Deployment

### 2.1 Installation Flow

```bash
npx skills add owner/repo          # Install all skills from a repo
npx skills add owner/repo --skill my-skill  # Install specific skill
npx skills add owner/repo -a claude  # Install for specific agent only
npx skills add ./local/path        # Install from local directory
npx skills add owner/repo -g       # Install globally
npx skills add owner/repo --list   # List available skills without installing
npx skills add owner/repo -y       # Non-interactive (CI/CD)
```

The CLI:
1. Clones/downloads the repo
2. Discovers all `SKILL.md` files in the repo
3. Auto-detects which agents are installed (checks for `.claude/`, `.codex/`, `.gemini/`, `.cursor/`, etc.)
4. Copies the skill directory to `.agents/skills/` (canonical location)
5. Creates **symlinks** from each agent's directory (`.claude/skills/`, `.codex/skills/`, etc.) to the canonical copy

Sources: [vercel-labs/skills README](https://github.com/vercel-labs/skills), [npm: skills](https://www.npmjs.com/package/skills), [Vercel KB](https://vercel.com/kb/guide/agent-skills-creating-installing-and-sharing-reusable-agent-context)

**Confidence: HIGH**

### 2.2 Subdirectory Handling (references/, scripts/)

**Yes, the entire skill directory is preserved.** When `npx skills add` installs a skill, it copies the complete directory tree including:
- `references/` subdirectories
- `scripts/` subdirectories
- Any other bundled assets

The agent sees the skill directory path and resolves relative references (`references/core-principles.md`, `scripts/metric-test-quality.sh`) from the skill root.

Gemini CLI specifically adds the skill's directory to the agent's allowed file paths upon activation, granting read access to all bundled assets.

**Confidence: HIGH**

### 2.3 Skill-Only Repos (No Commands)

**Yes, `npx skills add` works with repos that have NO commands directory.** The CLI only looks for `SKILL.md` files. The repo structure just needs:

```
skills/
  my-skill/
    SKILL.md
    references/
    scripts/
```

Or even flatter:
```
my-skill/
  SKILL.md
```

No `commands/`, no `plugin.json`, no `.claude-plugin/` required for `npx skills add` to work.

Sources: [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills), [anthropics/skills](https://github.com/anthropics/skills)

**Confidence: HIGH**

### 2.4 Required Repo Structure

Minimum viable structure for `npx skills add`:
```
repo-root/
  skills/
    skill-name/
      SKILL.md          # Required: YAML frontmatter + markdown
      scripts/           # Optional: executable scripts
      references/        # Optional: reference docs
      assets/            # Optional: templates, examples
```

The `skills/` top-level directory is the convention but not strictly required -- the CLI discovers any `SKILL.md` in the repo tree.

**Confidence: MEDIUM** (exact discovery heuristic may vary by CLI version)

---

## 3. Platform-Specific Skill Discovery

### 3.1 Claude Code

**Discovery paths (in precedence order):**
1. Plugin skills (`.claude-plugin/` + `skills/` in plugin root) -- namespaced as `plugin:skill`
2. Project skills (`.claude/skills/*/SKILL.md`)
3. Cross-agent skills (`.agents/skills/*/SKILL.md`)
4. User skills (`~/.config/claude/skills/*/SKILL.md` or `~/.claude/skills/`)
5. Monorepo: also scans `packages/*/. claude/skills/` when editing files in subdirectories

**Activation:** At session start, name + description loaded (~50-100 tokens per skill). Full SKILL.md loaded on demand when matched.

**Merge with commands:** Since v2.1.3, `.claude/commands/foo.md` and `.claude/skills/foo/SKILL.md` are equivalent. Skills take precedence on name collision.

Sources: [Claude Code Docs: Skills](https://code.claude.com/docs/en/skills), [Claude API Docs: Agent Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)

**Confidence: HIGH**

### 3.2 Codex CLI

**Discovery paths:**
1. `.codex/skills/*/SKILL.md`
2. `.agents/skills/*/SKILL.md` (cross-agent alias)
3. Scans from CWD up to repo root

**Activation:** Implicit (model matches prompt to skill description) or explicit (`$[skill-name]`).

Source: [OpenAI Developers: Codex Skills](https://developers.openai.com/codex/skills)

**Confidence: HIGH**

### 3.3 Gemini CLI

**Discovery paths (in precedence order):**
1. Workspace: `.gemini/skills/*/SKILL.md`
2. Workspace alias: `.agents/skills/*/SKILL.md` (takes precedence over `.gemini/` within same tier)
3. User: `~/.gemini/skills/*/SKILL.md`
4. User alias: `~/.agents/skills/*/SKILL.md`
5. Extension skills

**Activation:** Model calls `activate_skill` tool. Skill directory added to allowed file paths.

Sources: [Gemini CLI Docs: Skills](https://geminicli.com/docs/cli/skills/), [Gemini CLI: Creating Skills](https://geminicli.com/docs/cli/creating-skills/)

**Confidence: HIGH**

### 3.4 Cross-Platform Compatibility

**All three platforms support the SAME `SKILL.md` format without modification.** The `.agents/skills/` directory is the universal cross-agent location. A single `SKILL.md` file works on Claude Code, Codex CLI, Gemini CLI, Cursor, VS Code Copilot, and 10+ more tools.

**Confidence: HIGH**

---

## 4. Skills vs Commands Comparison

### 4.1 UX Differences Per Platform

| Aspect | Commands (Claude Code only) | Skills (Cross-platform) |
|---|---|---|
| **Invocation** | User types `/command-name` | Model auto-matches OR user types `/skill-name` (Claude Code) or `$[skill-name]` (Codex) |
| **Discovery** | Tab completion in terminal | Semantic matching from description |
| **Context cost** | Full prompt loaded every invocation (100-1000 tokens) | Metadata only at startup (~50 tokens), full content on demand |
| **Portability** | Claude Code only | 16+ platforms |
| **Arguments** | Supported via `$ARGUMENTS` | Supported via `$ARGUMENTS` (on Claude Code) |
| **Subcommands** | Plugin colon syntax (`/plugin:cmd`) | Not in spec (naming prefix workaround) |
| **Supporting files** | Single .md file | Directory with scripts/, references/, etc. |

### 4.2 Can a Skill Completely Replace a Command?

**Yes, on Claude Code.** Since the commands/skills merge in v2.1.3:
- A skill at `.claude/skills/autoresearch/SKILL.md` creates `/autoresearch` slash command
- Old `.claude/commands/autoresearch.md` files still work unchanged
- Skills are recommended for new work (support sub-files, invocation control, subagent execution)

**No, for the colon subcommand UX.** The `/autoresearch:plan` pattern requires the Claude Code plugin system (`plugin.json` namespacing). A standalone skill can only be `/autoresearch-plan` (kebab-case). On Codex/Gemini, there is no user-facing `/` command at all -- skills are model-invoked.

### 4.3 Limitations of Skills vs Commands

**Skills limitations:**
- No colon-based subcommand namespacing in the open spec (only via Claude Code plugins)
- On Codex/Gemini, users cannot explicitly invoke skills via slash syntax
- Semantic matching may not always trigger the right skill

**Commands limitations:**
- Claude Code only -- zero portability
- Single file -- no bundled scripts/references
- Higher token cost per invocation

**Confidence: HIGH**

---

## 5. Installer Patterns

### 5.1 `npx skills` (Vercel)

The dominant installer. Handles multi-platform detection and symlink creation automatically.

```bash
npx skills add owner/repo
```

### 5.2 Shell Installers

Several projects provide `curl | sh` installers:

- **skillshare** (`runkids/skillshare`): `curl -fsSL https://raw.githubusercontent.com/runkids/skillshare/main/install.sh | sh` -- syncs skills across all CLI tools with one command
- **agentikit** (`itlackey/agentikit`): `curl -fsSL https://raw.githubusercontent.com/itlackey/agentikit/main/install.sh | bash`
- **openskills** (`numman-ali/openskills`): `npm i -g openskills` -- universal skills loader

### 5.3 skills.sh Directory

[skills.sh](https://skills.sh/) is Vercel's directory and leaderboard for skill packages. Skills are listed with install counts and agent compatibility badges. Each skill has a page like `skills.sh/owner/repo/skill-name`.

### 5.4 Recommended Install Flow for Our Skill

```bash
# Option A: npx (recommended, handles all platforms)
npx skills add inchan/autoresearch

# Option B: Manual single-platform
git clone https://github.com/inchan/autoresearch /tmp/ar
cp -r /tmp/ar/skills/autoresearch ~/.claude/skills/autoresearch

# Option C: As Claude Code plugin (preserves colon subcommands)
claude plugin add inchan/autoresearch
```

**Confidence: HIGH**

---

## 6. Real-World Examples

### 6.1 anthropics/skills

- **Structure:** `skills/*/SKILL.md` flat layout, no commands directory
- **Skills-only:** Yes, pure skills repo
- **Cross-platform:** Yes, installs via `npx skills add anthropics/skills`
- **Notable:** Official Anthropic skills (skill-creator, docx, pdf, web-artifacts-builder, etc.)
- URL: https://github.com/anthropics/skills

### 6.2 vercel-labs/agent-skills

- **Structure:** `skills/*/SKILL.md` + `scripts/` subdirectories + `.zip` distribution files
- **Skills-only:** Yes, pure skills repo
- **Cross-platform:** Yes, explicitly tested on amp, claude-code, codex, cursor, gemini-cli, github-copilot, goose, opencode, windsurf, and more
- **Notable:** Demonstrates scripts/ bundling pattern
- URL: https://github.com/vercel-labs/agent-skills

### 6.3 hashicorp/agent-skills

- **Structure:** `skills/*/SKILL.md` with scripts and reference documents
- **Skills-only:** Yes
- **Cross-platform:** Yes, Claude Code + Codex + Gemini compatible
- URL: https://github.com/hashicorp/agent-skills

### 6.4 uditgoenka/autoresearch (closest competitor)

- **Structure:** `skills/autoresearch/SKILL.md` + `references/` + 8 slash commands
- **Architecture:** Claude Code plugin with commands AND skills
- **Cross-platform:** Partially -- skills are portable, commands are Claude Code only
- **Notable:** Uses the SAME pattern we do (thin command dispatchers + skill + references)
- URL: https://github.com/uditgoenka/autoresearch

### 6.5 shinpr/sub-agents-skills

- **Structure:** Skills-only, cross-platform sub-agent orchestration
- **Cross-platform:** Explicitly targets Claude Code, Codex, Cursor, Gemini
- URL: https://github.com/shinpr/sub-agents-skills

**Pattern:** All major skill distributors (Anthropic, Vercel, HashiCorp) use **skills-only repos** with zero commands. The commands layer is only used by autoresearch-style plugins that want the Claude Code colon UX.

**Confidence: HIGH**

---

## 7. Verdict: Skills-Only or Commands + Skills?

### The Core Tension

| Approach | Portability | UX on Claude Code | UX on Codex/Gemini |
|---|---|---|---|
| **Skills-only** (flat kebab names) | 16+ platforms | `/autoresearch-plan` (works but verbose) | Model-invoked (works) |
| **Plugin (commands + skills)** | Claude Code only for commands | `/autoresearch:plan` (clean colon UX) | Skills work, commands ignored |
| **Hybrid** (plugin for Claude Code, skills for cross-platform) | Best of both | `/autoresearch:plan` (clean) | Model-invoked via skills |

### Recommendation: Hybrid Architecture (Phase 1 -> Phase 2)

#### Phase 1: Restructure to Skills-First (NOW)

Convert the 6 subcommands to 6 standalone skills with kebab-case names:

```
skills/
  autoresearch/
    SKILL.md              # Main loop (primary skill)
    references/           # Shared references (loaded on-demand)
    scripts/              # Composite metric templates
  autoresearch-plan/
    SKILL.md              # Goal->config wizard
  autoresearch-debug/
    SKILL.md              # Scientific bug hunting
  autoresearch-fix/
    SKILL.md              # Iterative error repair
  autoresearch-security/
    SKILL.md              # STRIDE+OWASP audit
  autoresearch-ship/
    SKILL.md              # Release workflow
```

This immediately gives us:
- Cross-platform compatibility (16+ tools via `.agents/skills/`)
- `npx skills add inchan/autoresearch` works out of the box
- On Claude Code: `/autoresearch`, `/autoresearch-plan`, etc. via skill-as-command
- On Codex/Gemini: model-invoked by description matching

#### Phase 2: Keep Plugin Layer as Enhancement (OPTIONAL)

Retain `plugin.json` + thin command dispatchers for Claude Code users who want:
- The clean `/autoresearch:plan` colon syntax
- Tab completion with subcommand listing
- Plugin marketplace distribution

The commands would be 1-line dispatchers that invoke the corresponding skill:
```markdown
<!-- commands/autoresearch/plan.md -->
Load and execute the `autoresearch-plan` skill.
```

#### Phase 3: Watch Spec Issue #143

If the Agent Skills spec adopts colon-namespaced sub-skills, migrate to spec-native subcommands and drop the plugin command layer entirely.

### Why NOT Go Pure Skills-Only?

1. **UX regression on Claude Code:** `/autoresearch:plan` is meaningfully better than `/autoresearch-plan` for discoverability. The colon groups related commands in tab completion.
2. **Plugin marketplace:** Claude Code's plugin marketplace is a distribution channel. Skills-only repos can't be installed via `claude plugin add`.
3. **Hooks and settings:** Plugins can include `.claude/settings.json` and hooks; skills cannot.

### Why NOT Keep Current Commands-Heavy Approach?

1. **Zero portability:** Commands are Claude Code-only. We miss Codex, Gemini, Cursor, Copilot, and 10+ other tools.
2. **Ecosystem momentum:** All major players (Anthropic, Vercel, HashiCorp, Stripe) distribute skills-only. Commands are legacy.
3. **The spec won't wait:** Issue #143 will likely add native subcommand support, making our command layer redundant.

### Summary

| Decision | Recommendation |
|---|---|
| Primary distribution format | **Skills** (6 standalone SKILL.md directories) |
| Cross-platform path | `.agents/skills/` (universal) |
| Installer | `npx skills add inchan/autoresearch` |
| Claude Code enhancement | Keep plugin.json + thin command dispatchers for colon UX |
| Shared references | Keep in `autoresearch/references/`, have sub-skills reference via relative path `../autoresearch/references/` |
| Drop commands entirely? | **Not yet.** Wait for spec issue #143 to land, then drop. |

---

## Sources

### Specifications & Docs
- [Agent Skills Specification](https://agentskills.io/specification)
- [Anthropic Agent Skills Spec (GitHub)](https://github.com/anthropics/skills/blob/main/spec/agent-skills-spec.md)
- [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)
- [Claude API: Agent Skills Overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Claude API: Skill Authoring Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Codex CLI: Agent Skills](https://developers.openai.com/codex/skills)
- [Gemini CLI: Agent Skills](https://geminicli.com/docs/cli/skills/)
- [Gemini CLI: Creating Skills](https://geminicli.com/docs/cli/creating-skills/)
- [VS Code: Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)

### Tools & Installers
- [vercel-labs/skills (npx skills CLI)](https://github.com/vercel-labs/skills)
- [skills.sh Directory](https://skills.sh/)
- [npm: skills package](https://www.npmjs.com/package/skills)
- [Vercel KB: Agent Skills Guide](https://vercel.com/kb/guide/agent-skills-creating-installing-and-sharing-reusable-agent-context)

### Repositories Studied
- [anthropics/skills](https://github.com/anthropics/skills)
- [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills)
- [hashicorp/agent-skills](https://github.com/hashicorp/agent-skills)
- [uditgoenka/autoresearch](https://github.com/uditgoenka/autoresearch)
- [shinpr/sub-agents-skills](https://github.com/shinpr/sub-agents-skills)
- [FrancyJGLisboa/agent-skill-creator](https://github.com/FrancyJGLisboa/agent-skill-creator)
- [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills)

### Issues & Proposals
- [agentskills/agentskills#143: Nested skills via directory grouping](https://github.com/agentskills/agentskills/issues/143)
- [anthropics/claude-code#16438: Nested directory structure for skills](https://github.com/anthropics/claude-code/issues/16438)
- [anthropics/claude-code#15944: Cross-plugin skill references](https://github.com/anthropics/claude-code/issues/15944)
- [openai/codex#15167: Skill-style slash commands rejected](https://github.com/openai/codex/issues/15167)

### Articles & Analysis
- [Agent Skills Standard for Smarter AI (Medium)](https://nayakpplaban.medium.com/agent-skills-standard-for-smarter-ai-bde76ea61c13)
- [Claude Code Merges Slash Commands Into Skills (Medium)](https://medium.com/@joe.njenga/claude-code-merges-slash-commands-into-skills-dont-miss-your-update-8296f3989697)
- [Skills vs Commands: Developer's Guide (rewire.it)](https://rewire.it/blog/claude-code-agents-skills-slash-commands/)
- [Agent Skills vs Rules vs Commands (builder.io)](https://www.builder.io/blog/agent-skills-rules-commands)
- [Agent Skills Guide 2026 (Serenities AI)](https://serenitiesai.com/articles/agent-skills-guide-2026)
- [Anthropic Opens Agent Skills Standard (Unite.AI)](https://www.unite.ai/anthropic-opens-agent-skills-standard-continuing-its-pattern-of-building-industry-infrastructure/)
- [Skills Made Easy with Antigravity and Gemini CLI (Google Cloud)](https://medium.com/google-cloud/skills-made-easy-with-google-antigravity-and-gemini-cli-5435139b0af8)

---

## 8. Deployment Verification (2026-03-24)

### 실제 테스트 결과

**환경:**
- npx skills v1.4.6
- codex-cli v0.116.0
- gemini-cli v0.34.0
- macOS Darwin 22.6.0

### 8.1 `npx skills add inchan/autoresearch -y`

**결과: SUCCESS**

```
Found 1 skill: autoresearch
43 agents detected
Installing to: Antigravity, Claude Code, OpenClaw, Codex, Gemini CLI, GitHub Copilot, Kimi Code CLI, OpenCode
```

설치된 구조:
```
/tmp/test-skills-install/
├── .agents/skills/autoresearch/          ← 유니버설 원본 (Codex, Gemini 등 11개 에이전트)
│   ├── SKILL.md                          ← 18,124 bytes, 원본 그대로
│   └── references/                       ← 12개 프로토콜 문서 전부 복사됨
│       ├── autonomous-loop-protocol.md
│       ├── core-principles.md
│       ├── debug-workflow.md
│       ├── fix-workflow.md
│       ├── lessons-protocol.md
│       ├── metric-design.md
│       ├── pivot-protocol.md
│       ├── plan-workflow.md
│       ├── results-logging.md
│       ├── security-workflow.md
│       ├── session-resume.md
│       └── ship-workflow.md
├── .claude/skills/autoresearch           ← symlink → ../../.agents/skills/autoresearch
└── skills-lock.json                      ← {"autoresearch": {"source": "inchan/autoresearch"}}
```

### 8.2 검증된 사실

| 항목 | 결과 |
|------|------|
| SKILL.md frontmatter 호환 | `name` + `description` 필드로 자동 발견됨 |
| references/ 하위 디렉토리 보존 | 12개 파일 전부 복사됨 |
| Claude Code symlink | `.claude/skills/` → `.agents/skills/` symlink 자동 생성 |
| skills-lock.json | 버전 추적 + hash 기록됨 |
| 에이전트 자동 감지 | 43개 에이전트 중 설치된 CLI 기반으로 자동 선택 |

### 8.3 미포함 항목

| 항목 | 원인 | 해결 |
|------|------|------|
| `scripts/metric-*.sh` | `skills/autoresearch/` 밖에 위치 | `skills/autoresearch/scripts/`로 이동 필요 |
| `commands/*.md` | 스킬이 아닌 Claude Code 플러그인 커맨드 | plugin 배포 시에만 필요, skills 배포에서는 불필요 |
| `.claude-plugin/plugin.json` | 플러그인 매니페스트 | Claude Code 플러그인 배포 경로에서만 필요 |

### 8.4 결론

**현재 리포 구조 그대로 `npx skills add`가 동작한다.** 수정 없이 16+ 플랫폼에 배포 가능.
스킬 기반 배포가 v1.1의 핵심 전략으로 확정됨.
