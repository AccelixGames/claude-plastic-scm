# Plastic-SCM Gotcha-Lint System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/cm-lint` command + gotcha issue templates to the `claude-plastic-scm` plugin so friction experienced while using `cm` commands can be captured as GitHub issues, triaged interactively, and fix-verified with baseline + regression checks before skill updates ship.

**Architecture:** New `/cm-lint` slash command implements a 4-phase workflow (collect → triage → execute-with-verification → report) modeled after the existing `/lint` skill in `modular-gamedev-framework`. Issues are filed in the shared `accelix-ai-plugins` marketplace repo with `skill:plastic-scm` label for filtering. Hold counter is accumulated via `lint-hold:` comments. Accept path runs in a worktree: baseline subagent reproduces the issue, fix is applied, primary subagent re-runs the same reproduction, then two regression subagents execute unrelated smoke-test scenarios to confirm no behavioral regression. Philosophy: "a wrong update is worse than no update" — no fix merges without all four gates passing.

**Tech Stack:**
- GitHub Issues via `gh` CLI (label filtering, comment-based counters)
- `cm` CLI (PlasticSCM — tested scenarios come from real merge/checkin/label flows)
- Bash scripts (existing `merge_investigate.sh` pattern)
- Git worktree (`using-git-worktrees` skill)
- General-purpose subagents for baseline + regression checks

**Scope of this plan:** Phase 1 (lint processing pipeline + templates) + Phase 2 (manual pilot issue to validate the pipeline). Phase 3 (auto-reflection hook + SKILL.md global protocol) follows in a separate plan after this one ships and stabilizes.

**Out of scope:**
- Hook-based auto-trigger on `cm checkin/merge/label` completion (Phase 3)
- SKILL.md "Post-task Reflection" global protocol section (Phase 3)
- `templates/reflection-prompt.md` (Phase 3)
- Auto-promotion of held issues to accepted (always manual per user decision)

---

## Locked design decisions (from brainstorming session 2026-04-20)

| # | Area | Decision | Rationale |
|---|------|----------|-----------|
| 1 | Reflection trigger | **C+Hook hybrid** (Phase 3) — SKILL.md global + plugin-shipped hook | Deterministic fire vs Claude-judgment; covers raw `cm` via Bash tool |
| 2 | Hold counter storage | **(a) Comment accumulation** — `lint-hold: bump (now N)` comments | No title pollution, label schema stays simple, aggregation at lint time is cheap |
| 3 | Fix verification | **(B) Hybrid + regression ×2** — manual reproduction checklist in issue; script-based cases auto-verify; 2 smoke-test scenarios confirm no regression | "Wrong update > no update"; script path auto-covers common flows |
| 4 | Implementation order | **(β) Lint processing first**, then pilot, then hook | Don't open capture firehose before the pipeline can handle it |
| 5 | Regression scenario selection | **(i) Pre-defined smoke test set** (3-5 scenarios) | Deterministic, reproducible, incrementally extensible |

---

## File Structure

```
plugins/claude-plastic-scm/
├── .claude-plugin/plugin.json                [MODIFY] version 1.10.1 → 1.11.0-alpha
├── CHANGELOG.md                              [MODIFY] 1.11.0-alpha entry
├── commands/cm-lint.md                       [CREATE] /cm-lint slash command (4 phases)
├── docs/plans/
│   └── 2026-04-20-gotcha-lint-system.md      [THIS FILE]
└── skills/plastic-scm/
    ├── SKILL.md                              [MODIFY] /cm-lint row in Available Plugin Commands table
    └── templates/
        ├── gotcha-template.md                [CREATE] issue body structure + label rules
        └── regression-smoke.md               [CREATE] pre-defined smoke test set

.claude-plugin/marketplace.json               [MODIFY] version 1.10.1 → 1.11.0-alpha
```

Each file's single responsibility:
- `cm-lint.md` — workflow only. No domain knowledge about specific gotchas.
- `gotcha-template.md` — data contract for issue bodies. No workflow.
- `regression-smoke.md` — pure data. 3-5 scenarios, no logic.
- `SKILL.md` — catalog entry only. No protocol changes (Phase 3 adds protocol).

---

## Workspace strategy

The `accelix-ai-plugins` marketplace repo is on `main`. This plan's user has `feedback_worktree_only` memory: main workspace stays on master, feature work in worktrees.

- **For `modular-gamedev-framework`** repo (the primary workspace): never touched by this plan.
- **For `accelix-ai-plugins`** (marketplace): this repo's `main` is already being used as the release branch directly per user's established pattern (recent commits `2e93279`, `6b62df1` pushed to main directly). So **this plan writes to main directly**, but the `/cm-lint` command itself will specify worktree creation per issue during its execute phase.

---

## Task 1: Create `regression-smoke.md` template

**Files:**
- Create: `plugins/claude-plastic-scm/skills/plastic-scm/templates/regression-smoke.md`

Pre-defined smoke test scenarios for lint's regression verification step. Pure data, no logic. Initial set = 4 scenarios from real flows in recent sessions.

- [ ] **Step 1: Write `regression-smoke.md`**

```markdown
---
name: regression-smoke
description: Pre-defined smoke-test scenarios for /cm-lint regression verification. Lint Phase C picks 2 scenarios most relevant to the issue being fixed and dispatches them as subagents before/after the fix to confirm no behavioral regression. This file is pure data — add new scenarios as the plugin matures.
---

# Regression Smoke Test Set

Each scenario below is a **single, self-contained cm workflow** that a general-purpose subagent can execute without project-specific knowledge. Scenarios must stay **generic** — no hardcoded branch names, changeset IDs, file paths, or repo assumptions. The user's lint design principle: "script 일반적이어야 함, 프로젝트 특화 X, 특정 케이스 특화 X".

## SM-01: Simple file checkin

**Setup:** A workspace has one modified tracked text file with no conflicts.

**Steps:**
1. `cm status` — confirm the file appears under "변경됨/Changed".
2. `cm checkin <path> -c="smoke test"` — execute.
3. `cm log -l1` — verify the new changeset includes the file.

**Expected observation:** checkin succeeds, new changeset contains exactly the one file, comment matches.

## SM-02: Folder-scope checkin with mixed CH/PR

**Setup:** A workspace folder contains (a) a modified tracked file in "변경됨" state, (b) a new untracked "비공개" file.

**Steps:**
1. `cm status --short` — confirm both states present.
2. `cm add <untracked>` — register private file.
3. `cm checkin <folder> -c="smoke test mixed"` — folder-level checkin.
4. `cm log -l1` — verify both files in the resulting changeset.

**Expected observation:** both files checkin atomically under one changeset.

## SM-03: Label on current changeset with comment

**Setup:** Workspace is on a stable changeset with no pending changes.

**Steps:**
1. `cm wi` — read current changeset id.
2. `cm label create lb:smoke-test-<timestamp> cs:<id> -c="smoke test label"` — single-dash `-c=`.
3. `cm find label "where name='smoke-test-<timestamp>'" --format="{name}|{comment}" --nototal` — verify.

**Expected observation:** label created with attached comment. `--comment=` double-dash MUST fail with "예상치 못한 옵션 --comment" if tested as negative case.

## SM-04: Merge investigation brief

**Setup:** Two branches diverge with at least one changeset on the source.

**Steps:**
1. `bash <plugin>/skills/plastic-scm/scripts/merge_investigate.sh <src-branch> --workspace <path>` — run bundled investigation script.
2. Verify output sections: `=== Workspace ===`, `=== Prior Merges ===`, `=== Source Branch Info ===`, `=== Source Branch Changesets ===`, `=== Source Tip Comment ===`, `=== Source Changes ===`, `=== Effective Merge Delta ===`, `=== Destination Status ===`.

**Expected observation:** all 8 labeled sections present, no section empty unless genuinely so (e.g., no prior merges).

## How lint picks 2 of 4

Lint Phase C selects the 2 scenarios whose command surface most overlaps with the issue being fixed:

| Issue touches | Prefer scenarios |
|---------------|------------------|
| `cm checkin` | SM-01, SM-02 |
| `cm label` | SM-03, SM-01 |
| `cm merge` | SM-04, and the scenario matching any other `cm` call the fix affects |
| `cm status` parsing | SM-02, SM-01 |
| documentation only | SM-01 + one unrelated (e.g., SM-03) as sanity |

When no clear overlap, default to SM-01 + SM-04.
```

- [ ] **Step 2: Verify file exists and is well-formed**

Run: `cat "plugins/claude-plastic-scm/skills/plastic-scm/templates/regression-smoke.md" | head -40`
Expected: frontmatter + first 2 scenario headers visible.

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/splus/.claude/plugins/marketplaces/accelix-ai-plugins"
git add plugins/claude-plastic-scm/skills/plastic-scm/templates/regression-smoke.md
git commit -m "$(cat <<'EOF'
feat(claude-plastic-scm): add regression smoke-test set for /cm-lint

4 generic cm workflows (checkin, folder+PR, label+comment, merge brief).
Lint Phase C picks 2 most-overlapping scenarios per fix to verify
no behavioral regression. Scenarios are project-agnostic per user
design principle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Create `gotcha-template.md`

**Files:**
- Create: `plugins/claude-plastic-scm/skills/plastic-scm/templates/gotcha-template.md`

Issue body structure. Required fields ensure every captured gotcha is reproducible and measurable.

- [ ] **Step 1: Write `gotcha-template.md`**

```markdown
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

```markdown
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
```

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
```

- [ ] **Step 2: Verify file exists**

Run: `cat "plugins/claude-plastic-scm/skills/plastic-scm/templates/gotcha-template.md" | grep -c "^##"`
Expected: ≥ 7 (sections: 증상, 재현 단계, 시도한 것, 해결 또는 가설, 개선안, 영향 범위, + Labels/Title/etc.)

- [ ] **Step 3: Commit**

```bash
git add plugins/claude-plastic-scm/skills/plastic-scm/templates/gotcha-template.md
git commit -m "$(cat <<'EOF'
feat(claude-plastic-scm): add gotcha issue template for /cm-lint

Required body fields: 증상, 재현 단계, 시도, 해결/가설, 1줄 개선안, 영향 범위.
재현 단계 is mandatory because lint Phase C uses it for baseline + post-fix
subagent verification. Label schema: skill:plastic-scm only; state tracked
via issue open/closed + comment patterns (lint-hold:/lint-reject:/lint-attempted:).
Hold counter convention: lint-hold comments accumulated, counted at lint
Phase A as sort weight only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Create `/cm-lint` slash command — frontmatter + Phase A

**Files:**
- Create: `plugins/claude-plastic-scm/commands/cm-lint.md`

Split command authoring into frontmatter + each phase to keep steps bite-sized. Final file ≈ 250 lines.

- [ ] **Step 1: Write frontmatter + intro + Phase A**

Create `plugins/claude-plastic-scm/commands/cm-lint.md` with:

```markdown
---
name: cm-lint
description: >
  PlasticSCM skill 자동 진단 + 수리. GitHub Issues에 수집된 open 이슈를
  bump-counter로 new/held 구분 → 클러스터링 → 유저와 해결책 협의 → worktree
  격리 수정 → baseline + 회귀 2종 검증 → 닫기. 기존 accelix-ai-plugins
  marketplace repo에 `skill:plastic-scm` 라벨로 필터링.
triggers:
  - /cm-lint
  - cm lint
  - plastic lint
  - 플라스틱 린트
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(cm:*)
  - Bash(bash:*)
  - Bash(mkdir:*)
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(diff:*)
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
disable-model-invocation: true
---

# /cm-lint — Plastic-SCM Skill Auto-Diagnosis + Repair

## 실행 모드

- `/cm-lint` — 대화형 (전체 논의 → 수정)
- `/cm-lint --report-only` — 리포트만, 수정 X
- `/cm-lint --state <new|held>` — bump-counter 기반 필터링 (new = bump 0, held = bump ≥ 1)

## Environment note — Git Bash (MSYS)

Windows Git Bash 환경에서는 `gh` 커맨드 인자에 포함된 `/<slash-prefix>` 토큰이 자동으로 Windows 경로로 변환됨. 모든 `gh` 호출은 `MSYS_NO_PATHCONV=1` 가드를 prefix로 사용. Linux/macOS에서는 변수 무시됨 (무해).

## Step 0 — Workspace guard

```bash
!test -d .claude-plugin || echo "NOT_A_MARKETPLACE_REPO"
```

Must be run from the `accelix-ai-plugins` marketplace repo root. Abort if not.

## Step 0.5 — Label bootstrap

`skill:plastic-scm` 라벨이 없으면 생성. idempotent.

```bash
MSYS_NO_PATHCONV=1 gh label list \
  --repo AccelixGames/accelix-ai-plugins \
  --limit 200 \
  --json name | jq -r '.[].name' | grep -qx 'skill:plastic-scm' \
  || MSYS_NO_PATHCONV=1 gh label create 'skill:plastic-scm' \
       --repo AccelixGames/accelix-ai-plugins \
       --color '5319E7' \
       --description 'Filter: this issue targets the plastic-scm skill'
```

## Phase A — Collect + Cluster + Report

### Step A.1: Collect

```bash
MSYS_NO_PATHCONV=1 gh issue list \
  --repo AccelixGames/accelix-ai-plugins \
  --label skill:plastic-scm \
  --state open \
  --json number,title,body,labels,comments \
  --limit 100 > /tmp/cm-lint-issues.json
```

### Step A.2: Aggregate hold counter

For each issue, count comments matching `^lint-hold: bump` and attach as `hold_count` field:

```bash
jq '[.[] | . + {hold_count: ([.comments[].body | select(test("^lint-hold: bump"))] | length)}]' \
  /tmp/cm-lint-issues.json > /tmp/cm-lint-enriched.json
```

### Step A.3: Cluster by title similarity

Group issues whose titles share the `[cm <subcommand>]` prefix AND have ≥ 60% token overlap in the symptom portion. This is a judgment call — dispatch to a general-purpose subagent for clustering when issue count ≥ 10:

```
Agent(general-purpose): "Given the JSON array in /tmp/cm-lint-enriched.json,
group issues into clusters where each cluster represents the same underlying
gotcha. Use title prefix and symptom token overlap. Output JSON array of
clusters, each with: cluster_id, member_issue_numbers, representative_title,
total_occurrences (sum of 1 + hold_count across members), top_symptom."
```

For counts < 10, main agent clusters directly.

### Step A.4: Compute severity and sort

```
severity = total_occurrences (duplicates + hold bumps)
```

Sort clusters by severity DESC. This is the triage order.

### Step A.5: Report summary

Print to user:

```
=== /cm-lint — Phase A Report ===
Fetched: N issues (M clusters)
Breakdown by state:
  New  (bump 0):       X
  Held (bump ≥ 1):     Y   (total bump count: Z)
  (rejected / landed 이슈는 closed — Phase A.1 --state open 필터로 자동 제외)

Top clusters (severity desc):
  1. [severity 7] [cm checkin] atomic fail on hash-equal touched files
     → #42, #51, #58 (3 issues, 4 hold bumps)
  2. [severity 3] [cm label] --comment flag rejected
     → #39 (1 issue, 2 hold bumps)
  ...

Proceed to Phase B? (y/n)
```
```

- [ ] **Step 2: Verify Step 1 content**

Run: `grep -c "^## " "plugins/claude-plastic-scm/commands/cm-lint.md"`
Expected: ≥ 3 (실행 모드, Step 0, Phase A)

- [ ] **Step 3: Do NOT commit yet** — more phases come in Task 4/5/6.

---

## Task 4: `/cm-lint` Phase B — Triage Loop

**Files:**
- Modify: `plugins/claude-plastic-scm/commands/cm-lint.md` (append Phase B)

- [ ] **Step 1: Append Phase B**

Append to `cm-lint.md`:

```markdown

## Phase B — Triage Loop (per cluster)

For each cluster in severity order, present and decide:

### Step B.1: Present cluster

```
─────────────────────────────────────────
Cluster 1 of M [severity 7]
Title: [cm checkin] atomic fail on hash-equal touched files
Members: #42, #51, #58
Hold bumps total: 4

=== Representative body (from #42) ===
<paste body>

=== Symptom differences across members ===
<1-line per member if symptoms diverge; else "consistent">

Decision: [A]ccept / [H]old / [R]eject / [S]kip (defer to next /cm-lint)
```

### Step B.2: User input → action

**A — Accept:**
- Record cluster in `fix_plan[]` with: `cluster_id`, `representative_issue`, `member_issues`, `all_repro_steps`, `target_scope_files` (parsed from 영향 범위 field).
- Prompt user for fix approach (brainstorm options A/B/C).
- Record agreed approach in `fix_plan[cluster_id].approach`.

**H — Hold:**
- For each member issue: `MSYS_NO_PATHCONV=1 gh issue comment <N> --body "lint-hold: bump (now $((prev+1)))"`.
- Issue는 open 유지. Held state는 `lint-hold: bump` 코멘트 존재(bump ≥ 1)로 판정.
- Move to next cluster.

**R — Reject:**
- Prompt user for rejection reason (1-line).
- For each member: `MSYS_NO_PATHCONV=1 gh issue comment <N> --body "lint-reject: <reason>"` → `MSYS_NO_PATHCONV=1 gh issue close <N>`.
- Rejected state는 closed + `lint-reject:` 코멘트 존재로 판정.
- Move to next cluster.

**S — Skip:**
- No state change. Defer to next `/cm-lint` invocation.

### Step B.3: After all clusters processed

Print `fix_plan[]` summary → ask user: "Proceed to Phase C execution? (y/n)"
```

- [ ] **Step 2: Verify Phase B appended**

Run: `grep -c "Phase B" "plugins/claude-plastic-scm/commands/cm-lint.md"`
Expected: ≥ 2 (header + usage in text)

- [ ] **Step 3: Do NOT commit yet.**

---

## Task 5: `/cm-lint` Phase C — Execute with Verification Gates

**Files:**
- Modify: `plugins/claude-plastic-scm/commands/cm-lint.md` (append Phase C)

- [ ] **Step 1: Append Phase C**

Append to `cm-lint.md`:

```markdown

## Phase C — Execute (per accepted cluster)

Each cluster in `fix_plan[]` goes through a 4-gate verification. **All four gates must pass for the fix to land.** Philosophy: a wrong update is worse than no update.

### Step C.1: Create worktree (using-git-worktrees skill)

Invoke the superpowers:using-git-worktrees skill to create an isolated worktree for this cluster. The skill guides worktree creation; there is no bundled script. Typical result:

```bash
git worktree add "../accelix-ai-plugins-cm-lint-${cluster_id}" -b "cm-lint/cluster-${cluster_id}"
```

Record the worktree path as `$WT`. All subsequent work in `$WT`.

### Step C.2: Baseline gate — reproduce BEFORE fix

Dispatch a fresh general-purpose subagent:

```
Agent(general-purpose, description="Baseline reproduction for cluster {id}", prompt="
You will verify a plastic-scm gotcha is reproducible BEFORE any fix is applied.

Working directory: $WT
Issue: #{representative_issue}
Repository: AccelixGames/accelix-ai-plugins

Reproduction steps (copy from issue body 재현 단계 field):
{paste}

Execute these steps exactly. Report:
- Each step's actual output (verbatim, no summary)
- Whether the 'Actual' behavior from the issue body reproduces
- Any deviation from 'Expected' behavior

Report in under 300 words. Do NOT attempt any fix — this is baseline only.
")
```

Record result as `baseline_result`. If reproduction fails (issue is not reproducible), **pause and escalate to user**: "Issue #N's repro steps don't reproduce the symptom. Fix or close the issue?"

### Step C.3: Apply fix

Apply the agreed approach from `fix_plan[cluster_id].approach`. Scope matrix:

| File pattern | Allowed to modify? | Notes |
|--------------|--------------------|-------|
| `skills/plastic-scm/SKILL.md` | ✅ | Documentation and protocol edits |
| `skills/plastic-scm/references/**` | ✅ | Command reference expansion (most fixes land here) |
| `skills/plastic-scm/scripts/**` | ✅ | Must stay generic (no project-specific paths/branches/csids) |
| `skills/plastic-scm/templates/**` | ✅ | Template refinement |
| `commands/cm-*.md` | ✅ | Slash command workflow edits |
| `hooks/**` | ❌ (Phase 3 only) | Deferred to Phase 3 plan |
| `.claude-plugin/plugin.json` version | ✅ | Bump on lint commit |
| `CHANGELOG.md` | ✅ | Add lint entry |

Changes outside this matrix require escalation to user.

### Step C.4: Primary gate — re-run same repro AFTER fix

Dispatch the same reproduction subagent with identical prompt as Step C.2 (fresh subagent, same steps). Record as `primary_result`.

**Pass criterion:** `baseline_result` shows Actual behavior, `primary_result` shows Expected behavior (or improved behavior per fix_plan approach). If still shows Actual → **fix failed, move to Step C.8**.

### Step C.5: Regression gate — pick 2 scenarios from `regression-smoke.md`

Read `skills/plastic-scm/templates/regression-smoke.md`. Pick 2 scenarios per the "How lint picks 2 of 4" matrix based on `영향 범위` field of the representative issue.

### Step C.6: Regression baseline — scenarios BEFORE fix was applied

Since the fix is already applied in $WT, run the regression scenarios against `main` (not $WT) to establish regression baseline.

For each of the 2 picked scenarios, dispatch:

```
Agent(general-purpose, description="Regression baseline SM-{id}", prompt="
Working directory: <main repo checkout, NOT the lint worktree>
Execute scenario SM-{id} from:
plugins/claude-plastic-scm/skills/plastic-scm/templates/regression-smoke.md

Report each step's actual output verbatim and whether 'Expected observation'
holds. Under 200 words.
")
```

Record as `regression_baseline[SM-id]`.

### Step C.7: Regression verify — scenarios in $WT AFTER fix

Dispatch the same 2 scenarios against `$WT`. Record as `regression_after[SM-id]`.

**Pass criterion:** For each scenario, `regression_after` matches or improves on `regression_baseline`. Any new failure or new deviation = **regression detected, move to Step C.8**.

### Step C.8: Gate decision

```
All 4 gates:
  1. Baseline reproduces: {yes|no}
  2. Primary fix verified: {pass|fail}
  3. Regression SM-X: {pass|fail}
  4. Regression SM-Y: {pass|fail}

if all pass → proceed to Step C.9 (land fix)
else → discard worktree, comment on issues, move to next cluster
```

### Step C.9: Land fix (all gates passed)

```bash
cd $WT
# bump version in plugin.json, marketplace.json, CHANGELOG.md
# (lint MAY skip version bump if scope is very small — user prompt)
git add -A
git commit -m "fix(claude-plastic-scm): <summary> (closes #{all_member_issues})

Cluster ID: {cluster_id}
Gates:
- Baseline: reproduced Actual behavior from #{representative_issue}
- Primary: post-fix re-run shows Expected behavior
- Regression SM-{X}: pass (no deviation from main)
- Regression SM-{Y}: pass (no deviation from main)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
"
# merge worktree back (per using-git-worktrees skill guidance)
cd <marketplace-repo-main>
git merge --no-ff "cm-lint/cluster-${cluster_id}" -m "merge cm-lint cluster ${cluster_id}"
git worktree remove "$WT"
git branch -d "cm-lint/cluster-${cluster_id}"
# close all member issues. Landed state는 closed + "Fixed in <sha>" 코멘트로 판정.
for n in $member_issues; do
  MSYS_NO_PATHCONV=1 gh issue close $n --comment "Fixed in ${commit_sha} via /cm-lint"
done
```

### Step C.10: Discard fix (any gate failed)

```bash
# Discard per using-git-worktrees skill guidance
git worktree remove --force "$WT"
git branch -D "cm-lint/cluster-${cluster_id}"
# Issue는 open 유지 (재시도 가능). Attempted state는 `lint-attempted:` 코멘트로 판정.
for n in $member_issues; do
  MSYS_NO_PATHCONV=1 gh issue comment $n --body "lint-attempted: <gate-failure-summary>"
done
```
```

- [ ] **Step 2: Verify Phase C appended**

Run: `grep -c "Step C\." "plugins/claude-plastic-scm/commands/cm-lint.md"`
Expected: 10

- [ ] **Step 3: Do NOT commit yet.**

---

## Task 6: `/cm-lint` Phase D — Final Report + trailing sections

**Files:**
- Modify: `plugins/claude-plastic-scm/commands/cm-lint.md` (append Phase D + scope matrix reminder + troubleshooting)

- [ ] **Step 1: Append Phase D**

Append:

```markdown

## Phase D — Final Report

```
=== /cm-lint Report ===
Session: {timestamp}

Clusters processed: N
  Fixed (merged + issues closed):      X (closes Y issues)
  Held (bump added, deferred):         H
  Rejected (closed):                   R
  Skipped (deferred to next lint):     S
  Attempted but gate-failed:           F (lint-attempted: comment added, issue open 유지)

Verification gates (on fixed clusters):
  Total subagent dispatches:   X*4 = <n>
  Regression scenarios run:    X*2 = <n>
  Average primary-gate time:   ...s

Landed commits:
  - <sha>: <summary> (closes #<n>, #<m>)
  - ...

=== End of Report ===
```

## Scope reminder — what `/cm-lint` does NOT do

- Does not auto-capture new gotchas (Phase 3 plan — hook-based reflection)
- Does not auto-promote held issues (always manual triage — per locked decision #4)
- Does not modify `hooks/**` (Phase 3 territory)
- Does not touch other plugins in the marketplace (scope matrix enforces this)

## Troubleshooting

- **"NOT_A_MARKETPLACE_REPO"** — run from `accelix-ai-plugins` repo root.
- **`gh` auth error** — run `gh auth status`; re-login if needed.
- **Clustering produces single mega-cluster** — symptom tokenization too lenient. Manual split via `/cm-lint --state new` to narrow to fresh captures only.
- **Regression baseline fails on main** — indicates pre-existing issue unrelated to this fix. Log to user, skip regression gate for this cluster (with explicit user approval), continue.
```

- [ ] **Step 2: Verify full command file length**

Run: `wc -l "plugins/claude-plastic-scm/commands/cm-lint.md"`
Expected: 240-300 lines.

- [ ] **Step 3: Commit full `/cm-lint` command**

```bash
git add plugins/claude-plastic-scm/commands/cm-lint.md
git commit -m "$(cat <<'EOF'
feat(claude-plastic-scm): add /cm-lint slash command (alpha)

4-phase workflow: collect+cluster (Phase A) → triage accept/hold/reject
(Phase B) → execute with 4-gate verification (Phase C) → final report
(Phase D). Modeled after /lint skill in modular-gamedev-framework.

Phase C runs fix in a worktree and only lands if all gates pass:
  1. baseline reproduces Actual
  2. primary post-fix shows Expected
  3. regression SM-X no deviation from main
  4. regression SM-Y no deviation from main

Scope matrix limits fixes to skills/references/scripts/templates/commands.
hooks/** deferred to Phase 3 plan. Hold counter via lint-hold comments
(sort weight only, no auto-promotion).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `/cm-lint` to SKILL.md Available Plugin Commands

**Files:**
- Modify: `plugins/claude-plastic-scm/skills/plastic-scm/SKILL.md` (Available Plugin Commands table)

- [ ] **Step 1: Locate the existing table**

Run: `grep -n "Available Plugin Commands" "plugins/claude-plastic-scm/skills/plastic-scm/SKILL.md"`

The existing table includes `/cm-checkin`, `/cm-comment`, `/cm-merge-comment`, `/cm-branch-info`, `/cm-status`, `/cm-history`, `/cm-compile-check`, `/cm-hidden`, `/cm-diff`. Add `/cm-lint` as the last row.

- [ ] **Step 2: Use Edit tool to append row**

```
Edit:
  file_path: plugins/claude-plastic-scm/skills/plastic-scm/SKILL.md
  old_string:
    | `/cm-diff` | Compare changesets/branches/labels |
  new_string:
    | `/cm-diff` | Compare changesets/branches/labels |
    | `/cm-lint` | Skill auto-diagnosis + repair — triage `skill:plastic-scm` issues, fix with 4-gate verification |
```

- [ ] **Step 3: Verify**

Run: `grep "/cm-lint" "plugins/claude-plastic-scm/skills/plastic-scm/SKILL.md"`
Expected: one match on the table row.

- [ ] **Step 4: Commit**

```bash
git add plugins/claude-plastic-scm/skills/plastic-scm/SKILL.md
git commit -m "$(cat <<'EOF'
docs(claude-plastic-scm): list /cm-lint in SKILL.md plugin commands

Catalog entry only. Full workflow in commands/cm-lint.md. Phase 3
global Post-task Reflection protocol deferred to separate plan.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Version bump + CHANGELOG entry

**Files:**
- Modify: `plugins/claude-plastic-scm/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/claude-plastic-scm/CHANGELOG.md`

- [ ] **Step 1: Bump `plugin.json`**

```
Edit:
  file_path: plugins/claude-plastic-scm/.claude-plugin/plugin.json
  old_string: "version": "1.10.1",
  new_string: "version": "1.11.0-alpha",
```

- [ ] **Step 2: Bump `marketplace.json`**

```
Edit:
  file_path: .claude-plugin/marketplace.json
  old_string:
    "name": "claude-plastic-scm",
    "description": "PlasticSCM (Unity Version Control) workflow automation — checkin, merge comments, branch info, status, history, diff",
    "version": "1.10.1",
  new_string:
    "name": "claude-plastic-scm",
    "description": "PlasticSCM (Unity Version Control) workflow automation — checkin, merge comments, branch info, status, history, diff",
    "version": "1.11.0-alpha",
```

- [ ] **Step 3: Add CHANGELOG entry**

```
Edit:
  file_path: plugins/claude-plastic-scm/CHANGELOG.md
  old_string: ## [1.10.1] - 2026-04-20
  new_string: |
    ## [1.11.0-alpha] - 2026-04-20

    ### 추가
    - **`/cm-lint` 슬래시 커맨드** — plastic-scm 스킬 전용 gotcha 진단+수리. 4-phase 워크플로우: GitHub Issues(`skill:plastic-scm` 필터)에서 open 이슈 수집(bump 0 = new, bump ≥ 1 = held) → 타이틀 유사도 클러스터링 → 유저 triage(accept/hold/reject) → worktree에서 4-gate 검증(baseline 재현 / primary fix 검증 / regression 2종) → 통과 시 commit+close, 실패 시 worktree 폐기 + `lint-attempted:` 코멘트.
    - `skills/plastic-scm/templates/gotcha-template.md` — 이슈 body 필수 필드(증상, 재현 단계, 시도, 해결/가설, 1줄 개선안, 영향 범위) + 라벨 스키마(`skill:plastic-scm` 단일; state는 issue open/closed + 코멘트 패턴으로 추적) + hold 카운터 규약(`lint-hold: bump (now N)` 코멘트).
    - `skills/plastic-scm/templates/regression-smoke.md` — lint Phase C 회귀 검증용 smoke test 4개(SM-01 단순 checkin, SM-02 폴더+CH/PR 혼재, SM-03 label with -c=, SM-04 merge_investigate.sh). 프로젝트 비특화, 일반 cm 플로우만.
    - `docs/plans/2026-04-20-gotcha-lint-system.md` — 이번 릴리스의 설계+구현 플랜(Phase 1+2). Phase 3(hook 기반 auto-capture)는 별도 플랜.

    ### 설계 결정 (locked)
    - Reflection 트리거: **C+Hook hybrid**(Phase 3 예정)
    - Hold 카운터: comment 누적(`lint-hold: bump`)
    - 검증: 수동 재현 + script 자동 + 회귀 2종(smoke 세트에서 선정)
    - 승격: 항상 수동, hold 카운터는 정렬 가중치 only
    - 원칙: "잘못된 업데이트 > 업데이트 없음" — 4-gate 전부 통과해야 fix land

    ## [1.10.1] - 2026-04-20
```

- [ ] **Step 4: Verify all 3 files**

Run:
```bash
grep "version" plugins/claude-plastic-scm/.claude-plugin/plugin.json
grep -A1 '"name": "claude-plastic-scm"' .claude-plugin/marketplace.json | grep version
head -30 plugins/claude-plastic-scm/CHANGELOG.md
```

Expected: all three show `1.11.0-alpha`, CHANGELOG shows the new entry above `[1.10.1]`.

- [ ] **Step 5: Commit version + changelog**

```bash
git add plugins/claude-plastic-scm/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        plugins/claude-plastic-scm/CHANGELOG.md
git commit -m "$(cat <<'EOF'
release(claude-plastic-scm): v1.11.0-alpha — /cm-lint system

- /cm-lint slash command (4-phase workflow, 4-gate verification)
- gotcha-template.md (issue body contract)
- regression-smoke.md (4 generic cm scenarios for regression gate)
- plugin/marketplace version: 1.10.1 -> 1.11.0-alpha
- alpha tag: pending Phase 2 pilot validation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Commit the plan doc itself**

```bash
git add plugins/claude-plastic-scm/docs/plans/2026-04-20-gotcha-lint-system.md
git commit -m "$(cat <<'EOF'
docs(claude-plastic-scm): add gotcha-lint system implementation plan

Phase 1+2 scope: lint processing pipeline + pilot validation.
Phase 3 (hook-based auto-capture + SKILL.md global protocol) deferred
to separate plan after this one stabilizes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Phase 2 pilot — create pilot GitHub issue

**Files:**
- External: GitHub issue in `AccelixGames/accelix-ai-plugins`

The pilot issue captures the "unchanged trap" experienced during the 2026-04-20 session (touched-but-hash-equal file causing atomic checkin failure). This exercises `/cm-lint` on real data without waiting for Phase 3 auto-capture.

- [ ] **Step 1: Draft issue body using gotcha-template.md**

Write the body to a temporary file for the `gh` call:

```bash
cat > /tmp/pilot-issue-body.md <<'EOF'
## 증상 (Symptom)

`cm checkin <paths>` atomic-fails with "unchanged" error on a file that Unity or another tool touched without changing content. All other paths in the batch are rolled back.

## 재현 단계 (Reproduction)

1. In a plastic workspace with Unity open, force an asset reimport so a .asset file is touched but serializes back to byte-identical content.
2. Confirm `cm status` lists the file under "변경됨/Changed".
3. Modify another tracked file in the same workspace (actual content change).
4. `cm checkin <touched-but-equal.asset> <actually-changed.cs> -c="batch"`

**Expected:** both files checkin, or at minimum the actually-changed file lands.
**Actual:** whole batch rolled back. Server reports `(Config) Recipe.asset ... unchanged` or equivalent. Nothing committed.

## 시도한 것 (Attempts)

- Re-running the same `cm checkin` — same failure.
- `cm undo <touched-but-equal>` on the hash-equal file — file disappears from status, then batch succeeds.
- `cm co <touched-but-equal>` to force explicit checkout — batch succeeds; file is committed even though content equals HEAD.

## 해결 또는 가설 (Resolution or Hypothesis)

Plastic's "변경됨/Changed" state conflates two distinct conditions:
  (1) content hash differs from HEAD → legitimate change
  (2) file touched (mtime/size/attribute change) but content hash equals HEAD
Atomic `cm checkin` rejects condition (2) server-side as "unchanged", failing the entire batch. Workarounds: `cm co` (explicit checkout flag overrides hash check) or `cm undo` (drop the file from pending).

## 개선안 (Skill improvement idea — 1 line)

Document the CH hash-equal trap in `references/cm-commands.md` checkin section with the `cm co` / `cm undo` recovery pattern.

## 영향 범위 (Scope)

- `cm checkin` subcommand behavior
- Likely file to update: `plugins/claude-plastic-scm/skills/plastic-scm/references/cm-commands.md` (checkin section)
EOF
```

- [ ] **Step 2: Create issue via `gh`**

```bash
MSYS_NO_PATHCONV=1 gh issue create \
  --repo AccelixGames/accelix-ai-plugins \
  --title "[cm checkin] atomic fail when touched-but-hash-equal file in batch" \
  --label "skill:plastic-scm" \
  --body-file /tmp/pilot-issue-body.md
```

Record the returned issue URL + number as `$PILOT_ISSUE`.

- [ ] **Step 3: Verify**

```bash
gh issue view $PILOT_ISSUE --repo AccelixGames/accelix-ai-plugins
```

Expected: labels include `skill:plastic-scm` (single label); body matches above.

---

## Task 10: Phase 2 pilot — run `/cm-lint` against the issue

**Files:**
- Runtime only (no files modified unless lint finds a design defect).

- [ ] **Step 1: Run `/cm-lint`**

Invoke the command (either via Claude Code slash or simulate by following the command spec). Expected observations:

- Phase A: fetches 1 issue under `skill:plastic-scm` (open). Reports severity 1 (1 issue, 0 hold bumps → "new" state).
- Phase B: presents the cluster. Decision options shown. User chooses Accept.
- Phase C: worktree created; baseline subagent reproduces the trap; fix proposed (add checkin section gotcha doc); primary subagent re-runs (if the fix is documentation, the primary subagent verifies the doc now explains the recovery pattern); regression SM-01 + SM-02 (checkin-adjacent) pass.
- Phase D: report shows 1 fixed, 0 held, 0 rejected.

- [ ] **Step 2: Record outcome + any design defects**

Document in a follow-up note (not committed, just notes):
- Did clustering work correctly on 1 issue?
- Did Phase B prompts feel clear?
- Did the scope matrix correctly identify `references/cm-commands.md` as writable?
- Did regression subagents actually run the scenarios, or did they hallucinate?
- Time to complete all gates — any obvious bottleneck?

- [ ] **Step 3: If design defects found → Task 11 (conditional)**

If `/cm-lint` worked: proceed to Task 12.
If defects found: proceed to Task 11 to patch.

---

## Task 11 (conditional): Patch `/cm-lint` design defects

**Files:** depends on defect. Typically `commands/cm-lint.md` or templates.

- [ ] **Step 1: For each defect, Edit the relevant file.**
- [ ] **Step 2: Verify with `grep` / `head` as appropriate.**
- [ ] **Step 3: Commit:**

```bash
git commit -m "fix(claude-plastic-scm): /cm-lint Phase 2 pilot corrections

- <defect 1 summary>
- <defect 2 summary>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
"
```

- [ ] **Step 4: Re-run the pilot (Task 10) if a defect would have changed the outcome.**

---

## Task 12: Bump `1.11.0-alpha` → `1.11.0` (stable) after pilot passes

**Files:**
- Modify: `plugins/claude-plastic-scm/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/claude-plastic-scm/CHANGELOG.md`

Only proceed if Task 10 pilot completed successfully (or Task 11 patches brought it to green).

- [ ] **Step 1: Edit all three files — `1.11.0-alpha` → `1.11.0`**

(Same Edit pattern as Task 8 Steps 1-3, with `-alpha` stripped.)

- [ ] **Step 2: In CHANGELOG, rename the section header and add pilot note:**

```
## [1.11.0] - 2026-04-20

(promoted from alpha after Phase 2 pilot verified the /cm-lint pipeline
end-to-end against issue #<PILOT_ISSUE>)

### 추가
(unchanged from alpha)
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "release(claude-plastic-scm): v1.11.0 — /cm-lint system (pilot verified)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
"
```

---

## Task 13: Push to marketplace origin

- [ ] **Step 1: Push**

```bash
git push origin main
```

Expected: push succeeds. Marketplace consumers will see `1.11.0` on next update.

- [ ] **Step 2: Verify remote**

```bash
git log --oneline origin/main -5
```

Expected: the release commits visible on origin.

---

## Done criteria

- [ ] `/cm-lint` command file exists, 4 phases complete, scope matrix in place
- [ ] `gotcha-template.md` + `regression-smoke.md` templates exist
- [ ] SKILL.md lists `/cm-lint` in command table
- [ ] Pilot issue created and processed end-to-end through `/cm-lint`
- [ ] All 4 gates exercised in the pilot (not just trivially bypassed)
- [ ] Any pilot-discovered defects patched
- [ ] Released as `1.11.0` (not `-alpha`)
- [ ] Pushed to `AccelixGames/accelix-ai-plugins` main
- [ ] Pilot issue closed via `/cm-lint` (not manually)

---

## Deferred to next plan (Phase 3)

- `hooks/hooks.json` + `reflect-destructive-cm.sh` — PostToolUse hook matching `cm (checkin|merge|label)` success, inject `additionalContext` system reminder.
- `skills/plastic-scm/SKILL.md` — add "Post-task Reflection" global protocol section (friction eval + user question template).
- `skills/plastic-scm/templates/reflection-prompt.md` — exact user question format.
- Cross-platform bash compatibility validation on the hook script (Git Bash, WSL).
- Friction detection heuristic spec (≥1 of: estimate, retry, workaround, error, doc re-query).
- Re-verify `/cm-lint` handles the new auto-captured volume without noise issues.

That plan should reuse this plan's infrastructure (label schema, template, smoke tests, gate model) without changes.
