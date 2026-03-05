# Changelog

이 문서는 claude-plastic-scm 플러그인의 변경 내역을 기록한다.

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따른다.

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