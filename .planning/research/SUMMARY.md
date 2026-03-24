# Project Research Summary

**Project:** autoresearch v1.1 — Multi-agent CLI skill (Claude Code + Codex CLI + Gemini CLI)
**Domain:** CLI agent skill distribution and multi-platform adapter pattern
**Researched:** 2026-03-24
**Confidence:** HIGH

## Executive Summary

autoresearch v1.1의 목표는 기존 Claude Code 전용 플러그인을 Codex CLI와 Gemini CLI에서도 동작하게 확장하는 것이다. 핵심 통찰은 이미 존재하는 `skills/autoresearch/SKILL.md` + `references/` 구조가 Agent Skills 오픈 스탠다드(agentskills.io)를 이미 준수하고 있으므로 공통 코어 자체는 수정 없이 유지하고, 각 플랫폼에 맞는 얇은 어댑터 파일만 추가하면 된다는 것이다. Gemini는 TOML 커맨드 파일, Codex는 `.agents/skills/` 경로의 SKILL.md 래퍼, 그리고 두 플랫폼 모두를 위한 단일 `install.sh` 인스톨러가 추가되어야 한다. 기존 Claude Code 사용자에게 breaking change가 없어야 한다는 제약이 확정되어 있다.

세 플랫폼의 핵심 차이는 루프 실행 모델에서 발생한다. Claude Code는 무한 단일 세션을 네이티브 지원하지만, Codex는 태스크 완료 시 세션을 종료하는 아키텍처 특성이 있어 외부 재호출 메커니즘이 필요하고, Gemini는 반복 패턴을 내부적으로 감지하여 루프를 강제 종료하는 안전 장치가 있다. 이 두 가지 플랫폼별 루프 비호환성 문제는 어댑터 설계 단계에서 반드시 해결해야 할 크리티컬 아이템이다.

기술적 리스크는 명확하고 해결책도 알려져 있다: Codex는 외부 루프 래퍼 + 상태 파일 기반 재개 패턴, Gemini는 AfterAgent 훅 기반 컨텍스트 리셋 패턴, 그리고 두 플랫폼 모두에서 `${CLAUDE_PLUGIN_ROOT}` 변수가 작동하지 않으므로 인스톨러가 절대 경로를 주입하는 방식으로 처리한다. 이 패턴들은 커뮤니티 레퍼런스 구현(codex-autoresearch, ralph extension)을 통해 검증되어 있다.

## Key Findings

### Recommended Stack

현재 Claude Code 기반 스택(`plugin.json` + `commands/*.md` + `skills/` 구조)은 100% 유지된다. v1.1에서 추가되는 스택 요소는 세 가지다. 첫째, Codex CLI용 `.agents/skills/autoresearch/` 디렉토리 + `SKILL.md` 래퍼 + `agents/openai.yaml` 메타데이터 파일. 둘째, Gemini CLI용 `.gemini/extensions/autoresearch/` 디렉토리 + `gemini-extension.json` 매니페스트 + `commands/*.toml` (TOML 포맷 필수). 셋째, 플랫폼 자동 감지 기반 단일 `scripts/install.sh`. 빌드 파이프라인, 템플릿 엔진, MCP 서버는 명시적으로 제외된다.

**Core technologies:**
- Agent Skills 오픈 스탠다드 (agentskills.io): SKILL.md 공통 포맷 — 26개 이상 플랫폼 지원, 기존 파일이 이미 준수
- `.agents/skills/` 경로 컨벤션: Codex CLI + Gemini CLI 공통 — `npx skills` 인스톨러가 자동 처리
- Gemini TOML 커맨드 포맷: Gemini CLI 전용 — Markdown 아님, `{{args}}` / `!{shell}` / `@{file}` 변수
- `scripts/install.sh`: Vercel skills.sh 패턴 — 플랫폼 감지 + 절대 경로 주입 + 인터랙티브 메뉴
- `adapters/` 디렉토리 레이어: 플랫폼별 얇은 진입점 — 공통 코어와 분리, contribution 경계 명확화

### Expected Features

**Must have (v1.1 table stakes):**
- Codex CLI 어댑터 — `$autoresearch` 단일 진입점, 6개 모드 전부 (loop/plan/debug/fix/security/ship)
- Gemini CLI 어댑터 — `/autoresearch` TOML 커맨드, 동일 6개 서브커맨드
- Claude Code breaking change 없음 — 기존 `commands/` + `skills/` 경로 그대로 유지
- curl/npx 원라이너 인스톨러 — 플랫폼 자동 감지, 인터랙티브 선택 메뉴
- 공통 코어 확정 — `${CLAUDE_PLUGIN_ROOT}` 제거, 플랫폼 중립 검증

**Should have (v1.1.x 검증 후):**
- exec mode — Codex 전용, CI/CD 비대화형, 환경변수 기반 설정 + JSON 출력
- GOAL.md 생성기 — `/autoresearch:plan` 확장, goal-md 포맷으로 GOAL.md 출력

**Defer (v2+):**
- Background mode (Codex 전용) — Python helper scripts 기반 detached 실행, 높은 복잡도
- Parallel worktrees (Codex 전용) — Background mode 완성 후에만 의미 있음
- 환경 감지 프로브 — CPU/GPU/RAM 자동 감지, 우선순위 낮음

**Anti-features (절대 추가 금지):**
- MCP 서버 방식 — 명시적 Out of Scope
- 실시간 크로스 플랫폼 상태 동기화 — 아키텍처적으로 잘못된 방향
- 독립 웹 대시보드 — 범위 외
- npx setup wizard 별도 패키지 — `/autoresearch:plan`으로 이미 커버

### Architecture Approach

Thin Adapter + Shared Core 패턴이 결론이다. `skills/autoresearch/SKILL.md` + `references/*.md` + `scripts/metric-*.sh`는 Source of Truth로 절대 수정되지 않으며, 플랫폼별 어댑터가 이 파일들을 경로 참조로 로드한다. 어댑터 파일들은 5-20줄 수준으로 극히 얇다. 경로 변수 차이(`${CLAUDE_PLUGIN_ROOT}` vs 상대 경로 vs `@{path}`)는 인스톨러가 `{{CORE_PATH}}` 플레이스홀더를 실제 절대 경로로 치환하는 방식으로 해결한다. 단일 `install.sh`가 플랫폼 감지, 경로 치환, 파일 복사를 모두 처리한다.

**Major components:**
1. **Common Core** (`skills/autoresearch/`) — 8-phase 루프 프로토콜, 12개 references 문서, Source of Truth. 수정 금지
2. **Claude Code Adapter** (`commands/*.md`, `.claude-plugin/plugin.json`) — 기존 그대로 유지, backward compatibility 보장
3. **Codex Adapter** (`adapters/codex/SKILL.md`, `agents/openai.yaml`) — `$autoresearch` 진입점, re-invoke 루프 패턴 내장
4. **Gemini Adapter** (`adapters/gemini/gemini-extension.json`, `commands/*.toml`) — TOML 포맷, AfterAgent 훅 기반 루프 재개, 얇은 GEMINI.md
5. **Installer** (`scripts/install.sh`) — 플랫폼 자동 감지, 절대 경로 주입, 멱등성 보장

**Build order (의존성 기반):**
공통 코어 검증 → Gemini/Codex 어댑터 (병렬 가능) → Codex SKILL.md (openai.yaml 이후) → install.sh (어댑터 완성 이후)

### Critical Pitfalls

1. **Codex 루프 비호환성** — Codex는 태스크 완료 시 세션 종료. "NEVER stop" 프롬프트 지시 무효. 해결책: 외부 `while true` 래퍼 또는 lifecycle 훅으로 Codex를 반복 재호출; 각 세션이 `autoresearch-state.json`에서 상태를 복원

2. **`${CLAUDE_PLUGIN_ROOT}` 미정의** — Codex/Gemini에서 이 변수는 존재하지 않으며 실패가 무음으로 발생 (에이전트가 프로토콜 없이 실행). 해결책: 공통 코어 추출 전에 이 변수를 모든 공유 파일에서 제거; 인스톨러가 절대 경로를 주입

3. **Gemini 루프 반복 감지 종료** — Gemini CLI는 반복 툴 호출 패턴을 감지해 3-7 이터레이션 후 강제 종료. 해결책: AfterAgent 훅으로 컨텍스트 리셋; 이터레이션마다 번호/메트릭/가설을 컨텍스트에 포함해 정확한 반복 패턴 방지

4. **Codex 샌드박스가 git commit 차단** — `workspace-write` 샌드박스 모드에서 `.git/` 쓰기가 승인을 요구해 Phase 4 자동 커밋이 중단. 해결책: `.codex/config.toml`에 git 명령 allowlist 설정; 인스톨러가 이 설정을 자동 생성

5. **어댑터에 프로토콜 내용 복제** — 빠른 방법처럼 보이지만, 3개 플랫폼 × 12개 문서 = 36개 복사본이 즉시 diverge. 해결책: 어댑터는 경로 참조만 포함; 프로토콜은 Source of Truth에서만 유지

## Implications for Roadmap

### Phase 1: 공통 코어 확정 및 아키텍처 정립

**Rationale:** 모든 이후 작업의 기반. `${CLAUDE_PLUGIN_ROOT}` 미정의 문제(Pitfall 2)는 어댑터 구축 전에 반드시 해결해야 한다. `adapters/` 디렉토리 구조를 먼저 확립해야 contribution 경계가 명확해진다.

**Delivers:** 플랫폼 중립 공통 코어 + `adapters/` 디렉토리 스캐폴딩. 기존 Claude Code 기능 100% 보존 검증.

**Addresses:** 공통 코어 추출 (P1), Claude Code backward compatibility (P1)

**Avoids:** Pitfall 2 (`${CLAUDE_PLUGIN_ROOT}`), Anti-Pattern 2 (SKILL.md에 플랫폼 로직 추가), 코드 복제 Anti-Pattern 1

---

### Phase 2: Codex CLI 어댑터

**Rationale:** codex-autoresearch 레퍼런스 구현이 이미 검증된 패턴을 제공하므로 Gemini보다 선행 구현이 용이. 루프 재호출 메커니즘(Pitfall 1)이 가장 복잡한 설계 결정이므로 Gemini 전에 해결해 루프 패턴을 확립.

**Delivers:** `$autoresearch` + 6개 서브커맨드 Codex CLI에서 작동. `.codex/config.toml` 자동 생성 (git sandbox 허용). re-invoke 루프 패턴 검증 완료.

**Uses:** `.agents/skills/autoresearch/` 경로 컨벤션, `agents/openai.yaml`, 절대 경로 주입 패턴

**Implements:** Codex Adapter 컴포넌트

**Avoids:** Pitfall 1 (루프 비호환성), Pitfall 4 (git sandbox 차단)

---

### Phase 3: Gemini CLI 어댑터

**Rationale:** TOML 포맷으로 인한 구조적 차이와 AfterAgent 훅이 독립적인 설계 작업. ralph extension 패턴(Pitfall 3 해결책)을 구현해야 한다.

**Delivers:** `/autoresearch` + 6개 서브커맨드 Gemini CLI에서 작동. AfterAgent 훅으로 5+ 이터레이션 루프 검증. 얇은 GEMINI.md (세션마다 context 전체 로드 방지).

**Uses:** Gemini TOML 커맨드 포맷, `gemini-extension.json`, `@{path}` 파일 주입, AfterAgent 훅

**Implements:** Gemini Adapter 컴포넌트

**Avoids:** Pitfall 3 (Gemini 루프 감지 종료), `${extensionPath}` 스코프 오류 Integration Gotcha

---

### Phase 4: 멀티 플랫폼 인스톨러

**Rationale:** 설치할 어댑터가 완성되어야 인스톨러가 의미 있다. Vercel skills.sh 패턴이 검증된 UX. 인스톨러는 경로 치환 로직을 포함하므로 어댑터 구조가 확정된 이후에 작성해야 한다.

**Delivers:** `scripts/install.sh` — 플랫폼 자동 감지, 절대 경로 주입, 멱등성 보장. `curl -fsSL | bash` 원라이너로 3개 플랫폼 설치 가능. `npx skills add inchan/autoresearch` 지원.

**Uses:** Vercel skills.sh 패턴, `which codex` / `test -d ~/.gemini` 감지, `{{CORE_PATH}}` 플레이스홀더 치환

**Implements:** Installer 컴포넌트

**Avoids:** Installer UX Pitfalls (자동 감지 vs 질문 혼용, 사용자 커스터마이즈 덮어쓰기), Anti-Pattern 4 (플랫폼별 별도 스크립트)

---

### Phase 5: 통합 검증 및 엔드투엔드 테스트

**Rationale:** "Looks Done But Isn't" 체크리스트가 경험적으로 확립되어 있다. 각 플랫폼의 루프 컴플라이언스는 1-2 이터레이션이 아닌 5-10 이터레이션으로 검증해야 함.

**Delivers:** 3개 플랫폼 × 6개 커맨드 × 핵심 케이스 검증 매트릭스. 상태 파일 호환성 확인. 재설치 멱등성 확인.

**Addresses:** "Looks Done But Isn't" 체크리스트 항목 전체

---

### Phase Ordering Rationale

- **Phase 1 우선:** `${CLAUDE_PLUGIN_ROOT}` 제거가 모든 어댑터의 전제조건. 이것 없이 어댑터를 구축하면 Pitfall 2가 반드시 발생
- **Phase 2 → 3 순서:** Codex가 Gemini보다 레퍼런스 구현 품질이 높아 패턴 학습 비용이 낮음; Codex에서 루프 재호출 패턴을 먼저 확립하면 Gemini 설계에 인사이트 제공
- **Phase 4 마지막:** 인스톨러는 어댑터 경로가 확정되어야 경로 주입 로직을 작성할 수 있음
- **Phase 5 별도:** 플랫폼별 루프 검증은 실제 CLI 환경에서만 가능; 구현 완료 후 별도 단계로 실행

### Research Flags

**Phase 1 (공통 코어):** 표준 패턴, 연구 불필요. `${CLAUDE_PLUGIN_ROOT}` 위치를 grep으로 확인 후 제거하면 됨.

**Phase 2 (Codex 어댑터):** 부분 연구 필요 — Codex `$autoresearch:subcommand` 서브커맨드 네임스페이싱 동작이 LOW confidence (ARCHITECTURE.md 명시). issue #15167 확인 필요. 루프 재호출 메커니즘은 codex-autoresearch 구현 참조로 충분.

**Phase 3 (Gemini 어댑터):** AfterAgent 훅 구현 연구 필요 — ralph extension(github.com/gemini-cli-extensions/ralph) 구현 방식 직접 확인 권장.

**Phase 4 (인스톨러):** 표준 패턴, 연구 불필요. Vercel skills.sh 코드를 직접 참조.

**Phase 5 (검증):** 실행 기반, 연구 불필요. PITFALLS.md의 "Looks Done But Isn't" 체크리스트를 그대로 사용.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | 공식 문서 직접 확인 (agentskills.io, Codex docs, Gemini CLI docs). npx skills 설치 경로 검증 |
| Features | HIGH | 레퍼런스 구현 코드 직접 확인 (codex-autoresearch, goal-md, autoresearch-anything). 우선순위 매트릭스 근거 명확 |
| Architecture | HIGH (Claude/Gemini) / MEDIUM (Codex) | Claude Code: 현행 구현 기반. Gemini: 공식 Extensions 문서. Codex: Skills API 신규 기능으로 일부 불확실 |
| Pitfalls | HIGH | GitHub 이슈 번호 및 커뮤니티 evidence로 뒷받침. 해결책도 검증된 구현 사례 있음 |

**Overall confidence:** HIGH

### Gaps to Address

- **Codex 서브커맨드 네임스페이싱** (`$autoresearch:plan` 문법): LOW confidence. Phase 2에서 실제 Codex CLI로 테스트 전에 이슈 #15167 확인 필요. 작동 안 할 경우 대안: 별도 `$autoresearch-plan` skill로 분리
- **Gemini AfterAgent 훅 API 안정성**: Gemini CLI가 확장 Hook API를 현재 실험적 기능으로 제공. Phase 3 시작 전 현재 버전 상태 재확인 권장
- **Gemini Extension `contextFileName` 동작**: SKILL.md를 직접 `contextFileName`으로 지정할지 얇은 GEMINI.md를 만들지 결정 필요. 문서는 얇은 GEMINI.md 권장이나 실제 동작 검증 필요

## Sources

### Primary (HIGH confidence)
- [agentskills.io/specification](https://agentskills.io/specification) — SKILL.md 공식 스펙, frontmatter 필드 정의
- [developers.openai.com/codex/skills](https://developers.openai.com/codex/skills) — Codex Skills 탐색 경로, SKILL.md 포맷
- [developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md) — AGENTS.md 탐색 규칙
- [google-gemini.github.io/gemini-cli/docs/cli/custom-commands.html](https://google-gemini.github.io/gemini-cli/docs/cli/custom-commands.html) — Gemini TOML 커맨드 포맷
- [google-gemini.github.io/gemini-cli/docs/extensions/](https://google-gemini.github.io/gemini-cli/docs/extensions/) — Gemini Extension 구조
- [github.com/vercel-labs/skills](https://github.com/vercel-labs/skills) — npx skills 설치 툴, 플랫폼별 경로
- [leo-lilinxiao/codex-autoresearch](https://github.com/leo-lilinxiao/codex-autoresearch) — Codex 어댑터 레퍼런스 구현 직접 확인
- [jmilinovich/goal-md](https://github.com/jmilinovich/goal-md) — GOAL.md 스펙 및 dual-score 패턴
- [karpathy/autoresearch issue #57](https://github.com/karpathy/autoresearch/issues/57) — Codex 루프 비호환성 확인
- [google-gemini/gemini-cli issue #8928](https://github.com/google-gemini/gemini-cli/issues/8928) — Gemini 루프 감지 종료 확인
- [developers.openai.com/codex/concepts/sandboxing](https://developers.openai.com/codex/concepts/sandboxing) — git commit 승인 요구 사항

### Secondary (MEDIUM confidence)
- [developers.openai.com/codex/cli/slash-commands](https://developers.openai.com/codex/cli/slash-commands) — Codex 내장 슬래시 커맨드 (스킬 호출과 다름)
- [geminicli.com/docs/cli/skills/](https://geminicli.com/docs/cli/skills/) — Gemini 스킬 탐색 경로
- [github.com/gemini-cli-extensions/ralph](https://github.com/gemini-cli-extensions/ralph) — AfterAgent 훅 루프 패턴

### Tertiary (LOW confidence — needs validation)
- Codex `$skill:subcommand` 네임스페이싱 동작 — [openai/codex issue #15167](https://github.com/openai/codex/issues/15167) 미확인; Phase 2에서 직접 테스트 필요

---
*Research completed: 2026-03-24*
*Ready for roadmap: yes*
