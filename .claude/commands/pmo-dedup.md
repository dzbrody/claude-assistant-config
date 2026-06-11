# PMO Dedup — Identify and Collapse Duplicate Work Packages

Scan open work packages across all active projects, detect duplicates by title/description similarity, merge any unique details into the master task, and close the duplicate with a linking comment.

---

## Step 1 — Gather open tasks

Call `mcp__openproject-remote__list_work_packages` with `status=open` for each active project. Collect results from:

| Project | ID |
|---|---|
| axina-group-admin | 3 |
| axina-sales | 11 |
| uganda-admin | 7 |
| angola-admin | 8 |
| kazakhstan-admin | 9 |
| tgi-corporate | 14 |
| m-and-a | 13 |
| engineering | 33 |
| axina-carbon-registry | 28 |
| axinod | 51 |

Run all list calls in parallel. Build a flat list of all open work packages with: `id`, `subject`, `description`, `project_id`, `createdAt`.

---

## Step 2 — Detect duplicates

Group work packages by project. Within each project, compare task subjects using these rules:

- **Exact match** (case-insensitive, ignoring `[prefix]` tags): clear duplicate
- **High similarity**: subject shares 4+ consecutive words or a key noun phrase (e.g., "Kazakhstan presentation", "Tennessee 2.5MW", "Sean McNeill pitch deck")
- **Same action + same deliverable**: e.g., two tasks both say "send NDA to Henry"

For each candidate duplicate pair, identify:
- **Master** = the older task (lower ID)
- **Duplicate** = the newer task (higher ID)

---

## Step 3 — Present for confirmation

Print a table to the terminal:

```
Proposed Dedup Actions
──────────────────────────────────────────────────────────────────────────
 Master   Subject (truncated to 60 chars)           Project
 ──────   ─────────────────────────────────────────  ──────────────────
 #[id]    [subject]                                  [project]
   └─ Duplicate: #[id]  [subject]
   └─ Action: Merge description notes → master, close duplicate as "Closed (Duplicate of #[master id])"

[repeat for each pair]
──────────────────────────────────────────────────────────────────────────
Total: [N] duplicate pairs found across [M] projects.
```

If no duplicates found, print: "No duplicates detected across open work packages." and stop.

Ask: `Apply these dedup actions? [y/N]`

---

## Step 4 — Merge and close (on confirmation)

For each confirmed duplicate pair:

1. **Merge unique content**: Compare the duplicate's description against the master's. If the duplicate contains any unique details (links, context, notes) not present in the master, append them to the master's description with a separator:
   ```
   ---
   *Merged from #[duplicate id] on [date]:*
   [unique content]
   ```
   Call `mcp__openproject-remote__update_work_package` on the master with the updated description.

2. **Close the duplicate**: Call `mcp__openproject-remote__update_work_package` on the duplicate with:
   - `status`: `Closed`
   - Add a comment (via REST POST to `/api/v3/work_packages/{id}/activities`):
     ```
     Closing as duplicate of #[master id]. Unique details merged into master task.
     ```

---

## Step 5 — Print confirmation ledger

```
Dedup Complete
──────────────────────────────────────────────────────────────────
 Duplicate  Closed As          Master    Notes Merged
 ─────────  ─────────────────  ───────   ────────────
 #[id]      Closed (Dup)       #[id]     [yes / no unique content]
[...]
──────────────────────────────────────────────────────────────────
[N] duplicates closed. [M] master tasks updated with merged notes.
```
