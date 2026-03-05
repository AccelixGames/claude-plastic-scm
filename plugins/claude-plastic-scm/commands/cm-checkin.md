---
allowed-tools: Bash(cm wi:*), Bash(cm status:*), Bash(cm checkin:*), Bash(cm find:*), Bash(cm log:*), Read, Edit, Write
description: PlasticSCM checkin with smart comment generation — filters auto-generated files, supports user comments, archives filter patterns (체크인/커밋/푸시)
argument-hint: "[additional comment]"
---

## Context

- Workspace info: !`cm wi 2>/dev/null`
- Pending changes: !`cm status --short 2>/dev/null`
- Recent changesets (for comment style reference): !`cm find changeset "where branch = (SELECT cs.branch FROM changeset WHERE changesetid = (SELECT cs.changesetid FROM workspace))" --format="{changesetid}|{date}|{comment}" --nototal 2>/dev/null | tail -5`

## Your task

Create a PlasticSCM checkin (commit) with an intelligently generated comment. Filter out auto-generated files from the comment analysis, optionally collect additional user comments, and archive new filter patterns for future use.

### Step 1: Load filter patterns

**Built-in ancillary patterns** (always excluded from comment analysis):
- Extensions: `.meta`
- Directories: `Library/`, `Logs/`, `Temp/`, `obj/`, `UserSettings/`
- Files: `*.csproj`, `*.sln`, `Packages/packages-lock.json`

**Project archive** (additional patterns):
- Check if `.claude/checkin-filters.local.md` exists in the workspace root using Read.
- If it exists, load it and merge its "Ancillary Patterns" with the built-in list.
- If it does not exist, use only the built-in patterns.

### Step 2: Classify pending changes

Classify each file from `cm status --short` into three groups:

1. **Primary changes** (include in comment analysis):
   Files with extensions commonly edited directly — `.cs`, `.asset`, `.prefab`, `.unity`, `.json`, `.md`, `.txt`, `.shader`, `.cginc`, `.hlsl`, `.asmdef`, `.yaml`, `.yml`, `.xml`, `.png`, `.jpg`, `.wav`, `.mp3`, `.mat`, `.controller`, `.overrideController`, `.playable`, `.signal`, `.renderTexture`, `.lighting`, `.spriteatlas`, and any other clearly intentional file types.

2. **Ancillary changes** (exclude from comment, include in checkin):
   Files matching the built-in or archived ancillary patterns above.

3. **Unclassified** (need user decision):
   Files that don't match either group. Ask the user for each:
   - "이 파일은 코멘트 분석에 포함할까요? (주요 변경 / 자동 생성 파일)"
   - If the user says it's auto-generated, ask: "이 패턴을 앞으로도 자동 제외할까요?"
   - If yes, add the pattern to `.claude/checkin-filters.local.md` using Edit (or Write if file doesn't exist).

### Step 3: Generate comment

- Analyze only the **primary changes** to write a concise, descriptive checkin comment.
- If recent changesets have comments, match their style and language.
- If there are no recent comments to reference, write in Korean.
- If `$ARGUMENTS` contains text, treat it as additional user context and incorporate it into the comment.

### Step 4: Collect user comment (optional)

- Ask: "추가로 남기고 싶은 코멘트가 있으신가요?"
- If the user provides additional text, append it to or merge it with the generated comment.
- If the user declines, use the auto-generated comment as-is.

### Step 5: Present for confirmation

Show the user:
- **주요 변경** — List of primary change files
- **자동/부수 변경** — Count of ancillary files (collapsed, show details only if asked)
- **최종 코멘트** — The proposed comment
- Ask for approval before proceeding.

### Step 6: Execute checkin

Once confirmed, run:
```
cm checkin -c="{comment}"
```

### Step 7: Verify

1. Show the resulting changeset info to confirm success:
   ```
   cm find changeset "where changesetid = (SELECT cs.changesetid FROM workspace)" --format="{changesetid}|{date}|{comment}" --nototal
   ```

2. **Check for missed primary changes** — Run `cm status --short` again to see if any files remain pending. Cross-reference with the primary changes from Step 2:
   - If any **primary change** file still appears in pending status, it was "unchecked" and was NOT included in the checkin.
   - Warn the user: "⚠️ 다음 주요 변경 파일이 체크인되지 않았습니다:" followed by the list.
   - Ask: "추가 체크인이 필요하면 알려주세요. 또는 PlasticSCM GUI에서 해당 파일의 체크 상태를 확인해 주세요."
   - If only ancillary files remain, this is normal — do not warn.
   - If no files remain pending, the checkin is fully complete.

Do not use any other tools. Do not send any other text or messages besides these tool calls.
