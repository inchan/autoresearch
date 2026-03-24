# Feature Research

**Domain:** Multi-agent CLI autoresearch skill (Claude Code + Codex CLI + Gemini CLI)
**Researched:** 2026-03-24
**Confidence:** HIGH (레퍼런스 구현 직접 확인, 공식 문서 검증)

---

## Reference Implementation 분석

### codex-autoresearch (leo-lilinxiao) — Codex CLI 포트

**설치 방식:** `.agents/skills/codex-autoresearch/` 에 디렉토리 복사 또는 `$skill-installer install <url>`

**커맨드 포맷:**
- 단일 진입점: `$codex-autoresearch` (자연어 입력)
- Claude Code처럼 슬래시 커맨드 파일이 아니라 `SKILL.md` 하나가 모든 모드를 라우팅
- 모드: `loop`, `plan`, `debug`, `fix`, `security`, `ship`, `exec` — Claude Code와 동일한 7가지

**차별점:**
- **Background mode** — `autoresearch_runtime_ctl.py launch`로 detached 런타임 실행. Codex CLI의 `codex exec --dangerously-bypass-approvals-and-sandbox`를 서브프로세스로 호출
- **Parallel worktrees** — `references/parallel-experiments-protocol.md` 에 정의. CPU ≥ 4코어, RAM ≥ 8GB일 때 자동 제안. 최대 3개 병렬 워커. GPU 수 기반 max_workers 계산
- **Environment probe** — Phase 0에서 CPU/GPU/RAM/디스크/툴체인 자동 감지 (`references/environment-awareness.md`)
- **exec mode** — CI/CD용 비대화형 모드. JSON 출력 전용. `codex exec` 로 호출. 환경변수 지원 (`AUTORESEARCH_GOAL` 등)
- **Python helper scripts** — `scripts/autoresearch_*.py` 20개 이상. 상태 관리, 런타임 제어, 병렬 실험 배치 선택 등을 스크립트로 처리 (Claude Code 버전은 에이전트가 직접 처리)
- **구조적 출력 명세** — `references/structured-output-spec.md` 별도 정의

**Claude Code 버전과의 공통점:**
- 동일한 8-phase 루프, PIVOT/REFINE 로직, lessons, session resume, TSV logging
- `references/` 문서 구조 동일 (파일명까지 거의 같음)
- 두 버전 모두 `SKILL.md` + `references/` 아키텍처 사용

**설치 경로:** `.agents/skills/[skill-name]/` (프로젝트), `~/.agents/skills/[skill-name]/` (유저)

---

### goal-md (jmilinovich) — Tool-agnostic GOAL.md 스펙

**핵심 개념:** 에이전트에게 플랫폼 무관 "fitness function"을 제공하는 단일 파일 포맷.

**GOAL.md 5가지 요소:**
1. **Fitness function** — `./scripts/score.sh` 처럼 숫자를 출력하는 실행 가능한 스크립트
2. **Improvement loop** — measure → diagnose → act → verify → keep or revert → log
3. **Action catalog** — 구체적 행동 목록 + 포인트 임팩트 추정치
4. **Operating mode** — Converge(목표 달성시 종료), Continuous(무한), Supervised(게이트 있음)
5. **Constraints** — 에이전트가 넘으면 안 되는 선

**활성화 방법:**
```
Read github.com/jmilinovich/goal-md — read the template and examples.
Then write me a GOAL.md for this repo and start working on it.
```
어떤 에이전트든 이 프롬프트 하나로 작동. 슬래시 커맨드나 `$skill-name` 없음.

**Dual-score 패턴:** 메트릭 자체가 불신뢰할 때 "측정 도구 품질" 점수를 별도로 추적. 에이전트가 자기 망원경을 먼저 고치게 함.

**주요 인사이트:** autoresearch-anything이 "어떤 메트릭을 쓸지" 질문했다면, goal-md는 "메트릭 자체를 어떻게 구성할지"를 가르치는 한 단계 위 추상화.

---

### autoresearch-anything (zkarimi22) — npx 셋업 위저드

**작동 방식:** `npx autoresearch-anything` → 인터랙티브 질문 → `setup.md` 생성

**질문 항목:**
- 프로젝트 설명 (한 문장)
- 에이전트가 수정할 파일 목록
- 메트릭 이름 + 방향 (up/down)
- eval 커맨드 + 출력 패턴 파싱
- 보조 메트릭 (cost 등)
- 실험당 최대 시간
- 컨텍스트 파일 / 수정 불가 파일
- 추가 제약

**출력:** `setup.md` + `eval.js` 스타터 템플릿

**한계:** 생성된 `setup.md`는 Claude Code, Codex 등 어느 에이전트에든 붙여넣기 가능하지만, 각 플랫폼의 슬래시 커맨드나 스킬 포맷은 활용하지 않음. 가장 낮은 공통 분모 방식.

---

## Gemini CLI 커맨드 포맷 (공식 문서 확인)

**커맨드 파일:** `.gemini/commands/*.toml` (프로젝트) / `~/.gemini/commands/*.toml` (글로벌)

**TOML 포맷:**
```toml
description = "One-line description for /help menu"
prompt = """
Multi-line instruction text here.
{{args}} is replaced with user input.
!{git diff --staged} for shell execution (requires confirmation).
@{path/to/file} for file injection.
"""
```

**네임스페이싱:** `git/commit.toml` → `/git:commit`

**GEMINI.md:** 에이전트 지시 파일 (CLAUDE.md 상당). `~/.gemini/GEMINI.md` (글로벌) + 프로젝트 계층 로딩. 커맨드 파일과 분리된 개념.

**핵심 차이:** Gemini CLI는 커맨드가 TOML 포맷. `.md` 파일이 아님. `$skill-name` 없음. `/command-name` 슬래시 호출.

---

## Codex CLI 스킬 포맷 (공식 문서 확인)

**설치 경로:**
- `.agents/skills/[name]/` (프로젝트)
- `~/.agents/skills/[name]/` (유저 글로벌)
- `/etc/codex/skills/` (시스템)

**SKILL.md 프론트매터:**
```yaml
---
name: skill-name
description: "When to invoke and when NOT to invoke"
---
```

**호출:** `$skill-name` 명시적 호출 또는 description 기반 암묵적 자동 선택

**선택적 메타데이터:** `agents/openai.yaml` — display_name, icon, allow_implicit_invocation, MCP 의존성

---

## Vercel install.sh 패턴 (web-interface-guidelines)

**자동 감지 방식:** 디렉토리 존재 여부 또는 커맨드 존재 여부로 플랫폼 감지. 인터랙션 없음.

**지원 플랫폼:**
- Amp Code → `~/.config/amp/commands/`
- Claude Code → `~/.claude/commands/`
- Cursor → `~/.cursor/commands/`
- OpenCode → `~/.config/opencode/commands/`
- Windsurf → `~/.codeium/windsurf/memories/global_rules.md` (append)
- Gemini CLI → `~/.gemini/commands/` (TOML 변환 필요)

**설계 원칙:** 사용자에게 질문하지 않음. 감지된 모든 플랫폼에 동시 설치. 실패해도 다른 플랫폼은 계속.

---

## Feature Landscape

### Table Stakes (사용자가 당연히 기대하는 것들)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Codex CLI 어댑터 — `$autoresearch` 단일 진입점 | codex-autoresearch(635★)가 이미 검증된 패턴 제시. 사용자가 Codex에서 동일한 `$autoresearch` 호출을 기대 | MEDIUM | `.agents/skills/autoresearch/SKILL.md` 생성. 기존 `skills/autoresearch/SKILL.md` 콘텐츠를 Codex 포맷으로 래핑 |
| Gemini CLI 어댑터 — `/autoresearch` 커맨드 | Gemini CLI가 TOML 포맷으로 커맨드를 요구. `.gemini/commands/autoresearch.toml` 없으면 작동 안 함 | MEDIUM | TOML `prompt` 필드에 skill 지시를 임베드. 서브커맨드는 `.gemini/commands/autoresearch/plan.toml` 등으로 네임스페이스 |
| Claude Code breaking change 없음 | 기존 `commands/` + `skills/` 구조 유지가 제약으로 명시됨 | LOW | 어댑터만 추가, 기존 파일 수정 최소화 |
| 공통 코어 추출 — 플랫폼 무관 프로토콜 | 3개 플랫폼이 동일 루프 로직을 공유해야 유지보수 가능. 코어 수정이 모든 플랫폼에 반영 | MEDIUM | `skills/autoresearch/references/*.md` 를 공통 코어로 사용. 플랫폼별 진입점이 이를 참조 |
| curl 원라이너 설치 | autoresearch-anything(npx)과 Vercel skills.sh가 검증한 UX. 사용자가 복사-붙여넣기 1회로 설치 기대 | MEDIUM | `install.sh` — 플랫폼 자동 감지 + 인터랙티브 선택 |
| 6개 서브커맨드 전부 지원 (plan/debug/fix/security/ship) | codex-autoresearch가 동일한 7개 모드 지원. 부분 지원은 사용자 혼란 야기 | MEDIUM | 플랫폼별로 각 서브커맨드 파일 생성 필요 |

### Differentiators (경쟁 우위)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Background mode (Codex 전용) | Codex는 `codex exec --dangerously-bypass-approvals-and-sandbox`로 detached 실행 가능. 오버나이트 무인 실행 | HIGH | Python helper scripts 필요 (`autoresearch_runtime_ctl.py` 등). Claude Code/Gemini에는 해당 메커니즘 없음 |
| Parallel worktrees (Codex 전용) | CPU 4코어+ 환경에서 병렬 가설 검증. codex-autoresearch에서 검증된 패턴 | HIGH | git worktree + subagent 아키텍처. Claude Code/Gemini에는 적용 어려움 |
| exec mode — CI/CD 비대화형 | `AUTORESEARCH_GOAL=... codex exec ...` 환경변수 기반 완전 자동화. JSON 출력 | MEDIUM | Codex CLI에만 `codex exec` API 존재. 환경변수 + JSON 출력 명세 필요 |
| GOAL.md 생성기 (`/autoresearch:plan` 확장) | goal-md 패턴 — 에이전트가 프로젝트를 스캔해서 fitness function 포함 GOAL.md를 생성. 단일 파일로 플랫폼 무관 재사용 | MEDIUM | 기존 `plan-workflow.md`를 확장해서 GOAL.md 출력 포맷 지원. 즉각적 차별화 |
| 플랫폼 자동 감지 설치 | Vercel install.sh 방식 — 설치된 에이전트를 자동 감지해서 모두에 동시 설치. 사용자가 플랫폼을 몰라도 됨 | LOW | `command -v gemini`, `test -d ~/.claude` 등으로 감지. 감지된 모든 플랫폼에 설치 |
| 인터랙티브 플랫폼 선택 설치 | 자동 감지 실패 시 또는 선택적 설치 원할 때 메뉴 제공 | LOW | autoresearch-anything의 질문 방식 + Vercel의 자동 감지를 조합 |

### Anti-Features (요청되지만 피해야 할 것들)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| MCP 서버 방식 | "더 강력한 통합" | 오버엔지니어링. MCP 서버는 별도 프로세스, 인증, 설정 복잡도 추가. PROJECT.md에서 명시적으로 Out of Scope | CLI 플러그인/커맨드 방식으로 충분. 이미 작동하는 패턴 |
| 실시간 크로스 플랫폼 상태 동기화 | "어디서든 같은 실험 이어받기" | autoresearch-state.json은 gitignored 로컬 파일. 플랫폼 간 동기화는 파일 충돌, 잠금, 복잡도 야기 | 단일 플랫폼에서 한 번에 하나의 실험. 세션 재개는 동일 플랫폼 내에서만 |
| 독립 웹 대시보드 | "결과 시각화" | GUI는 이 프로젝트 범위 밖. 별도 호스팅 필요. PROJECT.md에서 명시적으로 Out of Scope | 기존 TSV 로깅 + git log로 충분. 필요하면 사용자가 직접 시각화 |
| 플랫폼 통합 CLI 래퍼 (cc-switch-cli 스타일) | "한 번에 모든 플랫폼 관리" | cc-switch는 별도 바이너리 의존성. 이 프로젝트는 순수 마크다운/스크립트 스킬 | 각 플랫폼 네이티브 설치. curl 인스톨러로 충분 |
| Python helper scripts 포팅 (codex-autoresearch 방식) | "더 정교한 상태 관리" | codex-autoresearch의 20+ Python 스크립트는 Codex 전용 background mode 때문. Claude Code/Gemini에는 불필요한 의존성 | 에이전트가 직접 처리하는 현재 방식 유지. Python은 background mode에만 선택적 추가 |
| `npx autoresearch-anything` 스타일 setup wizard | "쉬운 온보딩" | `/autoresearch:plan` 이 이미 동일 기능 제공. 별도 npm 패키지는 유지보수 부담 | 기존 plan 커맨드를 GOAL.md 출력 지원으로 확장 |

---

## Feature Dependencies

```
[공통 코어 추출]
    └──required-by──> [Codex 어댑터]
    └──required-by──> [Gemini 어댑터]
    └──required-by──> [플랫폼 무관 GOAL.md 생성]

[Codex 어댑터 (기본)]
    └──enables──> [Background mode]
    └──enables──> [Parallel worktrees]
    └──enables──> [exec mode / CI-CD]

[Gemini 어댑터]
    └──requires──> [TOML 커맨드 파일 생성]

[curl 인스톨러]
    └──requires──> [Codex 어댑터 완성]
    └──requires──> [Gemini 어댑터 완성]
    └──requires──> [Claude Code 기존 구조 유지]

[Background mode]
    └──requires──> [Python helper scripts (autoresearch_runtime_ctl.py 등)]
    └──conflicts──> [Gemini CLI] (Gemini에 detached exec 메커니즘 없음)

[Parallel worktrees]
    └──requires──> [Background mode OR foreground subagent API]
    └──requires──> [환경 감지 프로브]
```

### Dependency Notes

- **공통 코어 → 어댑터:** `skills/autoresearch/references/*.md` 가 이미 공통 코어 역할. 어댑터는 이를 참조만 하면 됨. 실질적 추출 비용 낮음
- **Codex 어댑터 → Background mode:** Background는 Codex의 `codex exec` API 존재에 의존. Claude Code/Gemini에는 동일 메커니즘 없어 Codex 전용 기능
- **Parallel worktrees → Background mode:** 병렬 실험은 독립 Codex 세션을 spawning하는 방식. 단순 foreground에서는 구현 어려움
- **curl 인스톨러 → 어댑터 완성:** 설치할 대상(어댑터 파일들)이 먼저 존재해야 인스톨러가 의미 있음

---

## MVP Definition

### Launch With (v1.1)

이 마일스톤에서 반드시 포함해야 하는 것들.

- [ ] **공통 코어 정리** — 플랫폼 전용 참조(`${CLAUDE_PLUGIN_ROOT}` 등) 제거 또는 추상화. 기존 `skills/autoresearch/` 를 공통 코어로 확정
- [ ] **Codex CLI 어댑터** — `.agents/skills/autoresearch/SKILL.md` 생성. 6개 모드 전부 (`loop`/`plan`/`debug`/`fix`/`security`/`ship`). 공통 코어 references 참조
- [ ] **Gemini CLI 어댑터** — `.gemini/commands/autoresearch.toml` + `autoresearch/plan.toml` 등 6개 서브커맨드. TOML prompt 필드에 지시 임베드
- [ ] **curl 인스톨러 `install.sh`** — 플랫폼 자동 감지 (Claude Code/Codex/Gemini). 감지 실패시 인터랙티브 메뉴. 각 플랫폼 설치 경로에 파일 복사

### Add After Validation (v1.1.x)

코어가 작동하면 추가할 것들.

- [ ] **exec mode** — Codex CLI 전용. CI/CD 비대화형. 환경변수 기반 설정 + JSON 출력. codex-autoresearch의 `exec-workflow.md` 참조
- [ ] **GOAL.md 생성기** — `/autoresearch:plan` 서브커맨드 확장. 프로젝트 스캔 후 goal-md 포맷으로 GOAL.md 출력. 3개 플랫폼 모두에서 작동

### Future Consideration (v2+)

검증 후 검토.

- [ ] **Background mode (Codex 전용)** — `autoresearch_runtime_ctl.py` 기반 detached 실행. Python 의존성 추가. 가치는 높지만 복잡도도 높음
- [ ] **Parallel worktrees (Codex 전용)** — Background mode 구현 후에만 의미 있음. 환경 감지 + 워커 조율 프로토콜 필요

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| 공통 코어 추출 | MEDIUM | LOW | P1 |
| Codex CLI 어댑터 (6개 모드) | HIGH | MEDIUM | P1 |
| Gemini CLI 어댑터 (6개 모드) | HIGH | MEDIUM | P1 |
| curl 인스톨러 | HIGH | LOW | P1 |
| Claude Code breaking change 없음 | HIGH | LOW | P1 |
| exec mode (CI/CD) | MEDIUM | MEDIUM | P2 |
| GOAL.md 생성기 | MEDIUM | MEDIUM | P2 |
| Background mode (Codex) | HIGH | HIGH | P3 |
| Parallel worktrees (Codex) | HIGH | HIGH | P3 |
| 환경 감지 프로브 | LOW | MEDIUM | P3 |

**Priority key:**
- P1: v1.1 필수
- P2: v1.1.x 검증 후
- P3: v2+ 검토

---

## Reference Implementation Feature Matrix

| Feature | claude-code (기존) | codex-autoresearch | goal-md | autoresearch-anything | 우리 v1.1 목표 |
|---------|-------------------|-------------------|---------|----------------------|--------------|
| 8-phase 루프 | yes | yes (동일) | 유사(5요소) | 유사(기본 loop) | 공통 코어 유지 |
| 슬래시/스킬 커맨드 | yes (6개) | yes (7개, exec 추가) | no (GOAL.md 파일) | no (setup.md 파일) | 각 플랫폼 네이티브 |
| Background mode | no | yes (detached runtime) | no | no | v2+ Codex 전용 |
| Parallel worktrees | no | yes (최대 3개) | no | no | v2+ Codex 전용 |
| exec/CI mode | no | yes (JSON 출력) | no | no | P2 Codex 전용 |
| 환경 감지 | no | yes (GPU/CPU/disk) | no | partial (eval cmd) | P3 |
| 설치 curl 원라이너 | partial (symlink) | `$skill-installer` | no | `npx` | P1 |
| 플랫폼 자동 감지 | no | no | no | no | P1 (신규) |
| GOAL.md 출력 | no | no | yes (spec) | no | P2 (plan 확장) |
| 단일 파일 포맷 | no | no | yes (GOAL.md) | yes (setup.md) | 지원 안 함 (범위 외) |

---

## Sources

- [leo-lilinxiao/codex-autoresearch](https://github.com/leo-lilinxiao/codex-autoresearch) — SKILL.md, references/ 직접 확인 (HIGH confidence)
- [jmilinovich/goal-md](https://github.com/jmilinovich/goal-md) — README, GOAL.md, CLAUDE.md 직접 확인 (HIGH confidence)
- [zkarimi22/autoresearch-anything](https://github.com/zkarimi22/autoresearch-anything) — README, init.js 직접 확인 (HIGH confidence)
- [Codex Agent Skills 공식 문서](https://developers.openai.com/codex/skills) — 설치 경로, SKILL.md 포맷, 호출 방식 (HIGH confidence)
- [Gemini CLI Custom Commands 공식 문서](https://geminicli.com/docs/cli/custom-commands/) — TOML 포맷, 설치 경로, 네임스페이싱 (HIGH confidence)
- [Vercel web-interface-guidelines/install.sh](https://github.com/vercel-labs/web-interface-guidelines/blob/main/install.sh) — 플랫폼 감지 + 자동 설치 패턴 (HIGH confidence)
- [Gemini CLI AGENTS.md 문서](https://developers.openai.com/codex/guides/agents-md) — AGENTS.md vs CLAUDE.md 차이 (HIGH confidence)

---
*Feature research for: autoresearch multi-agent CLI support (v1.1)*
*Researched: 2026-03-24*
