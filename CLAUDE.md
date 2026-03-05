# claude-plastic-scm — Maintenance Rules

## Absolute Rules

When **any** command, skill, or reference file is modified (even 1 line), you MUST do all of the following before completing the task:

1. **`CHANGELOG.md`** — Add entry under the current version (Keep a Changelog, Korean)
2. **`plugins/claude-plastic-scm/.claude-plugin/plugin.json`** AND **`.claude-plugin/marketplace.json`** — Update `version` (Semantic Versioning, both must match)
3. **`README.md`** — Update if commands were added, changed, or removed

### Version Management

- **Within a session:** Keep the same version across multiple changes — one version per commit
- **After commit:** Use the next version number for subsequent work
- **Semantic Versioning:**
  - MAJOR: Breaking changes (command rename, removed command)
  - MINOR: New commands, skills, or features
  - PATCH: Bug fixes, documentation improvements

### Keep a Changelog Categories (Korean)

| Category | Korean | Usage |
|----------|--------|-------|
| Added | 추가 | New commands, skills, features |
| Changed | 변경 | Modified behavior of existing commands/skills |
| Fixed | 수정 | Bug fixes |
| Removed | 제거 | Deleted commands, skills, features |

---

## Writing Rules

### Commands (`commands/*.md`)

- Write in **English** (Claude efficiency)
- `description` field: bilingual — `"English description (한국어 설명)"`
- `allowed-tools`: Only permit safe cm commands — no file editing tools
- End with: `"Do not use any other tools. Do not send any other text or messages besides these tool calls."`
- Use `!` backtick syntax to inject live context (e.g., `!cm wi`, `!cm status`)
- `argument-hint`: Show expected arguments if the command accepts them

### Skills (`skills/plastic-scm/SKILL.md`)

- Body: **English**
- `description` field: Include Korean triggers, update when new keywords are discovered
- Keep SKILL.md under 500 lines — move detail to `references/`
- Link to available `/cm-*` commands so users know what's available

### References (`skills/plastic-scm/references/cm-commands.md`)

- Based on `cm help {command}` output
- Add new commands/options as they are discovered
- Include practical examples for each command

---

## Plugin Structure

```
claude-plastic-scm/                      — Marketplace root (git repo)
├── .claude-plugin/
│   └── marketplace.json                 — Marketplace manifest
├── CLAUDE.md                            — This file (maintenance rules)
├── CHANGELOG.md                         — Version history (Keep a Changelog, Korean)
├── README.md                            — Install/usage guide (Korean)
├── .gitignore
└── plugins/
    └── claude-plastic-scm/              — Plugin root
        ├── .claude-plugin/
        │   └── plugin.json              — Plugin metadata (name, version, author)
        ├── LICENSE                      — MIT
        ├── commands/                    — Slash commands (user-invocable)
        │   ├── cm-checkin.md            — /cm-checkin
        │   ├── cm-merge-comment.md      — /cm-merge-comment
        │   ├── cm-branch-info.md        — /cm-branch-info
        │   ├── cm-status.md             — /cm-status
        │   ├── cm-history.md            — /cm-history
        │   └── cm-diff.md               — /cm-diff
        └── skills/
            └── plastic-scm/
                ├── SKILL.md             — Knowledge base (auto-trigger)
                └── references/
                    └── cm-commands.md   — Full cm CLI reference
```

**Key paths for maintenance:**
- Version: `plugins/claude-plastic-scm/.claude-plugin/plugin.json`
- Commands: `plugins/claude-plastic-scm/commands/`
- Skills: `plugins/claude-plastic-scm/skills/`
- Marketplace version: `.claude-plugin/marketplace.json` (sync with plugin.json)

## Distribution

```bash
# Add marketplace (first time only)
claude plugin marketplace add AccelixGames/claude-plastic-scm

# Install
claude plugin install claude-plastic-scm

# Update (after git push)
claude plugin marketplace update claude-plastic-scm
claude plugin update claude-plastic-scm

# Uninstall
claude plugin uninstall claude-plastic-scm
```