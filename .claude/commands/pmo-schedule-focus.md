# PMO Schedule Focus — Block Deep Work Time for High-Priority Tasks

Pull Daniel's top overdue and high-priority OpenProject tasks, find open calendar slots in the next 48 hours, and create structured "PMO Focus Block" calendar entries to protect focused time.

---

## Step 1 — Get top-priority tasks from OpenProject

Call `mcp__openproject-remote__list_work_packages` with `status=open` across all projects (same list as `/pmo-dedup`). Run in parallel.

From the results, rank tasks by:
1. **Overdue** (due date < today) — highest priority, flag with ⚠️
2. **Priority = urgent or high** — next
3. **Priority = normal with due date within 7 days** — next
4. **No due date, assigned to Dan (user ID 5)** — catch-all

Select the **top 5** tasks. If fewer than 5 have due dates, fill with highest-priority undated tasks assigned to Dan.

---

## Step 2 — Scan calendar for free slots

Call `mcp__google-workspace__list_events` for today and tomorrow (next 48 hours). Identify free blocks by finding gaps between existing events.

Rules for usable focus slots:
- Minimum 45 minutes of contiguous free time
- Working hours only: 8:00 AM – 7:00 PM Eastern
- Do not insert blocks back-to-back with other meetings — leave at least 15 minutes of buffer before and after
- Do not use slots already containing a "PMO Focus Block" event (avoid duplicating)

---

## Step 3 — Match tasks to slots

Pair the top tasks (in priority order) with the available slots (in chronological order). Each task gets one focus block. Duration guidelines:
- Overdue milestone tasks: 90 minutes
- High-priority tasks: 60 minutes
- Normal tasks: 45 minutes

If there are fewer slots than tasks, assign to available slots and note the remaining tasks as "no slot available — calendar is full."

---

## Step 4 — Present for confirmation

Print a table:

```
Proposed PMO Focus Blocks — Next 48 Hours
──────────────────────────────────────────────────────────────────────────────────
 Date       Time              Duration  Task                              Priority
 ─────────  ────────────────  ────────  ────────────────────────────────  ────────
 [date]     [HH:MM–HH:MM ET]  [Xm]      #[id] [subject truncated 40ch]   ⚠️ Overdue
 [date]     [HH:MM–HH:MM ET]  [Xm]      #[id] [subject truncated 40ch]   High
[...]
──────────────────────────────────────────────────────────────────────────────────
Tasks without available slots: [list subjects or "none"]
```

Ask: `Create these calendar focus blocks? [y/N]`

---

## Step 5 — Create calendar events (on confirmation)

For each confirmed block, call `mcp__google-workspace__create_event` with:
- `summary`: `PMO Focus Block: [task subject] (OP#[id])`
- `start`: slot start time (ISO 8601, Eastern)
- `end`: slot end time
- `description`: `OpenProject task: https://projects.axinagroup.com/work_packages/[id]\nPriority: [priority]\nDue: [due date or "no date set"]`
- `calendar`: `db@xgccorp.com` primary calendar

---

## Step 6 — Confirm

Print:

```
Focus blocks created:
  [date] [time] → #[id] [subject]
  [...]
Tasks without slots (calendar full):
  #[id] [subject] — schedule manually
```
