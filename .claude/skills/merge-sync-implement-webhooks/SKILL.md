---
name: merge-sync-implement-webhooks
description: >
  Implement Merge sync detection via webhooks — the PRIMARY production-recommended
  approach. A single endpoint handles both initial sync detection (first connection)
  and subsequent incremental syncs (ongoing data updates), with HMAC verification
  and a bounded `modified_after` / `modified_before` fetch window. Use when a
  developer says "set up Merge webhooks", "real-time sync", "implement sync",
  "fetch data from Merge", "Merge webhook handler", "Linked Account synced",
  "incremental sync", or after completing Merge Link. Production builders should
  also add `merge-sync-implement-polling` as a fallback safety net.
license: MIT
metadata:
  author: Merge
  version: 0.2.0
---

# Implementing Merge Sync via Webhooks (Primary)

Webhooks are the production-recommended way to detect Merge sync events. A single endpoint at `POST /api/webhooks/merge` handles **both** initial sync completion (after a customer first connects) and **subsequent** sync events (ongoing updates). Real-time, no polling overhead.

> **Webhooks are PRIMARY; polling is a fallback.** For production reliability, also implement `merge-sync-implement-polling` as a safety net — webhook delivery can lag, drop, or your endpoint can be briefly unavailable. The two complement each other.

> **Field-name convention used in this doc.** Pseudo-code and JSON snippets show the raw HTTP response shape (snake_case: `last_sync_result`, `modified_at`, `is_initial_sync`). The Merge SDKs auto-convert to camelCase — in Node, `model.is_initial_sync` becomes `model.isInitialSync`. Write your code in your SDK's convention.

## First activation: self-introduce

> I'm the merge-sync-implement-webhooks skill (v0.1.0). I'll wire up a single webhook endpoint that handles both initial and subsequent Merge syncs, with HMAC verification and async processing. For production, plan to also run `merge-sync-implement-polling` as a fallback.

## Prerequisites

- Sync context loaded (the `implementing-merge-sync` orchestrator runs this in Step 1)
- `MERGE_WEBHOOK_SECRET` in `.env` (from Merge Dashboard → Webhooks)
- `linked_accounts` table has `initial_sync_complete boolean DEFAULT false`
- Background job queue configured (Celery, Redis Queue, BullMQ, etc.) for async processing
- Webhook URL publicly accessible (use ngrok/cloudflared for local testing)

## Step 1: Register the webhook in Merge Dashboard

Go to **https://app.merge.dev/configuration/webhooks → Add webhook**. Point it to `POST /api/webhooks/merge` on your server. Subscribe to `Linked Account synced` events.

For production, also subscribe to `Linked Account.sync_completed` (recommended) — one event per sync covers all models in one payload. Alternatively, subscribe to `{CommonModel}.synced` events for per-model granularity if you need progressive processing.

> **Tunnel-hostname rotation warning:** cloudflared quick mode and ngrok free tier rotate hostnames on every restart, breaking the registered emitter URL. Use named/reserved tunnels for repeated dev work, or expect to re-register on each restart.

## Step 2: Webhook payload schema

Every Merge webhook delivers this shape:

| Field | Type | Notes |
|---|---|---|
| `hook.event` | string | Event type, e.g. `"Linked Account synced"` |
| `hook.id` | string (UUID) | Webhook config ID |
| `linked_account.id` | string (UUID) | Merge's Linked Account ID — match to your `merge_account_id` column |
| `linked_account.end_user_origin_id` | string | The origin ID you sent in `link_token` creation |
| `linked_account.integration` | string | Provider slug, e.g. `"salesforce"` |
| `linked_account.category` | string | e.g. `"crm"`, `"hris"`, `"ats"`, `"ticketing"`, `"accounting"` |
| `data` | object | Event-specific payload (sync metadata for sync events) |

**For sync events**, `data.sync_status` is keyed by model ID. Each entry has `last_sync_finished` (Merge's timestamp) and `last_sync_result` (`DONE`, `PARTIALLY_SYNCED`, or `FAILED`):

```javascript
{
  "hook": { "event": "Linked Account synced" },
  "linked_account": {
    "id": "merge-uuid",
    "end_user_origin_id": "your_user_id",
    "category": "crm"
  },
  "data": {
    "sync_status": {
      "crm.Contact": { "last_sync_finished": "2024-01-15T22:46:41Z", "last_sync_result": "DONE" },
      "crm.Account":  { "last_sync_finished": "2024-01-15T22:46:40Z", "last_sync_result": "DONE" }
    }
  }
}
```

## Step 3: Build the endpoint — HMAC verify, queue, return 200 immediately

This endpoint is security-critical. Follow these three rules exactly:

1. **Verify HMAC-SHA256 signature FIRST** — before parsing the request body.
2. **Queue the raw payload** for async processing.
3. **Return 200 OK immediately** — Merge times out after **10 seconds** (or on 4xx/5xx) and retries 5 times over ~1 hour with exponential backoff. Aim to ACK in under 5 seconds.

> **Order matters:** read the raw body *before* JSON parsing. If your framework auto-parses (e.g., Express with `app.use(express.json())`), use `express.raw({ type: '*/*' })` on the webhook route so you can compute HMAC against the raw Buffer.

```python
@app.post("/api/webhooks/merge")
def merge_webhook():
    signature = request.headers.get("X-Merge-Webhook-Signature")
    if not signature:
        logger.warning("Merge webhook: missing signature")
        return {"error": "Missing signature"}, 401

    raw_body = request.get_data()  # raw bytes — do NOT call request.json() first
    secret = os.environ.get("MERGE_WEBHOOK_SECRET")
    if not secret:
        return {"error": "Webhook secret not configured"}, 500

    digest = hmac.new(secret.encode(), raw_body, hashlib.sha256).digest()
    expected = base64.urlsafe_b64encode(digest).decode().rstrip("=")
    # Use compare_digest — never plain == (prevents timing attacks)
    if not hmac.compare_digest(expected, signature.rstrip("=")):
        logger.warning("Merge webhook: invalid signature")
        return {"error": "Invalid signature"}, 401

    process_merge_webhook.delay(request.get_json())  # queue async job
    return {}, 200
```

## Step 4: Background job — branch on initial vs. subsequent

A single job handles both phases. The `initial_sync_complete` flag on `linked_accounts` tells you which path to take.

```python
def process_merge_webhook(payload: dict):
    origin_id = payload["linked_account"]["end_user_origin_id"]
    account = db.query(LinkedAccount).filter_by(end_user_origin_id=origin_id).first()
    if not account:
        return  # already returned 200 at endpoint; no retry needed

    if not account.initial_sync_complete:
        # Initial sync path
        account.initial_sync_complete = True
        db.commit()
        fetch_initial_data(account)
    else:
        # Subsequent sync path — incremental fetch with bounded window
        process_subsequent_sync(account, payload)
```

## Step 5: Subsequent sync — the two timestamps

For subsequent syncs you need a `sync_state` table to track per-model timestamps.

**SQL migration:**

```sql
CREATE TABLE IF NOT EXISTS sync_state (
  id                        SERIAL PRIMARY KEY,
  linked_account_id         INTEGER NOT NULL REFERENCES linked_accounts(id) ON DELETE CASCADE,
  model_id                  TEXT NOT NULL,             -- e.g. "hris.Employee"
  last_synced_at            TIMESTAMPTZ,               -- YOUR timestamp — when you STARTED the last fetch
  merge_last_sync_finished  TIMESTAMPTZ,               -- Merge's timestamp from the webhook
  last_fetched_at           TIMESTAMPTZ,               -- when your fetch completed
  status                    TEXT,                       -- DONE | PARTIALLY_SYNCED | SYNCING | FAILED
  UNIQUE (linked_account_id, model_id)
);
```

**SQLAlchemy equivalent:**

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

| Timestamp                  | Owner        | Purpose                                     |
| -------------------------- | ------------ | ------------------------------------------- |
| `merge_last_sync_finished` | Merge        | DETECT new data — compare with stored value |
| `last_synced_at`           | Your backend | FETCH parameter — use as `modified_after`   |

**Why start time:** Overlap is safer than gaps — records modified during your fetch window are captured twice, never missed.

## Step 6: Per-model processing in the subsequent path

```python
def process_subsequent_sync(account, payload: dict):
    sync_status = payload["data"]["sync_status"]   # dict keyed by model_id

    for model_id, model_data in sync_status.items():
        last_sync_result = model_data.get("last_sync_result")

        # Accept successful results; skip failures
        if last_sync_result not in ("DONE", "PARTIALLY_SYNCED"):
            continue

        webhook_finished = parse_datetime(model_data["last_sync_finished"])

        stored = db.query(SyncState).filter_by(
            linked_account_id=account.id, model_id=model_id
        ).first()

        # Deduplicate / handle out-of-order webhooks automatically
        if stored and stored.merge_last_sync_finished and webhook_finished <= stored.merge_last_sync_finished:
            continue

        last_synced_at = datetime.utcnow()  # record BEFORE the fetch

        params = {"modified_before": webhook_finished.isoformat()}
        if stored and stored.last_synced_at:
            params["modified_after"] = stored.last_synced_at.isoformat()
        # No stored.last_synced_at → first subsequent sync; omit modified_after

        merge = Merge(api_key=os.environ["MERGE_API_KEY"], account_token=account.account_token)
        category, model_name = model_id.split(".")  # e.g., "crm.Contact" → "crm", "Contact"
        list_fn = getattr(getattr(merge, category), model_name.lower() + "s")  # merge.crm.contacts
        results = fetch_all_pages(list_fn, params)
        upsert_records(model_id, results)
        upsert_sync_state(account.id, model_id, last_synced_at, webhook_finished)
```

## Critical Differences: Initial vs. Subsequent

| Concern | Initial sync | Subsequent sync |
|---|---|---|
| Timestamps | None needed | Track `last_synced_at` + `merge_last_sync_finished` per model |
| Deduplication | `initial_sync_complete` flag | `webhook.last_sync_finished <= stored` check |
| Fetch scope | Full historical data | `modified_after` + `modified_before` bounded window |
| `PARTIALLY_SYNCED` | Skip (incomplete history) | Accept (baseline already exists) |

## Security requirements (critical)

- Verify signature **before** parsing JSON — work on raw bytes only.
- Use `hmac.compare_digest()` — never plain `==` (timing-attack vulnerability).
- Never log `MERGE_WEBHOOK_SECRET`.
- Log all signature failures for monitoring and alerting.
- Return **200** on missing account (already handled here) — prevents Merge from retrying on bad data.

## HTTP response codes

- **200**: Successfully received — Merge won't retry.
- **401**: Invalid/missing signature — Merge won't retry.
- **5xx**: Temporary failure — Merge retries up to 2 more times.

Never return other 4xx codes.

## Critical gotchas

- **30-second timeout**: return 200 at the endpoint immediately; ALL data fetching is in the background job.
- **Deduplication is automatic**: `webhook_finished <= stored.merge_last_sync_finished` handles both duplicates and out-of-order webhooks — no extra logic needed.
- **First subsequent sync**: `stored.last_synced_at` is null — omit `modified_after`, include only `modified_before`.
- **Record `last_synced_at` before the fetch**, not after — ensures no gap if records are modified during the fetch window.
- **Add polling as a fallback** (`merge-sync-implement-polling`): webhook delivery occasionally lags or drops. Polling on a slow cadence catches what webhooks miss.

## Testing checklist

- [ ] Endpoint accepts POST at `/api/webhooks/merge` (or your chosen path)
- [ ] HMAC-SHA256 signature verification implemented; uses `compare_digest`
- [ ] Returns 200 OK within 5 seconds (well under Merge's 30s timeout)
- [ ] Webhook processing is asynchronous (background job)
- [ ] Initial path: sets `initial_sync_complete = true` and triggers full fetch
- [ ] Subsequent path: extracts `last_sync_finished` per model from `data.sync_status`
- [ ] Subsequent path: skips webhooks where `webhook_finished <= stored.merge_last_sync_finished`
- [ ] Subsequent path: records `last_synced_at` before fetch
- [ ] Subsequent path: uses correct bounded window (`modified_after` + `modified_before`)
- [ ] Subsequent path: stores both timestamps after successful fetch
- [ ] Skips FAILED models; accepts DONE for initial, DONE + PARTIALLY_SYNCED for subsequent
- [ ] Handles duplicate webhooks idempotently
- [ ] Handles out-of-order webhooks gracefully
- [ ] First subsequent sync works when `last_synced_at` is null
- [ ] Signature failures return 401 and are logged

## Troubleshooting

**SYMPTOM:** HMAC signature validation fails for all webhook events
**CAUSE:** Webhook secret mismatch or body was parsed before signature check (Express `json()` middleware consuming raw body)
**FIX:** Use `express.raw()` on the webhook route; compute HMAC against the raw Buffer before JSON parsing.

**SYMPTOM:** Webhook endpoint returns 200 but data is never fetched
**CAUSE:** Background job is being enqueued but not processed, or job queue is paused.
**FIX:** Verify your job worker is running; check the job queue dashboard for stuck jobs.

**SYMPTOM:** Incremental fetch returns records already processed
**CAUSE:** `last_synced_at` timestamp is not being saved after each successful fetch.
**FIX:** Persist `last_synced_at` and `merge_last_sync_finished` only after a successful fetch; never update on failure.

**SYMPTOM:** Webhook URL changes every dev session
**CAUSE:** cloudflared quick mode or ngrok free tier rotates hostnames on every restart.
**FIX:** Use named/reserved tunnels for repeated dev work; re-register the emitter URL in the Merge dashboard after rotations.
