# Ingest Gemini Meeting Notes → OpenProject

Fetch the latest email(s) from `gemini-notes@google.com`, refine the raw notes through the Axina business context filter, and create or update OpenProject work packages.

---

## Step 1 — Fetch the email

Call `mcp__google-workspace__search_emails` with query `from:gemini-notes@google.com newer_than:2d`. Use `maxResults=10`.

For each result, call `mcp__google-workspace__read_email` to get the full body.

If no emails found, report: "No Gemini meeting notes received in the last 48 hours." and stop.

---

## Step 2 — Business context filter

For each email body, apply the following refinement rules before creating tasks:

### 2a. Strip filler
Remove: scheduling boilerplate ("Let's connect", "Looking forward"), pleasantries, duplicate sentences, filler phrases ("as we discussed", "just to confirm"), and any generic AI-generated summary prose that adds no actionable information.

### 2b. Map names to team members
Cross-reference names mentioned in the notes against the Task Assignment Rules from `morning-briefing.md`:
- Dan / Daniel / db → OP user ID 5
- Henry → OP user ID 13
- Trish → OP user ID 17
- Girish → OP user ID 16
- Jatin → OP user ID 23
- Ben / Benjamin → OP user ID 12
- Izzy → OP user ID 14
- Sean McNeill → external (assign follow-up task to Dan, ID 5; note Sean as counterpart in description)
- Unknown names → assign to Dan (ID 5) with the original name noted in the description

### 2c. Route to the correct project
Use the Project Routing Guide from `morning-briefing.md` to assign each action item to the correct project:
- Mentions of carbon, MRV, ANCR, ANCR rollout → consider `axina-carbon-registry` (ID 28) or geo sub-project (Angola → 8, Uganda → 7)
- Angola ADVENT City / Seaport / IITS → `angola-admin` (ID 8), version ID 29
- Uganda Commissioner / State House / Aimable → `uganda-admin` (ID 7), version ID 20
- Engineering / AXERP / platform → route by sub-domain per routing guide
- M&A / TGI corporate / financials → `m-and-a` (ID 13) or `tgi-corporate` (ID 14)
- Sales / pipeline / new country → `axina-sales` (ID 11)
- Default fallback → `axina-group-admin` (ID 3)

### 2d. Detect type
- Use **Milestone** if a hard date is stated explicitly ("by June 20", "deadline", "due").
- Use **Task** for all other items.

---

## Step 3 — Dedup check

For each refined action item, call `mcp__openproject-remote__list_work_packages` on the target project. Search for open tasks with a matching subject keyword. **Do not create duplicates.** If a match exists, note "already tracked as #[id]" in the output.

---

## Step 4 — Create work packages

For each new (non-duplicate) action item, call `mcp__openproject-remote__create_work_package` with:
- `project_id`: from routing above
- `subject`: `[Gemini] {concise action item}` — prefix with `[4ward]`, `[XGC]`, `[AXINA]`, or `[TGI]` if the meeting context makes the org identifiable
- `type`: Task or Milestone
- `assignee_id`: from name mapping above
- `version_id`: set if a pipeline stage is clear (e.g., Angola active deployment → 29, Uganda MOU → 20)
- `description`: meeting title, email date, and the exact relevant excerpt from the notes

---

## Step 5 — Output summary

Print to terminal:

```
Gemini Notes Ingested — {email subject} ({date})
  Action items found:     N
  Tasks created:          N  (#id, #id, ...)
  Milestones created:     N  (#id, ...)
  Already tracked:        N  (#id matches)
  Skipped (no match):     N
```

Then ask: "Open any of these in OpenProject? Paste task IDs separated by commas, or press Enter to skip."
If IDs provided, print the direct URL for each: `https://projects.axinagroup.com/work_packages/{id}`
