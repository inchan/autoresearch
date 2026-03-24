# Autoresearch

## What This Is

Claude Code용 자율 연구 스킬(플러그인). Karpathy의 autoresearch 패턴(modify → verify → keep/discard → repeat)을 일반화하여, 측정 가능한 메트릭이 있는 모든 도메인에서 LLM 에이전트가 자율적으로 실험/최적화를 수행한다.

## Core Value

하나의 메트릭, 하나의 스코프, 하나의 루프 — 사람은 방향을 설정하고 에이전트가 무한히 반복 실험한다.

## Requirements

### Validated

<!-- v1.0에서 구현 완료 -->

- [x] 8-phase 자율 루프 (preconditions → review → ideate → modify → commit → verify → decide → log → repeat)
- [x] 6개 슬래시 커맨드 (/autoresearch, plan, debug, fix, security, ship)
- [x] 3-tier 스코프 모델 (Core/Support/Context)
- [x] 3-level 메트릭 (Direct/Proxy/Composite) + anti-gaming guard
- [x] PIVOT/REFINE stuck recovery (3→REFINE, 5→PIVOT, 2PIVOTs→web search)
- [x] Git as memory (commit before verify, revert to rollback)
- [x] Session resume (autoresearch-state.json)
- [x] Cross-run lessons (autoresearch-lessons.md)
- [x] TSV results logging
- [x] Composite metric script templates (test-quality, code-health, perf-score)
- [x] 설치 스크립트 + 한국어 설치 가이드

### Active

<!-- v1.1: 멀티에이전트 지원 -->

- [ ] Codex CLI 호환 — 6개 커맨드 모두
- [ ] Gemini CLI 호환 — 6개 커맨드 모두
- [ ] 공통 코어 분리 — 플랫폼 무관 로직 추출
- [ ] curl 인스톨러 — 플랫폼/스코프 선택 인터랙티브 설치

### Out of Scope

- MCP 서버 방식 — 오버엔지니어링, CLI 플러그인/커맨드 방식으로 충분
- GUI/웹 대시보드 — 이 프로젝트는 터미널 에이전트 스킬
- 자체 LLM 호출 — 에이전트(Claude Code/Codex/Gemini)가 직접 도구를 호출, 스킬은 프롬프트/프로토콜만 제공

## Current Milestone: v1.1 Multi-Agent Support

**Goal:** 현재 Claude Code 전용인 autoresearch 스킬을 OpenAI Codex CLI와 Google Gemini CLI에서도 동일하게 사용할 수 있도록 확장한다.

**Target features:**
- 공통 코어 추출 (플랫폼 무관 프로토콜/로직)
- Codex CLI 어댑터 (agents.md/커스텀 커맨드 변환)
- Gemini CLI 어댑터 (GEMINI.md/커스텀 커맨드 변환)
- curl 기반 인터랙티브 인스톨러 (Vercel skills.sh 스타일)
- 전체 6개 커맨드 멀티에이전트 호환

## Context

- v1.0은 Claude Code의 `plugin.json` + `commands/` + `skills/` 구조에 최적화
- 커맨드 파일은 마크다운 프롬프트 (.md) — 에이전트에게 프로토콜을 지시
- `${CLAUDE_PLUGIN_ROOT}` 같은 Claude Code 전용 변수 사용 중
- Codex CLI는 `agents.md` 기반, Gemini CLI는 `GEMINI.md` 기반으로 추정 (리서치 필요)
- Reference implementations: codex-autoresearch (Codex), goal-md (tool-agnostic), autoresearch-anything (any agent)

## Constraints

- **호환성**: 기존 Claude Code 사용자에게 breaking change 없어야 함
- **구조**: 기존 `commands/` + `skills/` 디렉토리 구조 최대한 유지
- **배포**: 단일 리포에서 플랫폼별 출력물 생성 (모노리포)
- **설치**: curl 원라이너로 설치 가능, 인터랙티브 플랫폼/스코프 선택

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| v1.1 마이너 버전 | 기존 구조 유지 + 어댑터 패턴으로 추가 | — Pending |
| 전체 6개 커맨드 지원 | 부분 지원은 사용자 혼란 초래 | — Pending |
| Codex + Gemini 동시 진행 | 공통 코어 추출 시 두 플랫폼 동시 고려가 더 나은 추상화 도출 | — Pending |
| curl 인터랙티브 인스톨러 | Vercel skills.sh 패턴 — 검증된 UX | — Pending |
| 단일 리포 모노리포 | 공통 코어와 플랫폼 래퍼를 한 곳에서 관리 | — Pending |

---
*Last updated: 2026-03-24 after milestone v1.1 started*
