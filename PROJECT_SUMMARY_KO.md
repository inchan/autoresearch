# Autoresearch 프로젝트 요약 (한국어)

## 1) 목적 (Purpose)
- 이 프로젝트의 핵심 목적은 **측정 가능한 지표(metric)가 있는 어떤 도메인에서도** LLM이 자율적으로 개선 실험을 반복 수행하도록 만드는 것입니다.
- 즉, 사람이 방향(Goal/Direction)을 정하면 에이전트가 코드 변경과 검증을 반복하며 성능을 끌어올리는 **goal-directed iteration**을 구현합니다.

## 2) 목표 (Goals)
- 주요 목표는 아래 루프를 안정적으로 자동화하는 것입니다.
  - **Modify → Verify → Keep/Discard → Repeat**
- 성공 조건은 “기계적으로 추출 가능한 수치(metric)”가 개선되는지 여부로 판단합니다.
- 개선되지 않으면 되돌리고(discard), 개선되면 유지(keep)하는 방식으로 탐색 효율을 높입니다.

## 3) 주제 (Theme)
- 주제는 한마디로 **자율 실험(autonomous experimentation) 운영체계**입니다.
- 단순 코드 생성이 아니라, 실험 단위 변경·검증·판정·기록을 반복하는 **과학적 최적화 워크플로우**에 가깝습니다.
- Karpathy의 autoresearch 패턴을 일반화해 Claude Code 플러그인/스킬 형태로 제공하는 것이 핵심입니다.

## 4) 환경 요약 (Environment)
- 배포 형태: **Claude Code 플러그인** + 슬래시 커맨드 + 스킬 레퍼런스 문서 구조
- 주요 실행 방식:
  - `/autoresearch` 메인 루프 실행
  - `/autoresearch plan|debug|fix|security|ship`로 목적별 워크플로우 분기
- 상태/기록 관리:
  - 실험 로그: `autoresearch-results.tsv` (append-only)
  - 세션 상태: `autoresearch-state.json` (재개 가능)
  - 실험 히스토리 메모리: Git 커밋/리버트

## 5) 기술 요약 (Tech Summary)
- 문서 기반 프로토콜 설계:
  - `skills/autoresearch/SKILL.md`가 메인 규약
  - 세부 절차는 `references/*.md`로 온디맨드 로드
- 워크플로우 엔진 특성:
  - 8단계 루프(Review, Ideate, Modify, Commit, Verify, Guard, Decide, Log)
  - 3단계 스코프 모델(Core/Support/Context)
  - 정체 구간 대응(REFINE/PIVOT)
- 보조 스크립트:
  - `skills/autoresearch/scripts/metric-test-quality.sh` (테스트 + 커버리지 복합 지표)
  - `skills/autoresearch/scripts/metric-code-health.sh` (타입/린트/테스트 기반 코드 건강 지표)
  - `skills/autoresearch/scripts/metric-perf-score.sh` (지연시간 기반 성능 지표)

## 6) 전체 요약 (One-page Summary)
- **Autoresearch는 “LLM을 실험 변이 함수로 활용하는 자동 최적화 프레임워크”**입니다.
- 사람은 목표와 검증 기준을 정의하고, 에이전트는 작은 원자적 변경을 반복하며 성능 수치를 개선합니다.
- 개선 여부를 숫자로 판정하고 Git으로 실험 이력을 보존하여, 임의적 시도가 아닌 **재현 가능하고 누적 학습 가능한 개선 루프**를 제공합니다.
- 결과적으로 이 프로젝트는 특정 언어/도메인에 종속되지 않는 **범용 자율 개선 운영 패턴**을 제공하는 데 초점을 둡니다.

## 7) 향후 방향 (Claude 유지 + skills.sh 스타일 설치)
- 런타임 전략은 **Claude 플러그인 중심 유지**입니다.
- 설치 경험(UX)은 `scripts/install-autoresearch.sh`를 통해 개선 중입니다.
  1. **skills.sh 스타일 인터랙티브 모드**: 설치/업데이트/제거를 메뉴 기반으로 수행
  2. **비대화형 설치 옵션**: `--action`, `--source`, `--yes`, `--non-interactive`로 CI 대응
  3. **단일 런타임 최적화**: 멀티 런타임 확장보다 Claude 품질/안정성에 집중
- 즉, 범위를 넓히기보다 **설치 경험과 운영 완성도**를 높이는 것이 우선순위입니다.
