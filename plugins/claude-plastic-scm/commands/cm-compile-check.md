---
allowed-tools:
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(tail:*)
  - Bash(grep:*)
  - Bash(cm wi:*)
  - Read
description: Check Unity compile errors from Editor.log for the current PlasticSCM workspace. Use for "Unity 컴파일 에러", "compile check", "Unity 빌드 상태".
---

## Context

- Workspace info: !`cm wi 2>/dev/null || echo "NOT_A_WORKSPACE"`

## Task

Check whether the Unity project has compile errors via Editor.log.

### Step 0 — Workspace guard

If context contains `NOT_A_WORKSPACE` or is empty, either:
- Ask the user to confirm cwd is the Unity project root, or stop.

### Step 1 — Project path

Parse workspace path from `cm wi` output (contains `Assets/`, `Library/`, `Temp/`).

### Step 2 — Unity running?

```bash
ls -la "{PROJECT_PATH}/Temp/UnityLockfile" 2>/dev/null && echo "UNITY_RUNNING" || echo "UNITY_NOT_RUNNING"
```

If `UNITY_NOT_RUNNING` → report "Unity 에디터가 실행 중이 아님. 컴파일 상태 확인 불가." and stop.

### Step 3 — Extract errors

```bash
cat "$APPDATA/../Local/Unity/Editor/Editor.log" 2>/dev/null | grep -i "error CS\|## Script Compilation Error" | tail -30
```

### Step 4 — Current status

```bash
tail -100 "$APPDATA/../Local/Unity/Editor/Editor.log" 2>/dev/null | grep -i "error CS\|Reloading assemblies after finishing script compilation"
```

**Interpretation:**
- `Reloading assemblies after finishing script compilation` AFTER last `error CS` (or no `error CS`) → **no current errors**.
- `error CS` AFTER last `Reloading assemblies` → **active errors**.

### Step 5 — Report

**No errors:** "Unity 컴파일 에러 없음 (정상)"

**Active errors:** deduplicate repeated lines and list:
```
Unity 컴파일 에러 {n}개:
- {파일}({줄},{컬럼}): error CS{코드}: {메시지}
```
Suggest: "에러 수정 후 다시 확인."

Use only the tools listed above.
