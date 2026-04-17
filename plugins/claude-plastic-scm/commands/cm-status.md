---
allowed-tools:
  - Bash(cm status:*)
  - Bash(cm wi:*)
description: Show PlasticSCM workspace pending changes grouped by Added/Changed/Deleted/Moved/Private. Use for "cm status", "워크스페이스 상태", "pending changes".
---

## Context

- Workspace info: !`cm wi 2>/dev/null || echo "NOT_A_WORKSPACE"`
- Full status: !`cm status 2>/dev/null || echo "NOT_A_WORKSPACE"`

## Task

Present the workspace status cleanly.

### Step 0 — Workspace guard

If context above contains `NOT_A_WORKSPACE` or is empty, stop immediately:
- 이 디렉토리는 PlasticSCM workspace가 아님. git repo일 가능성 — `/commit` 계열 사용 권장.

### Step 1 — Branch context

Show current branch + changeset from workspace info.

### Step 2 — Categorize

Group `cm status` output into: **Added**, **Changed**, **Deleted**, **Moved**, **Private** (untracked).

### Step 3 — Summary

Counts per category + total. If no pending changes, state workspace is clean.

Use only the tools listed above.
