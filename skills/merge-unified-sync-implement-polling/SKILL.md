---
name: merge-unified-sync-implement-polling
description: >
  Implement Merge sync detection via a scheduled polling job. Use this as a
  development starting point (no public webhook endpoint required) and as a
  production fallback alongside `merge-unified-sync-implement-webhooks` to catch missed
  or delayed webhook deliveries. A single job covers both initial sync detection
  (first connection) and subsequent incremental syncs (`modified_after` bounded
  fetches). Use when a developer says "set up polling sync", "scheduled sync",
  "fallback sync", "sync without webhooks", "cron job for Merge", or wants a
  simple way to fetch data while developing locally.
license: MIT
metadata:
  author: Merge
  version: 0.2.0
---

# Implementing Merge Sync via Polling (Fallback / Development Starting Point)

A single scheduled background job polls every active linked account, detecting both initial sync completion and ongoing incremental updates. Simpler than webhooks — no public endpoint, no HMAC verification — and useful in two production-relevant scenarios:

1. **Development starting point.** You're prototyping locally and don't yet have a publicly reachable webhook URL. Polling gets you to working sync in minutes.
2. **Production fallback safety net.** Run alongside `merge-unified-sync-implement-webhooks` so missed or delayed webhook deliveries don't leave data stale.

> **Webhooks are the primary production approach.** This skill is intentionally framed as a fallback or development tool. For production reliability, also implement `merge-unified-sync-implement-webhooks` and let the two run in parallel — data fetches are idempotent because the bounded `modified_after` / `modified_before` window covers the same records safely.

> **Field-name convention used in this doc.** Pseudo-code and JSON snippets show the raw HTTP response shape (snake_case: `is_initial_sync`, `last_sync_result`, `modified_at`). The Merge SDKs auto-convert to camelCase — in Node, `model.is_initial_sync` becomes `model.isInitialSync`, and request params like `modified_after` become `modifiedAfter`. Write your code in your SDK's convention.

## First activation: self-introduce

> I'm the merge-unified-sync-implement-polling skill. I'll wire up a single scheduled job that detects both initial and subsequent Merge syncs by calling `GET /sync-status`. This is great for local dev and as a production fallback alongside webhooks.

## Prerequisites

- Merge API key available as env var (e.g., `MERGE_API_KEY`)
- Background job system available (cron, Celery, Redis Queue, BullMQ, etc.)

## Before Proceeding

Four pieces of information are needed before generating any code.

If invoked from `merge-unified-implementing-sync`, these were answered in Step 1 — use that context. Otherwise, gather them now:

- **Common models to sync**: which Merge common models? (e.g. `Employee`, `Contact`, `Ticket`) — drives the per-model fetch loop in Step 5.
- **`linked_accounts.initial_sync_complete` column**: present or missing? Required for the per-account branching in Step 2. If missing, the migration in Step 1 below adds it.
- **Background job system**: cron, Celery, Redis Queue, BullMQ, Sidekiq, or other? Drives the scheduling syntax. If `not found`, ask the user whether to scaffold cron or pick a queue.
- **Backend Merge SDK installed?** (`@mergeapi/merge-node-client` for Node, `MergePythonClient` for Python, `dev.merge:merge-java-client` for JVM, `merge-go-client` for Go, `merge_ruby_client` for Ruby, `Merge.Client` for .NET.) Drives whether examples below use the SDK or raw HTTP.

## Step 1: Database additions

If `initial_sync_complete` is not present:

```sql
ALTER TABLE linked_accounts ADD COLUMN initial_sync_complete boolean DEFAULT false;
```

For subsequent (incremental) sync you also need a `sync_state` table to track per-model timestamps:

```sql
CREATE TABLE IF NOT EXISTS sync_state (
  id                        SERIAL PRIMARY KEY,
  linked_account_id         INTEGER NOT NULL REFERENCES linked_accounts(id) ON DELETE CASCADE,
  model_id                  TEXT NOT NULL,             -- e.g. "hris.Employee"
  last_synced_at            TIMESTAMPTZ,               -- YOUR timestamp — when you STARTED the last fetch
  merge_last_sync_finished  TIMESTAMPTZ,               -- Merge's timestamp from /sync-status
  last_fetched_at           TIMESTAMPTZ,               -- when your fetch completed
  status                    TEXT,                       -- DONE | PARTIALLY_SYNCED | SYNCING | FAILED
  UNIQUE (linked_account_id, model_id)
);
```

**SQLAlchemy equivalent** (same shape as the webhooks variant):

```python
class SyncState(db.Model):
    __tablename__ = "sync_state"
    id = db.Column(db.Integer, primary_key=True)
    linked_account_id = db.Column(db.Integer, db.ForeignKey("linked_accounts.id"), nullable=False)
    model_id = db.Column(db.String(100), nullable=False)
    last_synced_at = db.Column(db.DateTime, nullable=True)
    merge_last_sync_finished = db.Column(db.DateTime, nullable=True)
    last_fetched_at = db.Column(db.DateTime, nullable=True)
    status = db.Column(db.String(20), nullable=True)
    __table_args__ = (db.UniqueConstraint("linked_account_id", "model_id"),)
```

Tell the user: "I'll create a `sync_state` table to track per-model sync timestamps. This requires a database migration. Ready to proceed?" Wait for confirmation.

## Step 2: The polling job — branches on `initial_sync_complete`

A single job covers both initial detection and subsequent incremental fetches. Per-account, branch on the `initial_sync_complete` flag.

A poll interval of **every 5–15 minutes is a reasonable default** for initial detection. Once you switch into subsequent (incremental) mode, adjust the cadence to your data volatility — high-frequency syncs can poll every 5–10 minutes; standard 24-hour-cadence syncs can poll every 30–60 minutes.

```text
every {configured interval}:
  for each account in linked_accounts WHERE account_token IS NOT NULL:
    try:
      response = GET https://api.merge.dev/api/{account.category}/v1/sync-status
        headers: Authorization: Bearer {MERGE_API_KEY}
                 X-Account-Token: {account.account_token}

      if NOT account.initial_sync_complete:
        if all_ready(response.results):
          set linked_accounts.initial_sync_complete = true WHERE id = account.id
          trigger fetch_initial_data(account)
      else:
        process_subsequent(account, response.results)

    except error:
      log error for account.id, continue to next account
```

## Step 3: Initial detection — readiness check

```text
function all_ready(models):
  for each model in models:
    if model.status == "DISABLED":
      continue  # skip — does not block readiness

    model_ready = (model.status == "DONE" OR model.is_initial_sync == false)

    if NOT model_ready:
      return false  # at least one enabled model not ready

  return true  # all non-DISABLED models are ready
```

**Critical:** Use **OR** logic (`status == "DONE" OR is_initial_sync == false`). Using AND misses cases where Merge marks old syncs as non-initial before completion.

## Step 4: Subsequent (incremental) detection — the two timestamps

| Timestamp                  | Owner        | Purpose                                     |
| -------------------------- | ------------ | ------------------------------------------- |
| `merge_last_sync_finished` | Merge        | DETECT new data — compare with stored value |
| `last_synced_at`           | Your backend | FETCH parameter — use as `modified_after`   |

**Why start time:** Overlap is safer than gaps — records modified during your fetch window are captured twice, never missed.

```text
function process_subsequent(account, models):
  for each model in models:
    skip if model.status in ["DISABLED", "FAILED"] or model.is_initial_sync == true

    new_data_available = (
      model.status in ["DONE", "PARTIALLY_SYNCED"]
      AND (model.last_sync_finished > stored.merge_last_sync_finished
           OR stored.merge_last_sync_finished IS NULL)
    )

    if new_data_available:
      fetch_incremental(model, stored)
```

## Step 5: Bounded incremental fetch

```text
function fetch_incremental(model, stored):
    # Step 1: Record YOUR fetch start time BEFORE fetching
    last_synced_at = now()

    # Step 2: Build bounded time window
    if stored.last_synced_at IS NULL:
        # First subsequent fetch — omit modified_after
        url = GET https://api.merge.dev/api/{category}/v1/{model}?modified_before={model.last_sync_finished}
    else:
        url = GET https://api.merge.dev/api/{category}/v1/{model}
              ?modified_after={stored.last_synced_at}
              &modified_before={model.last_sync_finished}

    # Step 3: Fetch with pagination
    results = fetch_all_pages(url)

    # Step 4: Store BOTH timestamps after successful fetch
    store sync_state:
        last_synced_at          = last_synced_at
        merge_last_sync_finished = model.last_sync_finished
        last_fetched_at         = now()
        status                  = model.status
```

### Concrete example

Stored: `last_synced_at = 2024-01-15T10:35:00Z`, `merge_last_sync_finished = 2024-01-15T10:30:00Z`

Poll returns: `last_sync_finished = 2024-01-15T22:46:41Z` → `22:46 > 10:30` = NEW DATA

```text
# Record start time BEFORE fetching
last_synced_at = 2024-01-15T22:50:00Z
GET https://api.merge.dev/api/employees?modified_after=2024-01-15T10:35:00Z&modified_before=2024-01-15T22:46:41Z
# Store both after success
last_synced_at = 2024-01-15T22:50:00Z, merge_last_sync_finished = 2024-01-15T22:46:41Z
```

## Step 6: Rate limit and error handling

Apply the same pattern to both `GET /sync-status` and the data fetch calls.

- **429 response** → exponential backoff with jitter (1s, 2s, 4s + random 0–500ms), max 3 retries.
- **Per-account handling**: log errors per linked account but continue polling others.
- **Per-model handling** (subsequent): if one model's data fetch hits 429, skip it and continue fetching other models for that account. The skipped model's `sync_state` timestamps are not updated, so it'll be picked up on the next poll cycle.
- **Polling frequency adjustment**: if rate limits are frequent across accounts, increase the poll interval temporarily (e.g., 5 min → 15 min).
- **401 handling**: an invalid/revoked `account_token`. Log as a relink-needed event; do NOT retry — retrying won't help. Surface a relink prompt to the customer.
- **Do NOT update timestamps on failure** — leave `last_synced_at` and `merge_last_sync_finished` unchanged so the next cycle retries the same window.
- **Do not stop the polling job** after initial sync completes — the same job is reused for subsequent sync detection.

## Critical gotchas

- **OR not AND for initial readiness**: `status == "DONE" OR is_initial_sync == false`.
- **Skip DISABLED models** when checking initial readiness.
- **Accept BOTH `DONE` and `PARTIALLY_SYNCED` for subsequent** — unlike initial sync, which requires DONE only.
- **Record `last_synced_at` BEFORE fetching** — recording after creates gaps.
- **First subsequent fetch**: `last_synced_at` is null — omit `modified_after`, use only `modified_before`.
- **Always store BOTH timestamps after success** — storing only one breaks the next detection cycle.
- **Polling alone is not production-grade**: layer in `merge-unified-sync-implement-webhooks` for real-time detection. The two are designed to coexist.

## Testing checklist

- [ ] Polling job runs on schedule continuously
- [ ] Per-account branch on `initial_sync_complete` works correctly
- [ ] Initial path: detects completion using OR logic (`DONE` or `is_initial_sync == false`)
- [ ] Initial path: skips DISABLED models when checking overall readiness
- [ ] Initial path: marks `initial_sync_complete = true` once all enabled models are ready
- [ ] Continues polling after initial sync completes (does not stop)
- [ ] Subsequent path: detects new data by comparing Merge's `last_sync_finished` with stored value
- [ ] Subsequent path: records `last_synced_at` BEFORE starting fetch
- [ ] Subsequent path: uses correct timestamps (`modified_after = last_synced_at`, `modified_before = merge_last_sync_finished`)
- [ ] Subsequent path: stores both timestamps after successful fetch
- [ ] Subsequent path: accepts DONE and PARTIALLY_SYNCED (not just DONE)
- [ ] Subsequent path: handles first incremental fetch when `last_synced_at` is null
- [ ] Subsequent path: skips DISABLED and FAILED models
- [ ] Handles pagination in responses
- [ ] Tracks state independently per model (one row per linked_account + model_id)
- [ ] Retries on 429 with exponential backoff
- [ ] Does NOT update timestamps on failed/skipped fetches
- [ ] Handles API errors per account gracefully (logs and continues)
- [ ] Works for multiple integrations simultaneously

## Troubleshooting

**SYMPTOM:** Polling job runs but `sync_status` always returns SYNCING
**CAUSE:** Initial sync genuinely takes time (15 minutes to several hours for large accounts), or `initial_sync_complete` flag is not being updated.
**FIX:** Check the actual Merge dashboard for that Linked Account; confirm your polling job saves `initial_sync_complete = true` when status is DONE (or `is_initial_sync == false`).

**SYMPTOM:** Incremental fetch returns records already processed
**CAUSE:** `last_synced_at` timestamp is not being saved after each successful fetch.
**FIX:** Persist `last_synced_at` and `merge_last_sync_finished` only after a successful fetch; never update on failure.

**SYMPTOM:** Frequent 429s in the poll loop
**CAUSE:** Poll interval is too short for the number of linked accounts you have.
**FIX:** Increase the base poll interval. Apply exponential backoff with jitter on 429. Consider running webhooks (`merge-unified-sync-implement-webhooks`) as the primary trigger and slowing polling to a low-frequency safety net.
