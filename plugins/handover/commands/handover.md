---
description: "Generate a handover document for the next agent session and copy to clipboard (핸드오버 문서 생성 + 클립보드 복사)"
argument-hint: "[next step hint] [--review]"
allowed-tools: Bash, Write, Read, Glob, Grep, Agent
---

# Handover Document Generator

You are generating a handover document so a NEW Claude Code session can continue this conversation's work. The new session has access to the same project (CLAUDE.md, memory, files) but has NO conversation context.

**Principle: pure transfer. Do NOT prescribe what the next session should decide. The next session decides WITH the user.**

## Step 1: Conversation Scan

Scan the conversation in REVERSE order and collect:

- [ ] User's verbatim instructions (do not paraphrase)
- [ ] Options discussed and REJECTED, with reasons
- [ ] Agreements reached but NOT recorded in any file
- [ ] Trade-offs explicitly weighed
- [ ] Work blocked, with root cause
- [ ] Open questions awaiting user decision
- [ ] If `$ARGUMENTS` has text (excluding `--review`): use as a contextual hint

The primary value of this handover is capturing what files do NOT already record.

## Step 2: Write the Handover

### Required structure

```
# Handover: <topic in 1 line>

## Status
- Done: <items>
- In progress: <items>
- Blocked: <items, with root cause>
- Pending user decision: <items with the concrete options discussed>

## Next Step
<Factual state of where we left off. If the next action depends on a user decision, write: "Next session: discuss with user — <options A / B / C>". Do NOT pick one.>
```

### After required sections: free-form

Add whatever the next session needs: absolute-path file references, reasoning chains, reverted options, etc.

### Hard rules

- English only (AI token optimization)
- Terse, no filler
- File references: absolute path as link, period. Never re-explain file contents — the next session reads the file itself
- **Content criterion**: EVERY rejected option, agreement, trade-off, and blocker from THIS conversation must be captured. Length is whatever that requires.

## Step 3: Optional Independent Review

If `$ARGUMENTS` contains `--review`, dispatch a general-purpose subagent:

- Input: draft handover text + all absolute file paths referenced in it
- Task: "You have NO context about a previous conversation. Using ONLY this handover document and the files it references, can you continue the work described in Status + Next Step? List every gap: ambiguous references, implicit assumptions, uncaptured rejected options, blockers without root cause. Do NOT suggest fixes — only identify gaps. Return JSON: { gaps: [...], severity: high|med|low }"
- Apply findings to a revised draft. **One round only** (no loops).

Skip Step 3 if `--review` is absent.

## Step 4: Save and Copy to Clipboard

Pipe the handover text via heredoc directly to the script (no `cat` — avoids rtk UTF-8 corruption):

```bash
rtk python ~/.claude/plugins/marketplaces/*/plugins/handover/scripts/handover-clip.py << 'EOF'
<handover content here>
EOF
```

**After the Bash call completes**, you MUST print the file path as plain conversation text so the user can see it outside the collapsed Bash output block. Format:

```
📋 Copied to clipboard → <file path from script output>
```

## Rules

- Do NOT re-explain file contents — link with absolute path, the next session reads it
- Do NOT repeat what CLAUDE.md or memory already says
- Do NOT decide what the next session should do — only report state
- Only THIS conversation's context
