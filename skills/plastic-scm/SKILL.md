---
name: plastic-scm
description: >
  PlasticSCM (Unity Version Control) knowledge base and cm CLI reference.
  Auto-triggers when the user discusses PlasticSCM, Unity Version Control,
  cm commands, changeset queries, branch management, merge operations,
  workspace status, or VCS workflows in a PlasticSCM workspace.
  Use this skill whenever the user needs help with cm CLI syntax, PlasticSCM
  concepts, or troubleshooting VCS issues — even if they don't explicitly
  mention "PlasticSCM" but are clearly working in a cm-managed workspace.
  Korean triggers: "플라스틱", "체인지셋", "cm 명령", "병합", "브랜치",
  "체크인", "워크스페이스", "변경 이력", "라벨"
tools: Bash, Read
---

# PlasticSCM (Unity Version Control) Knowledge Base

This skill provides cm CLI reference and PlasticSCM workflow knowledge.
For detailed command documentation, see `references/cm-commands.md`.

## Quick Reference — Most Used Commands

| Purpose | Command |
|---------|---------|
| Current branch | `cm wi` |
| Workspace status | `cm status` / `cm status --short` |
| Checkin (commit) | `cm checkin -c="{comment}"` |
| Switch branch | `cm switch br:{branch}` |
| Update workspace | `cm update` |
| Create branch | `cm branch create {name} br:{parent}` |
| Find changesets | `cm find changeset "where branch='{br}'" --format="{changesetid}\|{date}\|{comment}" --nototal` |
| Find merges | `cm find merge "where dstbranch='{br}'" --format="{dstchangeset}\|{srcchangeset}\|{srcbranch}" --nototal` |
| File history | `cm history "{path}" --format="{changesetid}\|{date}\|{owner}\|{comment}" --nototal` |
| Diff changesets | `cm diff cs:{a} cs:{b} --format="{path}\|{status}" --nototal` |
| Edit CS comment | `cm changeset editcomment cs:{id} "{comment}"` |
| Merge branch | `cm merge br:{source} --merge` |
| Undo changes | `cm undo "{path}"` |

## Object Specifications

| Type | Format | Example |
|------|--------|---------|
| Changeset | `cs:{id}` | `cs:2721` |
| Branch | `br:{path}` | `br:/main/Alpha2` |
| Label | `lb:{name}` | `lb:v1.0` |
| Shelve | `sh:{id}` | `sh:5` |
| Revision | `rev:{path}#cs:{id}` | `rev:file.cs#cs:100` |
| Repository | `rep:{name}@{server}` | `rep:MyRepo@unity` |

## Find Query System

The `cm find` command supports SQL-like queries against VCS objects.

### Queryable Objects
`changeset`, `branch`, `merge`, `label`, `revision`, `attribute`

### WHERE Conditions
```
cm find changeset "where branch='{path}'"
cm find changeset "where owner='{email}' and date > '{date}'"
cm find merge "where dstbranch='{path}' and dstchangeset > {id}"
cm find branch "where parent='{path}'"
```

### Format Parameters
`{changesetid}`, `{date}`, `{owner}`, `{comment}`, `{branch}`, `{name}`,
`{path}`, `{type}`, `{status}`, `{repository}`, `{server}`

### Common Options
- `--nototal` — Suppress record count line
- `--format="{...}"` — Custom output format
- `--xml` — XML output

## Available Plugin Commands

This plugin also provides slash commands for common workflows:

| Command | Purpose |
|---------|---------|
| `/cm-checkin` | Checkin with auto-generated comment |
| `/cm-merge-comment` | Consolidate merge comments |
| `/cm-branch-info` | Branch overview and merge history |
| `/cm-status` | Categorized workspace status |
| `/cm-history` | File/directory change history |
| `/cm-diff` | Compare changesets/branches/labels |

## Troubleshooting

### Common Issues

- **"cm: command not found"** — PlasticSCM CLI is not installed or not in PATH.
  Install from Unity Hub or download from plasticscm.com.

- **"not in a workspace"** — The current directory is not a PlasticSCM workspace.
  Navigate to a workspace root or create one with `cm workspace create`.

- **Merge conflicts** — Use `cm merge br:{source} --merge` and resolve conflicts
  with `cm resolveconflict`.

- **Korean output** — The cm CLI outputs messages in the system locale.
  Branch info from `cm wi` may be in Korean (e.g., "브랜치" instead of "Branch").
  Parse accordingly.

### Information Supplementation

If this skill lacks information about a specific cm command or feature:
1. Run `cm help {command}` to get the built-in documentation
2. Check `references/cm-commands.md` for detailed option lists
3. If the information is useful, consider adding it to the reference file
