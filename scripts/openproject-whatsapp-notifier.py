#!/usr/bin/env python3
"""
OpenProject → WhatsApp Notifier
Polls axina-group-admin for status changes and assignment updates,
posts a message with a link to the TSPG WhatsApp group.

Runs as a launchd service every 15 minutes.
State (last run timestamp) stored in ~/logs/claude-assistant/op-notifier-state.json
"""

import json
import os
import base64
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta
from pathlib import Path

# ---- Config ----
OP_URL = "https://projects.axinagroup.com"
OP_API_KEY = "YOUR_OPENPROJECT_API_KEY"
WHATSAPP_BRIDGE = "http://localhost:8080"
TSPG_JID = "120363424688758322@g.us"
PROJECT_ID = 3
PROJECT_IDENTIFIER = "axina-group-admin"
STATE_FILE = Path.home() / "logs/claude-assistant/op-notifier-state.json"
LOG_FILE = Path.home() / "logs/claude-assistant/op-notifier.log"

# Only notify for these change types
NOTIFY_STATUSES = True       # status changes
NOTIFY_ASSIGNMENTS = True    # assignee changes
NOTIFY_NEW = True            # newly created work packages
NOTIFY_DUE_DATE = False      # due date changes (can be noisy)

# ---- Helpers ----
def log(msg: str):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


def op_headers() -> dict:
    token = base64.b64encode(f"apikey:{OP_API_KEY}".encode()).decode()
    return {"Authorization": f"Basic {token}", "Content-Type": "application/json"}


def load_state() -> dict:
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            return json.load(f)
    # First run — look back 15 minutes
    return {"last_run": (datetime.now(timezone.utc) - timedelta(minutes=15)).isoformat()}


def save_state(state: dict):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


def wp_link(wp_id: int) -> str:
    return f"{OP_URL}/projects/{PROJECT_IDENTIFIER}/work_packages/{wp_id}"


def http_get(url: str, headers: dict) -> dict:
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        log(f"GET {url} failed: {e}")
        return {}


def http_post(url: str, data: dict) -> dict:
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body,
                                  headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        log(f"POST {url} failed: {e}")
        return {}


def send_whatsapp(message: str):
    result = http_post(f"{WHATSAPP_BRIDGE}/api/send",
                       {"recipient": TSPG_JID, "message": message})
    if result.get("success"):
        log(f"WhatsApp sent: {message[:80]}...")
    else:
        log(f"WhatsApp error: {result}")


def get_changed_work_packages(since: str) -> list:
    """Get work packages in axina-group-admin updated since `since` (ISO-8601)."""
    import urllib.parse
    filters = json.dumps([
        {"project": {"operator": "=", "values": [str(PROJECT_ID)]}},
        {"updatedAt": {"operator": "<>d",
                       "values": [since, datetime.now(timezone.utc).isoformat()]}},
    ])
    params = urllib.parse.urlencode({
        "filters": filters,
        "sortBy": '[["updatedAt","desc"]]',
        "pageSize": 50,
    })
    url = f"{OP_URL}/api/v3/work_packages?{params}"
    data = http_get(url, op_headers())
    return data.get("_embedded", {}).get("elements", [])


def get_journals(wp_id: int, since: str) -> list:
    """Get activity journal entries for a work package since `since`."""
    url = f"{OP_URL}/api/v3/work_packages/{wp_id}/activities"
    data = http_get(url, op_headers())
    all_entries = data.get("_embedded", {}).get("elements", [])
    return [e for e in all_entries if e.get("createdAt", "") > since]


def format_status_change(wp: dict, old_val: str, new_val: str, author: str) -> str:
    subject = wp["subject"][:55]
    link = wp_link(wp["id"])
    return (
        f"📋 *OpenProject Update*\n"
        f"#{wp['id']} {subject}\n"
        f"Status: *{old_val}* → *{new_val}*\n"
        f"By: {author}\n"
        f"🔗 {link}"
    )


def format_assignment_change(wp: dict, old_val: str, new_val: str, author: str) -> str:
    subject = wp["subject"][:55]
    link = wp_link(wp["id"])
    old_str = old_val if old_val else "Unassigned"
    new_str = new_val if new_val else "Unassigned"
    return (
        f"👤 *OpenProject Assignment*\n"
        f"#{wp['id']} {subject}\n"
        f"Assigned: *{old_str}* → *{new_str}*\n"
        f"By: {author}\n"
        f"🔗 {link}"
    )


def format_new_wp(wp: dict) -> str:
    subject = wp["subject"][:55]
    link = wp_link(wp["id"])
    assignee = wp["_links"].get("assignee", {}).get("title", "Unassigned")
    status = wp["_links"]["status"]["title"]
    author = wp["_links"].get("author", {}).get("title", "")
    return (
        f"🆕 *New Task in OpenProject*\n"
        f"#{wp['id']} {subject}\n"
        f"Status: {status} | Assigned: {assignee}\n"
        f"Created by: {author}\n"
        f"🔗 {link}"
    )


def is_newly_created(wp: dict, since: str) -> bool:
    return wp.get("createdAt", "") > since


def process_journals(wp: dict, journals: list) -> list[str]:
    """Extract notification messages from journal entries."""
    messages = []
    for journal in journals:
        author = journal.get("_links", {}).get("user", {}).get("title", "Unknown")
        details = journal.get("details", [])
        for detail in details:
            attr = detail.get("attribute", "")
            old_val = detail.get("oldValue") or detail.get("oldValueText", "")
            new_val = detail.get("newValue") or detail.get("newValueText", "")

            if NOTIFY_STATUSES and attr == "status":
                messages.append(format_status_change(wp, old_val, new_val, author))

            elif NOTIFY_ASSIGNMENTS and attr == "assignee":
                messages.append(format_assignment_change(wp, old_val, new_val, author))

            elif NOTIFY_DUE_DATE and attr == "dueDate" and new_val:
                subject = wp["subject"][:55]
                link = wp_link(wp["id"])
                messages.append(
                    f"📅 *Due Date Set*\n#{wp['id']} {subject}\n"
                    f"Due: *{new_val}*  (was: {old_val or 'none'})\n🔗 {link}"
                )
    return messages


def main():
    log("=== OpenProject WhatsApp Notifier starting ===")

    # Check WhatsApp bridge is up
    health = http_get(f"{WHATSAPP_BRIDGE}/api/health", {})
    if not health.get("connected"):
        log("WhatsApp bridge not connected — skipping")
        sys.exit(0)

    state = load_state()
    since = state["last_run"]
    now = datetime.now(timezone.utc).isoformat()
    log(f"Checking for changes since {since}")

    wps = get_changed_work_packages(since)
    log(f"Found {len(wps)} work packages updated since last run")

    notifications = []

    for wp in wps:
        # New work package
        if NOTIFY_NEW and is_newly_created(wp, since):
            notifications.append(format_new_wp(wp))
            continue  # creation covers all details — skip journals

        # Check journals for status/assignment changes
        journals = get_journals(wp["id"], since)
        msgs = process_journals(wp, journals)
        notifications.extend(msgs)

    log(f"Sending {len(notifications)} notification(s)")

    for msg in notifications:
        send_whatsapp(msg)

    # Save state
    save_state({"last_run": now})
    log(f"Done. Next run will check from {now}")


if __name__ == "__main__":
    main()
