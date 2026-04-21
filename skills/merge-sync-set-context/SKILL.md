---
name: merge-sync-set-context
description: Load Merge sync fundamentals documentation into context. Use as Step 1 of Merge sync trigger implementation before writing any code. Typically invoked automatically by the `implementing-merge-sync` skill — you usually don't need to invoke this directly.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Loading Merge Sync Context

Step 1 of the Merge sync trigger implementation guide. Read reference docs and scan the codebase. Do NOT write any code during this step.

## Step 1: Read Reference Documentation

Read both files (paths relative to this skill's base directory):

- `../implementing-merge-sync/references/platform-overview.md` — Overall Merge context: auth flow, account lifecycle, API structure
- `../implementing-merge-sync/references/sync-fundamentals.md` — Focused sync documentation covering:
  - Initial sync lifecycle
  - Sync status semantics
  - The two timestamp types (`last_synced_at` vs `merge_last_sync_finished`)
  - Subsequent sync with `modified_after` / `modified_before`
  - Webhook event types for sync triggers

Read each file completely before proceeding.

## Step 2: Scan the Codebase

Ask the user before scanning: "I'll search your codebase for your job system, existing sync logic, and `linked_accounts` schema. Ready to proceed?"

Identify:

- `linked_accounts` table structure (columns, indexes, existing sync fields)
- Background job system in use: Celery, Redis Queue, cron, or other
- Any existing sync logic (search for "sync", `modified_after`, `last_synced_at`)

## Step 3: Confirm Readiness

Output a brief summary covering:

1. Sync docs loaded (list both files read)
2. Which Merge common models will be synced — if not yet specified, ask the user now
3. Destination tables for each model
4. Background job system identified (or note if none found)
5. Ready to proceed to the next implementation step

Do not write any implementation code during this step.
