# Merge Sync Fundamentals

This document is a focused reference for developers implementing Merge API sync triggers — covering the sync lifecycle, status detection, incremental fetching, timestamp tracking, and webhook events.

---

## Initial Sync Lifecycle

When a user successfully completes the Merge Link authentication flow, Merge automatically initiates an **initial sync** in the background. This is a one-time process that fetches the complete historical dataset from the connected third-party system.

**Key Characteristics**:
- **Automatic**: Begins immediately after authentication, no manual triggering required
- **Background Process**: Happens asynchronously on Merge's infrastructure
- **Duration**: Can take minutes to hours depending on dataset size
- **Scope**: Fetches all available data for enabled models (Employee, Company, TimeOff, etc.)
- **One-Time**: Only runs once per integration connection

Your application should detect when the initial sync completes before attempting to fetch data. This prevents requesting data that hasn't finished syncing yet.

---

## Sync Status Endpoint

Merge provides the `GET /api/{category}/v1/sync-status` endpoint to monitor sync progress for each data model.

**Response Structure**:
```json
{
  "next": "https://api.merge.dev/api/hris/v1/sync-status?cursor=abc123",
  "previous": null,
  "results": [
    {
      "model_name": "Employee",
      "model_id": "hris.Employee",
      "last_sync_start": "2024-01-15T10:30:00Z",
      "next_sync_start": "2024-01-15T22:30:00Z",
      "status": "SYNCING",
      "is_initial_sync": true,
      "last_sync_result": null,
      "last_sync_finished": null
    },
    {
      "model_name": "Company",
      "model_id": "hris.Company",
      "last_sync_start": "2024-01-15T10:28:00Z",
      "next_sync_start": "2024-01-15T22:28:00Z",
      "status": "DONE",
      "is_initial_sync": false,
      "last_sync_result": "SUCCESSFUL",
      "last_sync_finished": "2024-01-15T10:29:15Z"
    },
    {
      "model_name": "TimeOff",
      "model_id": "hris.TimeOff",
      "last_sync_start": null,
      "next_sync_start": null,
      "status": "DISABLED",
      "is_initial_sync": false,
      "last_sync_result": null,
      "last_sync_finished": null
    }
  ]
}
```

**Status Values**:
- `SYNCING`: Sync currently in progress
- `DONE`: Sync completed successfully
- `FAILED`: Sync encountered errors
- `DISABLED`: Model not enabled for this integration
- `PARTIALLY_SYNCED`: Partial data retrieved
- `PAUSED`: Sync temporarily paused

**Key Fields**:
- `model_id`: Fully qualified model identifier (e.g., `"hris.Employee"`)
- `is_initial_sync`: `true` indicates first sync still running
- `last_sync_start`: Timestamp when sync began
- `last_sync_finished`: Timestamp when sync completed (use for incremental fetching)
- `next_sync_start`: Scheduled time for next automatic sync

**Pagination**: Results are paginated. Use `next` URL to retrieve additional models.

---

## Detecting Data Readiness (OR Logic)

### Initial Sync Readiness

**Initial Sync is Ready When:**
- `status == "DONE"` **OR** `is_initial_sync == false`

**Why This Logic**:
- `status == "DONE"` catches the moment sync completes
- `is_initial_sync == false` catches it if you poll after sync already completed
- `PARTIALLY_SYNCED` is **not acceptable** during initial sync — partial data represents an incomplete historical dataset

**Critical Timing**: The `is_initial_sync` flag flips to `false` immediately upon first completion, not after a second sync.

```text
for each model in sync_status.results:
    if model.status == "DISABLED":
        continue

    # Initial sync readiness check
    initial_sync_ready = (
        model.status == "DONE"
        OR
        model.is_initial_sync == false
    )

    if initial_sync_ready:
        # Safe to fetch complete historical data
        fetch_initial_data(model.model_id)
```

### Subsequent Sync Readiness

After initial sync completes, subsequent syncs can accept partial data since you already have the historical baseline.

**Subsequent Sync is Ready When:**
- `status == "DONE"` **OR** `status == "PARTIALLY_SYNCED"` **OR** `is_initial_sync == false`

```text
for each model in sync_status.results:
    if model.status == "DISABLED":
        continue

    if model.is_initial_sync == false:
        subsequent_sync_ready = (
            model.status in ["DONE", "PARTIALLY_SYNCED"]
            OR
            model.is_initial_sync == false
        )

        if subsequent_sync_ready:
            fetch_incremental_data(model.model_id, last_sync_timestamp)
```

**Common Mistakes**:
- Accepting `PARTIALLY_SYNCED` during initial sync leads to incomplete historical data
- Only checking `status == "DONE"` will miss models ready from previous syncs
- Not distinguishing between initial and subsequent sync logic

**Edge Cases**:
- **DISABLED models**: Always skip — integration doesn't support this model
- **FAILED status with is_initial_sync=false**: Data from previous successful sync may still be available
- **SYNCING status with is_initial_sync=false**: Previous sync data is available, new sync in progress for updates

---

## The Two Timestamp Types (Critical Distinction)

You must track **two separate timestamps** per model. Confusing them causes data gaps or duplicate fetches.

| Timestamp | Owner | Meaning |
|-----------|-------|---------|
| `last_synced_at` | Your backend | When YOUR backend **started** fetching data from Merge |
| `merge_last_sync_finished` (`last_sync_finished` in `/sync-status`) | Merge | When Merge **completed** syncing from the third-party system |

**How to use them**:

1. **Detecting New Data**: Poll `/sync-status`. Compare Merge's current `last_sync_finished` with your stored value. If newer → new data is available.

2. **Fetching New Data**:
   - Record current time as `last_synced_at` (when you start fetching)
   - Fetch: `GET /employees?modified_after={your_last_synced_at}&modified_before={merge_last_sync_finished}`
   - Store both timestamps for the next cycle

**Why store start time, not end time**: Using the start timestamp ensures complete coverage with potential overlap (which is safer than gaps). Records modified during your fetch window are captured in both syncs rather than potentially missed.

```text
Sync 1: Start 10:00, End 10:05, Store last_synced_at: 10:00
Sync 2: modified_after=10:00, Start 10:15, End 10:18, Store last_synced_at: 10:15
```

---

## Bounded Time Windows for Incremental Fetches

After the initial sync, use `modified_after` and `modified_before` together to fetch only records that changed within a specific time window.

**Pattern**:
```text
GET /api/{category}/v1/{model}?modified_after=2024-01-15T10:30:00Z&modified_before=2024-01-15T22:46:41Z
```

- `modified_after` = YOUR `last_synced_at` (when you last started fetching) — prevents duplicate fetches
- `modified_before` = Merge's `last_sync_finished` — creates a bounded upper boundary

**Example Flow**:
```text
# Initial state: No previous fetch
Poll /sync-status → last_sync_finished = 2024-01-15T10:30:00Z
Detect: New data available (first fetch)

# Start fetching
last_synced_at = current_time() = 2024-01-15T10:35:00Z
Fetch: GET /employees?modified_before=2024-01-15T10:30:00Z
Store: last_synced_at = 2024-01-15T10:35:00Z, last_sync_finished = 2024-01-15T10:30:00Z

# Next poll
Poll /sync-status → last_sync_finished = 2024-01-15T22:46:41Z
Detect: New data (timestamp changed from 10:30 to 22:46)

# Fetch incremental update
last_synced_at = current_time() = 2024-01-15T22:50:00Z
Fetch: GET /employees?modified_after=2024-01-15T10:35:00Z&modified_before=2024-01-15T22:46:41Z
Store: last_synced_at = 2024-01-15T22:50:00Z, last_sync_finished = 2024-01-15T22:46:41Z
```

**Benefits**:
- Reduced API response sizes (only fetch changes)
- Faster data processing, lower bandwidth usage
- Prevents duplicate data fetches
- Precise time windows for data consistency

**When No New Data Available**: If Merge hasn't started a new sync since your last data pull, the `modified_after` query will return empty results — this is expected and efficient behavior.

---

## Webhook Events

Webhooks are the real-time alternative to polling `/sync-status`. Both provide the same `last_sync_finished` timestamp — the only difference is timing (push vs. pull).

### `LinkedAccount.sync_completed`

Best for detecting **initial sync completion** and account-level sync events.

**When to Use**:
- Detecting initial sync completion (payload includes `is_initial_sync` flag)
- Getting sync status for all models in one notification
- Simpler setup — one webhook subscription per linked account

**Sample Payload**:
```json
{
  "hook": {
    "event": "LinkedAccount.sync_completed",
    "target": "https://yourapp.com/webhooks/merge"
  },
  "linked_account": {
    "end_user_origin_id": "org_123_hris",
    "category": "hris",
    "status": "COMPLETE"
  },
  "data": {
    "is_initial_sync": true,
    "sync_status": {
      "hris.Employee": {
        "last_sync_finished": "2024-01-15T10:29:15Z",
        "last_sync_result": "DONE"
      },
      "hris.Company": {
        "last_sync_finished": "2024-01-15T10:28:30Z",
        "last_sync_result": "DONE"
      },
      "hris.TimeOff": {
        "last_sync_finished": "2024-01-15T10:30:45Z",
        "last_sync_result": "PARTIALLY_SYNCED"
      }
    }
  }
}
```

**Key Fields**:
- `data.is_initial_sync`: Boolean indicating if this is the first sync
- `data.sync_status`: Object with all models and their sync results
- Each model includes `last_sync_finished` and `last_sync_result`

### `{CommonModel}.synced` (e.g., `Employee.synced`)

Best for **granular, model-specific** sync notifications during subsequent syncs.

**When to Use**:
- High-volume data scenarios
- Want immediate notification when a specific model completes syncing
- Need fine-grained control over which models trigger fetching

**Sample Payload**:
```json
{
  "hook": {
    "event": "Employee.synced",
    "target": "https://yourapp.com/webhooks/merge"
  },
  "data": {
    "synced_fields": ["first_name", "last_name", "work_email"],
    "sync_status": {
      "model_name": "Employee",
      "model_id": "hris.Employee",
      "status": "DONE",
      "last_sync_result": "DONE",
      "last_sync_finished": "2024-01-15T10:29:15Z",
      "is_initial_sync": false
    }
  }
}
```

**Key Fields**:
- `data.sync_status.last_sync_finished`: Timestamp for incremental fetching
- `data.sync_status.last_sync_result`: Sync outcome (DONE, PARTIALLY_SYNCED, FAILED)
- `data.synced_fields`: List of fields that were updated

### Webhook Processing Pattern

```text
1. Receive webhook with sync_status data
2. Extract last_sync_finished timestamp
3. Compare with your stored last_sync_finished
4. If newer:
   - Record your last_synced_at (current time)
   - Fetch: GET /model?modified_after={your_last_synced_at}&modified_before={webhook_last_sync_finished}
   - Store both timestamps
```

**Reliability Notes**:
- Return `200 OK` immediately upon receipt, then process asynchronously
- Merge retries failed deliveries up to 2 additional times (3 total) with a 30-second timeout
- Do not rely solely on webhooks — use polling as a backup for missed deliveries

### Strategy by Sync Phase

**For Initial Sync Detection**:
- Use `LinkedAccount.sync_completed`
- Check `data.is_initial_sync == true`
- Trigger data fetching for models with `last_sync_result == "DONE"`

**For Subsequent Sync Detection**:
- Option A: Continue using `LinkedAccount.sync_completed` for simplicity
- Option B: Use `{CommonModel}.synced` for granular per-model notifications
- Compare `last_sync_finished` with your stored value before triggering fetch

**Recommended**: Hybrid approach — webhooks as primary (real-time), polling every 1–6 hours as backup.
