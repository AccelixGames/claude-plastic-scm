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

Windows Git Bash 환경에서는 `gh` 커맨드 인자에 포함된 `/<slash-prefix>` 토큰이 자동으로 Windows 경로(예: `C:/Program Files/Git/...`)로 변환됨. `/cm-lint` 본문/코멘트에 `/cm-*` 같은 토큰이 들어가면 망가짐. 모든 `gh` 호출은 `MSYS_NO_PATHCONV=1` 가드를 prefix로 사용.

```bash
MSYS_NO_PATHCONV=1 gh issue ...   # 모든 gh 호출 공통
```

가드는 Linux/macOS에서도 무해 (변수 무시됨).

## Step 0 — Workspace guard

```bash
!test -d .claude-plugin || echo "NOT_A_MARKETPLACE_REPO"
```

Must be run from the `accelix-ai-plugins` marketplace repo root. Abort if not.

## Step 0.5 — Label bootstrap

`skill:plastic-scm` 라벨이 없으면 생성. idempotent — 이미 있으면 no-op. (State 추적은 issue open/closed + comment 패턴으로 하므로 이 라벨 하나만 관리하면 됨.)

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

## Phase C — Execute (per accepted cluster)

Each cluster in `fix_plan[]` goes through a 4-gate verification. **All four gates must pass for the fix to land.** Philosophy: a wrong update is worse than no update.

### Step C.0: Classify issue type — adapt gate strategy

Not every gotcha is a runtime bug. Before Phase C begins, classify the cluster's dominant issue type (decide during Phase B accept; record in `fix_plan[cluster_id].issue_type`). Each type uses an adapted baseline/primary/regression strategy:

| Type | Baseline gate (C.2) | Primary gate (C.4) | Regression gate (C.5-C.7) |
|------|---------------------|---------------------|----------------------------|
| **runtime** (cm CLI behavior, live workspace) | Subagent executes `재현 단계` in a live plastic workspace; confirms **Actual** behavior from issue body reproduces | Same subagent prompt post-fix; confirms **Expected** behavior now holds | Run 2 smoke scenarios from `regression-smoke.md` against live workspace (main vs $WT) — compare outputs |
| **doc** (missing/wrong documentation, no runtime behavior change) | Grep the target doc file(s) for the missing mention or wrong claim; confirm gap exists on main | Grep same file(s) in $WT; confirm gap filled and no unrelated text churn | **Diff scope check**: `git diff main -- <targeted-path>` in $WT — verify only the intended file(s) changed and diff size is proportionate to the fix |
| **process** (workflow/procedure, user-executed sequence) | Walk through current documented procedure; list step(s) that cause the symptom | Walk through revised procedure in $WT; confirm failing step now succeeds or is removed | Read adjacent procedures in the same file for unintended side effects; diff-scope check on touched files |

**Type hints:** if 재현 단계 requires a live plastic workspace or runtime state, it's `runtime`. If 영향 범위 points at `references/**` or `SKILL.md` sections without runtime impact, it's `doc`. If it's about `/cm-*` command steps or checklists, it's `process`.

The rest of Phase C (C.1-C.10) is the same workflow for all types — only the **content** of each gate adapts per the table above.

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
