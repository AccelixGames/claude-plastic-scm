---
allowed-tools: Bash(cm wi:*), Bash(cm status:*), Read, Edit, Write
description: View and manage hidden changes and ignore patterns in PlasticSCM (비공개/숨김 변경 관리)
argument-hint: "[unhide | hide | unignore | ignore]"
---

## Context

- Workspace info: !`cm wi 2>/dev/null`

## Your task

View and manage files excluded from checkin — hidden changes (`hidden_changes.conf`) and ignored files (`ignore.conf`).

### Reference: PlasticSCM workspace config files

| File | Matching | Effect |
|------|----------|--------|
| `hidden_changes.conf` | **Filename only** (no path, one per line) | VCS tracked but hidden from default `cm status`; visible only with `--hiddenchanged` |
| `ignore.conf` | Path/pattern/glob | Excluded from VCS tracking entirely; invisible to `cm status` |

### Step 1: Determine workspace root

Extract the workspace path from `cm wi` output.

### Step 2: Gather current state

1. **hidden_changes.conf:** Read `{WORKSPACE_ROOT}/hidden_changes.conf`. If not found, report "hidden_changes.conf 없음".

2. **Hidden changes (actual files matched):**
   ```
   cm status --hiddenchanged --short
   ```

3. **ignore.conf:** Read `{WORKSPACE_ROOT}/ignore.conf`. If not found, report "ignore.conf 없음".

4. **Ignored files (actual files matched):**
   ```
   cm status --ignored --short
   ```

### Step 3: Present summary

```
## 비공개/숨김 변경 현황

### Hidden Changes (hidden_changes.conf) — 패턴 {n}개
{hidden_changes.conf 내용. 없으면 "등록된 파일명 없음"}

### 실제 숨겨진 파일 — {n}개
{cm status --hiddenchanged 결과. 없으면 "숨겨진 변경 없음"}

### Ignore Patterns (ignore.conf) — 패턴 {n}개
{ignore.conf 내용 요약. 없으면 "패턴 없음"}

### 실제 무시된 파일 — {n}개
{cm status --ignored 결과. 없으면 "무시된 파일 없음"}
```

### Step 4: Handle user action

Based on `$ARGUMENTS` or user request, perform one of these actions:

#### Action: `unhide` — 숨김 해제 (hidden_changes.conf에서 제거)

1. Show current `hidden_changes.conf` entries with line numbers.
2. Ask which entries to remove (전체 / 선택).
3. Edit `hidden_changes.conf` using Edit tool to remove the selected lines.
   - Removing a line = immediate unhide (file returns to normal pending changes).
4. Verify with `cm status --hiddenchanged --short`.
5. Confirm: "숨김 해제 완료: {entries}가 제거되었습니다. 해당 파일이 기본 cm status에 표시됩니다."

#### Action: `hide` — 파일을 숨김 처리 (hidden_changes.conf에 추가)

1. Show current pending changes (`cm status --short`).
2. Ask which files to hide.
3. Extract the **filename only** (no path) from each selected file.
   - Example: `Assets/Scripts/Player.cs` → `Player.cs`
   - **Warning:** filename-only matching means ALL files with that name will be hidden.
   - If the filename is common (e.g., `AssemblyInfo.cs`), warn the user about broad matching.
4. Append filenames to `hidden_changes.conf` (create with Write if not exists).
   - One filename per line, no path prefix.
5. Verify with `cm status --hiddenchanged --short`.
6. Confirm: "숨김 처리 완료: {filenames}가 hidden_changes.conf에 추가되었습니다."

#### Action: `unignore` — ignore.conf에서 패턴 제거

1. Show current ignore.conf patterns with line numbers.
2. Ask which pattern(s) to remove.
3. Edit ignore.conf using Edit tool to remove the selected lines.
4. Verify with `cm status --ignored --short` to confirm the change took effect.
5. Confirm: "제거됨: {pattern}. 이 파일들이 이제 cm status에 표시됩니다."
6. **Note:** Already VCS-tracked files are not affected by ignore.conf — only untracked files.

#### Action: `ignore` — ignore.conf에 패턴 추가

1. Ask which file paths or patterns to ignore.
2. Append to ignore.conf (create with Write if not exists).
   - Use standard PlasticSCM ignore syntax: `*.tmp`, `path/to/dir`, `**/build/`
   - Convention: add lowercase duplicate for case-sensitivity (e.g., `*.DLL` + `*.dll`).
3. Verify with `cm status --ignored --short`.
4. Confirm: "추가됨: {pattern}"
5. **Note:** Already VCS-tracked files must be removed from tracking first before ignore takes effect.

#### No action specified — 열람만

If no argument or action is specified, present the summary (Step 3) and ask:
"어떤 작업을 하시겠습니까? (unhide / hide / unignore / ignore / 취소)"

### Important notes

- **hidden_changes.conf vs ignore.conf:**
  - `hidden_changes.conf`: 파일명 단순 매칭, VCS 추적 유지, 일시적 숨김용
  - `ignore.conf`: 경로/패턴/glob 매칭, VCS 추적 제외, 영구적 제외용
- **hidden_changes.conf 파일명 매칭:** 경로 없이 파일명만 기록. 경로 내 어디든 해당 이름의 파일이 있으면 모두 숨김 처리됨.
- **줄 삭제 = 즉시 반영:** 두 conf 파일 모두 줄을 삭제하면 즉시 효과가 해제됨.
- **ignore.conf와 이미 추적 중인 파일:** ignore.conf에 패턴을 추가해도 이미 VCS에 등록된 파일에는 적용되지 않음. 추적 해제 후 무시해야 함.

Do not use any other tools. Do not send any other text or messages besides these tool calls.
