# PMO Track Time — Log Calendar Blocks as OpenProject Time Entries

Scan today's Google Calendar events, match them to OpenProject work packages by task ID or keyword, and log the actual durations as time entries under Daniel Brody's profile.

---

## Step 1 — Fetch today's calendar events

Call `mcp__google-workspace__list_events` for today (from 00:00 to 23:59 local time). Retrieve all events with: `summary`, `start`, `end`, `description`.

---

## Step 2 — Match events to work packages

For each calendar event, attempt to match it to an OpenProject work package using these rules (in order):

1. **Explicit OP ID in title or description**: event title or description contains `#[number]` or `OP#[number]` → use that ID directly
2. **PMO Focus Block pattern**: title is `"PMO Focus Block: [Task Name] (OP#ID)"` → extract ID
3. **Keyword match**: event title contains a keyword that appears in an open work package subject (e.g., "Kazakhstan", "Tennessee", "Sean McNeill", "Uganda", "Angola") → use `mcp__openproject-remote__search_work_packages` to find the best match
4. **No match**: flag event as "unmatched — manual review needed"

Compute duration for each matched event in decimal hours (e.g., 1h30m = 1.5h).

---

## Step 3 — Present for confirmation

Print a table:

```
Proposed Time Log — [Today's Date]
──────────────────────────────────────────────────────────────────────
 Calendar Event                         Duration  OP Task           Match
 ─────────────────────────────────────  ────────  ────────────────  ──────
 [event title]                          [Xh Ym]   #[id] [subject]  [exact/keyword/none]
[...]
──────────────────────────────────────────────────────────────────────
Unmatched events (no OP task found):
 - [event title] [Xh Ym] — skipped
```

Ask: `Log these time entries to OpenProject? [y/N]`

---

## Step 4 — Log time entries (on confirmation)

For each confirmed match, POST to the OpenProject time entry endpoint:

```
POST https://projects.ctorescues.com/api/v3/time_entries
Authorization: Basic {AUTH}
Content-Type: application/json

{
  "hours": "PT{X}H{Y}M",
  "comment": { "format": "markdown", "raw": "Logged from Google Calendar: {event title}" },
  "spentOn": "{today ISO date}",
  "_links": {
    "workPackage": { "href": "/api/v3/work_packages/{id}" },
    "user": { "href": "/api/v3/users/5" },
    "activity": { "href": "/api/v3/time_entries/activities/1" }
  }
}
```

(Use the AXINA OP API key from `~/.claude-assistant/mcp-servers/openproject-mcp/.env` via the same Basic auth pattern as `morning-briefing.md`.)

---

## Step 5 — Print final summary

```
Time Logging Complete — [Date]
──────────────────────────────────────────────────────────────────────
 Task ID   Task Subject                             Duration   Status
 ───────   ───────────────────────────────────────  ────────   ──────
 #[id]     [subject]                                [Xh Ym]    Logged
 #[id]     [subject]                                [Xh Ym]    Logged
[...]
──────────────────────────────────────────────────────────────────────
Total logged: [N] entries, [X.X] hours. Unmatched: [M] events skipped.
```
