---
allowed-tools:
  - Bash(cm history:*)
  - Bash(cm find:*)
  - Bash(cm log:*)
description: Show PlasticSCM change history for a file or directory. Use for "파일 이력", "change history", "누가 언제 수정".
argument-hint: "<file-or-directory-path>"
---

## Task

Display change history for the path in `$ARGUMENTS`. If empty, ask the user for a path.

### Query

`cm history "$ARGUMENTS" --format="{changesetid}|{date}|{owner}|{branch}|{comment}" --nototal`

### Present

Last 20 entries as a table: `CS# | Date | Author | Branch | Comment`.
If path doesn't exist or has no history, say so.

Use only the tools listed above.
