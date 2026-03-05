---
allowed-tools: Bash(cm status:*), Bash(cm checkin:*), Bash(cm find:*), Bash(cm log:*)
description: PlasticSCM checkin with auto-generated comment (체크인/커밋)
---

## Context

- Workspace info: !`cm wi 2>/dev/null`
- Pending changes: !`cm status --short 2>/dev/null`
- Recent changesets (for comment style reference): !`cm find changeset "where branch = (SELECT cs.branch FROM changeset WHERE changesetid = (SELECT cs.changesetid FROM workspace))" --format="{changesetid}|{date}|{comment}" --nototal 2>/dev/null | tail -5`

## Your task

Create a PlasticSCM checkin (commit) based on the pending changes shown above.

### Steps

1. **Analyze pending changes** — Review the status output to understand what files were added, changed, deleted, or moved.

2. **Generate a comment** — Write a concise, descriptive checkin comment that summarizes the changes. If recent changesets have comments, match their style and language. If there are no recent comments to reference, write in Korean.

3. **Present for confirmation** — Show the user:
   - The list of files that will be checked in
   - The proposed comment
   - Ask for approval before proceeding

4. **Execute checkin** — Once confirmed, run:
   ```
   cm checkin -c="{comment}"
   ```

5. **Verify** — Show the resulting changeset info to confirm success.

Do not use any other tools. Do not send any other text or messages besides these tool calls.
