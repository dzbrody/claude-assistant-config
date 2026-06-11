# PMO Clean Backlog — Triage Tasks Missing Assignees or Dates

Find open work packages with missing assignees, start dates, or due dates. Apply smart defaults based on project context and present a confirmation table before writing any changes.

---

## Step 1 — Gather open tasks

Call `mcp__openproject-remote__list_work_packages` with `status=open` for all active projects (same list as `/pmo-dedup`). Run in parallel.

---

## Step 2 — Identify backlog issues

For each open work package, flag it if it has ANY of the following:

- `assignee` is null or unset
- `startDate` is null
- `dueDate` is null (applies only to Tasks and Milestones — ignore Feature types without dates)
- `priority` is null or set to "low" with no due date (potential ghost task)

---

## Step 3 — Apply triage defaults

For each flagged task, determine the smart default based on these rules:

### Missing assignee
- Subject prefix `[TSPG]`, `[Dev]`, `[TGI-Tech]` → assign to Dan (ID 5) as default triage owner, note in description: *"Assignee defaulted to Dan Brody by /pmo-clean-backlog — reassign if needed."*
- Subject prefix `[Angola]` → assign Dan (ID 5); version = "6. Signed — Active Deployment" (ID 29)
- Subject prefix `[Uganda]` → assign Dan (ID 5); version = "4. MOU / Agreement" (ID 20)
- Subject prefix `[NCR-]` → assign Dan (ID 5)
- Subject prefix `[Gemini]` → assign Dan (ID 5)
- No prefix / unknown → flag for manual review, do not auto-assign

### Missing start date
- Set to today's date

### Missing due date
- If the task belongs to a version/milestone with a defined end date → inherit that end date
- If no version → set due date to **+14 days from today** as a triage placeholder; note: *"Due date set to +14d triage placeholder by /pmo-clean-backlog."*
- Milestones: never set a placeholder date — flag for manual review instead

---

## Step 4 — Present for confirmation

Print a table:

```
Proposed Backlog Cleanup
──────────────────────────────────────────────────────────────────────────────────────
 ID      Subject (truncated 55 chars)           Project         Issue            Proposed Fix
 ──────  ─────────────────────────────────────  ──────────────  ───────────────  ──────────────────────────
 #[id]   [subject]                              [project]       No assignee      → Dan Brody (ID 5)
 #[id]   [subject]                              [project]       No due date      → +14d triage placeholder
 #[id]   [subject]                              [project]       No start date    → today
 #[id]   [subject]                              [project]       No assignee      → Manual review (no prefix)
[...]
──────────────────────────────────────────────────────────────────────────────────────
[N] tasks flagged. [M] require manual review (no auto-fix available).
```

If no issues found, print: "Backlog is clean — all open tasks have assignees and dates." and stop.

Ask: `Apply these triage defaults? [y/N]`

---

## Step 5 — Apply changes (on confirmation)

For each confirmed fix, call `mcp__openproject-remote__update_work_package` with the relevant fields (`assignee_id`, `startDate`, `dueDate`).

Skip any tasks flagged for manual review — list them at the end.

---

## Step 6 — Print results

```
Backlog Cleanup Complete
──────────────────────────────────────────────────────────────────
 Task ID   Fix Applied                               Status
 ───────   ───────────────────────────────────────   ──────────
 #[id]     Assignee → Dan Brody                      Updated
 #[id]     Due date → [date]                         Updated
[...]
──────────────────────────────────────────────────────────────────
[N] tasks updated.

Requires manual review (no auto-fix applied):
 #[id] [subject] — [reason]
```
