---
allowed-tools: Bash(cm wi:*), Bash(cm status:*), Bash(cm changelist:*), Read, Edit, Write
description: View and manage hidden changes and ignore patterns in PlasticSCM (비공개/숨김 변경 관리)
argument-hint: "[unhide | hide | unignore | ignore]"
---

## Context

- Workspace info: !`cm wi 2>/dev/null`

## Your task

View and manage files excluded from checkin — hidden changes (changelist-based) and ignored files (ignore.conf pattern-based).

### Step 1: Determine workspace root

Extract the workspace path from `cm wi` output.

### Step 2: Gather current state

Run these commands:

1. **Hidden changes:**
   ```
   cm status --hiddenchanged --short
   ```

2. **Changelist groups:**
   ```
   cm status --changelists --short
   ```

3. **Ignored files:**
   ```
   cm status --ignored --short
   ```

4. **ignore.conf:** Read `{WORKSPACE_ROOT}/ignore.conf` using Read tool. If not found, report "ignore.conf 없음".

### Step 3: Present summary

```
## 비공개/숨김 변경 현황

### Hidden Changes (숨겨진 변경) — {n}개
{파일 목록. 없으면 "숨겨진 변경 없음"}

### Changelists
{changelist별 파일 그룹. 없으면 "changelist 없음"}

### ignore.conf 패턴
{패턴 목록. 없으면 "패턴 없음"}

### Ignored Files (무시된 파일) — {n}개
{파일 목록. 없으면 "무시된 파일 없음"}
```

### Step 4: Handle user action

Based on `$ARGUMENTS` or user request, perform one of these actions:

#### Action: `unhide` — 숨겨진 변경을 기본 체크인 대상으로 복원

1. Show the list of hidden files and their changelists.
2. Ask which files to unhide (전체 / 선택).
3. Remove selected files from their changelist:
   ```
   cm changelist "{changelist_name}" rm "{file1}" "{file2}" ...
   ```
4. Verify with `cm status --hiddenchanged --short`.
5. Confirm: "숨김 해제 완료: {n}개 파일이 기본 체크인 대상으로 복원되었습니다."

#### Action: `hide` — 파일을 숨겨진 변경으로 이동

1. Show current pending changes (`cm status --short`).
2. Ask which files to hide.
3. Ask which changelist to use (existing or create new):
   - List existing changelists: `cm changelist`
   - To create: `cm changelist add "{name}" "{description}"`
4. Move files to the changelist:
   ```
   cm changelist "{changelist_name}" add "{file1}" "{file2}" ...
   ```
5. Verify and confirm.

#### Action: `unignore` — ignore.conf에서 패턴 제거

1. Show current ignore.conf patterns with line numbers.
2. Ask which pattern(s) to remove.
3. Edit ignore.conf using Edit tool to remove the selected lines.
4. Verify with `cm status --ignored --short` to confirm the change took effect.
5. Confirm: "제거됨: {pattern}. 이 파일들이 이제 cm status에 표시됩니다."

#### Action: `ignore` — ignore.conf에 패턴 추가

1. Ask which file paths or patterns to ignore.
2. Append to ignore.conf (create with Write if not exists).
   - Use standard PlasticSCM ignore syntax (e.g., `*.tmp`, `path/to/dir`).
3. Verify with `cm status --ignored --short`.
4. Confirm: "추가됨: {pattern}"

#### No action specified — 열람만

If no argument or action is specified, present the summary (Step 3) and ask:
"어떤 작업을 하시겠습니까? (unhide / hide / unignore / ignore / 취소)"

### Important notes

- **ignore.conf 수정 후** `cm status`를 다시 실행하여 변경 반영 확인.
- **changelist 이름**은 PlasticSCM GUI와 공유 — 이름 충돌 주의.
- **Hidden changes vs Ignore 차이:**
  - Hidden changes: VCS 추적 중이지만 체크인에서 제외 (changelist 기반, 일시적)
  - Ignore: VCS 추적 자체에서 제외 (패턴 매칭, 영구적)

Do not use any other tools. Do not send any other text or messages besides these tool calls.
