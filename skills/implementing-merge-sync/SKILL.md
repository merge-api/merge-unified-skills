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
  version: 0.4.0
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

- **`linked_accounts` table structure**: columns, indexes, presence of `initial_sync_complete`, `account_token`, `merge_account_id`, etc.
- **Background job system**: Celery, Redis Queue, BullMQ, Sidekiq, cron, or other. Record what you find or `not found`.
- **Existing sync logic**: search for `sync`, `modified_after`, `last_synced_at`.
- **Body-parsing middleware**: search for `express.json()`, `bodyParser.json()`, framework JSON middleware. Webhook signature verification needs raw bytes.
- **Backend Merge SDK installed?** Search the project's manifest for the language-appropriate package: `@mergeapi/merge-node-client` (package.json), `MergePythonClient` (requirements.txt / pyproject.toml), `dev.merge:merge-java-client` (pom.xml / build.gradle), `merge-go-client` (go.mod), `merge_ruby_client` (Gemfile), `Merge.Client` (.csproj). Record yes/no and which language.

**1c. Confirm readiness** with a brief summary:

1. Sync docs loaded (list both files read)
2. `linked_accounts` schema (`initial_sync_complete` present / missing)
3. Background job system: `{name}` or `not found`
4. Backend Merge SDK installed: yes / no
5. Body-parsing middleware identified (relevant for webhook raw-body handling)

**1d. Ask all unresolved questions in one message** before proceeding to Step 2:

> Before I start building, a few quick questions:
>
> 1. **Which Merge common models will you sync?** (e.g. `Employee`, `Contact`, `Ticket`) — and what destination tables map to each?
>
> 2. **Webhook endpoint feasibility**: Does your deployment have a publicly reachable URL where Merge can POST webhooks?
>    - **Production / staging URL** — webhooks are the primary recommended approach.
>    - **Local dev only (no public URL yet)** — start with polling; add webhooks before going live. ngrok / cloudflared work for testing.
>    - **Public URL not possible** (air-gapped, restrictive network) — polling-only.
>    Which fits your environment?
>
> 3. **Backend SDK preference**: [If not installed:] Would you prefer the official Merge SDK (recommended) or raw HTTP? [If already installed:] I see the Merge SDK is in your dependencies — I'll use it unless you prefer raw HTTP.
>
> 4. **Job system**: [If found:] I found `{name}` — I'll wire jobs to it. [If not found:] Should I scaffold a cron job, or do you have a preferred queue/scheduler?

Record the user's answers. Carry them as context into Step 2 (and Step 3 if running both).

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
