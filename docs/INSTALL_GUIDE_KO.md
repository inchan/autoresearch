# Autoresearch 설치 가이드 (모든 경우의 수)

이 프로젝트는 **Claude plugin** 기준으로 설치/업데이트/삭제를 지원합니다.

## 0) 사전 조건

1. `claude` CLI가 PATH에 있어야 합니다.

```bash
command -v claude
```

- 경로가 출력되면 정상
- 출력이 없으면 Claude CLI를 먼저 설치해야 합니다.

2. 저장소 루트에서 실행하는 것을 권장합니다.

---

## 1) 가장 간단한 설치 (직접 명령)

```bash
claude plugin add autoresearch
```

> 플러그인 레지스트리/별칭을 통해 설치하는 가장 간단한 경로입니다.

---

## 2) 로컬 저장소에서 설치

저장소를 clone한 뒤 루트에서:

```bash
claude plugin add .
```

또는 절대경로:

```bash
claude plugin add /absolute/path/to/autoresearch
```

---

## 3) 설치 스크립트 사용 (권장)

스크립트: `scripts/install-autoresearch.sh`

### 실행 시 내부 진행 순서

스크립트는 아래 순서로 동작합니다.

1. 인자 파싱 (`--action`, `--source`, `--yes`, `--non-interactive`)
2. `claude` CLI 존재 여부 확인
3. 실행 모드 결정
   - `--non-interactive`이면 `--action` 필수 검증
   - 아니면 메뉴(Install/Update/Uninstall) 표시
4. 확인 프롬프트 처리 (`--yes`면 자동 승인)
5. action 실행
   - `install`  -> `claude plugin add <source>`
   - `update`   -> `claude plugin add <source>`
   - `uninstall`-> `claude plugin remove autoresearch`
6. 완료 메시지 출력

즉, 실제 작업을 하기 전에 **CLI 존재 확인 + 입력 검증 + 사용자 확인**을 먼저 거친 뒤 실행됩니다.

### 3-1) 인터랙티브 모드 (TUI 느낌)

```bash
./scripts/install-autoresearch.sh
```

- 메뉴에서 `Install / Update / Uninstall` 선택
- `Install/Update` 선택 시 source 경로 입력 가능

예상 진행 예:

```text
Autoresearch Installer (skills.sh-style)
Choose action:
1) Install
2) Update
3) Uninstall
Enter choice [1-3]:
```

### 사용자 화면 예시 (실제 입력 흐름)

#### 예시 A: Install 선택

```text
$ ./scripts/install-autoresearch.sh
Autoresearch Installer (skills.sh-style)
Choose action:
1) Install
2) Update
3) Uninstall
Enter choice [1-3]: 1
Plugin source (default: /path/to/autoresearch): .
Proceed with install? [y/N]: y
Installing plugin 'autoresearch' from: .
Done: installed 'autoresearch'.
```

#### 예시 B: Update 선택

```text
$ ./scripts/install-autoresearch.sh
Autoresearch Installer (skills.sh-style)
Choose action:
1) Install
2) Update
3) Uninstall
Enter choice [1-3]: 2
Plugin source (default: /path/to/autoresearch): .
Proceed with update? [y/N]: y
Updating plugin 'autoresearch' from: .
Done: updated 'autoresearch'.
```

#### 예시 C: Uninstall 선택

```text
$ ./scripts/install-autoresearch.sh
Autoresearch Installer (skills.sh-style)
Choose action:
1) Install
2) Update
3) Uninstall
Enter choice [1-3]: 3
Proceed with uninstall? [y/N]: y
Removing plugin 'autoresearch'
Done: removed 'autoresearch'.
```

#### 예시 D: 취소 흐름 (`N` 입력)

```text
$ ./scripts/install-autoresearch.sh
Autoresearch Installer (skills.sh-style)
Choose action:
1) Install
2) Update
3) Uninstall
Enter choice [1-3]: 1
Plugin source (default: /path/to/autoresearch): .
Proceed with install? [y/N]: n
# 작업 없이 종료
```

### 3-2) 비대화형 모드 (CI/자동화)

#### (A) Install

```bash
./scripts/install-autoresearch.sh \
  --action install \
  --source . \
  --yes \
  --non-interactive
```

예상 실행:

```text
Installing plugin 'autoresearch' from: .
Done: installed 'autoresearch'.
```

#### (B) Update

```bash
./scripts/install-autoresearch.sh \
  --action update \
  --source . \
  --yes \
  --non-interactive
```

예상 실행:

```text
Updating plugin 'autoresearch' from: .
Done: updated 'autoresearch'.
```

#### (C) Uninstall

```bash
./scripts/install-autoresearch.sh \
  --action uninstall \
  --yes \
  --non-interactive
```

예상 실행:

```text
Removing plugin 'autoresearch'
Done: removed 'autoresearch'.
```

---

## 4) 옵션 조합별 동작 요약

### `--action`
- `install` : `claude plugin add <source>` 실행
- `update` : `claude plugin add <source>` 실행 (재설치/업데이트 경로)
- `uninstall` : `claude plugin remove autoresearch` 실행

### `--source`
- install/update에서만 사용
- 미지정 시 기본값은 현재 저장소 루트

### `--yes`
- 확인 프롬프트 자동 승인

### `--non-interactive`
- 메뉴 없이 동작
- 이 옵션 사용 시 `--action` 필수

---

## 5) 자주 쓰는 시나리오

### 시나리오 1: 개발자가 로컬 수정본 테스트 설치

```bash
./scripts/install-autoresearch.sh --action install --source . --yes --non-interactive
```

### 시나리오 2: 최신 로컬 코드로 업데이트

```bash
./scripts/install-autoresearch.sh --action update --source . --yes --non-interactive
```

### 시나리오 3: 완전 제거

```bash
./scripts/install-autoresearch.sh --action uninstall --yes --non-interactive
```

### 시나리오 4: 사람 손으로 메뉴 선택 설치

```bash
./scripts/install-autoresearch.sh
```

---

## 6) 실패 케이스와 해결

### 에러: `claude` CLI 없음
- 증상: `Error: 'claude' CLI not found in PATH.`
- 조치: Claude CLI 설치 후 다시 실행

### 에러: `--non-interactive`인데 `--action` 누락
- 증상: `Error: --non-interactive requires --action.`
- 조치: `--action install|update|uninstall` 중 하나 지정

### 에러: 잘못된 action 값
- 증상: `Error: invalid --action ...`
- 조치: `install`, `update`, `uninstall` 중 하나 사용

---

## 7) 설치 확인 체크리스트

1. 설치/업데이트 후 `/autoresearch` 명령이 인식되는지 확인
2. 필요 시 제거 후 재설치로 상태 초기화
3. CI에서는 반드시 `--non-interactive --yes` 조합 사용
