---
description: "Generate a handover document for the next agent session and copy to clipboard (핸드오버 문서 생성 + 클립보드 복사)"
argument-hint: "[next step hint] [--review]"
allowed-tools: Bash, Write, Read, Glob, Grep, Agent
---

# Handover Document Generator

You are generating a handover document so a NEW Claude Code session can continue this conversation's work. The new session has access to the same project (CLAUDE.md, memory, files) but has NO conversation context.

**Principle: intent-anchored transfer.** Capture the fixed Intent the user is pursuing plus the current disposable state. The next session re-anchors on Intent with the user, then decides. Do NOT pick a solution for the next session — DO prescribe re-anchoring on Intent (process, not solution).

## Step 1: Conversation Scan

Scan the conversation in REVERSE order and collect:

- [ ] **Top-level Intent**: what the user ultimately wants in this conversation — the fixed target. Distinct from the current solution being attempted (solutions are disposable, intent is fixed)
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

## Intent
<Top-level purpose the user is pursuing in this conversation. The fixed target — not a description of what was attempted. Everything below is a disposable solution serving this intent.>

## Next Step
<Factual state of where we left off. Include blockers (with root cause) and pending user decisions inline. If the next action depends on a user decision, write: "Next session: discuss with user — <options A / B / C>". Do NOT pick one.>

## First Action for Next Session
Re-anchor on Intent above with the user before acting. If friction appears later, return to Intent — solutions are disposable, intent is fixed.
```

### After required sections: free-form

Add whatever the next session needs: absolute-path file references, reasoning chains, reverted options, etc.

### Hard rules

- English only (AI token optimization)
- Terse, no filler
- File references: absolute path as link, period. Never re-explain file contents — the next session reads the file itself
- **External research** (URLs, third-party repos, fetched docs investigated this session) must first be saved as a project file (e.g., `.temp/research/<source>-YYYY-MM-DD.md` with `source`/`fetched_at`/`fetched_via` frontmatter), then referenced by absolute path. Never leave an external URL reachable only via conversation history.
- **Content criterion**: EVERY rejected option, agreement, trade-off, and blocker from THIS conversation must be captured. Length is whatever that requires.

## Step 3: Optional Independent Review

If `$ARGUMENTS` contains `--review`, dispatch a general-purpose subagent WITH `model: "sonnet"` override (different model from the drafter = truly independent perspective; cheaper and faster for a constrained gap-check task):

- Input: draft handover text + all absolute file paths referenced in it
- Task prompt (verbatim):

  ```
  You have NO context about a previous conversation. Using ONLY this handover
  document and the files it references, can you continue the work described
  in Status + Next Step?

  Flag ONLY:
  - Information explicitly discussed in the conversation but not captured
  - References that cannot be resolved from the given file paths
  - Implicit assumptions about prior state
  - Blockers stated without a root cause

  Do NOT flag as gaps:
  - Criteria, rubrics, or thresholds that only the user can define
  - Future-state decisions pending user input
  - Preferences the previous session had no way to predict
  - Questions the handover explicitly defers to the next session's user discussion

  Do NOT suggest fixes — only identify gaps.

  Return JSON: { can_continue, gaps: [{issue, severity: high|med|low, evidence}], overall_assessment }
  ```

- Apply findings to a revised draft. **One round only** (no loops).

Skip Step 3 if `--review` is absent.

## Step 4: Save and Copy to Clipboard

Write the handover text to a temp file first, then pipe to the script via `<` redirection.
Do NOT use a bash heredoc (`<< 'EOF'`) — on Windows, shell layers can drop heredoc framing
and parse apostrophes in the content as unclosed shell quotes, aborting the command before
the payload is sent. `<` redirection works on bash, cmd, and PowerShell.

```bash
# 1. Write via the Write tool to a temp path (e.g. C:\tmp\handover-text.md).
# 2. Pipe to the script:
python ~/.claude/plugins/marketplaces/*/plugins/handover/scripts/handover-clip.py < /c/tmp/handover-text.md
```

**After the Bash call completes**, you MUST print the file path as plain conversation text so the user can see it outside the collapsed Bash output block. Format:

```
📋 Copied to clipboard → <file path from script output>
```

## Rules

- Do NOT re-explain file contents — link with absolute path, the next session reads it
- Do NOT repeat what CLAUDE.md or memory already says
- Do NOT pick a solution for the next session — only report state and Intent
- DO prescribe re-anchoring on Intent (it's process, not solution)
- Only THIS conversation's context
