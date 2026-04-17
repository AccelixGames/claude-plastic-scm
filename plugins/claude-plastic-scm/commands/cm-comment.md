---
allowed-tools:
  - Bash(cm wi:*)
  - Bash(cm status:*)
  - Bash(cm find:*)
  - Bash(cm changeset:*)
  - Read
description: Generate a PlasticSCM checkin comment from pending changes — preview only, or apply to an existing changeset. Use for "코멘트 생성", "체크인 코멘트", "changeset comment edit". Does NOT perform checkin.
argument-hint: "[cs:{changesetid}]"
disable-model-invocation: true
---

## Context

- Workspace info: !`cm wi 2>/dev/null || echo "NOT_A_WORKSPACE"`
- Pending changes: !`cm status --short 2>/dev/null || echo "NOT_A_WORKSPACE"`
- Recent changesets (tone reference): !`cm find changeset "where branch = (SELECT cs.branch FROM changeset WHERE changesetid = (SELECT cs.changesetid FROM workspace))" --format="{changesetid}|{date}|{comment}" --nototal 2>/dev/null | tail -5`

## Task

Generate a checkin comment from pending changes. **No checkin is performed.** Optionally apply to an existing changeset.

### Step 0 — Workspace guard

If context contains `NOT_A_WORKSPACE` or is empty, stop:
- PlasticSCM workspace가 아님 — `/commit` 계열 사용 권장.

### Step 1 — Mode

- `$ARGUMENTS` contains `cs:{id}` → **edit mode** (generate + apply to that cs).
- Otherwise → **preview mode** (generate + display for copy).

### Step 2 — Filter patterns

**Built-in ancillary** (excluded from comment analysis):
- Extensions: `.meta`
- Directories: `Library/`, `Logs/`, `Temp/`, `obj/`, `UserSettings/`
- Files: `*.csproj`, `*.sln`, `Packages/packages-lock.json`

**Project archive** — read `.claude/checkin-filters.local.md` at workspace root; merge its "Ancillary Patterns" if present.

### Step 3 — Classify

From `cm status --short`:
1. **Primary** — common editable extensions: `.cs`, `.asset`, `.prefab`, `.unity`, `.json`, `.md`, `.txt`, `.shader`, `.cginc`, `.hlsl`, `.asmdef`, `.yaml`, `.yml`, `.xml`, `.png`, `.jpg`, `.wav`, `.mp3`, `.mat`, `.controller`, `.overrideController`, `.playable`, `.signal`, `.renderTexture`, `.lighting`, `.spriteatlas`, etc.
2. **Ancillary** — matches patterns above.

Unclassified → include in primary. No need to ask.

### Step 4 — Generate comment

Analyze **primary only**.

**Format — bullet list:**
```
- 작업 내용 1
- 작업 내용 2
```

Each bullet = one logical change. Group related files.

**Prefix rules** — each bullet MUST start with a category prefix:

| Prefix | Usage | Example |
|---|---|---|
| (없음) | 신규 기능·콘텐츠 추가 | `- 플레이 테이블 시스템 구현` |
| `수정:` | 버그 수정 | `- 수정: 연속퇴장 버그` |
| `변경:` | 기존 동작·구조 변경 | `- 변경: CustomerSpawner → SO 기반 파이프라인` |
| `제거:` | 코드·에셋 삭제 | `- 제거: 미사용 CustomerPool 클래스` |
| `리팩토링:` | 동작 변경 없는 구조 개선 | `- 리팩토링: Actor.Customer 네임스페이스 통일` |

- No prefix = 신규 추가 (default).
- Prefix + 설명은 같은 줄에.
- Language: **한국어**. Code identifiers (class/method names): original.
- If `$ARGUMENTS` has extra text (beyond `cs:` spec), treat as user context and incorporate.
- Reference tone of recent changesets but always follow the bullet format.

### Step 5 — Present and apply

**Preview mode** (no `cs:`):
- Show the generated comment.
- Ask: "이 코멘트를 현재 체인지셋에 적용할까요? (적용 / 복사만)"
- If apply:
  `cm changeset editcomment cs:{current_cs} "{comment}"` — `{current_cs}` = workspace current changeset ID.

**Edit mode** (`cs:{id}`):
- Show comment, ask: "이 코멘트를 cs:{id}에 적용할까요?"
- If confirmed:
  `cm changeset editcomment cs:{id} "{comment}"`

Verify:
```
cm find changeset "where changesetid={id}" --format="{changesetid}|{date}|{comment}" --nototal
```

Use only the tools listed above.
