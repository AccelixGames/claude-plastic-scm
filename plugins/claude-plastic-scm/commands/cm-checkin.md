---
allowed-tools:
  - Bash(cm wi:*)
  - Bash(cm status:*)
  - Bash(cm checkin:*)
  - Bash(cm find:*)
  - Bash(cm log:*)
  - Bash(cm partial:*)
  - Bash(cm add:*)
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(tail:*)
  - Bash(grep:*)
  - Read
  - Edit
  - Write
description: PlasticSCM checkin with smart Korean comment generation — filters auto-generated files, collects user context, verifies Unity compile, explicitly lists files to avoid silent skips. Use for "체크인", "커밋", "push to Plastic", "변경사항 올려".
argument-hint: "[additional comment]"
disable-model-invocation: true
---

## Context

- Workspace info: !`cm wi 2>/dev/null || echo "NOT_A_WORKSPACE"`
- Pending changes: !`cm status --short 2>/dev/null || echo "NOT_A_WORKSPACE"`
- Recent changesets (tone reference): !`cm find changeset "where branch = (SELECT cs.branch FROM changeset WHERE changesetid = (SELECT cs.changesetid FROM workspace))" --format="{changesetid}|{date}|{comment}" --nototal 2>/dev/null | tail -5`

## Task

Create a PlasticSCM checkin with intelligent Korean comment + safe file inclusion.

### Step 0 — Workspace guard

If context contains `NOT_A_WORKSPACE` or is empty, stop:
- PlasticSCM workspace가 아님. git repo면 `/commit`/`/ship` 사용.

### Step 1 — Filter patterns

**Built-in ancillary** (excluded from comment, kept in checkin):
- Extensions: `.meta`
- Directories: `Library/`, `Logs/`, `Temp/`, `obj/`, `UserSettings/`
- Files: `*.csproj`, `*.sln`, `Packages/packages-lock.json`

**Project archive** — read `.claude/checkin-filters.local.md` at workspace root; merge "Ancillary Patterns" if present.

### Step 2 — Classify

From `cm status --short`:
1. **Primary** (include in comment analysis): common editable extensions — `.cs`, `.asset`, `.prefab`, `.unity`, `.json`, `.md`, `.txt`, `.shader`, `.cginc`, `.hlsl`, `.asmdef`, `.yaml`, `.yml`, `.xml`, `.png`, `.jpg`, `.wav`, `.mp3`, `.mat`, `.controller`, `.overrideController`, `.playable`, `.signal`, `.renderTexture`, `.lighting`, `.spriteatlas`, etc.
2. **Ancillary** (exclude from comment, include in checkin): matches patterns above.
3. **Unclassified** — ask per file:
   - "이 파일은 코멘트 분석에 포함할까? (주요 변경 / 자동 생성 파일)"
   - If auto-generated: "이 패턴을 앞으로도 자동 제외할까?"
   - If yes, append pattern to `.claude/checkin-filters.local.md` (Edit or Write).

### Step 3 — Generate comment

Analyze **primary only**.

**Format — bullet list:**
```
- 작업 내용 1
- 작업 내용 2
```

Each bullet = one logical change. Group related files.

**Prefix rules** — each bullet MUST start with a category prefix:

| Prefix | Usage | Example |
|---|---|---|
| (없음) | 신규 기능·콘텐츠 추가 | `- 플레이 테이블 시스템 구현` |
| `수정:` | 버그 수정 | `- 수정: 연속퇴장 버그` |
| `변경:` | 기존 동작·구조 변경 | `- 변경: CustomerSpawner → SO 기반 파이프라인` |
| `제거:` | 코드·에셋 삭제 | `- 제거: 미사용 CustomerPool 클래스` |
| `리팩토링:` | 동작 변경 없는 구조 개선 | `- 리팩토링: Actor.Customer 네임스페이스 통일` |

- No prefix = 신규 추가 (default).
- Prefix + 설명은 같은 줄에.
- Language: **한국어**. Code identifiers: original.
- If `$ARGUMENTS` has text, treat as user context and merge.
- Reference tone of recent changesets but always follow bullet format.

### Step 4 — Optional user comment

- Ask: "추가로 남기고 싶은 코멘트가 있어?"
- If yes, append/merge with generated.
- If no, use auto-generated.

### Step 5 — Confirmation

Show:
- **주요 변경** — primary file list (WILL be checked in).
- **자동/부수 변경** — ancillary count (collapsed; expand on request).
- **최종 코멘트** — the proposed comment.
- Ask: "위 파일들을 체크인. 제외할 파일 있으면 알려줘."
- Remove excluded files before proceeding.

### Step 6 — Prepare files

Parse status codes via `cm status --machinereadable` for each confirmed file.

**Status codes:**

| Code | Meaning | Action |
|---|---|---|
| CO | Checked out | Ready |
| AD | Added (already `cm add`ed) | Ready |
| CH | Changed without checkout | `cm partial checkout "{file}"` |
| PR | Private (untracked) | `cm add "{file}"` |

1. **CH files:** `cm partial checkout "{file}"`
2. **PR files:**
   - If inside a new PR directory, `cm add` the directory first.
   - Then `cm add "{file}"`
3. Summary: "전처리 완료: CH {n}개 checkout, PR {n}개 add"
4. On pre-processing failure → show error, ask how to proceed.

### Step 7 — Compile error check

1. Unity running?
   ```bash
   ls -la "{PROJECT_PATH}/Temp/UnityLockfile" 2>/dev/null && echo "UNITY_RUNNING" || echo "UNITY_NOT_RUNNING"
   ```
   If `UNITY_NOT_RUNNING` → skip this step.

2. Current status:
   ```bash
   tail -100 "$APPDATA/../Local/Unity/Editor/Editor.log" 2>/dev/null | grep -i "error CS\|Reloading assemblies after finishing script compilation"
   ```

3. **Interpretation:**
   - `Reloading assemblies` AFTER last `error CS` (or no errors) → proceed to Step 8.
   - `error CS` AFTER last `Reloading assemblies` → **active errors**.

4. **On active errors:**
   - List deduplicated unique errors.
   - Ask: "컴파일 에러가 있음. 그래도 체크인 진행?"
   - Decline → stop. Confirm → Step 8.

### Step 8 — Execute checkin

**Always explicitly list all files** — guarantees inclusion regardless of GUI check state:
```
cm checkin "{file1}" "{file2}" ... -c="{comment}"
```

- Include both primary and ancillary.
- Quote each path (handles spaces).
- If >30 files, split into batches with the same comment.

**CRITICAL:** Do NOT run bare `cm checkin -c="{comment}"` without file args — it commits only "checked" files in the GUI, silently skipping unchecked primary changes.

### Step 9 — Verify

```
cm find changeset "where changesetid = (SELECT cs.changesetid FROM workspace)" --format="{changesetid}|{date}|{comment}" --nototal
```

Show resulting changeset info to confirm success.

Use only the tools listed above.
