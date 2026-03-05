---
allowed-tools: Bash(cm status:*), Bash(cm wi:*)
description: Show workspace status grouped by change type (워크스페이스 상태)
---

## Context

- Workspace info: !`cm wi 2>/dev/null`
- Full status: !`cm status 2>/dev/null`

## Your task

Parse and present the workspace status in a clean, organized format.

### Steps

1. **Show branch context** — Display the current branch and changeset from workspace info.

2. **Categorize changes** — Group the status output by change type:
   - **Added** — New files added to version control
   - **Changed** — Modified files
   - **Deleted** — Removed files
   - **Moved** — Renamed or moved files
   - **Private** — Untracked files (not under version control)

3. **Summary** — Show file counts per category and total.

If there are no pending changes, simply state that the workspace is clean.

Do not use any other tools. Do not send any other text or messages besides these tool calls.
