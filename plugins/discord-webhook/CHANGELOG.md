# Changelog — discord-webhook

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따른다.

## [0.1.0] - 2026-04-03

### 추가
- `/discord` — Discord webhook 메시지/파일 발송 커맨드
  - 프로젝트별 다중 채널 (named webhooks + description 기반 자동 선택)
  - 자연어 멘션 처리 (유저/역할 별칭 매칭)
  - 로컬 파일 첨부 (`--file`)
  - 대화 컨텍스트 → 파일 변환 첨부 (`--file-content`)
  - config 미존재 시 대화형 초기 설정
