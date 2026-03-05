# claude-plugins-accelix — Maintenance Rules

AccelixGames 팀 전용 Claude Code 플러그인 마켓플레이스.

## Absolute Rules

When **any** command, skill, or reference file is modified (even 1 line), you MUST do all of the following before completing the task:

1. **`CHANGELOG.md`** — Add entry under the current version (Keep a Changelog, Korean)
2. **Version files** — Update `version` (Semantic Versioning, both must match):
   - `plugins/{plugin}/.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json` (해당 plugin 항목)
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
- `allowed-tools`: Only permit safe commands — no file editing tools
- End with: `"Do not use any other tools. Do not send any other text or messages besides these tool calls."`
- Use `!` backtick syntax to inject live context (e.g., `!cm wi`, `!cm status`)
- `argument-hint`: Show expected arguments if the command accepts them

### Skills (`SKILL.md`)

- Body: **English**
- `description` field: Include Korean triggers, update when new keywords are discovered
- Keep SKILL.md under 500 lines — move detail to `references/`

### References (`references/*.md`)

- Based on official tool documentation / help output
- Add new commands/options as they are discovered
- Include practical examples for each command

---

## Marketplace Structure

```
claude-plugins-accelix/                  — Marketplace root (git repo)
├── .claude-plugin/
│   └── marketplace.json                 — Marketplace manifest (all plugins listed)
├── CLAUDE.md                            — This file (maintenance rules)
├── CHANGELOG.md                         — Version history (Keep a Changelog, Korean)
├── README.md                            — Install/usage guide (Korean)
├── .gitignore
└── plugins/
    └── claude-plastic-scm/              — PlasticSCM plugin
        ├── .claude-plugin/
        │   └── plugin.json
        ├── LICENSE
        ├── commands/
        │   ├── cm-checkin.md
        │   ├── cm-merge-comment.md
        │   ├── cm-branch-info.md
        │   ├── cm-status.md
        │   ├── cm-history.md
        │   └── cm-diff.md
        └── skills/
            └── plastic-scm/
                ├── SKILL.md
                └── references/
                    └── cm-commands.md
```

### Adding a New Plugin

1. Create `plugins/{plugin-name}/` with `.claude-plugin/plugin.json`
2. Add the plugin entry to `.claude-plugin/marketplace.json`
3. Update `CHANGELOG.md` and `README.md`

## Distribution

```bash
# Add marketplace (first time only)
claude plugin marketplace add AccelixGames/claude-plugins-accelix

# Install a plugin
claude plugin install claude-plastic-scm

# Update (after git push)
claude plugin marketplace update claude-plugins-accelix
claude plugin update claude-plastic-scm

# Uninstall
claude plugin uninstall claude-plastic-scm
```
