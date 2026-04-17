---
allowed-tools:
  - Bash(cm merge:*)
  - Bash(cm find:*)
  - Bash(cm changeset:*)
  - Bash(cm wi:*)
description: Server-side merge current PlasticSCM branch into target branch + consolidate sub-branch comments into the resulting merge changeset. Use for "서버 사이드 병합", "merge with comment consolidation", "sub-branch 코멘트 정리".
argument-hint: "<target-branch-path>"
disable-model-invocation: true
---

## Context

- Workspace info: !`cm wi 2>/dev/null || echo "NOT_A_WORKSPACE"`

## Task

Server-side merge (no workspace switch), then collect + consolidate all sub-branch comments into the merge changeset.

### Step 0 — Workspace guard

If context contains `NOT_A_WORKSPACE` or is empty, stop:
- PlasticSCM workspace가 아님. git repo면 `git merge`/PR 사용.

### Args

- `$ARGUMENTS` = target branch path (e.g. `/main/release`).
- If empty, ask: "어떤 브랜치로 병합할까? (예: /main/release)"

Source branch = current workspace branch.

### Step 1 — Confirm direction

Show merge direction and ask confirmation:
- **소스 (현재):** `{source}`
- **대상:** `{target}`
- "위 방향으로 서버 사이드 병합 진행?"

### Step 2 — Execute merge

```
cm merge br:{source} --to=br:{target} --merge
```

- Success → Step 3.
- Conflicts → show error, stop. Inform: "충돌 발생. GUI에서 해결하거나, 워크스페이스를 대상 브랜치로 전환 후 수동 병합."
- Nothing to merge → inform, stop.

### Step 3 — Latest changesets on target

```
cm find changeset "where branch='{target}'" --format="{changesetid}|{date}|{comment}" --nototal
```

Take last 2 rows: `latest` (last) and `prev` (2nd-to-last).
If only 1 changeset exists, merge created the first one — skip comment collection, use latest only.

### Step 4 — Find merges into target

```
cm find merge "where dstbranch='{target}'" --format="{dstchangeset}|{srcchangeset}|{srcbranch}" --nototal
```

Filter rows where `dstchangeset == latest` — these are new merges since `prev`.

### Step 5 — Collect sub-branch comments

For each merge source, find previous merge from same source to determine changeset range:
```
cm find changeset "where branch='{srcbranch}' and changesetid > {prevSrcCS} and changesetid <= {srcCS}" --format="{changesetid}|{comment}" --nototal
```

**Recursively check sub-branches** (max 3 levels deep):
```
cm find merge "where dstbranch='{srcbranch}' and dstchangeset > {prevSrcCS} and dstchangeset <= {srcCS}" --format="{srcchangeset}|{srcbranch}|{srccomment}" --nototal
```

For each deeper source, collect its changeset comments.

### Step 6 — Format

- Group by sub-branch (use last path segment as header).
- Format: `[BranchShortName]` header + `- comment` list.
- Skip empty, dedupe.

Example:
```
[feature-login]
- Added OAuth2 login flow
- Fixed token refresh logic

[hotfix-ui]
- Resolved layout overflow on mobile
- Updated button styles
```

Show the combined comment, confirm with user.

### Step 7 — Apply

```
cm changeset editcomment cs:{latest} "{combined}"
```

Verify:
```
cm find changeset "where changesetid={latest}" --format="{changesetid}|{date}|{comment}" --nototal
```

If all collected comments are empty, apply default: "Merged {source} into {target}".

Use only the tools listed above.
