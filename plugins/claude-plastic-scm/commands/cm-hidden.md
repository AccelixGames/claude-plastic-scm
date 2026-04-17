---
allowed-tools:
  - Bash(cm wi:*)
  - Bash(cm status:*)
  - Read
  - Edit
  - Write
description: View and manage PlasticSCM hidden changes (hidden_changes.conf) and ignored files (ignore.conf). Use for "숨김 변경", "ignore 패턴", "hidden_changes.conf 편집".
argument-hint: "[unhide | hide | unignore | ignore]"
disable-model-invocation: true
---

## Context

- Workspace info: !`cm wi 2>/dev/null || echo "NOT_A_WORKSPACE"`

## Task

View and manage files excluded from checkin — hidden changes and ignored files.

### Step 0 — Workspace guard

If context contains `NOT_A_WORKSPACE` or is empty, stop:
- PlasticSCM workspace가 아님. hidden_changes.conf/ignore.conf는 Plastic 고유 기능.

### Reference — workspace config files

| File | Matching | Effect |
|---|---|---|
| `hidden_changes.conf` | **Filename only** (no path, one per line) | VCS tracked but hidden from default `cm status`; visible only with `--hiddenchanged` |
| `ignore.conf` | Path/pattern/glob | Excluded from VCS tracking entirely; invisible to `cm status` |

### Step 1 — Workspace root

Extract path from `cm wi` output.

### Step 2 — Gather state

1. **hidden_changes.conf**: Read `{WORKSPACE_ROOT}/hidden_changes.conf`. Report "hidden_changes.conf 없음" if missing.
2. **Hidden files actual**: `cm status --hiddenchanged --short`
3. **ignore.conf**: Read `{WORKSPACE_ROOT}/ignore.conf`. Report "ignore.conf 없음" if missing.
4. **Ignored files actual**: `cm status --ignored --short`

### Step 3 — Summary

```
## 비공개/숨김 변경 현황

### Hidden Changes (hidden_changes.conf) — 패턴 {n}개
{conf 내용 / "등록된 파일명 없음"}

### 실제 숨겨진 파일 — {n}개
{cm status --hiddenchanged 결과 / "숨겨진 변경 없음"}

### Ignore Patterns (ignore.conf) — 패턴 {n}개
{conf 요약 / "패턴 없음"}

### 실제 무시된 파일 — {n}개
{cm status --ignored 결과 / "무시된 파일 없음"}
```

### Step 4 — Actions

Based on `$ARGUMENTS` or user request.

#### `unhide` — remove from hidden_changes.conf

1. Show current entries with line numbers.
2. Ask which to remove (전체 / 선택).
3. Edit to remove selected lines (removing = immediate unhide).
4. Verify with `cm status --hiddenchanged --short`.
5. Confirm: "숨김 해제 완료: {entries} 제거됨. 파일이 기본 cm status에 표시됩니다."

#### `hide` — add to hidden_changes.conf

1. Show current pending (`cm status --short`).
2. Ask which to hide.
3. Extract **filename only** (no path). Warn if filename is common (e.g. `AssemblyInfo.cs`) — all matches will hide.
4. Append filenames to `hidden_changes.conf` (create with Write if missing, one per line).
5. Verify with `cm status --hiddenchanged --short`.
6. Confirm: "숨김 처리 완료: {filenames} 추가됨."

#### `unignore` — remove from ignore.conf

1. Show current patterns with line numbers.
2. Ask which to remove.
3. Edit to remove selected lines.
4. Verify with `cm status --ignored --short`.
5. Confirm: "제거됨: {pattern}. 이 파일들이 이제 cm status에 표시됩니다."
6. **Note:** already VCS-tracked files are not affected by ignore.conf — only untracked files.

#### `ignore` — add to ignore.conf

1. Ask which paths/patterns to ignore.
2. Append to ignore.conf (create with Write if missing).
   - Standard syntax: `*.tmp`, `path/to/dir`, `**/build/`
   - Convention: add lowercase duplicate for case-sensitivity (e.g. `*.DLL` + `*.dll`).
3. Verify with `cm status --ignored --short`.
4. Confirm: "추가됨: {pattern}"
5. **Note:** already VCS-tracked files must be un-tracked first for ignore to take effect.

#### No action — view only

Present Step 3 summary and ask: "어떤 작업을 할까? (unhide / hide / unignore / ignore / 취소)"

### Important notes

- **hidden_changes.conf vs ignore.conf:**
  - `hidden_changes.conf`: filename-only match, VCS tracked, 일시적 숨김용.
  - `ignore.conf`: path/glob match, VCS 제외, 영구적 제외용.
- **Filename match:** any file with that name anywhere in tree is hidden.
- **줄 삭제 = 즉시 반영** for both confs.
- **ignore.conf + already tracked:** adding pattern does NOT affect already-tracked files. Un-track first.
- **hidden_changes.conf 위험:** do NOT add core files like `manifest.json`, `Packages.lock` — they'll silently skip checkin. Use only for machine-specific (Mac builder etc.), and never merge to other branches.

### ignore.conf glob guide

- **Partial path glob works:** `.claude/*.local.*` matches only direct children of `.claude/` with that pattern.
- **Parent-private pitfall:** if parent folder is still `비공개` (not added), `cm status .claude --private --ignored` shows ALL children as `무시 항목` (even non-matching). Validate by `cm add` parent first, then re-check.
- **`cm add -R` is 1-level deep:** grandchildren need separate `cm add` calls. Complete folder tree adds before validating ignore state.
- **Windows symlinks unsupported:** symlinks invisible to `cm add`/`cm status` regardless of ignore patterns.

Use only the tools listed above.
