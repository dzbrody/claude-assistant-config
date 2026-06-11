# PMO Sweep Completed — Auto-Close Finished Work Packages

Audit all open work packages. Identify tasks that are effectively done (100% progress or all child tasks closed) and present a confirmation table before closing them.

---

## Step 1 — Gather open tasks

Call `mcp__openproject-remote__list_work_packages` with `status=open` for each active project (same project list as `/pmo-dedup`). Run all calls in parallel.

---

## Step 2 — Identify candidates for closure

For each open work package, flag it as a closure candidate if ANY of the following are true:

- `percentageDone` is `100`
- Subject or description contains phrases: "done", "completed", "shipped", "signed", "confirmed", "paid", "resolved", "sent", "live", "launched" — and there is no further blocking action item in the description
- All child work packages (if any) have status `Closed` or `Finished` — check via `mcp__openproject-remote__list_work_packages` filtering by parent ID if children are listed

Do NOT flag tasks as candidates if:
- They have a future due date and no progress indicator
- They are Milestones (those require explicit manual close)
- Subject contains `[NCR-` prefix (NCR tasks require field confirmation)

---

## Step 3 — Present for confirmation

Print a table:

```
Proposed Closure — Sweep Completed Tasks
──────────────────────────────────────────────────────────────────────────
 ID      Subject (truncated 60 chars)               Project         Reason
 ──────  ─────────────────────────────────────────  ──────────────  ──────────────────
 #[id]   [subject]                                  [project]       100% progress
 #[id]   [subject]                                  [project]       All children closed
 #[id]   [subject]                                  [project]       Keyword: "confirmed"
[...]
──────────────────────────────────────────────────────────────────────────
[N] tasks flagged for closure across [M] projects.
```

If no candidates found, print: "No completed tasks identified. All open work packages appear to have active work remaining." and stop.

Ask: `Close these work packages? [y/N]`

---

## Step 4 — Close confirmed tasks

For each confirmed task, call `mcp__openproject-remote__update_work_package` with:
- `status`: `Closed`

Then post a comment via REST:
```
POST /api/v3/work_packages/{id}/activities
{ "comment": { "format": "markdown", "raw": "Closed by /pmo-sweep-completed — task marked complete." } }
```

---

## Step 5 — Print cleanup ledger

```
Sweep Complete
──────────────────────────────────────────────────────────────────
 Task ID   Subject                                   Status
 ───────   ───────────────────────────────────────   ──────────
 #[id]     [subject]                                 Closed
[...]
──────────────────────────────────────────────────────────────────
[N] tasks closed. [M] tasks skipped (user declined or criteria not met).
```
