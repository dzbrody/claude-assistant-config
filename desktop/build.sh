#!/bin/bash
# Copyright (c) 2026 Yom Shore Ventures LLC
# dba: CTO Rescues - https://ctorescues.com/
# Author: Daniel Brody (@dzbrody)
#
# Principal Place of Business:
# 8 The Green – Suite 12060
# Dover, Delaware 19901
# United States
#
# All rights reserved. Proprietary and confidential.

# Packages app.py as a native .app bundle using py2app, OR creates a lightweight
# launcher .app using Automator/shell — we use the simpler shell approach here.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Claude Assistant"
APP_DEST="$HOME/Applications"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.dzbrody.claude-assistant.plist"

echo "Building '$APP_NAME'..."
mkdir -p "$APP_DEST"

# ---------- Create .app shell bundle ----------
APP_PATH="$APP_DEST/$APP_NAME.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Claude Assistant</string>
    <key>CFBundleIdentifier</key>
    <string>com.dzbrody.claude-assistant</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>launch</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Launcher script inside the .app
cat > "$APP_PATH/Contents/MacOS/launch" << LAUNCHER
#!/bin/bash
# Kill any existing instance
pkill -f "claude-assistant/desktop/app.py" 2>/dev/null || true; sleep 1
exec /usr/bin/env python3 "$SCRIPT_DIR/app.py"
LAUNCHER
chmod +x "$APP_PATH/Contents/MacOS/launch"

echo "✅ App built at: $APP_PATH"

# ---------- LaunchAgent (start at login) ----------
read -p "Install LaunchAgent to start at login? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    cat > "$LAUNCH_AGENT" << PLIST2
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dzbrody.claude-assistant</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_PATH/Contents/MacOS/launch</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/logs/claude-assistant/menu-bar.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/logs/claude-assistant/menu-bar.log</string>
</dict>
</plist>
PLIST2
    mkdir -p "$HOME/logs/claude-assistant"
    launchctl load "$LAUNCH_AGENT"
    echo "✅ LaunchAgent installed — app will start at login"
fi

echo ""
echo "To launch now:"
echo "  open '$APP_PATH'"
echo ""
echo "Or run directly:"
echo "  python3 $SCRIPT_DIR/app.py"
