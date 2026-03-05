# accelix-ai-plugins — Maintenance & Development Rules

AccelixGames 팀 전용 Claude Code 플러그인 마켓플레이스.

## Absolute Rules

### 1. Version & Changelog

When **any** command, skill, reference, or hook file is modified (even 1 line), you MUST do all of the following before completing the task:

1. **Plugin `CHANGELOG.md`** — Add entry under the current version in `plugins/{plugin}/CHANGELOG.md`
2. **Plugin `plugin.json`** — Update `version` in `plugins/{plugin}/.claude-plugin/plugin.json`
3. **Marketplace `marketplace.json`** — Sync the plugin's `version` in `.claude-plugin/marketplace.json`
4. **Marketplace `CHANGELOG.md`** — Add a summary entry (plugin name + version) in root `CHANGELOG.md`
5. **`README.md`** — Update if commands were added, changed, or removed

### 2. Security Review — MANDATORY before every commit

Before committing any change to plugin files, **you MUST verify** that none of the following are exposed:

- **Team-internal information**: real project names, internal server names, internal URLs
- **Personal information**: individual names, personal emails, user-specific paths (C:\Users\{name})
- **Project-specific details**: real branch names from live projects, real changeset IDs (use small placeholder IDs like cs:100-150), real file paths from team projects
- **Credentials**: API keys, tokens, passwords

**How to verify:**
1. The `check_info_leak.py` hook runs automatically on Edit/Write to plugin files
2. Before committing, also manually grep for patterns:
   ```bash
   grep -rn "Alpha2\|MacBuilder\|MaidCafe\|ProjectMaid\|C:\\\\Users\\\\" plugins/
   ```
3. All examples must use generic, fictional placeholders:
   - Branches: `/main/develop`, `/main/release`, `/main/feature-login`
   - Changeset IDs: `cs:100`, `cs:150` (small numbers)
   - Servers: `MyRepo@localhost:8087`
   - Paths: `Assets/Scripts/Player.cs` (generic Unity paths only)

### 3. Version Management

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

## Development Workflow

### Adding a New Command

1. Create `plugins/{plugin}/commands/{command-name}.md`
2. Follow the command format:
   ```yaml
   ---
   allowed-tools: Bash(cm ...:*)
   description: English description (한국어 설명)
   argument-hint: "[optional-args]"
   ---
   ```
3. Write in **English** (Claude efficiency)
4. `allowed-tools`: Only permit safe, read-only commands — no file editing tools
5. End with: `"Do not use any other tools. Do not send any other text or messages besides these tool calls."`
6. Use `!` backtick syntax to inject live context (e.g., `` !`cm wi` ``)
7. **Security check**: Ensure all examples use generic placeholders
8. Update plugin CHANGELOG + version + marketplace version + README

### Adding a New Skill

1. Create `plugins/{plugin}/skills/{skill-name}/SKILL.md`
2. Body: **English**
3. `description` field: Include Korean triggers, update when new keywords are discovered
4. Keep SKILL.md under 500 lines — move detail to `references/`
5. **Security check**: Ensure all examples use generic placeholders
6. Update plugin CHANGELOG + version + marketplace version

### Updating References

1. Based on official tool documentation / `cm help` output
2. Add new commands/options as they are discovered
3. Include practical examples — **all generic, no real project data**

### Adding a New Plugin

1. Create `plugins/{plugin-name}/` with:
   - `.claude-plugin/plugin.json` (name, version, description, author, repository, license, keywords)
   - `CHANGELOG.md` (initial version entry)
   - `commands/` and/or `skills/` directories
2. Add the plugin entry to `.claude-plugin/marketplace.json`
3. Update root `CHANGELOG.md` and `README.md`
4. **Security review** before committing

### Testing a Plugin Change

1. Commit and push changes
2. Update marketplace cache: `claude plugin marketplace update accelix-ai-plugins`
3. Update plugin: `claude plugin update {plugin-name}`
4. Test affected commands in a live workspace
5. Verify with `claude plugin list` that the new version is shown

---

## Writing Rules

### Commands (`commands/*.md`)

- Write in **English** (Claude efficiency)
- `description` field: bilingual — `"English description (한국어 설명)"`
- `allowed-tools`: Only permit safe commands — no file editing tools
- End with: `"Do not use any other tools. Do not send any other text or messages besides these tool calls."`
- Use `!` backtick syntax to inject live context
- `argument-hint`: Show expected arguments if the command accepts them

### Skills (`SKILL.md`)

- Body: **English**
- `description` field: Include Korean triggers
- Keep SKILL.md under 500 lines — move detail to `references/`
- Link to available slash commands so users know what's available

### References (`references/*.md`)

- Based on official tool documentation / help output
- Add new commands/options as they are discovered
- Include practical examples — **all generic placeholders**

### Hooks (`hooks/`)

- `hooks.json` at marketplace root for marketplace-wide hooks
- Scripts in `hooks/scripts/` — use `${CLAUDE_PLUGIN_ROOT}` for portable paths
- Security hooks run on PreToolUse for Edit/Write operations

---

## Marketplace Structure

```
accelix-ai-plugins/                     — Marketplace root (git repo)
├── .claude-plugin/
│   └── marketplace.json                — Marketplace manifest
├── CLAUDE.md                           — This file (rules & workflow)
├── CHANGELOG.md                        — Marketplace-level changelog
├── README.md                           — Install/usage guide (Korean)
├── LICENSE                             — MIT License
├── .gitignore
├── hooks/
│   ├── hooks.json                      — Marketplace-wide hooks
│   └── scripts/
│       └── check_info_leak.py          — Information leak detection
└── plugins/
    └── claude-plastic-scm/             — PlasticSCM plugin
        ├── .claude-plugin/
        │   └── plugin.json             — Plugin metadata (version here)
        ├── CHANGELOG.md                — Plugin-specific changelog
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

## Distribution

```bash
# Add marketplace (first time only)
claude plugin marketplace add AccelixGames/accelix-ai-plugins

# Install a plugin
claude plugin install claude-plastic-scm

# Update (after git push)
claude plugin marketplace update accelix-ai-plugins
claude plugin update claude-plastic-scm@accelix-ai-plugins

# Uninstall
claude plugin uninstall claude-plastic-scm
```
