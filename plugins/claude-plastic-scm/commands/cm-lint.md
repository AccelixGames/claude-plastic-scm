---
name: cm-lint
description: >
  PlasticSCM skill 자동 진단 + 수리. GitHub Issues에 수집된 gotcha-open /
  gotcha-hold 이슈를 수집 → 클러스터링 → 유저와 해결책 협의 → worktree 격리
  수정 → baseline + 회귀 2종 검증 → 닫기. 기존 accelix-ai-plugins marketplace
  repo에 `skill:plastic-scm` 라벨로 필터링.
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
- `/cm-lint --state <label>` — 특정 state 라벨만 (`gotcha-open`, `gotcha-hold`)

## Step 0 — Workspace guard

```bash
!test -d .claude-plugin || echo "NOT_A_MARKETPLACE_REPO"
```

Must be run from the `accelix-ai-plugins` marketplace repo root. Abort if not.

## Phase A — Collect + Cluster + Report

### Step A.1: Collect

```bash
gh issue list \
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
  gotcha-open:     X
  gotcha-hold:     Y   (total bump count: Z)
  gotcha-rejected: (filtered, closed issues excluded)

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
- For each member issue: `gh issue comment <N> --body "lint-hold: bump (now $((prev+1)))"`.
- Ensure label = `gotcha-hold` (switch from `gotcha-open` if needed): `gh issue edit <N> --remove-label gotcha-open --add-label gotcha-hold`.
- Move to next cluster.

**R — Reject:**
- Prompt user for rejection reason (1-line).
- For each member: `gh issue comment <N> --body "lint-reject: <reason>"`, then `gh issue edit <N> --remove-label gotcha-open,gotcha-hold --add-label gotcha-rejected`, then `gh issue close <N>`.
- Move to next cluster.

**S — Skip:**
- No state change. Defer to next `/cm-lint` invocation.

### Step B.3: After all clusters processed

Print `fix_plan[]` summary → ask user: "Proceed to Phase C execution? (y/n)"

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
# close all member issues
for n in $member_issues; do
  gh issue close $n --comment "Fixed in ${commit_sha} via /cm-lint"
done
```

### Step C.10: Discard fix (any gate failed)

```bash
# Discard per using-git-worktrees skill guidance
git worktree remove --force "$WT"
git branch -D "cm-lint/cluster-${cluster_id}"
# comment on all member issues with gate failure summary
for n in $member_issues; do
  gh issue comment $n --body "lint-attempted: <gate-failure-summary>"
  gh issue edit $n --add-label lint-attempted
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
  Attempted but gate-failed:           F (lint-attempted label added)

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
- **Clustering produces single mega-cluster** — symptom tokenization too lenient. Manual split via `/cm-lint --state gotcha-open` on specific labels.
- **Regression baseline fails on main** — indicates pre-existing issue unrelated to this fix. Log to user, skip regression gate for this cluster (with explicit user approval), continue.
