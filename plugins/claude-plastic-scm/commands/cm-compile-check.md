---
allowed-tools: Bash(ls:*), Bash(cat:*), Bash(tail:*), Bash(grep:*), Read
description: Check Unity compile errors from Editor.log (Unity 컴파일 에러 확인)
---

## Context

- Workspace info: !`cm wi 2>/dev/null`

## Your task

Check whether the Unity project has compile errors by inspecting the Unity Editor log.

### Step 1: Determine project path

Extract the workspace path from `cm wi` output. This is the Unity project root (contains `Assets/`, `Library/`, `Temp/`).

### Step 2: Check Unity is running

```bash
ls -la "{PROJECT_PATH}/Temp/UnityLockfile" 2>/dev/null && echo "UNITY_RUNNING" || echo "UNITY_NOT_RUNNING"
```

- If `UNITY_NOT_RUNNING` → report "Unity 에디터가 실행 중이 아닙니다. 컴파일 상태를 확인할 수 없습니다." and stop.

### Step 3: Extract compile errors from Editor.log

```bash
cat "$APPDATA/../Local/Unity/Editor/Editor.log" 2>/dev/null | grep -i "error CS\|## Script Compilation Error" | tail -30
```

### Step 4: Determine current compile status

Check whether errors are from the latest compilation or already resolved:

```bash
tail -100 "$APPDATA/../Local/Unity/Editor/Editor.log" 2>/dev/null | grep -i "error CS\|Reloading assemblies after finishing script compilation"
```

**Interpretation:**
- If `Reloading assemblies after finishing script compilation` appears AFTER the last `error CS` line (or no `error CS` exists) → **no current errors**
- If `error CS` lines appear AFTER the last `Reloading assemblies` line → **active compile errors**

### Step 5: Report results

**No errors:**
- "Unity 컴파일 에러 없음 (정상)"

**Active errors:**
- List each unique error (deduplicate repeated lines from multiple compilation attempts):
  ```
  Unity 컴파일 에러 {n}개:
  - {파일경로}({줄},{컬럼}): error CS{코드}: {메시지}
  - ...
  ```
- Suggest: "에러를 수정한 후 다시 확인해 주세요."

Do not use any other tools. Do not send any other text or messages besides these tool calls.
