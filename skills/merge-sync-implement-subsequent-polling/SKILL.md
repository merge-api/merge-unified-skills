---
name: merge-sync-implement-subsequent-polling
description: Implement incremental data fetching via polling — after initial sync completes, detect new Merge syncs by comparing timestamps and fetch only changed records using bounded time windows. Use as Step 3a of Merge sync implementation.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing Subsequent Sync Detection via Polling

Extends the initial sync polling job to detect when new data is available and fetch only changed records. Eliminates full re-fetches by tracking timestamps per model.

## Prerequisites

- Initial sync detection complete (Step 2a or 2b)
- `initial_sync_complete = true` for at least one linked account

## Before Proceeding

Tell the user: "I'll create a new `sync_state` table to track per-model sync timestamps. This requires a database migration. Ready to proceed?"

Wait for confirmation before continuing.

## New Database Table: sync_state

```
sync_state
- linked_account_id   FK to linked_accounts
- model_id            e.g. "hris.Employee"
- last_synced_at      YOUR timestamp — when you STARTED the last fetch
- merge_last_sync_finished  Merge's timestamp from /sync-status response
- last_fetched_at     when your fetch completed
- status              DONE | PARTIALLY_SYNCED | SYNCING | FAILED
```

## The Two Timestamps (Critical Distinction)

| Timestamp                  | Owner        | Purpose                                     |
| -------------------------- | ------------ | ------------------------------------------- |
| `merge_last_sync_finished` | Merge        | DETECT new data — compare with stored value |
| `last_synced_at`           | Your backend | FETCH parameter — use as `modified_after`   |

**Why start time**: Overlap is safer than gaps — records modified during your fetch window are captured twice, never missed.

## Implementation: Extend the Polling Job

### 1. Detection

For each linked account where `initial_sync_complete = true`, call `GET https://api.merge.dev/api/{category}/v1/sync-status`:

```
for each model in sync_status.results:
    skip if model.status in ["DISABLED", "FAILED"] or model.is_initial_sync == true

    new_data_available = (
        model.status in ["DONE", "PARTIALLY_SYNCED"]
        AND (model.last_sync_finished > stored.merge_last_sync_finished
             OR stored.merge_last_sync_finished IS NULL)
    )

    if new_data_available:
        fetch_incremental(model, stored)
```

### 2. Incremental Fetch

```
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

### 3. Dynamic Polling Frequency

- High-frequency syncs (< 1 hour): poll every 5–10 minutes
- Standard syncs (24-hour cadence): poll every 30–60 minutes

## Concrete Example

Stored: `last_synced_at = 2024-01-15T10:35:00Z`, `merge_last_sync_finished = 2024-01-15T10:30:00Z`

Poll returns: `last_sync_finished = 2024-01-15T22:46:41Z` → `22:46 > 10:30` = NEW DATA

```
# Record start time BEFORE fetching
last_synced_at = 2024-01-15T22:50:00Z
GET https://api.merge.dev/api/employees?modified_after=2024-01-15T10:35:00Z&modified_before=2024-01-15T22:46:41Z
# Store both after success
last_synced_at = 2024-01-15T22:50:00Z, merge_last_sync_finished = 2024-01-15T22:46:41Z
```

## Critical Gotchas

- Accept BOTH `DONE` and `PARTIALLY_SYNCED` — unlike initial sync which requires DONE only
- Record `last_synced_at` BEFORE fetching — recording after creates gaps
- First subsequent fetch: `last_synced_at` is null — omit `modified_after`, use only `modified_before`
- Always store BOTH timestamps after success — storing only one breaks the next detection cycle

## Testing Checklist

- [ ] Detects new data by comparing Merge's `last_sync_finished` with stored value
- [ ] Records `last_synced_at` BEFORE starting fetch
- [ ] Uses correct timestamps: `modified_after = last_synced_at`, `modified_before = merge_last_sync_finished`
- [ ] Stores both timestamps after successful fetch
- [ ] Accepts DONE and PARTIALLY_SYNCED (not just DONE)
- [ ] Handles first subsequent fetch when `last_synced_at` is null
- [ ] Skips DISABLED and FAILED models
- [ ] Handles pagination in responses
- [ ] Tracks state independently per model (one row per linked_account + model_id)
