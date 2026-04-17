# Changelog

## v1.1.1 (2026-04-17)

- **Reviewer model = Sonnet** (was inherited from drafter). Sonnet runs the `--review` subagent — cheaper, faster, and a genuinely different model from the Opus drafter for stronger independence
- **Reviewer scope tightened**: added "Flag ONLY" / "Do NOT flag" rules to the review prompt. User-owned criteria (rubrics, thresholds, preferences), future-state decisions, and questions the handover explicitly defers are no longer flagged as gaps
- **Rationale**: v1.1.0 self-test showed the Opus reviewer mis-classifying user-owned ambiguity (e.g. "no evaluation rubric defined") as high-severity gaps, inflating severity and noise

## v1.1.0 (2026-04-17)

- **Pure transfer principle**: the handover no longer prescribes what the next session should do — it reports state; the next session decides WITH the user
- **Removed**: length limits (was "20–40 lines typical, max 100") — replaced by a content criterion that requires capturing every rejected option, agreement, trade-off, and blocker from the conversation
- **Removed**: Step 1.5 Skill Trigger detection (design-doc → `superpowers:executing-plans` hint). Judgment belongs to the next session
- **Added**: Status section (Done / In progress / Blocked / Pending user decision) as required structure
- **Added**: reverse-order conversation scan checklist to reduce omission of early-session context
- **Added**: optional independent review via `--review` flag — dispatches a general-purpose subagent to find gaps in the draft (one round only, no self-review)
- **Rationale**: self-review suffers from confirmation bias; length caps caused over-compression and dropped reasoning chains

## v1.0.0 (2026-04-07)

- Initial plugin release (migrated from `~/.claude/commands/handover.md`)
- Handover document generator with clipboard copy
- Skill trigger detection for plan → implementation transitions
- Portable script path (relative to plugin, no hardcoded `~/.claude/`)
