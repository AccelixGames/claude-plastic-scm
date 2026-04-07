---
description: "Generate a handover document for the next agent session and copy to clipboard (핸드오버 문서 생성 + 클립보드 복사)"
argument-hint: "[next step hint]"
allowed-tools: Bash, Write, Read, Glob, Grep
---

# Handover Document Generator

You are generating a handover document so a NEW Claude Code session can continue this conversation's work seamlessly. The new session has access to the same project (CLAUDE.md, memory, files) but has NO conversation context.

## Step 1: Analyze This Conversation

Scan the full conversation and identify what the next agent NEEDS to know to continue. Focus on:

- What was the task, what got done, what's left
- Reasoning, trade-offs, and agreements that are NOT recorded in any file
- If the user provided an argument: `$ARGUMENTS` — use it as the next step hint

## Step 1.5: Detect Skill Trigger

If the conversation completed a **plan or design doc** (via /office-hours, /plan-eng-review, /plan-ceo-review, or similar) and the next step is **implementation**, add this line to the Next Step section:

```
⚡ SKILL TRIGGER: Run `superpowers:executing-plans` — design doc path provided in References.
```

Detection criteria (ANY of these):
- Design doc status is APPROVED
- Eng review status is CLEARED
- User said "구현", "implement", "build it", "구현시작"
- The argument ($ARGUMENTS) implies implementation

## Step 2: Write the Handover

### Required structure (only these two are mandatory):

```
# Handover: <topic in 1 line>

## Next Step
<what the next agent should do first>
```

### Everything else: free-form

After the required sections, write whatever the next agent needs to know — in whatever structure best fits this conversation. Use headings, bullets, prose, or any mix. No prescribed sections.

### Hard rules:
- English only (AI token optimization)
- Terse, no filler
- **File references**: absolute path as link, period. Do NOT re-explain file contents — the next agent can read the file itself
  - Good: `See C:/WorkSpace/.../cooking-system/master-plan.md`
  - Bad: `The master plan describes a 3-phase approach where...` (the agent will read the file)
- Reasoning/trade-offs discussed in this conversation that are NOT in any file — this is the primary value of the handover. Write these in full.

## Step 3: Save and Copy to Clipboard

Determine the script path relative to this command file:

```bash
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/../scripts" && pwd)"
rtk python "$SCRIPT_DIR/handover-clip.py" << 'EOF'
<handover content here>
EOF
```

**After the Bash call completes**, you MUST print the file path as plain conversation text so the user can see it outside the collapsed Bash output block. Format:

```
📋 Copied to clipboard → <file path from script output>
```

## Rules

- Do NOT re-explain file contents — link with absolute path, the next agent reads it
- Do NOT repeat what CLAUDE.md or memory already says
- Only THIS conversation's context
- **Length guide**: 20–40 lines typical. Up to 80 if reasoning chain would be lost. Never exceed 100.
