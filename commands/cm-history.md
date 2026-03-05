---
allowed-tools: Bash(cm history:*), Bash(cm find:*), Bash(cm log:*)
description: Show file or directory change history (파일/디렉토리 변경 이력)
argument-hint: "<file-or-directory-path>"
---

## Your task

Display the change history for the specified file or directory.

### Arguments

`$ARGUMENTS` should contain the path to a file or directory. If empty, ask the user to provide a path.

### Steps

1. **Query history:**
   ```
   cm history "$ARGUMENTS" --format="{changesetid}|{date}|{owner}|{branch}|{comment}" --nototal
   ```

2. **Format as table** — Display the last 20 entries as a clean table:
   | CS# | Date | Author | Branch | Comment |
   |-----|------|--------|--------|---------|

3. If the path doesn't exist or has no history, inform the user.

Do not use any other tools. Do not send any other text or messages besides these tool calls.
