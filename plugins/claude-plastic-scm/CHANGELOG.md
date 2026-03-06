# Changelog — claude-plastic-scm

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따른다.

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
