---
name: wiki
description: >
  LLM Wiki (Karpathy) — Modes: ingest (소스→wiki 컴파일), query (wiki 검색·응답),
  context (작업 전 관련 지식 surface), lint (승격·검증·정리), session (세션 기록).
  Triggers: 'ingest', 'add to wiki', 'wiki query', 'wiki context', 'wiki lint',
  'wiki search', 'wiki health', 'session log', 'wiki에 추가', 'wiki 검색', 'wiki 건전성'.
  Also use when user says /wiki with or without arguments.
argument-hint: "ingest | query | context | lint | session"
---

# Wiki Workflow — Karpathy LLM Wiki Pattern

Ingest/Query/Lint operations for a persistent, compounding wiki.
Format is delegated to obsidian-markdown skill. Search is via Obsidian CLI.
Web source cleanup is delegated to defuddle skill.

Core ideas (Karpathy):
- "The LLM writes and maintains the wiki; the human reads and asks questions."
- "The wiki is a persistent, compounding artifact."
- "Obsidian is the IDE; the LLM is the programmer; the wiki is the codebase."

---

## Prerequisites (single batch — run on every invocation)

Run ALL checks in one command. Evaluate the combined output.

```bash
echo "---PREREQ---" && \
(obsidian version 2>/dev/null || echo "OBSIDIAN_CLI_MISSING") && \
(obsidian vault info=name 2>/dev/null || echo "NO_VAULT") && \
(test -d wiki && test -f wiki/index.md && echo "WIKI_OK" || echo "WIKI_NOT_INITIALIZED") && \
(test -f wiki/sessions/index.md && test -d wiki/entities && echo "INFRA_OK" || echo "INFRA_INCOMPLETE")
```

**Evaluate output — first failure wins, stop immediately:**

| Marker | Action |
|--------|--------|
| `OBSIDIAN_CLI_MISSING` | STOP. "Obsidian CLI not available. Obsidian must be running with CLI enabled (Settings → General → CLI)." |
| `NO_VAULT` | STOP. "No Obsidian vault open. Open the project root as an Obsidian vault." |
| `WIKI_NOT_INITIALIZED` | Ask user "No wiki found in this project. Initialize one?" If declined, STOP. If approved, create from Init Template below. |
| `INFRA_INCOMPLETE` | Auto-create missing paths. `wiki/sessions/index.md` from Init Template if absent. `wiki/entities/` dir if absent. No ask — infrastructure, not content. |

**No silent fallbacks. No grep fallback. Explicit errors only.**

### Wiki Initialization Template

When creating a new wiki, generate these files:

**wiki/index.md:**
```markdown
---
title: "Wiki Index"
type: index
tags:
  - topic/wiki-system
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Wiki Index

> LLM-maintained project knowledge catalog.

## Concepts

| Article | Summary | Updated |
|---------|---------|---------|

## Entities

| Article | Summary | Updated |
|---------|---------|---------|

## Sessions

> Session records: [[wiki/sessions/index]]
```

**wiki/log.md:**
```markdown
---
title: "Wiki Log"
type: log
tags:
  - topic/wiki-system
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Wiki Log

> Chronological operation log. Append-only.

## [YYYY-MM-DD] setup | Wiki initialized
```

**wiki/sessions/index.md:**
```markdown
---
title: "Sessions Index"
type: session-archive
tags:
  - topic/wiki-system
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Sessions

> Current week session records. Past weeks archived in weekly folders.

## Current Week (YYMM-WN)

| Session | Summary | Date |
|---------|---------|------|

## Archives

No archives yet.
```

Also create empty directory: `wiki/entities/`.

---

## Architecture

Two directories under the project root:

**raw/** — Immutable source material. Add-only, never modify existing files. Contains:
- Debate/discussion folders (e.g., `raw/design-discussions/`) — design discussion records
- Ingested external sources (e.g., `raw/llm-wiki/2026-04-06-karpathy-gist.md`)

**wiki/** — Compiled knowledge. LLM owns this layer. Contains:
- `wiki/index.md` — Global catalog. One row per article with link + summary + updated date.
- `wiki/log.md` — Append-only operation log.
- `wiki/sessions/` — Session log files (type=session).
- `wiki/entities/` — Entity pages for concepts without a formal decision.
- `wiki/<topic>/` — Topic-scoped articles.

**decisions/** — Formal design documents (read-only for wiki). Cross-reference with wikilinks but never modify. If a concept has a decision, do NOT create a wiki entity page for it — the decision IS the canonical page.

---

## Frontmatter Schema (Obsidian Properties)

All wiki/ and raw/ files MUST have YAML frontmatter. Use Obsidian Properties format (follow obsidian-markdown skill for syntax).

### wiki/ articles

```yaml
---
title: "Article Title"
type: concept | entity | source-summary | archive | session | session-archive
tags:
  - topic/{name}
sources:
  - "[[raw/{topic}/{file}]]"
created: YYYY-MM-DD
updated: YYYY-MM-DD
confidence: high | medium | low
related:
  - "[[wiki/{topic}/{article}]]"
---
```

### raw/ sources

```yaml
---
title: "Source Title"
source_url: "https://..."
author: "Author Name"
published: YYYY-MM-DD
collected: YYYY-MM-DD
tags:
  - topic/{name}
---
```

### Confidence levels

- **high**: 3+ corroborating sources, or authoritative primary source
- **medium**: 1-2 sources, reasonable but verify
- **low**: Single unverified source, or LLM synthesis without strong backing

### Session-specific fields

Session files may include additional frontmatter for the 2-Phase promotion system:

```yaml
has_candidates: true    # session contains 승격 후보 section
promoted: true          # all candidates processed by Lint
```

- `has_candidates: true` — set when session has a `## 승격 후보` section.
- `promoted: true` — set by Lint after all candidates in this session are processed.
- Omit both fields entirely if session has no promotion candidates (0 candidates).
- **Idempotency:** If Lint crashes mid-session, `promoted` stays `false`. Next Lint run reprocesses. Already-created entities detected by dedup search.

---

## Ingest

Fetch a source into raw/, then compile it into wiki/. Always both steps.

### 1. Fetch (raw/)

1. Get source content. For URLs, use the defuddle skill to extract clean markdown. For files or user paste, use directly.
2. Pick a topic directory. Reuse existing `raw/` subdirectories if topic matches. Create new only for genuinely distinct topics.
3. Save as `raw/<topic>/YYYY-MM-DD-descriptive-slug.md`.
   - Slug from source title, kebab-case, max 60 chars.
   - Published date unknown → omit date prefix. Set `published: Unknown` in frontmatter.
   - If a file with the same name exists, append a numeric suffix (`-2`, `-3`).
   - Include full frontmatter (title, source_url, author, published, collected, tags).
   - Preserve original text. Clean formatting noise. Do not rewrite opinions.

### 2. Compile (wiki/)

Determine where content belongs:
- **Same thesis as existing article** → Merge. Add source to Sources. Update sections.
- **New concept** → Create new article. Name after the concept, not the raw file.
- **Spans topics** → Place in most relevant. Add See Also to others.

Check for factual conflicts: annotate disagreements with source attribution.

**Entity rule**: If a `decisions/` document exists for this concept, do NOT create a wiki entity. Link to the decision instead.

### 3. Cascade Updates

After the primary article, check for ripple effects with bounded scope:
1. Scan articles **in the same topic directory** for content affected by the new source.
2. Scan articles **linked via `related:` fields** in the primary article.
3. Update every materially affected article. Refresh `updated` date.

Do NOT scan the entire wiki. Only same-topic + direct related links.

### 4. Post-Ingest

Update `wiki/index.md`: add/update entries for every touched article.

Append to `wiki/log.md`:
```
## [YYYY-MM-DD] ingest | <primary article title>
- Updated: <cascade-updated article>
```

---

## Query

Search the wiki and answer questions.

### Steps

1. Read `wiki/index.md` for structural overview. Also read `wiki/sessions/index.md` for current week sessions.
2. Use Obsidian CLI for targeted search:
   ```bash
   obsidian search query="<terms>" path="wiki" format=json
   ```
3. Read relevant articles and synthesize answer.
4. Prefer wiki content over training knowledge. Cite with wikilinks: `[[wiki/topic/article]]`.
5. Output answer in conversation. Do not write files unless asked.

### Archiving

When user asks to save the answer:
1. Write as new wiki page (type=archive). Never merge into existing articles.
2. Update `wiki/index.md`. Prefix summary with `[Archived]`.
3. Append to `wiki/log.md`:
   ```
   ## [YYYY-MM-DD] query | Archived: <page title>
   ```

---

## Context

Surface relevant wiki knowledge before starting work. No file writes.
Shares Prerequisites with all other modes — failures produce explicit errors, no silent fallbacks.

### Invocation

`/wiki context <topic-keywords>`

topic-keywords는 자유 텍스트. 예: `/wiki context agent02 implementer`, `/wiki context cooking system pipeline`.

### Steps

1. Read `wiki/index.md` — identify related entries from Entities, Concepts, Decisions tables.
2. Search wiki + decisions (두 경로 병렬):
   ```bash
   obsidian search query="<keywords>" path="wiki" format=json
   obsidian search query="<keywords>" path="decisions" format=json
   ```
3. Read top matches (max 5, priority: decision > entity > concept > session).
4. Output summary to conversation:
   - Per document: wikilink + relevance to current topic (1 line)
   - 0 results: "관련 wiki 지식 없음"
   - Search failure: 명시적 에러 보고 ("obsidian search failed: \<reason\>")
5. Reference list는 대화 컨텍스트에 유지됨 — 별도 상태 저장 불필요.
   Session Recording 시 대화에서 수집하여 `## 참조 문서`에 기록.

### Query와의 차이

- **Query**: 질문에 답하기 → 종합된 답변 출력. 파일 쓰기 없음 (archive 제외).
- **Context**: 작업 전 관련 지식 surface → 문서별 1줄 시사점 출력 + 세션 기록 연동. 파일 쓰기 없음.

---

## Lint

Quality checks + knowledge integration. Recommended minimum cadence: weekly. Ad hoc runs supported. Single-operator assumption (no concurrent Lint runs).

### Execution Order

Run in this order (promotion first — may create entities that affect subsequent checks):

1. **Promotion Integration** — process session candidates into wiki entities
2. **Session Index Cleanup** — archive past-week entries
3. **Log Quarterly Rotation** — split log.md at quarter boundary
4. **Deterministic Checks** — existing auto-fix checks
5. **Heuristic Checks** — existing report-only checks

### Promotion Integration (Phase 2)

Process knowledge candidates captured during Session Recording.

**Scan scope:** Only session files where `has_candidates: true` AND `promoted: false`. Do NOT scan all session files.

**Procedure:**

1. Find matching sessions:
   ```bash
   obsidian search query="has_candidates" path="wiki/sessions" format=json
   ```
   Then filter results to files where `has_candidates: true` AND `promoted: false` in frontmatter.

2. For each candidate in each matching session, perform ALL mandatory steps:
   a. Read the **full session file** (not just the candidate text).
   b. Read the context section referenced by `Context: see ## [Section Name]`.
   c. Search wiki broadly:
      ```bash
      obsidian search query="<candidate keywords>" path="wiki" format=json
      ```
   d. If existing entity found, read it fully before deciding merge vs. new.

3. **Apply promotion criteria** — candidate must pass **3 of 4**:
   - **Reusability:** Will this knowledge be referenced in other sessions/contexts?
   - **Independence:** Does it stand alone as an entity without session context?
   - **Non-duplication:** Is it genuinely new to the wiki?
   - **Verifiability:** Can it be confirmed by other sources or reproduction?

4. Execute based on outcome:
   - **New knowledge (passes 3/4)** → create entity file in `wiki/entities/`, follow existing wiki entity creation conventions (frontmatter, naming). Add to `wiki/index.md` Entities table.
   - **Duplicate of existing entity** → merge into existing entity, add source reference `[[wiki/sessions/YYMM-WN/file]]`.
   - **Cross-session related candidates** → synthesize into single entity. Add all session sources.
   - **Contradicts existing entity** → add `## Conflicts` section in the relevant entity with source attribution and both claims.
   - **Decision exists** → if `decisions/` has a document for this concept, do NOT create an entity. Add supplementary details to the candidate's session text only. Link to the decision.
   - **Fails criteria (<3 of 4)** → leave in session file as-is. No action needed.

5. After ALL candidates in a session are processed, set frontmatter: `promoted: true`.

6. Update `wiki/index.md` (if entities created/modified) and append to `wiki/log.md`:
   ```
   ## [YYYY-MM-DD] lint:promote | <N> candidates processed, <M> entities created/updated
   ```

**Safety notes:**
- `promoted: true` is set only after ALL candidates in a session are processed. If interrupted, the session stays `promoted: false` and will be reprocessed next run.
- Already-created entities are detected by the dedup search in step 2c — reprocessing is safe.
- Unprocessed candidates remain searchable via `obsidian search` even without Lint.

### Session Index Cleanup

Move past-week entries from `wiki/sessions/index.md` to weekly archive indexes.

**Procedure:**

1. Read `wiki/sessions/index.md`.
2. Calculate the current week folder name (`YYMM-WN`, same formula as Session Recording: `N = ceil(day_of_month / 7)`).
3. For each session entry in the table:
   - If the session's week folder ≠ current week → move the table row to `wiki/sessions/YYMM-WN/index.md`.
   - If the target `YYMM-WN/index.md` does not exist, create it with frontmatter:
     ```yaml
     ---
     title: "YYYY-MM WN Sessions"
     type: session-archive
     tags:
       - topic/wiki-system
     created: YYYY-MM-DD
     updated: YYYY-MM-DD
     ---
     ```
     And an empty sessions table.
4. After moving, `wiki/sessions/index.md` should contain only current week entries.
5. Verify: each weekly folder that contains `.md` session files has a corresponding `index.md`.

**Note:** Lint does NOT move session files (they are already in weekly folders since Phase 1). Lint only moves index table entries.

### Log Quarterly Rotation

At the first Lint of a new quarter, rotate `wiki/log.md`.

**Procedure:**

1. Determine current quarter from today's date (Q1=Jan-Mar, Q2=Apr-Jun, Q3=Jul-Sep, Q4=Oct-Dec).
2. Read `wiki/log.md` frontmatter. Check if the first entry's date belongs to a previous quarter.
3. If rotation needed:
   a. Split entries by quarter: entries dated in the previous quarter stay, entries dated in the current quarter are extracted.
   b. Rename the previous-quarter portion to `log-YYYY-QN.md` (e.g., `log-2026-Q1.md`).
   c. Create fresh `log.md` with current-quarter entries and back-reference:
      ```markdown
      ---
      title: "Wiki Log"
      type: log
      tags:
        - topic/wiki-system
      created: YYYY-MM-DD
      updated: YYYY-MM-DD
      ---

      # Wiki Log

      > Chronological operation log. Append-only.
      >
      > Previous: [[log-YYYY-QN]]
      ```
4. If no rotation needed (same quarter), skip.

**Date safety:** Rotation is based on today's date. Entries in the old log.md belong to whatever quarter the file represents.

### Deterministic Checks (auto-fix)

**Index consistency**: Compare `wiki/index.md` against actual wiki/ files.
- File exists but missing from index → add with `(no summary)` placeholder.
- Index entry → nonexistent file → mark `[MISSING]`.
- Scope: main index.md only (sessions have their own index hierarchy).

**Internal links**: Every wikilink in wiki/ articles.
- Target missing → search wiki/ for same name. One match → fix. Zero/multiple → report.
- Reflect weekly folder paths for session references (`sessions/YYMM-WN/file.md`).

**Raw references**: Every link in sources field must point to existing raw/ file.
- Missing → search raw/. One match → fix. Zero/multiple → report.

**See Also**: Within each topic directory.
- Add missing cross-references. Remove links to deleted files.

**Frontmatter**: Every wiki/ file must have required fields (title, type, tags, created, updated).
- Missing fields → report.

### Heuristic Checks (report only)

- Factual contradictions across articles
- Outdated claims superseded by newer sources
- Orphan pages with no inbound links
- Concepts frequently mentioned but lacking a page
- Missing cross-topic references

### Post-Lint

Append to `wiki/log.md` (one entry covering all Lint work):
```
## [YYYY-MM-DD] lint | <N> issues found, <M> auto-fixed, <P> candidates processed
```

Include promotion stats in the lint summary. Session index cleanup and log rotation are infrastructure — no separate log entries needed.

---

## Session Recording

At session end, create the session file in a weekly folder.

### Weekly Folder Path

1. Calculate week folder name `YYMM-WN`:
   - `YY` = 2-digit year, `MM` = 2-digit month, `N` = `ceil(day_of_month / 7)`
   - Example: 2026-04-06 → `2604-W1` (day 6, ceil(6/7) = 1)
   - Example: 2026-04-15 → `2604-W3` (day 15, ceil(15/7) = 3)
   - Example: 2026-12-31 → `2612-W5` (day 31, ceil(31/7) = 5)
   - This is NOT ISO 8601 week numbering. It is a human-readable month-week format.
2. Create `wiki/sessions/YYMM-WN/` folder if it does not exist.
3. Create session file: `wiki/sessions/YYMM-WN/YYYY-MM-DD-topic.md`
4. If a file with the same name exists, append a numeric suffix (`-2`, `-3`).

**Date boundary rule:** Session start time determines week assignment. A session starting at 23:50 on day 7 (Sunday) belongs to W1, not W2.

```yaml
---
title: "YYYY-MM-DD Session Topic"
type: session
tags:
  - topic/{relevant-topic}
created: YYYY-MM-DD
updated: YYYY-MM-DD
confidence: high
---
```

Body structure:
1. `## 목적` — session goals
2. `## 참조 문서` — wiki context results (있을 때만, 아래 규칙 참조)
3. 핵심 결정, Actions, Decisions, Next Steps, Gotchas 등
4. `## 승격 후보` (있을 때만, Phase 1 참조)

### 참조 문서 섹션 (`## 참조 문서`)

`/wiki context` 실행 결과를 기록. `## 목적` 바로 다음에 배치.

```markdown
## 참조 문서

- [[decisions/205-pipeline-architecture]] — 독립 세션 모델 전환 필요, 기존 디스패치 모델 전제 주의
- [[wiki/entities/windows-ipc-patterns]] — Named Pipe 제약이 IPC 설계에 영향
```

0건일 때:

```markdown
## 참조 문서

관련 wiki 지식 없음.
```

규칙:
- `/wiki context` 실행했으면 반드시 기록. 0건도 기록.
- `/wiki context` 미실행 세션은 `## 참조 문서` 섹션 자체 생략.
- 세션 중간에 추가 참조한 wiki 문서(query 결과, 직접 읽은 entity 등)도 추가.
- 최대 10건. 초과 시 decision > entity > concept > session 우선순위로 절삭.
- 중복 wikilink 제거 (같은 문서 2번 참조 시 1건으로).

### Promotion Candidate Extraction (Phase 1)

After writing the session body, extract reusable knowledge discovered during the session.

**Procedure:**

1. Review session content for discoveries that would be useful in future contexts.
2. **Context sufficiency check:** Does the session body contain cause/process/conclusion for each discovery? If insufficient, enrich the relevant session section BEFORE writing candidates.
3. If reusable knowledge exists, append a `## 승격 후보` section to the session:

```markdown
## 승격 후보

- **[Keyword]**: [Discovery in 1-2 sentences, sufficient for a future LLM to understand without this session's context].
  - Context: see `## [Section Name]` in this session
  - Target: merge into [[wiki/entities/xxx]] or new entity `suggested-name`
```

4. Set frontmatter flags:

```yaml
has_candidates: true
promoted: false
```

**Rules:**
- Only reusable knowledge qualifies — not work logs ("modified file X") or task tracking.
- 0 candidates → omit the `## 승격 후보` section entirely. Do not set `has_candidates`.
- Link to existing entities with wikilinks if the candidate relates to them.
- When uncertain whether something is reusable, include it as a candidate. Phase 2 (Lint) filters with strict 3-of-4 criteria.
- Self-verify: "Can a Lint LLM that never saw this session understand this candidate from the text alone?"

### Post-Session

1. Add row to `wiki/sessions/index.md` (current week table).
2. Append to `wiki/log.md`:
```
## [YYYY-MM-DD] session | <topic>
```

---

## Conventions

- All files use Obsidian Flavored Markdown (follow obsidian-markdown skill).
- Wikilinks `[[target]]` for internal references. Markdown links for external URLs.
- wiki/ supports one level of topic subdirectories only. No deeper nesting.
  Exception: `wiki/sessions/` allows weekly subfolders (`sessions/YYMM-WN/`).
- `updated` date = when knowledge content last changed (not filesystem timestamp).
- Ingest/Archive update both index.md and log.md. Lint updates log.md. Plain queries write nothing.
- Search priority: index.md first (structural overview), then Obsidian CLI (detailed search).
- File name collisions: append numeric suffix (`-2`, `-3`). Never overwrite.
