---
allowed-tools: Bash(cm diff:*), Bash(cm find:*)
description: Compare changesets, branches, or labels (변경 비교)
argument-hint: "<spec1> <spec2>  (e.g., cs:100 cs:200, br:/main/dev br:/main)"
---

## Your task

Compare two PlasticSCM objects and display the differences.

### Arguments

`$ARGUMENTS` should contain two object specifications separated by a space.
Supported formats:
- Changesets: `cs:100 cs:200`
- Branches: `br:/main/dev br:/main`
- Labels: `lb:v1.0 lb:v2.0`

If arguments are missing or invalid, ask the user to provide two valid specs.

### Steps

1. **Run diff:**
   ```
   cm diff $ARGUMENTS --format="{path}|{status}" --nototal
   ```

2. **Categorize results** by change type:
   - **Added** — New files
   - **Changed** — Modified files
   - **Deleted** — Removed files
   - **Moved** — Renamed/moved files

3. **Present results:**
   - List files under each category
   - Show summary with file counts per category and total

If no differences found, state that the two specs are identical.

Do not use any other tools. Do not send any other text or messages besides these tool calls.
