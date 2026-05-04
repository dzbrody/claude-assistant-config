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

## Other Scripts

| Script | Purpose |
|--------|---------|
| `health-check.sh` | Verify all MCP servers and directories are in order |
| `ssm-mcp-tunnel.sh` | Open SSM tunnel to EC2 for MCP access |
| `sync-nextcloud-to-openproject.sh` | Migrate files from NextCloud to S3 |
| `decommission-nextcloud.sh` | NextCloud cleanup |
