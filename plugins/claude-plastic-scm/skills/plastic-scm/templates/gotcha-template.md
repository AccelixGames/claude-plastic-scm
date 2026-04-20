---
name: gotcha-template
description: GitHub issue body template for plastic-scm gotchas captured via /cm-lint (Phase 3 auto-capture) or manual creation. Defines required fields so every issue is reproducible and lint-verifiable.
---

# Gotcha Issue Template

## Labels (single label)

| Label | Purpose |
|-------|---------|
| `skill:plastic-scm` | Filter from other plugins in shared marketplace repo. **Required on every gotcha.** |

State는 라벨이 아니라 **issue open/closed + 코멘트 패턴**으로 추적:

| State | 판정 조건 |
|-------|-----------|
| `new` | open + `lint-hold: bump` 코멘트 0건 |
| `held` | open + `lint-hold: bump` 코멘트 ≥ 1건 |
| `rejected` | closed + `lint-reject:` 코멘트 존재 |
| `landed` | closed + `Fixed in <sha> via /cm-lint` 코멘트 존재 |
| `attempted` | open + `lint-attempted:` 코멘트 존재 (gate 실패, 재시도 대기) |

## Title

Format: `[cm <subcommand>] <short symptom>`

Examples:
- `[cm label] --comment flag rejected with "예상치 못한 옵션"`
- `[cm checkin] atomic fail when touched-but-hash-equal file in batch`
- `[cm merge] --ancestor silently wrong base on reparented branch`

Keep ≤70 chars. No changeset numbers or project-specific paths in the title.

## Body (required fields)

~~~markdown
## 증상 (Symptom)

<1-2 sentences: what went wrong observably. No speculation.>

## 재현 단계 (Reproduction — REQUIRED for lint verification)

<Numbered minimal steps. Must be runnable by a subagent with no project context.
Avoid project-specific paths; use `<path>`, `<branch>`, `<cs-id>` placeholders
when the exact value doesn't matter to the bug.>

1. ...
2. ...
3. ...

**Expected:** <what should happen>
**Actual:** <what actually happened, including exact error text if any>

## 시도한 것 (Attempts)

- <Attempt 1: what, result>
- <Attempt 2: what, result>
- ...

## 해결 또는 가설 (Resolution or Hypothesis)

<If resolved: the working answer. If not: best current hypothesis.>

## 개선안 (Skill improvement idea — 1 line)

<Single line. More detailed analysis happens during /cm-lint triage.>

## 영향 범위 (Scope)

<Which cm subcommands / which skill files this likely touches.>
~~~

## Field rationale

- **재현 단계** is required because lint's Phase C runs a baseline subagent on these steps before the fix, then a primary subagent on the same steps after the fix. No reproduction = no verification = fix cannot land.
- **1-line 개선안** keeps capture fast (≤ 30 seconds for Phase 3 hook reflection) while deferring analysis to lint.
- **영향 범위** feeds lint's smoke-test picker (see `regression-smoke.md` → "How lint picks 2 of 4").

## Hold counter convention

When the user chooses "hold" during lint Phase B, lint appends a comment:

```
lint-hold: bump (now N)
```

where N = previous hold count + 1. Lint Phase A aggregates these by counting comments matching `^lint-hold: bump` per issue. Counter is **sort-weight only**; accept/land 결정은 항상 유저 수동 triage.
