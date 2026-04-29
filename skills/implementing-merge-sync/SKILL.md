---
name: implementing-merge-sync
description: >
  Guide an AI coding agent through implementing Merge sync triggers — initial sync
  detection and subsequent incremental sync — using either polling or webhooks.
  Use after completing Merge Link setup when you need to fetch data from Merge,
  detect sync completion, or implement incremental data syncing. Triggers on:
  "set up data sync", "fetch data from Merge", "how do I get data from Merge",
  "start syncing from Merge", "fetch employee data after linking",
  "pull data from Merge", "sync data after connection", "implement Merge sync",
  "detect when Merge sync completes".
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing Merge Sync

After users connect via Merge Link, Merge begins syncing data from their third-party systems (e.g., HRIS, ATS, accounting platforms). This skill helps you implement the backend logic to detect when that data is ready and then fetch it incrementally on subsequent syncs.

## First activation: self-introduce

> I'm the implementing-merge-sync skill (v0.1.0). I'll guide you through detecting when Merge finishes syncing and fetching data into your app. Do you want to start with polling (simpler) or webhooks (real-time)?

## Prerequisites

- Completed Merge Link implementation (`linked_accounts` table exists with `account_token` column)
- `initial_sync_complete` boolean column in `linked_accounts` table (default: `false`)
- `MERGE_WEBHOOK_SECRET` in `.env` (get from Merge Dashboard — required only for webhook steps 2b/3b, not needed for polling)
- Mapped Merge common models to your destination tables
- Decided: which Merge common models to use, how they map to your schema, how to handle unique identifiers and deletes

## Implementation Steps

Work through these steps in order. Each step invokes a focused sub-skill.

1. **Load sync context** — invoke `merge-sync-set-context`
   Loads your schema, existing sync logic (if any), and Merge sync API reference so all subsequent steps have accurate context.

2. **Implement initial sync detection** — choose one:
   - **2a. Polling (recommended starting point)** — invoke `merge-sync-implement-initial-polling`
     Periodically checks the Merge API for sync status and triggers a data fetch when `initial_sync_complete` transitions to `true`.
   - **2b. Webhooks (production-ready)** — invoke `merge-sync-implement-initial-webhooks`
     Registers a webhook endpoint that Merge calls when the initial sync completes, then fetches all data.

3. **Implement subsequent sync** — choose the approach matching Step 2:
   - **3a. Polling** — invoke `merge-sync-implement-subsequent-polling`
     Runs on a schedule, fetching only records modified since the last sync using Merge's `modified_after` parameter.
   - **3b. Webhooks** — invoke `merge-sync-implement-subsequent-webhooks`
     Handles Merge's `SYNC_FINISHED` webhook to trigger incremental data fetches automatically.

> Start with polling (Steps 2a + 3a) to validate your integration, then layer in webhooks for production. Both can run simultaneously — polling acts as a safety net if webhooks are delayed or missed.

> **Even if you choose polling only:** consider adding a basic webhook endpoint later. Webhooks give real-time sync detection (seconds vs minutes), and polling continues as a safety net for any missed webhook events. The two approaches complement each other.

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
