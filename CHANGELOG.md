# Changelog

이 문서는 accelix-ai-plugins 마켓플레이스 자체의 변경 내역을 기록한다.
개별 플러그인의 변경 내역은 각 플러그인의 `CHANGELOG.md`를 참조.

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따른다.

## [1.8.0] - 2026-03-06

### 추가
- claude-plastic-scm v1.7.0: `/cm-hidden` 비공개/숨김 변경 관리 커맨드

## [1.7.0] - 2026-03-06

### 추가
- claude-plastic-scm v1.6.0: `/cm-compile-check` 컴파일 에러 확인 + `/cm-checkin` 체크인 전 자동 확인

## [1.6.0] - 2026-03-06

### 추가
- claude-plastic-scm v1.5.0: `/cm-comment` 코멘트 전용 커맨드 추가

## [1.5.0] - 2026-03-06

### 변경
- claude-plastic-scm v1.4.0: `/cm-checkin` CH/PR 파일 자동 전처리 + `partial`/`add` 명령 참조 추가

## [1.4.0] - 2026-03-05

### 변경
- claude-plastic-scm v1.3.0: `/cm-merge-comment` 서버 사이드 병합 통합 + `/cm-checkin` 코멘트 불렛 포인트 형식·접두사 규칙

## [1.3.1] - 2026-03-05

### 변경
- claude-plastic-scm v1.2.1: `/cm-checkin` allowed-tools 누락 수정 + 명시적 파일 지정 체크인

## [1.3.0] - 2026-03-05

### 변경
- claude-plastic-scm v1.2.0: 체크인 코멘트 생성 강화, Git 용어 매핑, 필터 아카이브

## [1.2.0] - 2026-03-05

### 추가
- 보안 검토 훅: 플러그인 업데이트 시 정보 노출 자동 검증
- 개발 방법론 (CLAUDE.md): 신규 커맨드 추가/테스트/배포 절차 정의
- 플러그인별 독립 CHANGELOG 분리
- LICENSE를 마켓플레이스 루트로 이동

### 변경
- marketplace.json 이름: `accelix-ai-plugins` (예약어 제한 대응)
- claude-plastic-scm v1.1.0: 보안 수정 + plugin.json 필드 보강

## [1.1.0] - 2026-03-05

### 변경
- 마켓플레이스 이름 변경: `claude-plastic-scm` → `claude-plugins-accelix`
- 팀 전용 마켓플레이스로 구조 개편 (복수 플러그인 호스팅 지원)

## [1.0.0] - 2026-03-05

### 추가
- claude-plastic-scm v1.0.0 — PlasticSCM 워크플로우 자동화 플러그인 초기 릴리스