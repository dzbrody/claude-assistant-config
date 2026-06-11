#!/usr/bin/env python3
"""
WhatsApp Command Hub
Polls Dan's direct chat for !command triggers and fires headless Claude responses back.

Commands:
  !status [project]   — open work packages in that project (or axina-group-admin)
  !deadlines          — work packages with due dates in the next 7 days
  !brief              — one-paragraph summary of today's briefing file
  !ncr                — NCR Africa touchpoint status table
  !help               — list available commands

Runs as a launchd service or on-demand. State in ~/logs/claude-assistant/wa-cmd-state.json
"""

import json
import os
import subprocess
import sys
import urllib.request
import urllib.parse
import base64
from datetime import datetime, timezone, timedelta
from pathlib import Path

# ---- Config ----
WHATSAPP_BRIDGE = "http://localhost:8080"
OP_URL = "https://projects.axinagroup.com"
OP_API_KEY = os.environ.get("OPENPROJECT_API_KEY", "")
CLAUDE_BIN = os.environ.get("CLAUDE_BIN", str(Path.home() / ".local/bin/claude"))
STATE_FILE = Path.home() / "logs/claude-assistant/wa-cmd-state.json"
LOG_FILE = Path.home() / "logs/claude-assistant/wa-cmd-hub.log"
WA_TOKEN_FILE = Path.home() / "whatsapp-mcp/whatsapp-bridge/store/.bridge-token"
DAILY_BRIEF_DIR = Path.home() / ".claude-assistant/daily_briefs"

# Dan's direct JID — loaded from .people.private.md at runtime or env
DAN_JID = os.environ.get("DAN_JID", "14164569020@s.whatsapp.net")

COMMAND_PREFIX = "!"
POLL_LOOKBACK_MINUTES = 16  # slightly wider than cron interval to avoid gaps


# ---- Helpers ----
def log(msg: str):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


def _wa_token() -> str:
    try:
        return WA_TOKEN_FILE.read_text().strip()
    except Exception:
        return ""


def wa_get(path: str) -> dict:
    token = _wa_token()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(f"{WHATSAPP_BRIDGE}{path}", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        log(f"WA GET {path} failed: {e}")
        return {}


def wa_post(path: str, data: dict) -> dict:
    token = _wa_token()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(f"{WHATSAPP_BRIDGE}{path}", data=body, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        log(f"WA POST {path} failed: {e}")
        return {}


def send_reply(message: str):
    result = wa_post("/api/send", {"recipient": DAN_JID, "message": message})
    if not result.get("success"):
        log(f"Send failed: {result}")


def op_headers() -> dict:
    token = base64.b64encode(f"apikey:{OP_API_KEY}".encode()).decode()
    return {"Authorization": f"Basic {token}", "Content-Type": "application/json"}


def op_get(endpoint: str) -> dict:
    req = urllib.request.Request(
        f"{OP_URL}/api/v3/{endpoint}", headers=op_headers()
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        log(f"OP GET failed: {e}")
        return {}


def load_state() -> dict:
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"last_processed": (datetime.now(timezone.utc) - timedelta(minutes=POLL_LOOKBACK_MINUTES)).isoformat()}


def save_state(state: dict):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


# ---- Command Handlers ----
def cmd_status(project_arg: str) -> str:
    project = project_arg.strip() if project_arg.strip() else "axina-group-admin"
    # Map common shorthand
    aliases = {
        "uganda": "uganda-admin",
        "angola": "angola-admin",
        "tgi": "tgi-corporate",
        "axinod": "axinod",
        "sales": "axina-sales",
        "admin": "axina-group-admin",
    }
    project = aliases.get(project.lower(), project.lower())

    filters = urllib.parse.quote(json.dumps([{"status": {"operator": "o", "values": []}}]))
    data = op_get(f"projects/{project}/work_packages?filters={filters}&pageSize=10&sortBy=%5B%5B%22updatedAt%22%2C%22desc%22%5D%5D")
    items = data.get("_embedded", {}).get("elements", [])
    if not items:
        return f"📋 No open tasks in `{project}`."
    lines = [f"📋 *Open tasks — {project}* ({len(items)} shown):"]
    for wp in items[:10]:
        status = wp.get("_links", {}).get("status", {}).get("title", "")
        assignee = wp.get("_links", {}).get("assignee", {}).get("title", "—")
        lines.append(f"• #{wp['id']} {wp['subject'][:50]} [{status}] → {assignee}")
    return "\n".join(lines)


def cmd_deadlines() -> str:
    today = datetime.now(timezone.utc).date().isoformat()
    in_7 = (datetime.now(timezone.utc) + timedelta(days=7)).date().isoformat()
    filters = urllib.parse.quote(json.dumps([
        {"status": {"operator": "o", "values": []}},
        {"dueDate": {"operator": "<>d", "values": [today, in_7]}},
    ]))
    data = op_get(f"work_packages?filters={filters}&pageSize=20&sortBy=%5B%5B%22dueDate%22%2C%22asc%22%5D%5D")
    items = data.get("_embedded", {}).get("elements", [])
    if not items:
        return "📅 No tasks due in the next 7 days."
    lines = ["📅 *Deadlines — next 7 days:*"]
    for wp in items:
        due = wp.get("dueDate", "?")
        project = wp.get("_links", {}).get("project", {}).get("title", "")
        lines.append(f"• {due} — #{wp['id']} {wp['subject'][:45]} ({project})")
    return "\n".join(lines)


def cmd_brief() -> str:
    today = datetime.now().strftime("%Y-%m-%d")
    brief_file = DAILY_BRIEF_DIR / f"{today}.md"
    if not brief_file.exists():
        return f"📄 No briefing file found for {today}. Run `/brief-morning` first."
    content = brief_file.read_text()
    # Extract Alerts section for a compact summary
    lines = content.split("\n")
    alerts = []
    in_alerts = False
    for line in lines:
        if line.startswith("## Alerts"):
            in_alerts = True
            continue
        if in_alerts and line.startswith("## "):
            break
        if in_alerts and line.strip().startswith("- "):
            alerts.append(line.strip())
    if alerts:
        return f"📋 *Brief summary — {today}:*\n" + "\n".join(alerts[:6])
    return f"📋 *{today} brief is ready.* Check `daily_briefs/{today}.md` for full details."


def cmd_ncr() -> str:
    # Return static touchpoint table from today's brief if available
    today = datetime.now().strftime("%Y-%m-%d")
    brief_file = DAILY_BRIEF_DIR / f"{today}.md"
    if brief_file.exists():
        content = brief_file.read_text()
        lines = content.split("\n")
        table_lines = []
        in_table = False
        for line in lines:
            if "NCR Africa Groups" in line and "Touchpoint" in line:
                in_table = True
            if in_table:
                table_lines.append(line)
                if in_table and line.startswith("## ") and "NCR" not in line:
                    break
        if table_lines:
            return "🌍 *NCR Touchpoints:*\n" + "\n".join(table_lines[:15])
    return "🌍 NCR touchpoint data not available — run `/brief-morning` to refresh."


def cmd_help() -> str:
    return (
        "🤖 *Claude Command Hub*\n"
        "Available commands:\n"
        "• `!status [project]` — open tasks (e.g. `!status uganda`)\n"
        "• `!deadlines` — tasks due in next 7 days\n"
        "• `!brief` — today's briefing alerts summary\n"
        "• `!ncr` — NCR Africa touchpoint status\n"
        "• `!help` — this message"
    )


# ---- Main ----
def main():
    log("=== WhatsApp Command Hub starting ===")

    # Verify bridge is up
    health = wa_get("/api/health")
    if not health.get("connected"):
        log("WhatsApp bridge not connected — exiting")
        sys.exit(0)

    state = load_state()
    since = state["last_processed"]
    now = datetime.now(timezone.utc).isoformat()

    # Get recent messages from Dan's direct chat
    since_encoded = urllib.parse.quote(since)
    msgs_data = wa_get(f"/api/messages?chat_jid={DAN_JID}&after={since_encoded}&limit=50&sort_by=oldest")
    messages = msgs_data.get("messages", [])

    processed = 0
    for msg in messages:
        # Only process inbound messages (not_from_me)
        if msg.get("is_from_me"):
            continue
        text = (msg.get("text") or "").strip()
        if not text.startswith(COMMAND_PREFIX):
            continue

        parts = text[len(COMMAND_PREFIX):].split(None, 1)
        cmd = parts[0].lower() if parts else ""
        arg = parts[1] if len(parts) > 1 else ""

        log(f"Command: !{cmd} {arg!r}")

        if cmd == "status":
            reply = cmd_status(arg)
        elif cmd == "deadlines":
            reply = cmd_deadlines()
        elif cmd == "brief":
            reply = cmd_brief()
        elif cmd == "ncr":
            reply = cmd_ncr()
        elif cmd == "help":
            reply = cmd_help()
        else:
            reply = f"Unknown command `!{cmd}`. Type `!help` for available commands."

        send_reply(reply)
        processed += 1

    log(f"Processed {processed} command(s). Saving state.")
    save_state({"last_processed": now})


if __name__ == "__main__":
    main()
