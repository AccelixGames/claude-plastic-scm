---
allowed-tools: Bash(cm find:*), Bash(cm wi:*), Bash(cm branch:*)
description: Show branch info, changesets, and merge history (브랜치 정보 조회)
argument-hint: "[branch-path]"
---

## Context

- Workspace info: !`cm wi 2>/dev/null`

## Your task

Display a comprehensive overview of the target branch.

### Arguments

- If `$ARGUMENTS` contains a branch path, use that branch.
- If empty, parse the current branch from the workspace info above.

### Steps

1. **Current branch and changeset info:**
   ```
   cm find changeset "where branch='{branch}'" --format="{changesetid}|{date}|{owner}|{comment}" --nototal
   ```
   Show the most recent changeset details.

2. **Child branches:**
   ```
   cm find branch "where parent='{branch}'" --format="{name}" --nototal
   ```
   List child branches (if any).

3. **Recent changesets** (last 10):
   Display as a formatted table with columns: CS#, Date, Owner, Comment.

4. **Merge history — Incoming** (merged INTO this branch):
   ```
   cm find merge "where dstbranch='{branch}'" --format="{dstchangeset}|{srcchangeset}|{srcbranch}|{srccomment}" --nototal
   ```
   Show the last 10 incoming merges.

5. **Merge history — Outgoing** (merged FROM this branch):
   ```
   cm find merge "where srcbranch='{branch}'" --format="{dstchangeset}|{dstbranch}|{srcchangeset}|{srccomment}" --nototal
   ```
   Show the last 10 outgoing merges.

Present everything in a clean, readable format with clear section headers.

Do not use any other tools. Do not send any other text or messages besides these tool calls.
