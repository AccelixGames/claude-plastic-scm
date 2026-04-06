---
name: chatgpt-agent
description: "ChatGPT subagent — Codex CLI를 통해 ChatGPT에 작업 위임. 세컨드 오피니언, 교차 검증, 번역 톤 비교 등에 사용. Trigger: 'chatgpt한테 물어봐', 'GPT 의견', 'second opinion', '교차 검증', 'ChatGPT 비교'"
---

# ChatGPT Subagent

Claude가 Codex CLI를 통해 ChatGPT에 작업을 위임하는 래퍼.
ChatGPT Plus 구독 인증 사용 — API 크레딧 불필요.

## When to Use

- Second opinion / cross-validation of Claude's own answer
- Tasks where ChatGPT may have different strengths
- Comparing two AI responses for the user
- User explicitly requests ChatGPT involvement

## How to Call

Run via Bash from a subagent or directly:

```bash
node "<plugin-dir>/skills/chatgpt-agent/scripts/ask-chatgpt.mjs" \
  --prompt "Your question here" \
  --model "gpt-5.4" \
  --system "Optional system prompt"
```

### Parameters

| Flag | Default | Description |
|------|---------|-------------|
| `--prompt` | (required) | User prompt |
| `--model` | (codex default) | OpenAI model ID |
| `--system` | (empty) | System prompt |
| `--sandbox` | `read-only` | Codex sandbox mode |

### Output

- **stdout**: ChatGPT response text (parsed, clean)
- **stderr**: Error messages
- **exit code**: 0 on success, 1 on failure

## Prerequisites

- `codex` CLI installed: `npm install -g @openai/codex`
- ChatGPT login done: `codex login`

## Script Location

`skills/chatgpt-agent/scripts/ask-chatgpt.mjs`

## Constraints

- Do NOT send sensitive project data (API keys, credentials, internal URLs) in prompts
- Do NOT use as primary agent — this is a supplementary tool
- Always present ChatGPT's response clearly attributed as "ChatGPT의 답변"
- 5-minute timeout on all calls
