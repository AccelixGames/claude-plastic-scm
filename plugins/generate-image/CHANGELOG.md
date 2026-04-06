# Changelog

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따른다.

## [0.2.0] - 2026-04-06

### 추가
- CLI 래퍼 (`generate-mockup.mjs`): Gemini API 직접 호출 스크립트
  - 백그라운드 서브에이전트에서 Bash로 이미지 생성 가능
  - MCP 서버 없이도 GEMINI_API_KEY만으로 동작
  - 레퍼런스 이미지, aspect-ratio 지원
- 서브에이전트 디스패치 패턴 문서화 (SKILL.md Step 4-B)

### 변경
- Step 0: MCP 실패 시 CLI 래퍼 폴백 로직 추가
- Error Handling: MCP 불가 시 CLI 폴백 안내로 변경 (BLOCKING → 폴백)

## [0.1.0] - 2026-03-30

### 추가
- `generate-image` 스킬 초기 릴리스
  - Ideation 모드: 분기축 기반 3~4개 변형 탐색
  - Detail 모드: 확정 이미지의 멀티뷰 생성
  - 의존성 자동 체크 (MCP 서버, API key, config, references)
  - 프로젝트별 config.json + 카테고리 시스템
  - sidecar JSON 메타데이터 자동 생성
