# Pitfalls Research

**Domain:** Multi-platform CLI agent skill adaptation (Claude Code -> Codex CLI + Gemini CLI)
**Researched:** 2026-03-24
**Confidence:** HIGH (platform docs + community issues + active ecosystem evidence)

---

## Critical Pitfalls

### Pitfall 1: Autonomous Loop Non-Compliance — Codex Stops When Told to Continue

**What goes wrong:**
Codex CLI ignores "NEVER stop" / "loop until interrupted" instructions. The current `SKILL.md` and `autonomous-loop-protocol.md` rely on the model obeying `# NEVER ask "should I continue?"` as a hard constraint. On Codex, this instruction is treated as a suggestion — Codex terminates upon task completion regardless. The core autoresearch loop becomes single-shot.

**Why it happens:**
Claude has deep session continuity training and a native `/loop` command. Codex's sandbox + approval policy model is architecturally oriented toward discrete task completion with human confirmation gates, not unbounded autonomous execution.

Evidence: karpathy/autoresearch issue #57 — "Codex ignores instruction to never stop, unlike Claude."

**How to avoid:**
- Do not rely on prompt instruction alone for loop continuation on Codex
- The Codex adapter must use an external loop mechanism: either a shell `while true` wrapper that re-invokes Codex per iteration, or the officially-planned Codex lifecycle hooks
- Design the state file (`autoresearch-state.json`) so it survives session termination — each invocation reads state and continues from where it left off
- Accept that on Codex, "autonomous" means "re-invokable" not "infinite single session"

**Warning signs:**
- Codex completes setup phase, runs one iteration, then prints a summary and exits
- No error — the model simply finishes

**Phase to address:**
Core extraction phase — the loop protocol must be split into "session-local loop" (Claude) and "invocation-resume loop" (Codex). This is a design decision, not a configuration tweak.

---

### Pitfall 2: `${CLAUDE_PLUGIN_ROOT}` Variable Is Undefined on Non-Claude Platforms

**What goes wrong:**
Every command file uses `${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/...` for file references. On Codex CLI and Gemini CLI this variable does not exist. The skill files either fail to load or the agent interprets the literal string as a path, producing silent context omission — the agent runs without the protocol documents it depends on.

**Why it happens:**
`${CLAUDE_PLUGIN_ROOT}` is a Claude Code-specific substitution injected by the plugin runtime. It is not a shell variable, not an environment variable — it only works inside Claude Code's command dispatcher. Codex has no equivalent. Gemini CLI uses `${extensionPath}` in `gemini-extension.json` but does NOT substitute it inside markdown content.

**How to avoid:**
- For Codex: Skill files discover paths via `.agents/skills/` scan from cwd up to repo root. Use relative paths: `references/autonomous-loop-protocol.md` (relative to SKILL.md location)
- For Gemini: GEMINI.md supports `@./references/autonomous-loop-protocol.md` inline import syntax (relative to the GEMINI.md file)
- Core references/ files must be path-agnostic — no absolute paths, no platform variables
- Add a path resolution smoke test to the installer: verify at least one reference file can be reached from its command entry point on each platform

**Warning signs:**
- Agent produces correct behavior on first command but forgets the loop protocol
- Agent skips Phase 0 preconditions or uses simplified rollback
- Behavior matches SKILL.md but not the detailed `autonomous-loop-protocol.md` steps

**Phase to address:**
Core extraction phase — remove all `${CLAUDE_PLUGIN_ROOT}` references from shared files; make them platform-neutral before adapters are built.

---

### Pitfall 3: Gemini's Loop Anti-Repetition Guard Terminates the Autoresearch Loop

**What goes wrong:**
Gemini CLI has a built-in loop detection heuristic that halts execution when it detects "repetitive tool calls or other model behavior." The autoresearch loop is intentionally repetitive — read scope files, run verify, commit, revert. Gemini interprets this pattern as a stuck loop and injects "A potential loop was detected. This can happen due to repetitive tool calls or other model behavior. The request has been halted."

Evidence: google-gemini/gemini-cli issue #8928 — reported on Gemini 2.5 flash; confirmed as active issue.

**Why it happens:**
Gemini's safety heuristic cannot distinguish between an unintentional infinite loop bug and an intentional iterative agent workflow. The autoresearch loop is structurally identical to what Gemini's guard is designed to catch.

**How to avoid:**
- The Gemini adapter must use `AfterAgent` hooks to intercept completion signals and re-inject context, resetting Gemini's repetition counter between iterations
- The `ralph` extension pattern (github.com/gemini-cli-extensions/ralph) is specifically designed to enable ralph loops in Gemini via AfterAgent hooks — use this pattern
- Vary the per-iteration context slightly: include iteration number, current metric, and hypothesis in each loop invocation to prevent exact-match repetition detection
- Do not attempt to run unbounded loops with Gemini without the hook mechanism in place

**Warning signs:**
- Loop terminates at iteration 3-7 with a loop detection message
- No error in the skill logic — Gemini's runtime killed it
- Happens more frequently with fast metrics (verify command completes quickly)

**Phase to address:**
Gemini adapter phase — this requires the AfterAgent hook integration, not just a prompt change.

---

### Pitfall 4: Codex Sandbox Blocks git commit by Default

**What goes wrong:**
Autoresearch's "Git as memory" pattern (Phase 4: Commit before Verify) relies on running `git commit` every iteration. Codex's `workspace-write` sandbox mode keeps `.git/` read-only in some environments even when the workspace is writable, requiring explicit approval for git operations. This breaks the autonomous loop's commit-before-verify guarantee.

Evidence: Codex sandbox docs — "commands like git commit may still require approval to run outside the sandbox."

**Why it happens:**
Codex's default `workspace-write` sandbox is designed for safe autonomous editing. Committing to git is treated as a higher-trust operation than editing files. The sandbox applies to all spawned commands including git.

**How to avoid:**
- The Codex adapter must explicitly configure `approval_policy` to allow git operations without prompting
- In `.codex/config.toml`, set `sandbox_mode = "workspace-write"` with an explicit allowlist for git commands
- Alternatively, document that Codex users must invoke with `--auto-edit` flag or set `full_auto` mode
- Test the commit phase explicitly during Codex integration testing — do not assume it works

**Warning signs:**
- Codex pauses on Phase 4 and prompts the user for approval
- Autonomous loop is interrupted mid-iteration
- `autoresearch-state.json` shows iteration committed but then stalls

**Phase to address:**
Codex adapter phase — add explicit sandbox config to the Codex installation instructions and adapter setup.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Copy-paste command files per platform with minor edits | Fast initial port | 6 files become 18; every fix requires 3x work | Never — use shared core + thin adapters |
| Single GEMINI.md with all protocol inline | No file references needed | Context window exhaustion on short sessions; 1M token limit helps but structure matters | Only for MVP proof-of-concept |
| Hardcode platform detection as `if [[ "$AGENT" == "codex" ]]` in installer | Simple logic | Breaks when new agents added; not extensible | Only if confident no 4th platform needed in 6 months |
| Use `--full-auto` / `danger-full-access` in docs to bypass sandbox issues | Works immediately | Security risk; users copy-paste without reading risk warning | Document risk explicitly, never default |
| Inherit existing SKILL.md structure unchanged for Codex | No refactor needed | `${CLAUDE_PLUGIN_ROOT}` silently breaks all file references | Never — fix before shipping |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Codex AGENTS.md | Treating it as a drop-in for CLAUDE.md | AGENTS.md is project context only; it does not dispatch commands. Slash commands live in `.agents/skills/`, not AGENTS.md |
| Gemini custom commands | Writing `.md` command files expecting same behavior as Claude | Gemini commands are `.toml` files with a `prompt` field; markdown is not parsed as a command |
| Gemini extension context | Expecting `${extensionPath}` to work in GEMINI.md content | `${extensionPath}` only works in `gemini-extension.json`; GEMINI.md uses `@./path` relative imports |
| Codex skill discovery | Placing skills in `skills/autoresearch/` (Claude path) | Codex scans `.agents/skills/` from cwd up to repo root; must place skills there |
| TSV state files across platforms | Sharing `autoresearch-results.tsv` between Claude and Codex runs | State file format is compatible, but each platform writes different run_tag prefixes — ensure parser handles both |
| git revert in Codex sandbox | Assuming revert works same as Claude | `git revert` is a write to `.git/` — same sandbox approval issue as commit; test explicitly |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading all 12 reference files on every Gemini CLI invocation | Slow startup; hits Gemini's context injection limit | Load references on-demand using GEMINI.md `@` imports gated by session state | From first Gemini invocation if all refs loaded |
| Codex re-reading full scope on every iteration (in re-invoke loop pattern) | N iterations = N full scope reads; slow | Store scope summary in state JSON; only re-read changed files | Noticeable at iteration 5+ on large codebases |
| Gemini's 1M context misused as "load everything" | SKILL.md + 12 refs + full scope = huge prompt on every turn | Large context != no cost; Gemini still has per-turn processing cost | When composite metric scripts are also large |
| Installer downloads fresh copy of skills on every run | Re-run installer = overwrites user edits | Check version hash before overwriting; prompt on conflict | Any re-run after user customization |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Installer asks "which platform?" but user has all three installed | Confusion — user expects auto-detection | Detect installed agents automatically (`which codex`, `ls ~/.gemini`) and confirm, don't ask from scratch |
| Multi-platform installer creates all three configs by default | Pollutes project with unused config files | Install only for detected platforms; offer `--all` flag for explicit opt-in |
| Breaking existing Claude Code user's `/autoresearch` command during restructure | Existing users suddenly broken | The core skills/ and commands/ paths must not change; adapters go into new directories |
| Codex adapter uses different command names (e.g., `autoresearch-loop` vs `/autoresearch`) | Mental model fragmentation across platforms | Keep command names identical; only directory structure changes |
| Version mismatch: user upgrades Claude plugin but not Codex adapter | Codex runs old protocol; state files may be incompatible | Embed version in state JSON; adapter checks compatibility on session resume |

---

## "Looks Done But Isn't" Checklist

- [ ] **Codex loop compliance:** Ran 10+ iterations without user intervention — verify the re-invoke mechanism works, not just one iteration
- [ ] **Gemini loop detection:** Ran 5+ iterations — verify loop detection guard did not terminate early
- [ ] **Path resolution:** Reference files actually load on each platform — verify by checking if agent follows Phase 0 preconditions (only present in `autonomous-loop-protocol.md`)
- [ ] **git commit in Codex sandbox:** Committed during Phase 4 without approval prompt in full-auto mode — verify with a real Codex run
- [ ] **Backward compatibility:** Existing Claude Code users ran `/autoresearch` after restructure — no broken file references
- [ ] **Installer idempotency:** Ran installer twice — second run detected existing installation, asked before overwriting
- [ ] **Platform detection:** Ran installer on machine with only one CLI installed — only installed for that platform
- [ ] **State file portability:** Started run on Claude, resumed on Codex — state JSON was read correctly

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Codex loop non-compliance shipped without fix | HIGH | Requires redesigning loop protocol split; impacts all 6 commands; state file schema may need version bump |
| `${CLAUDE_PLUGIN_ROOT}` silently broken on Codex/Gemini | MEDIUM | Grep all skill/reference files; replace with relative paths; re-test all 6 commands |
| Gemini loop detection termination | MEDIUM | Add AfterAgent hook; requires gemini-extension.json changes + new hook script |
| git sandbox blocks commit | LOW | Add explicit `approval_policy` config to Codex installer output |
| Installer overwrites user customizations | MEDIUM | Implement backup-before-overwrite; restore from backup; add conflict detection to installer |
| Breaking Claude Code users during restructure | HIGH | Maintain old paths as symlinks for one version; document migration in CHANGELOG |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Codex loop non-compliance | Core extraction — design re-invoke pattern | Run 10 Codex iterations unattended |
| `${CLAUDE_PLUGIN_ROOT}` undefined | Core extraction — remove all platform vars from shared files | Grep shared files for `CLAUDE_PLUGIN_ROOT`; zero results required |
| Gemini loop detection termination | Gemini adapter — AfterAgent hook integration | Run 8 Gemini iterations; no premature halt |
| Codex git sandbox blocking commit | Codex adapter — sandbox config in installer output | Run Phase 4 commit on Codex without approval prompt |
| Backward compatibility break | Core extraction — no changes to existing paths | Claude Code users: run all 6 commands after restructure; zero regressions |
| Installer overwrites user configs | Installer phase — conflict detection before write | Re-run installer on modified install; detect modification and prompt |
| Lowest-common-denominator protocol | Core extraction — keep Claude-specific features in Claude adapter | Codex adapter retains full protocol richness via re-invoke pattern |
| Abstraction layer over-engineering | Core extraction — shared core is prose, not code | Core protocol files are plain markdown; no template engine, no build step |

---

## Sources

- [karpathy/autoresearch issue #57: Codex doesn't work](https://github.com/karpathy/autoresearch/issues/57) — Confirmed Codex loop non-compliance
- [google-gemini/gemini-cli issue #8928: Loop detection halts](https://github.com/google-gemini/gemini-cli/issues/8928) — Confirmed Gemini loop guard
- [google-gemini/gemini-cli issue #15773: Gemini CLI stops loop](https://github.com/google-gemini/gemini-cli/issues/15773) — Additional loop stop evidence
- [Codex Sandboxing docs](https://developers.openai.com/codex/concepts/sandboxing) — git commit approval requirement
- [Gemini CLI Extensions docs](https://google-gemini.github.io/gemini-cli/docs/extensions/) — `${extensionPath}` scope limitation
- [Gemini CLI Custom Commands docs](https://geminicli.com/docs/cli/custom-commands/) — TOML format, not markdown
- [Claude Code vs Codex: Shared Core approach](https://github.com/shakacode/claude-code-commands-skills-agents/blob/main/docs/claude-code-with-codex.md) — Platform incompatibility analysis
- [Cross-platform convergence gaps](https://www.implicator.ai/claude-code-codex-and-gemini-cli-are-converging-the-gaps-matter-more/) — Configuration file incompatibility
- [gemini-cli-extensions/ralph](https://github.com/gemini-cli-extensions/ralph) — AfterAgent hook pattern for Gemini loops
- [Codex Agent Skills docs](https://developers.openai.com/codex/skills) — `.agents/skills/` path convention
- [Gemini GEMINI.md file importing](https://geminicli.com/docs/cli/gemini-md/) — `@./path` relative import syntax
- [LCD Abstraction pitfall](https://mohewedy.medium.com/lcd-least-common-denominator-abstractions-f86edeaeb4a9) — Over-abstraction consequences
- [Skills.sh Vercel agent skills ecosystem](https://vercel.com/kb/guide/agent-skills-creating-installing-and-sharing-reusable-agent-context) — Installer patterns

---
*Pitfalls research for: Multi-platform CLI agent skill adaptation (Claude Code + Codex CLI + Gemini CLI)*
*Researched: 2026-03-24*
