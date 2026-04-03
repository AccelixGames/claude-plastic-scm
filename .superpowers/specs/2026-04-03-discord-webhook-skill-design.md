# Discord Webhook Skill Design

> **Status**: APPROVED
> **Date**: 2026-04-03
> **Plugin**: `discord-webhook` (accelix-ai-plugins marketplace)

## Overview

Discord webhook을 통해 메시지와 파일을 발송하는 슬래시 커맨드 플러그인. 프로젝트별 다중 채널 지원, 자연어 기반 채널 선택 및 멘션 자동 처리.

## Plugin Structure

```
plugins/discord-webhook/
├── .claude-plugin/
│   └── plugin.json              # 플러그인 메타데이터
├── CHANGELOG.md
├── commands/
│   └── discord.md               # 슬래시 커맨드 정의 (LLM 지시문)
└── scripts/
    └── send.sh                  # curl wrapper (발송 전용)
```

프로젝트 측:
```
{project-root}/
└── .discord-webhook/
    └── config.json              # 프로젝트별 webhook/mentions 설정
```

## Config Schema

### `.discord-webhook/config.json`

```jsonc
{
  "webhooks": {
    "default": {
      "url": "https://discord.com/api/webhooks/{id}/{token}",
      "description": "일반 알림용"
    },
    "build-log": {
      "url": "https://discord.com/api/webhooks/{id}/{token}",
      "description": "빌드 결과, CI/CD 로그, 컴파일 에러"
    },
    "design-review": {
      "url": "https://discord.com/api/webhooks/{id}/{token}",
      "description": "설계 리뷰, 스펙 변경, 아키텍처 논의"
    }
  },
  "mentions": {
    "users": {
      "233223": "대표님, 김기민, 기민, kimin"
    },
    "roles": {
      "445566": "개발팀, dev, developers",
      "778899": "디자인팀, design, 그래픽"
    }
  },
  "username": "Claude Bot",
  "avatar_url": null
}
```

### Config Rules

- `webhooks.default` 필수. 채널명 생략 시 여기로 발송
- webhook URL 형식: `https://discord.com/api/webhooks/{id}/{token}` 또는 `https://discordapp.com/api/webhooks/...`
- `mentions.users` key = Discord user ID (snowflake), value = 자연어 별칭 (쉼표 구분)
- `mentions.roles` key = Discord role ID (snowflake), value = 자연어 별칭 (쉼표 구분)
- `username`, `avatar_url`은 optional
- `.gitignore`에 `.discord-webhook/` 추가 권장 (webhook URL = credential)

## Command Interface

### `/discord` Usage

```bash
# 기본 — 채널 자동 선택, 멘션 자동 감지
/discord "빌드 실패했어. 기민한테 알려줘"

# 채널 명시
/discord build-log "컴파일 에러 3건"

# 로컬 파일 첨부
/discord "로그 확인해주세요" --file ./build.log

# 대화 컨텍스트 → 파일 변환 첨부
/discord "분석 결과 정리해서 보내줘" --file-content analysis.txt

# 채널 명시 + 파일 첨부
/discord design-review "스펙 변경됨. 개발팀 확인 필요" --file ./spec.md
```

### Command Frontmatter

```yaml
allowed-tools: Bash(bash *send.sh*), Read, Write
description: Send message to Discord via webhook (디스코드 웹훅 메시지 발송)
argument-hint: "[channel] \"message\" [--file path] [--file-content filename]"
```

## Command Internal Flow

### Step 1: Config 로드

1. `.discord-webhook/config.json` 읽기
2. 있으면 → 조용히 진행
3. 없으면 → 대화형 초기 설정 플로우 (아래 참조)

### Step 2: 채널 결정

1. 첫 인자가 등록된 채널명(`webhooks`의 key)이면 → 해당 채널
2. 아니면 → 메시지 내용과 각 webhook의 `description`을 비교하여 LLM이 선택
3. 매칭 불확실 → `default`

### Step 3: 멘션 처리

1. 메시지에서 태그 의도 감지 (자연어)
2. `mentions.users` / `mentions.roles`의 별칭과 매칭
3. 매칭된 ID를 Discord 멘션 구문으로 변환:
   - 유저: `<@USER_ID>`
   - 역할: `<@&ROLE_ID>`
4. `allowed_mentions` 배열 구성 (매칭된 ID만 포함)
5. 별칭 매칭 실패 시 → 멘션 없이 발송 + 경고 표시

### Step 4: 파일 처리

- `--file <path>`: 로컬 파일 경로 존재 확인. 없으면 에러
- `--file-content <filename>`: 대화 컨텍스트에서 적절한 내용 추출 → `/tmp/<filename>`에 파일 생성

### Step 5: 발송

에이전트가 Discord payload JSON을 구성하여 `send.sh` 호출:

```json
{
  "content": "빌드 실패 <@233223>",
  "username": "Claude Bot",
  "allowed_mentions": { "users": ["233223"] }
}
```

### Step 6: 결과 보고

- HTTP 2xx → 성공 보고
- HTTP 4xx/5xx → 에러 + 응답 body 표시
- curl 실패 → 에러 + 네트워크 상태 안내

## send.sh Specification

### Interface

```bash
send.sh <webhook_url> <payload_file> [--file <path>]
```

- `<payload_file>`: Discord payload JSON이 담긴 임시 파일 경로 (shell escaping 문제 방지)

### Behavior

- 메시지만: `curl -s -w '\n%{http_code}' -H "Content-Type: application/json" -d @<payload_file> <webhook_url>`
- 파일 포함: `curl -s -w '\n%{http_code}' -F "payload_json=<$(cat <payload_file>)" -F "file=@<path>" <webhook_url>`
- stdout: HTTP 상태코드
- stderr: curl 에러 시 에러 메시지
- exit code: 0 (성공), non-zero (실패)

### Scope

send.sh는 발송만 담당. 채널 선택, 멘션 처리, 파일 생성 등 판단 로직은 discord.md(에이전트)가 수행.

## Config 초기 설정 플로우

config.json이 없을 때 대화형으로 설정을 생성:

1. "Discord webhook 설정이 없습니다. 지금 만들까요?" 확인
2. 유저 거부 → 에러로 중단
3. 유저 승인 → 순차적으로 질문:
   - a. "default webhook URL을 입력해주세요"
   - b. "추가 채널이 있으면 이름과 URL을 알려주세요 (없으면 스킵)"
   - c. "태그할 사람이나 역할이 있으면 알려주세요 (없으면 스킵)"
4. 유저가 자연어로 입력 → LLM이 파싱하여 config.json 생성
5. 원래 요청한 메시지 발송 계속

## Error Handling

| 상황 | 동작 |
|------|------|
| config.json 없음 | 대화형 초기 설정 플로우 시작 |
| 채널명 지정했으나 미등록 | 에러 + 등록된 채널 목록 표시 |
| webhook URL 형식 오류 | 에러 + 올바른 형식 안내 |
| curl 실패 (네트워크) | 에러 + HTTP 상태코드 표시 |
| Discord API 에러 (400/401/404) | 에러 + 응답 body 표시 |
| `--file` 경로 없음 | 에러 + 경로 확인 요청 |
| 멘션 별칭 매칭 실패 | 멘션 없이 발송 + "매칭 실패" 경고 표시 |

모든 에러는 명시적 실패. silent fallback 없음.

## Discord API Reference

### Mention Formats

| 대상 | 구문 |
|------|------|
| 유저 | `<@USER_ID>` |
| 역할 | `<@&ROLE_ID>` |
| @everyone | `@everyone` (텍스트) |
| @here | `@here` (텍스트) |

### allowed_mentions

```json
{
  "allowed_mentions": {
    "parse": ["users", "roles", "everyone"],
    "users": ["111222333"],
    "roles": ["444555666"]
  }
}
```

- `parse`와 개별 ID 배열을 같은 타입으로 동시 사용 불가
- 특정 대상만 멘션할 때: ID 배열 사용 (parse 생략)
- Discord ID: snowflake 포맷, 17~20자리 숫자
