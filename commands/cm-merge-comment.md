---
allowed-tools: Bash(cm find:*), Bash(cm changeset:*), Bash(cm wi:*)
description: Collect and consolidate merge comments into the latest changeset (병합 코멘트 정리)
argument-hint: "[branch-path]"
---

## Context

- Workspace info: !`cm wi 2>/dev/null`

## Your task

Collect all comments from sub-branch changesets that were merged between the latest and previous changesets on the target branch, then consolidate them into the latest changeset's comment.

### Arguments

- If `$ARGUMENTS` contains a branch path (e.g., `/main/MacBuilder`), use that branch.
- If `$ARGUMENTS` is empty, parse the current branch from the workspace info above. Extract the branch path from the pattern `브랜치 {path}@` or `Branch {path}@`.

### Steps

1. **List changesets on the target branch:**
   ```
   cm find changeset "where branch='{branch}'" --format="{changesetid}|{date}|{comment}" --nototal
   ```
   Take the last two lines: latest (last) and previous (second-to-last).
   If there are fewer than 2 changesets, inform the user and stop.

2. **Find all merges into the target branch:**
   ```
   cm find merge "where dstbranch='{branch}'" --format="{dstchangeset}|{srcchangeset}|{srcbranch}" --nototal
   ```
   Identify merges where `dstchangeset == latest` (these are the new merges since previous).

3. **For each merge source, find the previous merge from the same source branch** to determine the changeset range. Then query sub-branch changesets in that range:
   ```
   cm find changeset "where branch='{srcbranch}' and changesetid > {prevSrcCS} and changesetid <= {srcCS}" --format="{changesetid}|{comment}" --nototal
   ```

4. **Recursively check sub-branches** (max 3 levels deep). For each source branch in the range, check if it received merges from deeper sub-branches:
   ```
   cm find merge "where dstbranch='{srcbranch}' and dstchangeset > {prevSrcCS} and dstchangeset <= {srcCS}" --format="{srcchangeset}|{srcbranch}|{srccomment}" --nototal
   ```
   For each deeper sub-branch found, collect its changesets' comments.

5. **Format the collected comments:**
   - Group by sub-branch (use the last segment of the branch path as the header)
   - Format: `[BranchShortName]` header + `- comment` list
   - Skip empty comments and remove duplicates
   - Example:
     ```
     [BugFix_Alpha2_SB]
     - Fixed build error: VolumeProfile reconnection
     - Phone UI home button added

     [Km-RealLastBugFix]
     - Scene restore bug fix
     - Furniture placement particle
     ```

6. **Show the formatted comment to the user and ask for confirmation** before applying.

7. **Apply** (only after user confirms):
   ```
   cm changeset editcomment cs:{latest} "{combined_comment}"
   ```
   Then verify by querying the changeset:
   ```
   cm find changeset "where changesetid={latest}" --format="{changesetid}|{comment}" --nototal
   ```

If no comments were found (all empty), inform the user that there are no comments to consolidate.

Do not use any other tools. Do not send any other text or messages besides these tool calls.
