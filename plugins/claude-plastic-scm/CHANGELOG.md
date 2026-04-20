# Changelog — claude-plastic-scm

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따른다.

## [1.11.0] - 2026-04-20

(promoted from alpha after pilot: issue #1 처리 end-to-end 성공. 4-gate 전부 통과. 파일럿 중 발견한 3건 설계 결함은 #2/#3/#4로 등록 — 하나는 즉시 패치(Phase C issue type matrix, 커밋 `6cc13fa`), 나머지는 다음 /cm-lint 세션에서 자기참조 개선)

### 추가 (v1.11.0-alpha에서)

- **`/cm-lint` 슬래시 커맨드** — plastic-scm 스킬 전용 gotcha 진단+수리. 4-phase 워크플로우: GitHub Issues(`skill:plastic-scm` 필터)에서 gotcha-open/hold 수집 → 타이틀 유사도 클러스터링 → 유저 triage(accept/hold/reject) → worktree에서 4-gate 검증(baseline 재현 / primary fix 검증 / regression 2종) → 통과 시 commit+close, 실패 시 worktree 폐기+lint-attempted 라벨.
- `skills/plastic-scm/templates/gotcha-template.md` — 이슈 body 필수 필드(증상, 재현 단계, 시도, 해결/가설, 1줄 개선안, 영향 범위) + 라벨 스키마(`skill:plastic-scm` + `gotcha-open/hold/accepted/rejected`) + hold 카운터 규약(`lint-hold: bump (now N)` 코멘트).
- `skills/plastic-scm/templates/regression-smoke.md` — lint Phase C 회귀 검증용 smoke test 4개(SM-01 단순 checkin, SM-02 폴더+CH/PR 혼재, SM-03 label with -c=, SM-04 merge_investigate.sh). 프로젝트 비특화, 일반 cm 플로우만.
- `docs/plans/2026-04-20-gotcha-lint-system.md` — 이번 릴리스의 설계+구현 플랜(Phase 1+2). Phase 3(hook 기반 auto-capture)는 별도 플랜.

### 추가 (stable promotion에서)

- `references/cm-commands.md` checkin 섹션에 "⚠️ CH Hash-Equal Trap" 추가 — 파일럿 이슈 #1의 fix. atomic checkin이 touched-but-hash-equal 파일로 전체 롤백되는 trap과 `cm undo` / `cm co` 복구 패턴 문서화.
- `commands/cm-lint.md` Phase C.0 "Classify issue type" — 파일럿 중 발견한 결함 #3 즉시 패치. runtime/doc/process 3가지 issue type별 baseline/regression 전략 표 추가. 이전엔 runtime 버그만 다뤘음.

### 설계 결정 (locked)

- Reflection 트리거: **C+Hook hybrid**(Phase 3 예정)
- Hold 카운터: comment 누적(`lint-hold: bump`)
- 검증: 수동 재현 + script 자동 + 회귀 2종(smoke 세트에서 선정)
- 승격: 항상 수동, hold 카운터는 정렬 가중치 only
- 원칙: "잘못된 업데이트 > 업데이트 없음" — 4-gate 전부 통과해야 fix land

### 알려진 한계 (open gotcha issues)

- #2 — label bootstrap 누락 (최초 실행 시 수동 생성 필요)
- #3 — Git Bash MSYS가 gh 커맨드 인자의 `/cm-*` 토큰을 Windows 경로로 변환 (`MSYS_NO_PATHCONV=1` 가드 필요)
- #4 — Phase B/C에 gotcha-open → gotcha-accepted 라벨 전환 명령 누락


- **`/cm-lint` 슬래시 커맨드** — plastic-scm 스킬 전용 gotcha 진단+수리. 4-phase 워크플로우: GitHub Issues(`skill:plastic-scm` 필터)에서 gotcha-open/hold 수집 → 타이틀 유사도 클러스터링 → 유저 triage(accept/hold/reject) → worktree에서 4-gate 검증(baseline 재현 / primary fix 검증 / regression 2종) → 통과 시 commit+close, 실패 시 worktree 폐기+lint-attempted 라벨.
- `skills/plastic-scm/templates/gotcha-template.md` — 이슈 body 필수 필드(증상, 재현 단계, 시도, 해결/가설, 1줄 개선안, 영향 범위) + 라벨 스키마(`skill:plastic-scm` + `gotcha-open/hold/accepted/rejected`) + hold 카운터 규약(`lint-hold: bump (now N)` 코멘트).
- `skills/plastic-scm/templates/regression-smoke.md` — lint Phase C 회귀 검증용 smoke test 4개(SM-01 단순 checkin, SM-02 폴더+CH/PR 혼재, SM-03 label with -c=, SM-04 merge_investigate.sh). 프로젝트 비특화, 일반 cm 플로우만.
- `docs/plans/2026-04-20-gotcha-lint-system.md` — 이번 릴리스의 설계+구현 플랜(Phase 1+2). Phase 3(hook 기반 auto-capture)는 별도 플랜.

### 설계 결정 (locked)
- Reflection 트리거: **C+Hook hybrid**(Phase 3 예정)
- Hold 카운터: comment 누적(`lint-hold: bump`)
- 검증: 수동 재현 + script 자동 + 회귀 2종(smoke 세트에서 선정)
- 승격: 항상 수동, hold 카운터는 정렬 가중치 only
- 원칙: "잘못된 업데이트 > 업데이트 없음" — 4-gate 전부 통과해야 fix land

## [1.10.1] - 2026-04-20

### 수정
- `references/cm-commands.md` `label` 섹션 대폭 확장. 기존에 옵션 테이블이 비어 있어 코멘트 부여 문법을 추정하다 `cm label ... --comment="..."` (double-dash)로 호출해 `label: 예상치 못한 옵션 --comment` 에러가 반복 발생하던 문제.
  - 실제 syntax 추가: `cm label [create] <label-spec> <cs-spec> [-c="..." | -commentsfile=...]`
  - "Option Trap — `--comment` does NOT exist" 경고 섹션 추가. `cm checkin -c=`/`cm merge -c=`와 동일한 single-dash 규칙 명시.
  - 예제: 코멘트 포함 create, commentsfile 사용, workspace-path 라벨링, rename/delete.

## [1.10.0] - 2026-04-20

### 추가
- **Merge Investigation Playbook + `scripts/merge_investigate.sh`** — 병합 조사를 단일 Bash 호출로 번들링한 스크립트. 6개 `cm` 쿼리(`wi`, `find merge`, `find branch`, `find changeset`, `log`/`diff`, `status`)를 정해진 순서로 실행하고 라벨링된 섹션으로 raw data 출력.
  - 소스 브랜치 changeset 개수에 따라 single-cs 모드(`cm log`, Move/rename 보존) vs range-diff 모드 자동 선택
  - `Effective Merge Delta (dst_tip → src_tip)` 섹션 — 실제 병합 시 워크스페이스에 반영될 변경 범위
  - 300+ 엔트리 출력은 요약 모드 자동 전환 (status counts + top-level-path buckets + head 100 + tail 30)
- **Core Principles 섹션** — 조사 시작 전 3대 원칙: (1) slash commands first, (2) purpose-first exploration, (3) `cm status` 기본 full.
- **"STOP INVESTIGATING" 규칙** — 스크립트 완료 후 추가 `cm diff`/`find`/`cat` 호출을 명시적으로 제한. 3가지 예외 조건만 추가 탐색 허용(mode=unknown, auto-summary 세부, 스크립트 미수집 항목).
- **Environment Notes** — Windows Bash 툴 cwd 리셋 동작 및 우회법(`--workspace` 인자, 절대경로, PowerShell 툴).

### 수정
- `references/cm-commands.md` `diff` 섹션: 잘못 나열된 `--nototal` 옵션 제거 + "`cm diff`는 `--nototal` 미지원(`cm find`에서만 동작)" 주의 추가.

### 변경
- SKILL.md 본문 전면 영어화(일관성 + 토큰 효율). Playbook / Core Principles / Environment Notes는 영어로 신규 작성.

### 측정된 효과 (ProjectMaid 병합 조사 벤치마크)
| 지표 | 이전 | 1.10.0 |
|---|---|---|
| Tool execution 시간 | ~496s | ~20s |
| Tool uses | 67 | 8 |
| 병합 전략 식별 품질 | Move/rename 미감지, base 혼동, `cm merge --ancestor` 오작동 | Move 감지, Effective Delta, pending 매칭, 제약 위반 0 |

## [1.9.0] - 2026-04-18

### 추가
- 전 스킬 `Step 0 — Workspace guard`: frontmatter `!cm ...` pre-load에 `|| echo "NOT_A_WORKSPACE"` sentinel 추가. non-workspace(예: git repo)에서 호출 시 "Shell command failed for pattern"으로 죽던 로딩 실패를 친절한 조기 종료로 대체. 영향: cm-status, cm-branch-info, cm-comment, cm-compile-check, cm-hidden, cm-merge-comment, cm-checkin (7개).

### 변경
- **destructive 스킬에 `disable-model-invocation: true` 추가** — Claude 자동 호출 차단, 수동 `/cmd` 호출만 허용. 대상: `/cm-checkin`, `/cm-comment`, `/cm-hidden`, `/cm-merge-comment`. read-only 스킬(status/diff/history/branch-info/compile-check)은 자동 호출 유지.
- `allowed-tools` 포맷을 YAML list로 통일 (공식 스펙 권장; 이전 콤마 구분은 비규격).
- `description` front-load 재작성: 영어 요약 + 한국어 trigger keywords. 1536-char cap 대비 모두 ~11-18% 수준.
- 본문 전면 영어화 + 압축 (총 크기 -14%; 모든 step/rule/guard는 보존).

### 수정
- non-workspace에서 `/cm-checkin` 등 호출 시 pre-load가 exit 1을 반환해 skill 본문이 로드되지 않던 문제.

## [1.8.1] - 2026-04-10

### 추가
- `references/cm-commands.md` `diff` 섹션: **GUI Trap** 경고 — 파일 경로 인자 지정 시 비교 창이 열려 자동화가 hang되는 동작 문서화. 텍스트 전용 대안 3가지 (`--format`, `cm cat` 조합, `--download=` 옵션) 명시.

## [1.8.0] - 2026-04-10

### 추가
- `references/cm-commands.md`: `cm cat "serverpath:{path}#cs:{id}"` 명령 섹션 — 특정 changeset의 파일 내용을 워크스페이스 전환 없이 직접 조회 (머지 히스토리 추적 시 유용)
- `references/cm-commands.md` `add` 섹션 Gotchas:
  - `cm add -R`이 깊이 1단만 처리하는 함정 (손자/증손자는 별도 add 호출 필요)
  - 부모 폴더가 `비공개` 상태일 때 자식의 ignore 매칭이 전부 `무시 항목`으로 잘못 표시되는 동작
  - Windows 심볼릭 링크가 `cm add`/`cm status`에서 아예 인식되지 않는 한계
- `/cm-hidden` Important notes 확장:
  - `hidden_changes.conf`에 핵심 파일(`manifest.json` 등)을 넣으면 안 되는 이유 (체크인 누락 위험)
  - ignore.conf 글로브 패턴 가이드 (`.claude/*.local.*` 동작 확인, 부모 private 상태 함정, 검증 절차)

## [1.7.0] - 2026-03-06

### 추가
- `/cm-hidden` — 비공개/숨김 변경 관리 커맨드 (hidden changes + ignore.conf 열람·수정)

## [1.6.0] - 2026-03-06

### 추가
- `/cm-compile-check` — Unity Editor.log 기반 컴파일 에러 확인 커맨드
- `/cm-checkin` Step 7: 체크인 전 Unity 컴파일 에러 자동 확인 (에러 시 사용자 확인 후 진행)

## [1.5.0] - 2026-03-06

### 추가
- `/cm-comment` — 체크인 없이 코멘트만 생성·미리보기·기존 체인지셋에 적용

## [1.4.0] - 2026-03-06

### 추가
- `/cm-checkin` Step 6: CH/PR 상태 파일 자동 전처리 — CH→`cm partial checkout`, PR→`cm add` 실행 후 체크인
- `references/cm-commands.md`: `partial`, `add` 명령 참조 추가

## [1.3.0] - 2026-03-05

### 변경
- `/cm-merge-comment` 전면 재구성: 서버 사이드 병합(`--to`) + 코멘트 정리 통합 워크플로우
  - 현재 브랜치에 머물면서 대상 브랜치로 병합 실행
  - 병합 후 자동 코멘트 수집·정리·적용
- `/cm-checkin` Step 3: 코멘트 형식 규칙 강화 — 불렛 포인트 형식 + 카테고리 접두사(수정/변경/제거/리팩토링)
- `references/cm-commands.md`: merge `--to` 서버 사이드 병합 예시 추가

## [1.2.1] - 2026-03-05

### 수정
- `/cm-checkin` allowed-tools에 `Bash(cm wi:*)` 누락 — 컨텍스트 주입 시 권한 차단 수정

### 변경
- `/cm-checkin` Step 6: 명시적 파일 지정 체크인으로 변경 — GUI 체크 해제 상태와 무관하게 모든 파일 포함 보장

## [1.2.0] - 2026-03-05

### 변경
- `/cm-checkin` 코멘트 생성 강화: 자동 생성 파일(.meta 등) 필터링, 사용자 추가 코멘트 입력, 3계층 필터 판정
- 프로젝트별 필터 아카이브 지원 (`.claude/checkin-filters.local.md`)

### 추가
- Git ↔ PlasticSCM 용어 매핑 테이블 (SKILL.md)
- Git 용어 트리거 확장: "커밋", "푸쉬", "commit", "push" 등으로 스킬 자동 활성화
- `references/cm-commands.md`에 Checkin Filter Patterns 섹션

### 수정
- `cs:2700` → `cs:150` (보안: 실제 체인지셋 번호 제거)
- plugin.json `repository` URL 수정

## [1.1.0] - 2026-03-05

### 변경
- 보안 검토: 모든 예시에서 실제 프로젝트 정보(브랜치명, 체인지셋 번호, 개인 이니셜)를 일반 플레이스홀더로 교체
- plugin.json 필드 보강: `repository`, `license`, `keywords` 추가

### 추가
- 플러그인별 독립 CHANGELOG 분리 (마켓플레이스 CHANGELOG과 별도 관리)

## [1.0.0] - 2026-03-05

### 추가
- `/cm-checkin` — 변경 분석 후 코멘트 자동 생성 체크인
- `/cm-merge-comment` — 병합된 서브 브랜치 코멘트 수집·정리하여 최신 체인지셋에 적용
- `/cm-branch-info` — 브랜치 개요, 체인지셋 목록, 병합 이력 (수신/발신)
- `/cm-status` — 워크스페이스 상태를 카테고리별로 정리 (추가/수정/삭제/이동/미추적)
- `/cm-history` — 파일/디렉토리 변경 이력 테이블 조회
- `/cm-diff` — 체인지셋, 브랜치, 라벨 간 변경 비교
- PlasticSCM 지식 베이스 스킬 — cm CLI 관련 대화 시 자동 트리거
- cm CLI 명령 상세 참조 (`references/cm-commands.md`)
