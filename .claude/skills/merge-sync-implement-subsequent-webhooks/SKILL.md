---
name: merge-sync-implement-subsequent-webhooks
description: Implement incremental data fetching via Merge webhooks — extend the webhook endpoint to process sync_completed events and fetch only changed records using bounded timestamps. Use as Step 3b of Merge sync implementation alongside or after Step 2b webhooks.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing Subsequent Sync via Merge Webhooks

Extends the existing webhook endpoint to handle `LinkedAccount.sync_completed` events after initial sync. Real-time and efficient — compares `last_sync_finished` timestamps per model and fetches only changed records with a bounded window. No polling overhead.

## Prerequisites

- Step 2b (initial webhook) complete — HMAC verification endpoint exists at `POST /api/webhooks/merge`
- `sync_state` table with columns `(linked_account_id, model_id, last_synced_at, merge_last_sync_finished)` — create now if not from Step 3a
- Background job queue configured (Celery, Redis Queue, etc.)

## Webhook Event Options

- **Option A** (recommended): `LinkedAccount.sync_completed` — one event per sync, all models in one payload; simpler
- **Option B**: `{CommonModel}.synced` — one event per model; better for high-volume or progressive processing

## Webhook payload for sync events

The `Linked Account synced` webhook delivers:

```javascript
{
  "hook": { "event": "Linked Account synced" },
  "linked_account": { "id": "merge-uuid", "end_user_origin_id": "your_user_id", "category": "crm" },
  "data": {
    "sync_status": {
      "crm.Contact": { "last_sync_finished": "2024-01-15T22:46:41Z", "last_sync_result": "DONE" },
      "crm.Account": { "last_sync_finished": "2024-01-15T22:46:40Z", "last_sync_result": "DONE" }
    }
  }
}
```

`data.sync_status` is keyed by model ID. Each entry has `last_sync_finished` (Merge's timestamp) and `last_sync_result` (`DONE`, `PARTIALLY_SYNCED`, or `FAILED`).

## Implementation

### Update Background Job

Extend `process_merge_webhook` to branch on initial vs. subsequent sync:

```python
def process_merge_webhook(payload: dict):
    origin_id = payload["linked_account"]["end_user_origin_id"]
    account = db.query(LinkedAccount).filter_by(end_user_origin_id=origin_id).first()
    if not account:
        return  # return 200 (already done at endpoint); no retry needed

    if not account.initial_sync_complete:
        # Initial sync path — existing logic
        account.initial_sync_complete = True
        db.commit()
        fetch_initial_data(account)
    else:
        # Subsequent sync path
        process_subsequent_sync(account, payload)
```

### Per-Model Processing

```python
def process_subsequent_sync(account, payload: dict):
    sync_status = payload["data"]["sync_status"]   # dict keyed by model_id

    for model_id, model_data in sync_status.items():
        last_sync_result = model_data.get("last_sync_result")

        # Accept only successful results; skip failures
        if last_sync_result not in ("DONE", "PARTIALLY_SYNCED"):
            continue

        webhook_finished = parse_datetime(model_data["last_sync_finished"])

        stored = db.query(SyncState).filter_by(linked_account_id=account.id, model_id=model_id).first()

        if stored and stored.merge_last_sync_finished and webhook_finished <= stored.merge_last_sync_finished:
            continue  # duplicate or out-of-order — skip automatically

        last_synced_at = datetime.utcnow()  # record BEFORE the fetch

        params = {"modified_before": webhook_finished.isoformat()}
        if stored and stored.last_synced_at:
            params["modified_after"] = stored.last_synced_at.isoformat()
        # No stored.last_synced_at → first subsequent sync; omit modified_after

        # Fetch changed records using the Merge SDK with bounded window
        merge = Merge(api_key=os.environ["MERGE_API_KEY"], account_token=account.account_token)
        category, model_name = model_id.split(".")  # e.g., "crm.Contact" → "crm", "Contact"
        list_fn = getattr(getattr(merge, category), model_name.lower() + "s")  # merge.crm.contacts
        results = fetch_all_pages(list_fn, params)  # your pagination helper from Step 6
        upsert_records(model_id, results)
        upsert_sync_state(account.id, model_id, last_synced_at, webhook_finished)
```

## Critical Differences from Initial Sync Webhook

| Concern | Initial sync | Subsequent sync |
|---|---|---|
| Timestamps | None needed | Track `last_synced_at` + `merge_last_sync_finished` per model |
| Deduplication | `initial_sync_complete` flag | `webhook.last_sync_finished <= stored` check |
| Fetch scope | Full historical data | `modified_after` + `modified_before` bounded window |
| PARTIALLY_SYNCED | Skip (incomplete history) | Accept (baseline already exists) |

## Critical Gotchas

- **30-second timeout**: return 200 at the endpoint immediately; ALL data fetching is in the background job
- **Deduplication is automatic**: `webhook_finished <= stored.merge_last_sync_finished` handles both duplicates and out-of-order webhooks — no extra logic needed
- **First subsequent sync**: `stored.last_synced_at` is null — omit `modified_after`, include only `modified_before`
- **Record `last_synced_at` before the fetch**, not after — ensures no gap if records are modified during the fetch window

## HTTP Response Codes

Same as initial webhook: **200** (queued), **401** (bad signature — already handled), **5xx** (Merge retries up to 2 more times).

## Testing Checklist

- [ ] Webhook returns 200 within 5 seconds
- [ ] Background job processes webhook asynchronously
- [ ] Extracts `last_sync_finished` per model from `data.sync_status`
- [ ] Compares webhook timestamp with stored value (skips if not newer)
- [ ] Records `last_synced_at` before fetch
- [ ] Fetches with correct bounded window (`modified_after` + `modified_before`)
- [ ] Stores both timestamps after successful fetch
- [ ] Skips FAILED models; accepts DONE and PARTIALLY_SYNCED
- [ ] Handles duplicate webhooks gracefully (idempotent)
- [ ] Handles out-of-order webhooks gracefully
- [ ] Works when `last_synced_at` is null (first subsequent sync)
