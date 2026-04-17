---
allowed-tools: Bash(cm diff:*), Bash(cm cat:*), Bash(diff:*), Read
description: Compare changesets, branches, labels, or workspace file vs head — text-only (변경 비교)
argument-hint: "<spec1> <spec2>  |  <workspace-file-path>"
---

## Your task

Compare PlasticSCM objects or workspace file changes — **text-only output, never GUI**.

### ⚠ CRITICAL — Avoid GUI

`cm diff <path>` or `cm diff <cs:N> <path>` triggers the Plastic GUI viewer and blocks the CLI.
Use **only** the patterns below.

### Mode 1 — Two-spec comparison (changesets / branches / labels)

If `$ARGUMENTS` contains two specs like `cs:100 cs:200`, `br:/main/dev br:/main`, `lb:v1.0 lb:v2.0`:

```
cm diff <spec1> <spec2> --format="{path}|{status}" --nototal
```

Categorize results by status:
- **Added** — New files
- **Changed** — Modified files
- **Deleted** — Removed files
- **Moved** — Renamed/moved files

Present list per category + total counts.

### Mode 2 — Single workspace file vs head (pending change)

If `$ARGUMENTS` is one workspace path (contains `/` or `\`, no `cs:`/`br:`/`lb:` prefix):

```
cm cat "rev:<path>#cs:head" > /tmp/cm-old.tmp
diff -u /tmp/cm-old.tmp "<path>" | head -200
```

This produces unified text diff. For large prefab/scene/yaml files, pipe to `head` or filter relevant blocks.

If `cm cat` fails on `rev:path` form, try `serverpath:` form:
```
cm cat "serverpath:/full/repo/path/to/file#cs:head" > /tmp/cm-old.tmp
```

### Mode 3 — Two changesets, file-scoped

If two specs + a path (`cs:100 cs:200 <path>`):
```
cm cat "rev:<path>#cs:100" > /tmp/cm-a.tmp
cm cat "rev:<path>#cs:200" > /tmp/cm-b.tmp
diff -u /tmp/cm-a.tmp /tmp/cm-b.tmp
```

### If arguments are invalid

Ask the user to provide one of: `<spec1> <spec2>`, `<workspace-path>`, or `<cs:A> <cs:B> <path>`.

### Constraints

- **NEVER** invoke `cm diff` without explicit `cs:A cs:B` / `br:A br:B` / `lb:A lb:B` — prevents GUI.
- Do not use any other tools besides `cm diff`, `cm cat`, `diff`, `Read`.
- Clean up /tmp/cm-*.tmp files after use if possible.
