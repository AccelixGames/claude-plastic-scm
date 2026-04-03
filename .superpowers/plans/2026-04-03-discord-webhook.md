# Discord Webhook Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Discord webhook으로 메시지/파일을 발송하는 `/discord` 슬래시 커맨드 플러그인 구현

**Architecture:** `discord.md`(LLM 판단)와 `send.sh`(curl 발송)의 분리 구조. discord.md가 config 로드, 채널 선택, 멘션 처리, 파일 준비를 지시하고, send.sh는 구성된 payload를 curl로 발송만 담당.

**Tech Stack:** Bash (curl), Claude Code plugin SDK (commands/*.md)

**Spec:** `.superpowers/specs/2026-04-03-discord-webhook-skill-design.md`

**Codebase:** `C:\Users\splus\.claude\plugins\marketplaces\accelix-ai-plugins`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `plugins/discord-webhook/.claude-plugin/plugin.json` | 플러그인 메타데이터 |
| Create | `plugins/discord-webhook/CHANGELOG.md` | 플러그인 변경 이력 |
| Create | `plugins/discord-webhook/scripts/send.sh` | curl wrapper (발송 전용) |
| Create | `plugins/discord-webhook/commands/discord.md` | 슬래시 커맨드 정의 (LLM 지시문) |
| Modify | `.claude-plugin/marketplace.json` | 새 플러그인 등록 |
| Modify | `CHANGELOG.md` | 마켓플레이스 변경 이력 추가 |

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `plugins/discord-webhook/.claude-plugin/plugin.json`
- Create: `plugins/discord-webhook/CHANGELOG.md`

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "discord-webhook",
  "version": "0.1.0",
  "description": "Discord webhook message and file delivery for Claude Code",
  "author": {
    "name": "AccelixGames",
    "email": "accelix.staff@gmail.com"
  },
  "repository": "https://github.com/AccelixGames/accelix-ai-plugins",
  "license": "MIT",
  "keywords": ["discord", "webhook", "notification", "messaging"]
}
```

- [ ] **Step 2: Create CHANGELOG.md**

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add plugins/discord-webhook/.claude-plugin/plugin.json plugins/discord-webhook/CHANGELOG.md
git commit -m "feat(discord-webhook): add plugin scaffold — plugin.json + CHANGELOG"
```

---

### Task 2: send.sh — curl wrapper

**Files:**
- Create: `plugins/discord-webhook/scripts/send.sh`

- [ ] **Step 1: Create send.sh**

```bash
#!/usr/bin/env bash
# Discord webhook sender — curl wrapper
# Usage: send.sh <webhook_url> <payload_file> [--file <path>]
#
# <payload_file>: JSON file containing the Discord message payload
# --file <path>: optional file attachment (sent as multipart/form-data)
#
# stdout: HTTP response body (if any) + status code on last line
# exit code: 0 if HTTP 2xx, 1 otherwise

set -euo pipefail

webhook_url="${1:?Usage: send.sh <webhook_url> <payload_file> [--file <path>]}"
payload_file="${2:?Usage: send.sh <webhook_url> <payload_file> [--file <path>]}"

# Validate inputs
if [ ! -f "$payload_file" ]; then
    echo "ERROR: payload file not found: $payload_file" >&2
    exit 1
fi

# Parse optional --file argument
attach_file=""
shift 2
while [ $# -gt 0 ]; do
    case "$1" in
        --file)
            attach_file="${2:?--file requires a path argument}"
            if [ ! -f "$attach_file" ]; then
                echo "ERROR: attachment file not found: $attach_file" >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Send request
if [ -z "$attach_file" ]; then
    # Text-only message
    response=$(curl -s -w '\n%{http_code}' \
        -H "Content-Type: application/json" \
        -d "@${payload_file}" \
        "$webhook_url" 2>&1)
else
    # Message with file attachment (multipart/form-data)
    payload_json=$(cat "$payload_file")
    response=$(curl -s -w '\n%{http_code}' \
        -F "payload_json=${payload_json}" \
        -F "file=@${attach_file}" \
        "$webhook_url" 2>&1)
fi

# Extract HTTP status code (last line)
http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | sed '$d')

# Output body if present
[ -n "$body" ] && echo "$body"

# Report status
if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo "$http_code"
    exit 0
else
    echo "$http_code" >&2
    exit 1
fi
```

- [ ] **Step 2: Make send.sh executable**

Run: `chmod +x plugins/discord-webhook/scripts/send.sh`

- [ ] **Step 3: Verify send.sh syntax**

Run: `bash -n plugins/discord-webhook/scripts/send.sh`
Expected: no output (syntax OK)

- [ ] **Step 4: Commit**

```bash
git add plugins/discord-webhook/scripts/send.sh
git commit -m "feat(discord-webhook): add send.sh — curl wrapper for webhook delivery"
```

---

### Task 3: discord.md — Command Definition

**Files:**
- Create: `plugins/discord-webhook/commands/discord.md`

This is the core of the plugin. The command file instructs the LLM on how to handle `/discord` invocations. It follows the `cm-checkin.md` pattern: YAML frontmatter + context section + numbered steps.

- [ ] **Step 1: Create discord.md**

```markdown
---
allowed-tools: Bash(bash *send.sh*), Read, Write
description: Send message to Discord via webhook (디스코드 웹훅 메시지 발송)
argument-hint: "[channel] \"message\" [--file path] [--file-content filename]"
---

## Context

- Config: !`cat .discord-webhook/config.json 2>/dev/null || echo "CONFIG_NOT_FOUND"`

## Your task

Send a Discord message via webhook. Parse the user's arguments, resolve the target channel and mentions from config, then deliver via `send.sh`.

### Arguments

The user provides arguments in this format:

```
[channel] "message" [--file path] [--file-content filename]
```

- `channel` (optional): a webhook key name from config. If omitted, auto-select based on message content.
- `message` (required): the message text, may contain natural-language mention intent (e.g., "기민한테 알려줘").
- `--file path` (optional): attach a local file.
- `--file-content filename` (optional): extract relevant content from the conversation context, write it to `/tmp/<filename>`, and attach it.

### Step 1: Load config

Read `.discord-webhook/config.json` using the Read tool.

- If the file exists, proceed silently to Step 2.
- If `CONFIG_NOT_FOUND` appeared in Context above, ask the user:

  > "Discord webhook 설정이 없습니다. 지금 만들까요?"

  If the user agrees, ask sequentially:
  1. "default webhook URL을 입력해주세요"
  2. "추가 채널이 있으면 이름, URL, 설명을 알려주세요 (없으면 스킵)"
  3. "태그할 사람이나 역할이 있으면 알려주세요 (없으면 스킵)"

  Parse the user's natural-language responses into the config schema below and write `.discord-webhook/config.json`:

  ```json
  {
    "webhooks": {
      "default": {
        "url": "<webhook_url>",
        "description": "<purpose>"
      }
    },
    "mentions": {
      "users": {},
      "roles": {}
    },
    "username": "Claude Bot",
    "avatar_url": null
  }
  ```

  Then continue to Step 2 with the original message.

  If the user declines, stop and report: "config 없이는 발송할 수 없습니다."

### Step 2: Select channel

Determine which webhook to use:

1. Check if the first argument matches a key in `webhooks` (e.g., `build-log`, `design-review`). If so, use that channel and treat the remaining text as the message.
2. If the first argument does NOT match any webhook key, treat the entire input as the message. Compare the message content against each webhook's `description` field and select the best match.
3. If no description clearly matches, use `default`.

If a channel name was explicitly provided but does not exist in config, stop and report the error with the list of registered channel names.

### Step 3: Process mentions

Scan the message for mention intent (natural-language references to people or teams).

For each detected mention intent:
1. Search `mentions.users` values (comma-separated aliases) for a match.
2. Search `mentions.roles` values (comma-separated aliases) for a match.
3. If matched, insert the Discord mention syntax into the message:
   - User: `<@USER_ID>` (e.g., "기민한테 알려줘" → matched ID `233223` → append `<@233223>`)
   - Role: `<@&ROLE_ID>` (e.g., "개발팀 확인" → matched ID `445566` → append `<@&445566>`)
4. Build `allowed_mentions` with only the matched IDs:
   - `"users": ["233223"]` for matched user IDs
   - `"roles": ["445566"]` for matched role IDs
   - Do NOT use `"parse"` array together with ID arrays.
5. If no mention alias matches, send the message without mentions and warn: "멘션 별칭을 찾지 못했습니다: <원본 표현>"

If there is no `mentions` section in config or no mention intent detected, skip this step.

### Step 4: Prepare files

- If `--file <path>` is present: verify the file exists with `ls <path>`. If not found, stop and report the error.
- If `--file-content <filename>` is present: review the conversation context, extract the most relevant content for the user's request, and write it to `/tmp/<filename>` using the Write tool.
- Both flags may be used together. If so, only one file can be attached to a single Discord message. Prefer `--file` if both are present (attach the local file; include `--file-content` text in the message body instead).

### Step 5: Construct payload and send

Build the Discord webhook payload as a JSON file:

```json
{
  "content": "<final message with Discord mention syntax>",
  "username": "<from config, or 'Claude Bot'>",
  "allowed_mentions": {
    "users": ["<matched_user_ids>"],
    "roles": ["<matched_role_ids>"]
  }
}
```

If `avatar_url` is set in config (non-null), include it in the payload.

Write the payload to `/tmp/discord-payload.json` using the Write tool, then invoke send.sh:

**Without file attachment:**
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/send.sh" "<webhook_url>" "/tmp/discord-payload.json"
```

**With file attachment:**
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/send.sh" "<webhook_url>" "/tmp/discord-payload.json" --file "<file_path>"
```

### Step 6: Report result

- If send.sh exits 0: report success with the channel name used and a brief summary.
- If send.sh exits non-zero: report the HTTP status code and response body. Common errors:
  - 400: malformed payload (check JSON structure)
  - 401: invalid webhook token
  - 404: webhook URL deleted or wrong
  - 429: rate limited (retry after the indicated time)

Do not use any other tools. Do not send any other text or messages besides these tool calls.
```

- [ ] **Step 2: Review discord.md against spec**

Verify the following spec requirements are covered:
- Config schema with webhooks (named + description) and mentions (users/roles + aliases): **Step 1** ✓
- Channel auto-selection via description matching: **Step 2** ✓
- Natural-language mention detection and alias matching: **Step 3** ✓
- `--file` local file attachment: **Step 4** ✓
- `--file-content` context extraction: **Step 4** ✓
- `allowed_mentions` with ID arrays (no `parse` + ID conflict): **Step 3** ✓
- Config initialization flow: **Step 1** ✓
- Error handling (all cases from spec table): **Steps 1-6** ✓
- No silent fallbacks: all error paths report explicitly ✓

- [ ] **Step 3: Commit**

```bash
git add plugins/discord-webhook/commands/discord.md
git commit -m "feat(discord-webhook): add /discord command — channel selection, mentions, file attach"
```

---

### Task 4: Marketplace Registration

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CHANGELOG.md` (root)

- [ ] **Step 1: Update marketplace.json**

Add the new plugin entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "discord-webhook",
  "description": "Discord webhook message and file delivery — multi-channel, natural-language mentions, file attachments",
  "version": "0.1.0",
  "author": {
    "name": "AccelixGames",
    "email": "accelix.staff@gmail.com"
  },
  "source": "./plugins/discord-webhook",
  "category": "communication"
}
```

Append this object to the end of the existing `plugins` array.

- [ ] **Step 2: Update root CHANGELOG.md**

Add a new version entry at the top of `CHANGELOG.md` (below the header, above the latest existing entry):

```markdown
## [2.1.0] - 2026-04-03

### 추가
- discord-webhook v0.1.0: Discord webhook 메시지/파일 발송 플러그인 — 다중 채널, 자연어 멘션, 파일 첨부
```

- [ ] **Step 3: Security review**

Run the security check to ensure no personal info leaked:

```bash
cd /c/Users/splus/.claude/plugins/marketplaces/accelix-ai-plugins
grep -rn "MaidCafe\|ProjectMaid\|MacBuilder\|Alpha2\|splus" plugins/discord-webhook/ || echo "CLEAN"
```

Expected: `CLEAN`

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "feat(marketplace): register discord-webhook v0.1.0"
```

---

### Task 5: Verification

- [ ] **Step 1: Verify plugin structure**

```bash
find plugins/discord-webhook/ -type f | sort
```

Expected output:
```
plugins/discord-webhook/.claude-plugin/plugin.json
plugins/discord-webhook/CHANGELOG.md
plugins/discord-webhook/commands/discord.md
plugins/discord-webhook/scripts/send.sh
```

- [ ] **Step 2: Verify send.sh is executable**

```bash
ls -la plugins/discord-webhook/scripts/send.sh | grep -c "x"
```

Expected: `1` or more (has execute permission)

- [ ] **Step 3: Verify marketplace.json is valid JSON**

```bash
cat .claude-plugin/marketplace.json | jq '.plugins | length'
```

Expected: `4` (was 3, now 4 with discord-webhook)

- [ ] **Step 4: Dry-run send.sh with invalid URL (verify error handling)**

```bash
echo '{"content":"test"}' > /tmp/discord-test-payload.json
bash plugins/discord-webhook/scripts/send.sh "https://discord.com/api/webhooks/invalid/test" "/tmp/discord-test-payload.json" 2>&1; echo "EXIT:$?"
```

Expected: HTTP error code (401 or 404) + `EXIT:1`

- [ ] **Step 5: Functional test (requires real webhook)**

If a real webhook URL is available, test end-to-end:

```bash
echo '{"content":"Plugin verification test from Claude Code"}' > /tmp/discord-test-payload.json
bash plugins/discord-webhook/scripts/send.sh "<REAL_WEBHOOK_URL>" "/tmp/discord-test-payload.json"
```

Expected: `204` (Discord returns 204 No Content on success) + message appears in Discord channel.

If no real webhook is available, skip this step — functional testing will happen on first `/discord` invocation.
