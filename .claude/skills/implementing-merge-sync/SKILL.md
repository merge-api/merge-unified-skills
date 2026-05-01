---
name: implementing-merge-sync
description: >
  Guide an AI coding agent through implementing Merge sync triggers — initial sync
  detection and subsequent incremental sync. Webhooks are the recommended primary
  approach; polling acts as a development starting point and a production fallback.
  Use after completing Merge Link setup when you need to fetch data from Merge,
  detect sync completion, or implement incremental data syncing. Triggers on:
  "set up data sync", "fetch data from Merge", "how do I get data from Merge",
  "start syncing from Merge", "fetch employee data after linking",
  "pull data from Merge", "sync data after connection", "implement Merge sync",
  "detect when Merge sync completes", "set up Merge webhooks",
  "Merge webhook handler", "incremental sync".
license: MIT
metadata:
  author: Merge
  version: 0.3.0
---

# Implementing Merge Sync

After users connect via Merge Link, Merge begins syncing data from their third-party systems (e.g., HRIS, ATS, accounting platforms). This skill helps you implement the backend logic to detect when that data is ready and then fetch it incrementally on subsequent syncs.

## First activation: self-introduce

> I'm the implementing-merge-sync skill (v0.3.0). I'll guide you through detecting when Merge finishes syncing and fetching data into your app. Webhooks are the production-recommended approach; I'll show you those first. Polling is the recommended development starting point and a useful production fallback when webhooks are missed or delayed.

## Prerequisites

- Completed Merge Link implementation (`linked_accounts` table exists with `account_token` column)
- `initial_sync_complete` boolean column in `linked_accounts` table (default: `false`)
- `MERGE_WEBHOOK_SECRET` in `.env` (get from Merge Dashboard — required only for webhook steps 2b/3b, not needed for polling)
- Mapped Merge common models to your destination tables
- Decided: which Merge common models to use, how they map to your schema, how to handle unique identifiers and deletes

## Implementation Steps

Work through these steps in order. Step 2 invokes a focused sub-skill; Step 1 runs inline. Step 3 is optional but strongly recommended for production.

### Step 1: Load sync context

Do **not** write any code in this step. Read the reference docs first, then scan the codebase, then confirm readiness.

**1a. Read both reference docs:**

- `references/platform-overview.md` — Overall Merge context: auth flow, account lifecycle, API structure
- `references/sync-fundamentals.md` — Sync lifecycle, sync status semantics, the two timestamp types (`last_synced_at` vs `merge_last_sync_finished`), `modified_after` / `modified_before` parameters, and webhook event types

Read each file completely before proceeding.

**1b. Scan the codebase.** Ask the user first:

> "I'll search your codebase for your job system, existing sync logic, and `linked_accounts` schema. Ready to proceed?"

Then identify:

- `linked_accounts` table structure (columns, indexes, existing sync fields)
- Background job system in use: Celery, Redis Queue, cron, or other
- Any existing sync logic (search for `sync`, `modified_after`, `last_synced_at`)

**1c. Confirm readiness** with a brief summary:

1. Sync docs loaded (list both files read)
2. Which Merge common models will be synced — if not yet specified, ask the user now
3. Destination tables for each model
4. Background job system identified (or note if none found)
5. Ready to proceed to the next implementation step

### Step 2: Implement sync — webhooks primary, polling fallback

Pick **one of these starting paths**, then add the other as a fallback when going to production.

- **2a. Webhooks (PRIMARY for production)** — invoke `merge-sync-implement-webhooks`
  Registers a webhook endpoint that Merge calls when `SYNC_FINISHED` (or related events) fires. Covers both initial sync detection and incremental subsequent syncs.
- **2b. Polling (development starting point and production fallback)** — invoke `merge-sync-implement-polling`
  Runs a scheduled job that checks Merge sync status and fetches data via `modified_after`. Covers both initial detection and subsequent incremental fetches.

### Step 3 (recommended): Run both for production reliability

In production, run **both** webhooks and polling simultaneously:

- Webhooks give real-time sync detection (seconds vs. minutes).
- Polling acts as a safety net when webhooks are delayed, dropped, or your endpoint is briefly unavailable.

The two approaches complement each other; data is idempotent if your fetch logic uses `modified_after` correctly.

> Recommended path: start with **2a (webhooks)** for production architecture, then add **2b (polling)** as a fallback. If you're prototyping locally and a webhook endpoint isn't yet practical, you can start with **2b** and add **2a** before going live.

## Troubleshooting

**SYMPTOM:** Polling job runs but sync_status always returns SYNCING  
**CAUSE:** Initial sync genuinely takes time (15 min to several hours for large accounts); or `initial_sync_complete` flag is not being updated  
**FIX:** Check the actual Merge dashboard for that Linked Account; confirm your polling job saves `initial_sync_complete = true` when status is DONE

**SYMPTOM:** Webhook endpoint returns 200 but data is never fetched  
**CAUSE:** Background job is being enqueued but not processed, or job queue is paused  
**FIX:** Verify your job worker is running; check the job queue dashboard for stuck jobs

**SYMPTOM:** Incremental fetch returns records already processed  
**CAUSE:** `modified_after` timestamp is not being saved after each successful fetch  
**FIX:** Persist `last_synced_at = modified_before` only after a successful fetch; never update on failure

**SYMPTOM:** HMAC signature validation fails for all webhook events  
**CAUSE:** Webhook secret mismatch or body was parsed before signature check (Express `json()` middleware consuming raw body)  
**FIX:** Use `express.raw()` on the webhook route; compute HMAC against the raw Buffer before JSON parsing
