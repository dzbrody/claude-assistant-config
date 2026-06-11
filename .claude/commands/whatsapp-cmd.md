# WhatsApp Command Hub

Run the WhatsApp command hub to poll Dan's direct chat for `!command` triggers and respond instantly.

## Usage

Run the polling script directly:
```bash
python3 ~/.claude-assistant/scripts/whatsapp-cmd-hub.py
```

Or install as a launchd service to run every 15 minutes (same pattern as the OP notifier).

## Available Commands (send from your phone)

| Command | Response |
|---|---|
| `!status [project]` | Open tasks in that project. Shorthand: `uganda`, `angola`, `tgi`, `axinod`, `sales` |
| `!deadlines` | All tasks with due dates in the next 7 days |
| `!brief` | Alerts section from today's morning briefing |
| `!ncr` | NCR Africa touchpoint table from today's brief |
| `!help` | List available commands |

## Install as launchd Service

To have this run every 15 minutes automatically:

```bash
cat > ~/Library/LaunchAgents/com.dzbrody.wa-cmd-hub.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.dzbrody.wa-cmd-hub</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/env</string>
        <string>python3</string>
        <string>/Users/dzbrody/.claude-assistant/scripts/whatsapp-cmd-hub.py</string>
    </array>
    <key>StartInterval</key><integer>900</integer>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OPENPROJECT_API_KEY</key><string>REPLACE_WITH_KEY</string>
        <key>DAN_JID</key><string>14164569020@s.whatsapp.net</string>
    </dict>
    <key>StandardOutPath</key><string>/Users/dzbrody/logs/claude-assistant/wa-cmd-hub.log</string>
    <key>StandardErrorPath</key><string>/Users/dzbrody/logs/claude-assistant/wa-cmd-hub.log</string>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.dzbrody.wa-cmd-hub.plist
```
