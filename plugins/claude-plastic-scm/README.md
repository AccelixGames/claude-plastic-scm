# claude-plastic-scm

PlasticSCM (Unity Version Control) 워크플로우 자동화 플러그인.

## 요구사항

- PlasticSCM CLI (`cm`) 설치 및 PATH 등록
- PlasticSCM 워크스페이스 내에서 실행

## 명령

| 명령 | 설명 | 사용법 |
|------|------|--------|
| `/cm-checkin` | 변경 분석 후 코멘트 자동 생성 → 체크인 | `/cm-checkin` |
| `/cm-comment` | 코멘트만 생성 (미리보기 또는 기존 체인지셋에 적용) | `/cm-comment [cs:{id}]` |
| `/cm-merge-comment` | 서버 사이드 병합 + 서브 브랜치 코멘트 수집·정리 | `/cm-merge-comment [브랜치경로]` |
| `/cm-branch-info` | 브랜치 개요, 체인지셋 목록, 병합 이력 표시 | `/cm-branch-info [브랜치경로]` |
| `/cm-status` | 워크스페이스 변경 사항을 카테고리별로 정리 | `/cm-status` |
| `/cm-history` | 파일/디렉토리 변경 이력 조회 | `/cm-history <경로>` |
| `/cm-compile-check` | Unity 컴파일 에러 확인 | `/cm-compile-check` |
| `/cm-hidden` | 비공개/숨김 변경 열람·관리 | `/cm-hidden [unhide\|hide\|unignore\|ignore]` |
| `/cm-diff` | 체인지셋, 브랜치, 라벨 간 비교 | `/cm-diff cs:100 cs:200` |

## 자동 트리거

PlasticSCM 관련 대화 시 cm CLI 지식 베이스가 자동 활성화됩니다.

**트리거 키워드:** 플라스틱, 체인지셋, cm 명령, 병합, 브랜치, 체크인, 커밋, 푸시, pending changes 등

## 주요 기능

### 스마트 체크인 (`/cm-checkin`)
- 변경 파일 자동 분류 (Primary / Ancillary)
- `.meta`, `Library/`, `obj/` 등 자동 생성 파일 필터링
- 한국어 불렛 포인트 코멘트 자동 생성 (카테고리 접두사: 수정/변경/제거/리팩토링)
- CH/PR 상태 파일 자동 전처리 (partial checkout / cm add)
- 체크인 전 Unity 컴파일 에러 자동 확인
- 프로젝트별 필터 아카이브 지원 (`.claude/checkin-filters.local.md`)

### 코멘트 생성 (`/cm-comment`)
- 체크인 없이 코멘트만 생성·미리보기
- 기존 체인지셋에 코멘트 적용 (`/cm-comment cs:{id}`)

### 컴파일 에러 확인 (`/cm-compile-check`)
- Unity Editor.log에서 컴파일 에러 감지
- 최신 컴파일 결과 기준으로 현재 에러 상태 판별
- `/cm-checkin` 실행 시 자동으로 포함

### 비공개/숨김 변경 관리 (`/cm-hidden`)
- `hidden_changes.conf` (파일명 매칭) 열람·숨김 해제·추가
- `ignore.conf` (패턴 매칭) 열람·추가·제거
- `cm status --hiddenchanged`, `cm status --ignored` 기반

### 서버 사이드 병합 (`/cm-merge-comment`)
- 현재 브랜치에서 대상 브랜치로 서버 사이드 병합
- 병합된 서브 브랜치 코멘트 수집·정리·적용

## 라이선스

MIT License
