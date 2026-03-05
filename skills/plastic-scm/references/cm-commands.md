# cm CLI Command Reference

Detailed reference for PlasticSCM CLI commands used by the claude-plastic-scm plugin.

## Table of Contents
1. [checkin](#checkin)
2. [status](#status)
3. [find](#find)
4. [diff](#diff)
5. [merge](#merge)
6. [history](#history)
7. [log](#log)
8. [branch](#branch)
9. [changeset](#changeset)
10. [switch](#switch)
11. [update](#update)
12. [label](#label)
13. [undo](#undo)
14. [workspace](#workspace)

---

## checkin

Save pending changes to the repository.

```
cm checkin [paths] [options]
```

| Option | Description |
|--------|-------------|
| `-c="{comment}"` | Checkin comment |
| `--commentsfile="{file}"` | Read comment from file |
| `--all` / `-a` | Include local changes and deletes |
| `--applychanged` | Include detected changes |
| `--private` | Include uncontrolled items |
| `--machinereadable` | Machine-friendly output |

**Examples:**
```bash
cm checkin -c="Fixed login bug"
cm checkin Assets/Scripts/ -c="Refactored player controller"
cm checkin --all -c="Full sync"
```

---

## status

Show workspace pending changes.

```
cm status [paths] [options]
```

| Option | Description |
|--------|-------------|
| `--short` | Path-only listing |
| `--machinereadable` | Machine-friendly output with `STATUS` header |
| `--added` | Show only added files |
| `--checkout` | Show only checked-out files |
| `--changed` | Show only changed files |
| `--deleted` | Show only deleted files |
| `--moved` | Show only moved files |
| `--private` | Show only private (untracked) files |
| `--ignored` | Show only ignored files |
| `--fullpaths` / `--fp` | Absolute paths |
| `--xml` | XML output |
| `--header` / `--noheader` | Show/hide header line |

**Examples:**
```bash
cm status
cm status --short --changed
cm status --machinereadable
```

---

## find

Execute SQL-like queries against VCS objects.

```
cm find {object} "where {conditions}" [options]
```

### Queryable Objects

| Object | Key Fields |
|--------|------------|
| `changeset` | `changesetid`, `date`, `owner`, `comment`, `branch`, `repository` |
| `branch` | `name`, `parent`, `owner`, `date`, `comment` |
| `merge` | `dstchangeset`, `srcchangeset`, `dstbranch`, `srcbranch`, `srccomment` |
| `label` | `name`, `date`, `owner`, `comment`, `changeset` |
| `revision` | `revid`, `owner`, `date`, `size`, `branch` |

### WHERE Operators
`=`, `!=`, `>`, `<`, `>=`, `<=`, `like`, `and`, `or`, `not`

### Subqueries
```sql
where branch = (SELECT cs.branch FROM changeset WHERE changesetid = 100)
```

### Options

| Option | Description |
|--------|-------------|
| `--format="{fields}"` | Custom output format |
| `--nototal` | Suppress record count |
| `--xml` | XML output |
| `on repository '{spec}'` | Target repository |

### Format Parameters

| Parameter | Available On |
|-----------|-------------|
| `{changesetid}` | changeset, merge |
| `{date}` | changeset, branch, label |
| `{owner}` | changeset, branch, label |
| `{comment}` | changeset, branch, label |
| `{branch}` | changeset, revision |
| `{name}` | branch, label |
| `{parent}` | branch |
| `{dstchangeset}` | merge |
| `{srcchangeset}` | merge |
| `{dstbranch}` | merge |
| `{srcbranch}` | merge |
| `{srccomment}` | merge |
| `{repository}` | changeset |
| `{newline}` | all |
| `{tab}` | all |

**Examples:**
```bash
# Changesets on a branch
cm find changeset "where branch='/main/Alpha2'" --format="{changesetid}|{date}|{comment}" --nototal

# Merges into a branch
cm find merge "where dstbranch='/main/MacBuilder'" --format="{dstchangeset}|{srcchangeset}|{srcbranch}" --nototal

# Changesets by author in date range
cm find changeset "where owner='user@email.com' and date > '2026-01-01'" --format="{changesetid}|{comment}" --nototal

# Child branches
cm find branch "where parent='/main/Alpha2'" --format="{name}" --nototal

# Merges in changeset range
cm find merge "where dstbranch='/main/Alpha2' and dstchangeset > 2700 and dstchangeset <= 2720" --format="{srcchangeset}|{srcbranch}|{srccomment}" --nototal
```

---

## diff

Compare files, changesets, branches, or labels.

```
cm diff {spec1} {spec2} [options]
```

### Comparison Modes

| Mode | Example |
|------|---------|
| Changesets | `cm diff cs:100 cs:200` |
| Branches | `cm diff br:/main br:/main/dev` |
| Labels | `cm diff lb:v1.0 lb:v2.0` |
| Shelves | `cm diff sh:1 sh:2` |
| Revisions | `cm diff rev:file#cs:100 rev:file#cs:200` |

### Options

| Option | Description |
|--------|-------------|
| `--format="{path}\|{status}"` | Custom output format |
| `--added` | Show only added items |
| `--changed` | Show only changed items |
| `--deleted` | Show only deleted items |
| `--moved` | Show only moved items |
| `--clean` | Exclude merge-generated differences |
| `--ignore=(eol\|whitespaces\|none)` | Ignore whitespace changes |
| `--download={path}` | Save diff content |
| `--nototal` | Suppress record count |

---

## merge

Merge changes from a source into the current workspace.

```
cm merge {source-spec} [options]
```

| Option | Description |
|--------|-------------|
| `--merge` | Actually perform the merge |
| `--cherrypicking` | Cherry-pick mode |
| `--forced` | Skip connection checks |
| `--mergetype=(onlyone\|onlysrc\|onlydst\|try\|forced)` | Merge strategy |
| `--keepsource` | Resolve conflicts with source |
| `--keepdestination` | Resolve conflicts with destination |
| `-c="{comment}"` | Merge comment |
| `--to={branch}` | Server-side merge (no workspace needed) |
| `--shelve` | Create shelve instead of changeset |

**Examples:**
```bash
cm merge br:/main/feature --merge
cm merge cs:100 --cherrypicking --merge
cm merge br:/main/hotfix --merge --keepsource
```

---

## history

Display file or directory revision history.

```
cm history {paths} [options]
```

| Option | Description |
|--------|-------------|
| `--long` | Show additional information |
| `--format="{fields}"` | Custom output format |
| `--xml` | XML output |

### Format Parameters
`{date}`, `{changesetid}`, `{branch}`, `{comment}`, `{owner}`, `{id}`, `{repository}`

**Examples:**
```bash
cm history "Assets/Scripts/Player.cs" --format="{changesetid}|{date}|{owner}|{comment}" --nototal
cm history "Assets/Scripts/" --long
```

---

## log

Get changeset revision information.

```
cm log {spec} [options]
```

| Option | Description |
|--------|-------------|
| `--from={spec}` | Range starting point |
| `--allbranches` | Include all branches |
| `--ancestors` | Show parent/merge-linked changesets |
| `--csformat="{fields}"` | Changeset format |
| `--itemformat="{fields}"` | Item format |
| `--xml` | XML output |
| `--fullpaths` | Full workspace paths |

---

## branch

Manage branches.

```
cm branch {command} [options]
```

| Command | Description |
|---------|-------------|
| `create` / `mk` | Create new branch |
| `delete` / `rm` | Delete branch |
| `rename` | Rename branch |
| `history` | Show branch history |
| `showmain` | Show main branch |
| `showmerges {file}` | Show branch merges for a file |

**Examples:**
```bash
cm branch create feature-login br:/main/Alpha2
cm branch delete br:/main/old-feature
cm branch rename br:/main/old-name br:/main/new-name
```

---

## changeset

Advanced changeset operations.

```
cm changeset {command} [options]
```

| Command | Description |
|---------|-------------|
| `move` / `mv` | Move changeset to another branch |
| `delete` / `rm` | Delete changeset |
| `editcomment` / `edit` | Edit changeset comment |

**Examples:**
```bash
cm changeset editcomment cs:2721 "Updated comment text"
cm changeset move cs:100 br:/main/target
```

---

## switch

Switch workspace to a different branch, changeset, or label.

```
cm switch {spec}
```

**Examples:**
```bash
cm switch br:/main/feature
cm switch cs:2700
cm switch lb:v1.0
```

---

## update

Update workspace with the latest changes.

```
cm update [options]
```

| Option | Description |
|--------|-------------|
| `--forced` | Force update even with conflicts |
| `--dontmerge` | Don't auto-merge |

---

## label

Manage labels (tags).

```
cm label {command} [options]
```

| Command | Description |
|---------|-------------|
| `create` / `mk` | Create label |
| `delete` / `rm` | Delete label |
| `rename` | Rename label |

**Examples:**
```bash
cm label create v1.0 cs:2721
cm label delete lb:old-label
```

---

## undo

Revert workspace changes.

```
cm undo {paths} [options]
```

**Examples:**
```bash
cm undo "Assets/Scripts/Player.cs"
cm undo --all
```

---

## workspace

Manage workspaces.

```
cm workspace {command} [options]
```

### Workspace Info
```
cm wi
```
Shows current workspace info including branch, changeset, and repository.

**Output format (Korean locale):**
```
브랜치 /main/Alpha2@RepoName@ServerName
```

**Output format (English locale):**
```
Branch /main/Alpha2@RepoName@ServerName
```
