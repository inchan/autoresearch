# Stack Research

**Domain:** Multi-agent CLI skill distribution (Claude Code + Codex CLI + Gemini CLI)
**Researched:** 2026-03-24
**Confidence:** HIGH (official docs + agentskills.io spec verified)

---

## Context: What This Milestone Actually Needs

v1.0은 Claude Code 전용 `plugin.json + commands/*.md + skills/**` 구조.
v1.1 목표: 동일한 프로토콜 파일을 Codex CLI, Gemini CLI에서도 사용 가능하게.

**핵심 발견:** Agent Skills는 2025-12-18 Anthropic이 발표한 오픈 스탠다드이며, Claude Code / OpenAI Codex / Gemini CLI / GitHub Copilot / VS Code 등 26개 이상 플랫폼이 채택함. `SKILL.md` 포맷이 공통 스펙. **기존 `skills/autoresearch/SKILL.md`는 이미 이 스탠다드를 따르고 있음.**

---

## Platform Discovery Mechanisms

### Claude Code (현재 v1.0)

| 항목 | 값 |
|------|-----|
| 커맨드 파일 위치 | `.claude/commands/*.md` (프로젝트) / `~/.claude/commands/*.md` (글로벌) |
| 스킬 위치 | `.claude/skills/<skill-name>/SKILL.md` (프로젝트) / `~/.claude/skills/` (글로벌) |
| 플러그인 매니페스트 | `plugin.json` (플러그인 루트) |
| 경로 변수 | `${CLAUDE_PLUGIN_ROOT}` — 플러그인 설치 디렉토리의 절대 경로 |
| 커맨드 파일 포맷 | YAML frontmatter (`description`, `argument-hint`) + Markdown 본문 |
| 서브커맨드 네이밍 | 파일명 → `/command`, 서브디렉토리 → `/command:subcommand` |
| 플레이스홀더 | `$ARGUMENTS`, `$1`-`$9`, 네임드 `$VARNAME` |

### OpenAI Codex CLI

| 항목 | 값 |
|------|-----|
| 컨텍스트 파일 (AGENTS.md) | 프로젝트 루트 → CWD까지 순서대로 탐색, 디렉토리당 1개 |
| 탐색 우선순위 | `AGENTS.override.md` > `AGENTS.md` > `project_doc_fallback_filenames` |
| 글로벌 컨텍스트 | `~/.codex/AGENTS.md` |
| 스킬 위치 | `.agents/skills/<skill-name>/SKILL.md` (프로젝트) |
| 스킬 위치 (글로벌) | `~/.agents/skills/` 또는 `~/.codex/skills/` |
| 스킬 탐색 순서 | `.agents/skills` (CWD → repo 루트 순으로 walk up) → `~/.agents/skills` → `/etc/codex/skills` |
| 커스텀 커맨드 위치 | `~/.codex/prompts/*.md` (deprecated, skills로 대체 권장) |
| 커스텀 커맨드 포맷 | YAML frontmatter (`description`, `argument-hint`) + Markdown — **Claude Code와 동일** |
| 플레이스홀더 | `$ARGUMENTS`, `$1`-`$9`, 네임드 `$VARNAME` |
| 경로 변수 | `$CODEX_HOME` (기본 `~/.codex`), `CODEX_SQLITE_HOME` |
| **경로 변수 주의** | `${CLAUDE_PLUGIN_ROOT}` 해당 없음 — 스킬 본문에서 상대 경로 사용 |
| 설정 파일 | `~/.codex/config.toml`, `.codex/config.toml` (프로젝트) |

**Codex AGENTS.md 포맷:**
```markdown
## Working agreements
- 설명...
- 설명...

## Test conventions
- 설명...
```
순수 Markdown. 특수 변수 없음. 디렉토리마다 하나씩, 루트에서 CWD까지 누적 로드 (나중 파일이 앞 파일 override).

### Google Gemini CLI

| 항목 | 값 |
|------|-----|
| 컨텍스트 파일 (GEMINI.md) | `~/.gemini/GEMINI.md` (글로벌) → 워크스페이스 루트 → CWD (계층형) |
| import 구문 | `@./파일.md`, `@../shared/파일.md` (상대/절대 경로) |
| 스킬 위치 | `.agents/skills/<skill-name>/SKILL.md` (프로젝트) / `.gemini/skills/` (별칭) |
| 스킬 위치 (글로벌) | `~/.agents/skills/` / `~/.gemini/skills/` (별칭) |
| 스킬 우선순위 | `.agents/skills/` > `.gemini/skills/` (동일 티어 내) |
| 커스텀 커맨드 위치 | `.gemini/commands/*.toml` (프로젝트) / `~/.gemini/commands/*.toml` (글로벌) |
| 커스텀 커맨드 포맷 | **TOML** (Claude/Codex와 다름) |
| 커맨드 네이밍 | 파일명 → `/test`, 서브디렉토리 → `/git:commit` |
| 템플릿 변수 | `{{args}}` (인자), `!{shell cmd}` (쉘 실행), `@{path/to/dir}` (파일 내용 주입) |
| 경로 변수 | `GEMINI_CLI_HOME` (기본 `~/.gemini` 부모 디렉토리) |
| **경로 변수 주의** | `${CLAUDE_PLUGIN_ROOT}` 해당 없음 — 스킬 상대 경로 사용 |
| 설정 파일 | `~/.gemini/settings.json` |

**Gemini 커스텀 커맨드 TOML 포맷:**
```toml
description = "한 줄 설명 (도움말에 표시)"
prompt = """
{{args}}를 받아서 처리하는 지시사항.
!{git log --oneline -5}
"""
```

---

## Agent Skills 오픈 스탠다드 (핵심)

> **출처:** https://agentskills.io/specification (HIGH confidence — 공식 스펙)

### SKILL.md 공식 스펙

```markdown
---
name: skill-name          # 필수. 소문자+하이픈, 64자 이내. 디렉토리명과 일치
description: "..."        # 필수. 1024자 이내. 언제 쓰는지 포함
license: MIT              # 선택
compatibility: "..."      # 선택. 환경 요구사항
metadata:                 # 선택. 임의 key-value
  author: inchan
  version: "1.1.0"
allowed-tools: Bash Read  # 선택 (실험적)
---

# 스킬 본문 (Markdown, 제한 없음)
500줄 이내 권장. 긴 내용은 references/ 분리.
```

### 공통 디렉토리 구조

```
skill-name/
├── SKILL.md          # 필수
├── scripts/          # 선택 — 실행 스크립트
├── references/       # 선택 — 상세 문서 (on-demand 로드)
└── assets/           # 선택 — 템플릿/정적 파일
```

**기존 `skills/autoresearch/` 구조는 이 스펙에 이미 부합함.**

### Progressive Disclosure 패턴

| 단계 | 로드 내용 | 토큰 |
|------|-----------|------|
| 스타트업 | `name` + `description` frontmatter만 | ~100 |
| 스킬 활성화 | `SKILL.md` 전체 본문 | <5000 권장 |
| on-demand | `references/`, `scripts/`, `assets/` | 필요시 |

---

## 플랫폼별 경로 변수 비교

| 플랫폼 | 스킬 경로 변수 | 사용법 |
|--------|--------------|--------|
| Claude Code | `${CLAUDE_PLUGIN_ROOT}` | 커맨드 .md에서 skill 파일 참조 시 |
| Codex CLI | 없음 | 스킬은 `.agents/skills/` 기준 상대경로 |
| Gemini CLI | 없음 | 스킬은 `.agents/skills/` 기준 상대경로 |

**결론:** `${CLAUDE_PLUGIN_ROOT}`를 사용하는 `commands/*.md`는 Claude Code 전용. Codex/Gemini용 어댑터 파일에서는 이 변수를 제거하고 상대 경로 또는 Agent Skills 스펙의 파일 참조 방식을 써야 함.

---

## 설치 배포: npx skills (Vercel skills.sh 계승)

> **출처:** https://github.com/vercel-labs/skills + https://vercel.com/kb/guide/agent-skills-creating-installing-and-sharing-reusable-agent-context

```bash
# 기본 설치
npx skills add <owner/repo>
npx skills add inchan/autoresearch

# 특정 스킬만
npx skills add inchan/autoresearch --skill autoresearch

# 글로벌 설치 (모든 프로젝트에서 사용)
npx skills add -g inchan/autoresearch

# 에이전트 타겟 지정
npx skills add inchan/autoresearch -a claude
npx skills add inchan/autoresearch -a codex
npx skills add inchan/autoresearch -a gemini

# 모든 에이전트
npx skills add inchan/autoresearch --all

# CI-friendly
npx skills add inchan/autoresearch -y
```

**플랫폼별 설치 경로 (npx skills 자동 처리):**
| 플랫폼 | 프로젝트 | 글로벌 |
|--------|---------|--------|
| Claude Code | `.claude/skills/autoresearch/` | `~/.claude/skills/autoresearch/` |
| Codex CLI | `.agents/skills/autoresearch/` | `~/.agents/skills/autoresearch/` |
| Gemini CLI | `.agents/skills/autoresearch/` | `~/.gemini/skills/autoresearch/` |

**curl 원라이너 (npm 없는 환경 대비):**
```bash
curl -sSL https://skills.sh/install | bash -s -- inchan/autoresearch
```

---

## 권장 파일 구조 변경 (v1.0 → v1.1)

### 추가해야 할 것

```
skills/autoresearch/SKILL.md       # frontmatter에 name, description 추가/정규화
  → name: autoresearch
  → metadata.version: "1.1.0"

# Codex CLI 어댑터 (커맨드 파일 — ${CLAUDE_PLUGIN_ROOT} 제거 버전)
.agents/commands/autoresearch.md
.agents/commands/autoresearch/plan.md
.agents/commands/autoresearch/debug.md
.agents/commands/autoresearch/fix.md
.agents/commands/autoresearch/security.md
.agents/commands/autoresearch/ship.md

# Gemini CLI 어댑터 (TOML 커맨드)
.gemini/commands/autoresearch.toml
.gemini/commands/autoresearch/plan.toml
... (각 커맨드를 TOML로 변환)

# Gemini 컨텍스트
GEMINI.md   또는   .gemini/GEMINI.md
```

### 유지할 것 (Claude Code 기존 구조 — breaking change 없음)

```
.claude-plugin/plugin.json
.claude/settings.json
commands/autoresearch.md
commands/autoresearch/*.md
skills/autoresearch/SKILL.md
skills/autoresearch/references/
scripts/
```

### 공통 코어 (수정 불필요 — 플랫폼 무관)

```
skills/autoresearch/SKILL.md        # 스킬 본문 — 이미 에이전트 무관
skills/autoresearch/references/*.md # 프로토콜 문서 — 이미 에이전트 무관
scripts/*.sh                        # 메트릭 스크립트 — 이미 플랫폼 무관
```

---

## 추가하지 말 것 (과잉 추상화 방지)

| 항목 | 이유 |
|------|------|
| MCP 서버 | 이미 Out of Scope로 결정됨. CLI 플러그인으로 충분 |
| 단일 빌드 파이프라인 | 파일 수가 적어 빌드 불필요. 수동 심링크/복사 충분 |
| 템플릿 엔진 | 플랫폼마다 변수 포맷이 다름. 어댑터 파일 직접 작성이 더 명확 |
| `agents/openai.yaml` | Codex의 선택적 UI 메타데이터. v1.1에서는 불필요 |
| AGENTS.override.md | 프로젝트별 override — 사용자 영역, 우리가 배포 X |

---

## Alternatives Considered

| 우리 선택 | 대안 | 대안이 나은 경우 |
|---------|------|----------------|
| SKILL.md 공통 + 플랫폼별 커맨드 어댑터 | 단일 공통 커맨드 파일 | 플랫폼 간 커맨드 포맷이 완전히 동일할 때 (현재는 Gemini만 TOML로 다름) |
| `.agents/skills/` 심링크/복사 | npm 패키지 배포 | npm 의존성을 원하는 사용자 |
| npx skills 사용 | curl 직접 구현 | npx를 피하고 싶은 환경 (curl fallback 제공) |
| 모노리포 | 플랫폼별 별도 리포 | 각 플랫폼 커뮤니티 단독 배포를 원할 때 |

---

## Sources

- [agentskills.io/specification](https://agentskills.io/specification) — SKILL.md 공식 스펙 (HIGH)
- [developers.openai.com/codex/skills](https://developers.openai.com/codex/skills) — Codex 스킬 탐색 경로, frontmatter (HIGH)
- [developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md) — AGENTS.md 탐색 규칙 (HIGH)
- [developers.openai.com/codex/custom-prompts](https://developers.openai.com/codex/custom-prompts) — Codex 커스텀 프롬프트 포맷 (deprecated) (HIGH)
- [google-gemini.github.io/gemini-cli/docs/cli/custom-commands.html](https://google-gemini.github.io/gemini-cli/docs/cli/custom-commands.html) — Gemini TOML 커맨드 포맷 (HIGH)
- [google-gemini.github.io/gemini-cli/docs/cli/gemini-md.html](https://google-gemini.github.io/gemini-cli/docs/cli/gemini-md.html) — GEMINI.md 계층 탐색 규칙 (HIGH)
- [geminicli.com/docs/cli/skills/](https://geminicli.com/docs/cli/skills/) — Gemini 스킬 탐색 경로 (HIGH)
- [github.com/vercel-labs/skills](https://github.com/vercel-labs/skills) — npx skills 설치 툴, 에이전트별 경로 (HIGH)
- [vercel.com/kb/guide/agent-skills-creating-installing-and-sharing-reusable-agent-context](https://vercel.com/kb/guide/agent-skills-creating-installing-and-sharing-reusable-agent-context) — 설치 플래그 레퍼런스 (HIGH)

---

*Stack research for: autoresearch v1.1 multi-agent support*
*Researched: 2026-03-24*
