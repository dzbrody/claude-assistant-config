# Settings Reference

Reference copies of Claude configuration files. No real tokens or API keys are committed here — use placeholders only.

## Files

| File | Purpose |
|------|---------|
| `claude-settings.json` | Reference `.claude/settings.json` with placeholder values |

## What Goes Here

- Sanitized copies of settings files for version control and reference
- Structure and key names, with `<YOUR_VALUE_HERE>` for any secrets

## What Does Not Go Here

- Real API keys, tokens, or credentials
- `.claude.json` (excluded by `.gitignore` — contains auth tokens)

## Security

The `.gitignore` at the repo root excludes:
- `*.env`
- `*.secret`
- `claude-config.json` (the live `~/.claude.json` copy)

If you accidentally commit a credential, rotate it immediately, then remove it from git history with `git filter-repo` or BFG Repo Cleaner.
