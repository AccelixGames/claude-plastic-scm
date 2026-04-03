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
