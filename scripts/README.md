# Scripts

Utility scripts for the AXINA Claude Assistant ecosystem.

## Background Services (launchd)

Two scripts run automatically as launchd agents — started at login, no manual intervention needed.

### openproject-whatsapp-notifier.py

Posts OpenProject `axina-group-admin` changes to the AXINA-TSPG-TEAM WhatsApp group every 15 minutes.

**Notifies on:**
- 🆕 New work package created
- 📋 Status change (e.g. New → In Progress → Closed)
- 👤 Assignee change

**Every message includes a direct link** to the work package in OpenProject.

**Security note:** WhatsApp bridge v0.3.0+ requires Bearer token auth. The notifier injects the token automatically from `~/whatsapp-mcp/whatsapp-bridge/store/.bridge-token`. `save_state` only runs after all notifications succeed — failures exit 1 to preserve the retry window.

**Setup:**
```bash
# Already installed if you ran TEAM-INSTALL.md
launchctl load ~/Library/LaunchAgents/com.dzbrody.openproject-notifier.plist

# Check it's running
launchctl list | grep openproject-notifier

# View logs
tail -f ~/logs/claude-assistant/op-notifier.log

# Reload after editing the script
launchctl unload ~/Library/LaunchAgents/com.dzbrody.openproject-notifier.plist
launchctl load ~/Library/LaunchAgents/com.dzbrody.openproject-notifier.plist
```

**State file:** `~/logs/claude-assistant/op-notifier-state.json` — stores last-run timestamp. Delete to reset.

**Config** (edit top of script to change behaviour):
- `NOTIFY_STATUSES` — status changes (default: on)
- `NOTIFY_ASSIGNMENTS` — assignee changes (default: on)
- `NOTIFY_NEW` — new work packages (default: on)
- `NOTIFY_DUE_DATE` — due date changes (default: off, can be noisy)

---

## run-scheduled-task.sh

Runs a briefing prompt via the Claude CLI. Called by the menu bar app and can be run directly:

```bash
bash ~/.claude-assistant/scripts/run-scheduled-task.sh morning-briefing
```

**How it works:**
1. Checks AWS SSO credentials — result cached for 30 min via `~/.aws/.cred-cache-xgc-main` to avoid a round-trip on every run
2. Checks WhatsApp bridge health with a 3-second timeout (Bearer token auth since v0.3.0)
3. Extracts the `## Prompt` section from the task `.md` file
4. Injects private contact data via `os.environ` (not shell interpolation — prevents script injection)
5. Appends email instruction to the prompt so the entire run — task work and email summary — is handled in a single `claude` invocation
6. Writes prompt to a temp file; `trap EXIT` guarantees the temp file is wiped on any exit path
7. Runs `claude --print` — streams tool calls and output live, tees to the log file

**Requires:**
- `claude` resolved dynamically via `command -v claude`
- AWS SSO session active (`aws sso login --profile xgc-main`)
- WhatsApp bridge running

---

## whatsapp-cmd-hub.py

Polls Daniel's direct WhatsApp chat for `!command` triggers and responds automatically.

**Supported triggers:**
| Command | Response |
|---------|---------|
| `!status` | Summary of open OP tasks by project |
| `!deadlines` | Tasks with due dates in the next 7 days |
| `!brief` | Short morning-brief-style summary |
| `!ncr` | NCR Africa pipeline status |
| `!help` | Lists available commands |

Project shorthands accepted in commands: `uganda`, `angola`, `tgi`, `axinod`, `sales`.

State-tracked via `last_processed` timestamp — safe to run on a 15-minute cron without duplicating replies.

```bash
# Run manually
python3 ~/.claude-assistant/scripts/whatsapp-cmd-hub.py

# Install as 15-min cron
(crontab -l; echo "*/15 * * * * python3 ~/.claude-assistant/scripts/whatsapp-cmd-hub.py") | crontab -
```

---

## Other Scripts

| Script | Purpose |
|--------|---------|
| `health-check.sh` | Verify all MCP servers and directories are in order |
| `ssm-mcp-tunnel.sh` | Open SSM tunnel to EC2 on port 39128 for direct MCP access |
| `decommission-nextcloud.sh` | Paginated S3 bucket deletion — handles >1,000 object versions |
