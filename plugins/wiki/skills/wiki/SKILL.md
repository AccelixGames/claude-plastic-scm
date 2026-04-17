---
name: wiki
description: >
  LLM Wiki (Karpathy) — Modes: ingest (source→wiki compile), query (wiki search/answer),
  context (surface prior knowledge before work), lint (promote/verify/cleanup), session (record session).
  Triggers: 'ingest', 'add to wiki', 'wiki query', 'wiki context', 'wiki lint',
  'wiki search', 'wiki health', 'session log'.
  Also use when user says /wiki with or without arguments.
argument-hint: "ingest | query | context | lint | session"
---

# Wiki Workflow — Karpathy LLM Wiki Pattern

Persistent, compounding wiki. Format: obsidian-markdown skill. Search: Obsidian CLI. Web cleanup: defuddle skill.

---

## Preamble (run first)

Run on every invocation. Evaluate markers — first `PREREQ_FAIL` wins, stop immediately.

```bash
echo "---WIKI-PREAMBLE---"
(obsidian version 2>/dev/null || echo "PREREQ_FAIL: OBSIDIAN_CLI_MISSING")
(obsidian vault info=name 2>/dev/null || echo "PREREQ_FAIL: NO_VAULT")
test -d wiki && test -f wiki/index.md && echo "WIKI: OK" || echo "PREREQ_FAIL: WIKI_NOT_INITIALIZED"
test -f wiki/sessions/index.md && test -d wiki/entities && echo "INFRA: OK" || echo "INFRA: INCOMPLETE"
echo "ENTITIES: $(ls wiki/entities/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "SESSIONS: $(find wiki/sessions -name '2*.md' 2>/dev/null | wc -l | tr -d ' ')"
```

| Marker | Action |
|--------|--------|
| `PREREQ_FAIL: OBSIDIAN_CLI_MISSING` | STOP. "Obsidian CLI not available. Enable in Settings → General → CLI." |
| `PREREQ_FAIL: NO_VAULT` | STOP. "No vault open. Open project root as Obsidian vault." |
| `PREREQ_FAIL: WIKI_NOT_INITIALIZED` | Ask user to initialize. If approved, create from Init Template. |
| `INFRA: INCOMPLETE` | Auto-create missing `wiki/sessions/index.md` and `wiki/entities/`. |

**No silent fallbacks. Explicit errors only.**

### Init Template

Create these files when initializing a new wiki:

- **wiki/index.md**: frontmatter `type: index, tags: [topic/wiki-system]`. Body: `# Wiki Index` with empty tables for Concepts, Entities, Decisions (cross-ref), and link to `[[wiki/sessions/index]]`.
- **wiki/log.md**: frontmatter `type: log`. Body: `# Wiki Log` append-only. First entry: `## [YYYY-MM-DD] setup | Wiki initialized`.
- **wiki/sessions/index.md**: frontmatter `type: session-archive`. Body: `# Sessions` with a bullet list of weekly folder links (`- [[wiki/sessions/YYMM-WN/index]]`). No session rows. Initially empty list.
- **wiki/sessions/YYMM-WN/index.md** (per week, lazily created): frontmatter `type: session-archive`. Body: a single table `| Session | Summary | Date |` for that week's sessions.
- Create empty directory: `wiki/entities/`.

---

## Architecture

- **raw/** — Immutable source material. Add-only. Debates, ingested external sources.
- **wiki/** — Compiled knowledge (LLM-owned). index.md, log.md, sessions/, entities/, topic subdirs.
- **decisions/** — Read-only for wiki. Cross-reference via wikilinks. If a concept has a decision, do NOT create a wiki entity — the decision IS canonical.

---

## Frontmatter Schema

All wiki/ and raw/ files require YAML frontmatter (obsidian-markdown skill format).

**wiki/ articles:**
```yaml
title: "Title"
type: concept | entity | source-summary | archive | session | session-archive
tags: [topic/{name}]
sources: ["[[raw/{topic}/{file}]]"]
created: YYYY-MM-DD
updated: YYYY-MM-DD
confidence: high | medium | low  # high=3+ sources, medium=1-2, low=unverified
related: ["[[wiki/{topic}/{article}]]"]
```

**raw/ sources:** title, source_url, author, published, collected, tags.

**Session promotion fields** (omit if 0 candidates):
- `has_candidates: true` — session has promotion candidates section.
- `promoted: true` — set by Lint after all candidates processed. Idempotent: crash-safe via dedup.

---

## Ingest

Fetch source into raw/, compile into wiki/. Always both steps.

### 1. Fetch (raw/)

1. Get content (URLs: defuddle skill; files/paste: direct).
2. Save as `raw/<topic>/YYYY-MM-DD-slug.md` (kebab-case, max 60 chars). Reuse existing topic dirs. Collision: append `-2`, `-3`.
3. Full frontmatter. Preserve original text, clean formatting noise only.

### 2. Compile (wiki/)

- Same thesis as existing → merge, add source. New concept → new article. Spans topics → most relevant + See Also.
- Factual conflicts: annotate with source attribution.
- **Entity rule**: decision exists → do NOT create entity. Link to decision.

### 3. Cascade Updates

Bounded scope only: (1) same topic directory, (2) direct `related:` links. Do NOT scan entire wiki.

### 4. Post-Ingest

Update `wiki/index.md`. Append to `wiki/log.md`: `## [YYYY-MM-DD] ingest | <title>`.

---

## Query

Search wiki and answer questions. No file writes (except Archive).

1. Read `wiki/index.md` + `wiki/sessions/index.md`.
2. `obsidian search query="<terms>" path="wiki" format=json`
3. Read relevant articles, synthesize answer. Prefer wiki over training knowledge. Cite with wikilinks.

**Archive** (on request): write as `type: archive`, update index with `[Archived]` prefix, append to log.

---

## Context

Surface relevant wiki knowledge before starting work. No file writes.
Same prerequisites as all modes — failures produce explicit errors.

**Invocation:** `/wiki context <topic-keywords>` (free text)

### Steps

1. Read `wiki/index.md` — identify related Entities, Concepts, Decisions.
2. Search both paths:
   ```bash
   obsidian search query="<keywords>" path="wiki" format=json
   obsidian search query="<keywords>" path="decisions" format=json
   ```
3. Read top matches (max 5, priority: decision > entity > concept > session).
4. Output per document: wikilink + 1-line relevance to current topic.
   - 0 results: "No related wiki knowledge found."
   - Search failure: explicit error ("obsidian search failed: \<reason\>")
5. Reference list retained in conversation context (no file storage). Session Recording collects into `## References`.

**vs Query**: Query synthesizes an answer. Context surfaces documents with per-item relevance notes + session recording linkage.

---

## Lint

Quality checks + knowledge integration. Weekly cadence minimum. Single-operator.

### Execution Order

1. **Promotion Integration** — candidates → entities
2. **Session Index Cleanup** — archive past-week entries
3. **Log Quarterly Rotation** — split at quarter boundary
4. **Deterministic Checks** — auto-fix
5. **Heuristic Checks** — report only

### Promotion Integration (Phase 2)

**Scope:** Only sessions with `has_candidates: true` AND `promoted: false`.

```bash
obsidian search query="has_candidates" path="wiki/sessions" format=json
```

Per candidate:
1. Read full session + referenced context section.
2. Search wiki for existing coverage: `obsidian search query="<keywords>" path="wiki" format=json`
3. **Criteria (pass 3 of 4):** Reusability, Independence, Non-duplication, Verifiability.
4. Outcomes:
   - Passes → create entity in `wiki/entities/`, add to index.
   - Duplicate → merge into existing, add session source.
   - Cross-session → synthesize single entity.
   - Contradicts → add `## Conflicts` section with attribution.
   - Decision exists → do NOT create entity. Link to decision.
   - Fails (<3/4) → leave as-is.
5. After ALL candidates processed: set `promoted: true`.
6. Update index + log: `## [YYYY-MM-DD] lint:promote | <N> processed, <M> created/updated`

**Safety:** `promoted: true` only after all candidates done. Crash → reprocess next run (dedup-safe).

### Session Index Verification

Main `wiki/sessions/index.md` is a folder-link list — no session rows.
Week formula: `N = ceil(day_of_month / 7)`.

Checks (auto-fix where possible):
- Every `wiki/sessions/YYMM-WN/` dir with `2*.md` session files must have a matching `index.md`. Missing → create from Init Template.
- Main `sessions/index.md` must list every existing weekly folder as `- [[wiki/sessions/YYMM-WN/index]]`. Missing link → add. Link to nonexistent folder → remove.
- If main `sessions/index.md` contains a session row (wikilink to a `YYYY-MM-DD-*.md` file), that row is a legacy leftover → move it to the correct `YYMM-WN/index.md`.
- Each weekly `index.md` table must include every session file in its folder. Missing row → add with placeholder summary. Row pointing to nonexistent file → mark `[MISSING]`.

### Log Quarterly Rotation

At first Lint of new quarter: rename old entries to `log-YYYY-QN.md`, create fresh `log.md` with back-reference `Previous: [[log-YYYY-QN]]`. Skip if same quarter.

### Deterministic Checks (auto-fix)

- **Index consistency**: file exists but missing from index → add `(no summary)`. Index entry → no file → `[MISSING]`.
- **Internal links**: broken wikilink → search wiki/ for same name. One match → fix. Else → report.
- **Raw references**: sources field → missing raw/ file → search. One match → fix. Else → report.
- **See Also**: within topic dir, add missing cross-refs, remove dead links.
- **Frontmatter**: required fields (title, type, tags, created, updated). Missing → report.
- **Table structure**: for every markdown table in wiki/, verify `header row → separator row (| --- | ... |) → data rows`, with no orphan separator rows mid-table and no data rows before the separator. Violations → report with file + line.

### Heuristic Checks (report only)

Contradictions, outdated claims, orphan pages, missing concept pages, cross-topic gaps.

### Post-Lint

Append: `## [YYYY-MM-DD] lint | <N> found, <M> fixed, <P> candidates processed`

---

## Session Recording

Create session file at session end.

### Weekly Folder Path

`YYMM-WN`: `YY`=2-digit year, `MM`=month, `N`=`ceil(day/7)`. Examples: 2026-04-06→`2604-W1`, 2026-04-15→`2604-W3`.
NOT ISO 8601. Session start time determines week. Collision: append `-2`, `-3`.

File: `wiki/sessions/YYMM-WN/YYYY-MM-DD-topic.md`

```yaml
title: "YYYY-MM-DD Topic"
type: session
tags: [topic/{relevant}]
created: YYYY-MM-DD
updated: YYYY-MM-DD
confidence: high
```

### Body Structure

1. `## 목적` — session goals
2. `## 참조 문서` — wiki context results (if `/wiki context` was run; see below)
3. Decisions, actions, next steps, gotchas
4. `## 승격 후보` (if any; see Phase 1 below)

### 참조 문서 Section (`## 참조 문서`)

Record `/wiki context` results after `## 목적`.

```markdown
## 참조 문서

- [[decisions/205-pipeline-architecture]] — independent session model needed
- [[wiki/entities/windows-ipc-patterns]] — Named Pipe constraints affect IPC design
```

0 results: `관련 wiki 지식 없음.`

Rules:
- If `/wiki context` ran: always record (even 0 results).
- If not ran: omit `## 참조 문서` entirely.
- Add docs referenced mid-session (query results, directly read entities).
- Max 10. Overflow: prioritize decision > entity > concept > session. Dedup wikilinks.

### Promotion Candidate Extraction (Phase 1)

Extract reusable knowledge after writing session body.

1. Review for discoveries useful in future contexts.
2. **Context sufficiency**: session body must contain cause/process/conclusion. Enrich if insufficient.
3. Append `## 승격 후보` section:
   ```markdown
   - **[Keyword]**: [1-2 sentence discovery, standalone-understandable].
     - Context: see `## [Section Name]`
     - Target: merge into [[wiki/entities/xxx]] or new entity `suggested-name`
   ```
4. Set `has_candidates: true`, `promoted: false`. 0 candidates → omit section + fields.

Rules: only reusable knowledge (not work logs). When uncertain, include — Lint Phase 2 filters. Self-test: "Can a Lint LLM understand this without session context?"

### Post-Session

1. Add row to `wiki/sessions/YYMM-WN/index.md` (the weekly index). Create the file from Init Template if missing.
2. Ensure `wiki/sessions/index.md` lists this week's folder (e.g., `- [[wiki/sessions/YYMM-WN/index]]`). Add if missing. Main index never holds session rows.
3. Append: `## [YYYY-MM-DD] session | <topic>`

---

## Conventions

- Obsidian Flavored Markdown. Wikilinks internal, markdown links external.
- wiki/ max 1 level of topic subdirs. Exception: `sessions/YYMM-WN/`.
- `updated` = knowledge change date, not filesystem mtime.
- Ingest/Archive update index + log. Lint updates log. Query/Context write nothing.
- Search priority: index.md first, then Obsidian CLI.
- File collision: append numeric suffix. Never overwrite.
