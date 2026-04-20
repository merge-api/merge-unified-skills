---
name: merge-sync-implement-initial-webhooks
description: Implement initial sync detection via Merge webhooks — a webhook endpoint that receives sync completion events and triggers initial data fetches. Use as Step 2b of Merge sync implementation for production-grade real-time sync detection.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing Initial Sync Detection via Merge Webhooks

Creates a webhook endpoint that Merge calls when an initial sync completes, triggering an immediate data fetch. Provides real-time sync detection with no polling overhead.

## Prerequisites

- `merge-sync-set-context` complete
- `MERGE_WEBHOOK_SECRET` in `.env` (from Merge Dashboard → Webhooks)
- `linked_accounts` table has `initial_sync_complete boolean DEFAULT false`
- Background job queue configured (Celery, Redis Queue, etc.) for async processing
- Webhook URL publicly accessible (use ngrok for local testing)

## Implementation

Implement a Merge webhook endpoint for initial sync detection. This is a security-critical endpoint — follow these steps exactly.

### Step 1: Register Webhook in Merge Dashboard

Subscribe to the `LinkedAccount.sync_completed` event pointing to `POST /api/webhooks/merge` on your server.

### Step 2: Webhook Endpoint — `POST /api/webhooks/merge`

Implement in three strict steps:

1. **Verify HMAC-SHA256 signature FIRST** — before parsing the request body
2. **Queue the raw payload** for async processing
3. **Return 200 OK immediately** — Merge times out after 30 seconds

### Step 3: HMAC Signature Verification + Endpoint

> **Order matters:** `request.get_data()` MUST be called before `request.json()`. Calling `request.json()` first consumes the body, making HMAC verification impossible. Some frameworks (e.g., Express with `json()` middleware) parse the body automatically — use `express.raw()` on the webhook route to prevent this.

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
    expected = base64.b64encode(digest).decode()
    # Use compare_digest — never plain == (prevents timing attacks)
    if not hmac.compare_digest(expected, signature):
        logger.warning("Merge webhook: invalid signature")
        return {"error": "Invalid signature"}, 401

    process_merge_webhook.delay(request.json)  # queue async job
    return {}, 200
```

### Step 4: Background Job

```python
def process_merge_webhook(payload: dict):
    origin_id = payload["linked_account"]["end_user_origin_id"]
    account = db.query(LinkedAccount).filter_by(end_user_origin_id=origin_id).first()

    if not account or account.initial_sync_complete:
        return  # missing account → 200 avoids retries; duplicate → idempotent

    account.initial_sync_complete = True
    db.commit()
    fetch_initial_data(account)
```

## Security Requirements (Critical)

- **Verify signature before `request.json`** — parse raw bytes only for verification
- **Use `hmac.compare_digest()`** — never `==` (timing attack vulnerability)
- **Never log `MERGE_WEBHOOK_SECRET`**
- **Log all signature failures** for monitoring and alerting
- **Return 200 on missing account** — prevents Merge from retrying on bad data

## HTTP Response Codes

- **200**: Successfully received — Merge won't retry
- **401**: Invalid/missing signature — Merge won't retry
- **5xx**: Temporary failure — Merge retries up to 2 more times

Never return other 4xx codes.

## Testing Checklist

- [ ] Endpoint accepts POST at correct URL
- [ ] Signature verification implemented using HMAC-SHA256
- [ ] Returns 200 OK within 5 seconds (under 30s Merge timeout)
- [ ] Webhook processing is asynchronous (background job)
- [ ] `initial_sync_complete` set to true on valid webhook
- [ ] Duplicate webhooks handled idempotently
- [ ] Signature failures return 401, logged for monitoring
