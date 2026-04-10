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
15. [partial](#partial)
16. [add](#add)
17. [cat](#cat)

---

## Checkin Comment Filter Patterns (Unity Project)

Used by `/cm-checkin` to classify pending changes for smart comment generation.

### Primary Changes (include in comment analysis)

File extensions that are typically edited directly by developers:

`.cs`, `.asset`, `.prefab`, `.unity`, `.json`, `.md`, `.txt`, `.shader`, `.cginc`, `.hlsl`,
`.asmdef`, `.yaml`, `.yml`, `.xml`, `.png`, `.jpg`, `.wav`, `.mp3`, `.mat`, `.controller`,
`.overrideController`, `.playable`, `.signal`, `.renderTexture`, `.lighting`, `.spriteatlas`

### Auto-generated / Ancillary (exclude from comment, include in checkin)

Files that are auto-generated or change as a side effect of primary changes:

| Pattern | Reason |
|---------|--------|
| `*.meta` | Unity auto-generates for every asset |
| `Library/*` | Unity import cache |
| `Logs/*` | Unity editor logs |
| `Temp/*` | Unity temporary files |
| `obj/*` | Build output |
| `UserSettings/*` | Per-user editor settings |
| `*.csproj` | Auto-generated project files |
| `*.sln` | Auto-generated solution file |
| `Packages/packages-lock.json` | Auto-generated package lock |

### Project-specific Archive

Projects can define additional ancillary patterns in `.claude/checkin-filters.local.md`.
The `/cm-checkin` command reads this file and merges patterns with the built-in list.

When a user classifies an unrecognized file as auto-generated, the command offers to archive the pattern for future use.

### Notes

- This list should be updated as new auto-generated patterns are discovered
- When in doubt, ask the user whether a file should be included in comment analysis

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
cm find changeset "where branch='/main/develop'" --format="{changesetid}|{date}|{comment}" --nototal

# Merges into a branch
cm find merge "where dstbranch='/main/release'" --format="{dstchangeset}|{srcchangeset}|{srcbranch}" --nototal

# Changesets by author in date range
cm find changeset "where owner='user@email.com' and date > '2026-01-01'" --format="{changesetid}|{comment}" --nototal

# Child branches
cm find branch "where parent='/main/develop'" --format="{name}" --nototal

# Merges in changeset range
cm find merge "where dstbranch='/main/develop' and dstchangeset > 100 and dstchangeset <= 120" --format="{srcchangeset}|{srcbranch}|{srccomment}" --nototal
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
# Standard merge (workspace must be on target branch)
cm merge br:/main/feature --merge

# Server-side merge — merge source INTO target without switching branches
cm merge br:/main/feature --to=br:/main/develop --merge

# Server-side merge with comment
cm merge br:/main/feature --to=br:/main/release --merge -c="Merged feature"

# Cherry-pick specific changeset
cm merge cs:100 --cherrypicking --merge

# Merge keeping source on conflicts
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
cm branch create feature-login br:/main/develop
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
cm changeset editcomment cs:150 "Updated comment text"
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
cm switch cs:150
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
cm label create v1.0 cs:150
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
브랜치 /main/develop@MyRepo@localhost:8087
```

**Output format (English locale):**
```
Branch /main/develop@MyRepo@localhost:8087
```

---

## partial

Manage partial workspace configuration and file checkout.

In partial workspaces, files modified locally without explicit checkout have status **CH** (Changed without checkout). These files must be checked out before they can be checked in.

```
cm partial {command} {paths} [options]
```

| Command | Description |
|---------|-------------|
| `checkout` | Check out files in partial workspace (CH → CO) |
| `configure` | Configure partial workspace download paths |
| `add` | Add paths to partial workspace configuration |
| `undo` | Undo partial checkout |

**Examples:**
```bash
# Check out a single CH file
cm partial checkout "Assets/Scripts/Player.cs"

# Check out multiple CH files
cm partial checkout "Assets/Scripts/Player.cs" "Assets/Scenes/Main.unity"

# Configure partial workspace paths
cm partial configure /main/develop
```

---

## add

Register private (untracked) files for version control. Files with status **PR** (Private) must be added before they can be checked in.

```
cm add {paths} [options]
```

| Option | Description |
|--------|-------------|
| `-R` / `--recursive` | Add directories recursively |

**Examples:**
```bash
# Add a single file
cm add "Assets/Scripts/NewFile.cs"

# Add a directory (registers the directory itself)
cm add "docs/plans/"

# Add a directory and all contents recursively
cm add "docs/" -R

# Add multiple files
cm add "file1.cs" "file2.cs" "file3.cs"
```

**Note:** When adding files inside a new directory, add the parent directory first, then the files.

### Gotchas

- **`-R` only descends one level** — `cm add path/ -R` adds the immediate children of `path/` and processes one level of subfolders, but **does NOT recurse into nested grandchildren**. Folders deeper than one level appear as `이(가) 제외되었습니다.` and must be added with additional `cm add` calls targeting the inner path.
  - Example: to add `.claude/skills/nodecanvas-bt/references/*.md` you must run `cm add` separately for the references folder, then again for its files.
  - Workaround: walk the tree bottom-up or run `cm add` repeatedly per depth level until `cm status .claude --private --ignored` shows only the truly ignored files.

- **Parent-private state masks ignore evaluation** — When a parent folder is still `비공개` (private/untracked), Plastic reports **all** of its children as `무시 항목` in `cm status --ignored`, regardless of whether they actually match an `ignore.conf` pattern. Ignore matching is only re-evaluated correctly **after** the parent is added. Always add the parent first, then re-run status to see the real ignore state.

- **Windows symlinks are invisible to Plastic** — `cm add` silently skips symbolic links on Windows; `cm status` does not list them at all. Symlinks under tracked folders cannot be checked in. Re-create them locally on each workspace instead.

---

## cat

Read the contents of any file at a specific changeset directly from the server, without checking out a workspace at that revision.

```
cm cat "serverpath:{path}#cs:{id}"
```

Useful for inspecting how a config file (e.g. `hidden_changes.conf`, `manifest.json`) looked at a specific point in history when investigating which merge introduced a change.

**Examples:**
```bash
# Read a file at a specific changeset
cm cat "serverpath:/hidden_changes.conf#cs:2434"

# Compare two versions side-by-side via shell
cm cat "serverpath:/hidden_changes.conf#cs:2433" > /tmp/before.txt
cm cat "serverpath:/hidden_changes.conf#cs:2434" > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt
```
