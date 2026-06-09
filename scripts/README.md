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
1. Checks AWS SSO credentials
2. Checks WhatsApp bridge health (Bearer token auth since v0.3.0)
3. Extracts the `## Prompt` section from the task `.md` file
4. Injects private contact data from `.people.private.md`
5. Writes prompt to a temp file and runs `claude --print` — streams tool calls live
6. Captures output, sends summary email to `db@axinagroup.com`

**Requires:**
- `~/.local/bin/claude` (native install) — resolved dynamically via `command -v claude`
- AWS SSO session active (`aws sso login --profile xgc-main`)
- WhatsApp bridge running

---

## Other Scripts

| Script | Purpose |
|--------|---------|
| `health-check.sh` | Verify all MCP servers and directories are in order |
| `ssm-mcp-tunnel.sh` | Open SSM tunnel to EC2 for direct MCP access |
