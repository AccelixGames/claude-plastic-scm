---
allowed-tools:
  - Bash(cm find:*)
  - Bash(cm wi:*)
  - Bash(cm branch:*)
description: Show PlasticSCM branch info — changesets, child branches, incoming/outgoing merge history. Use for "브랜치 정보", "branch info", "merge history".
argument-hint: "[branch-path]"
---

## Context

- Workspace info: !`cm wi 2>/dev/null || echo "NOT_A_WORKSPACE"`

## Task

Display an overview of the target branch.

### Step 0 — Workspace guard

If context contains `NOT_A_WORKSPACE` or is empty, stop:
- PlasticSCM workspace가 아님 — 브랜치 조회 불가.

### Step 1 — Resolve branch

- If `$ARGUMENTS` is a branch path, use it.
- Otherwise parse current branch from workspace info.

### Step 2 — Queries

1. **Latest changeset details:**
   `cm find changeset "where branch='{branch}'" --format="{changesetid}|{date}|{owner}|{comment}" --nototal`
2. **Child branches:**
   `cm find branch "where parent='{branch}'" --format="{name}" --nototal`
3. **Recent 10 changesets** — format as table: `CS# | Date | Owner | Comment`.
4. **Incoming merges (last 10):**
   `cm find merge "where dstbranch='{branch}'" --format="{dstchangeset}|{srcchangeset}|{srcbranch}|{srccomment}" --nototal`
5. **Outgoing merges (last 10):**
   `cm find merge "where srcbranch='{branch}'" --format="{dstchangeset}|{dstbranch}|{srcchangeset}|{srccomment}" --nototal`

### Step 3 — Present

Clean sections with clear headers. Use only the tools listed above.
