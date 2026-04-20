# Webhooks Reference

Webhook setup, signature verification, and event types per Merge category.

## Two webhook systems

### 1. Merge → You (Merge webhooks)

Merge tells your app when something happens. Always available, configured per webhook URL.

Common events:
- `linked_account.created` — new Linked Account finished linking
- `linked_account.deleted` — end-user disconnected
- `linked_account.synced` — initial or incremental sync completed
- `*.created`, `*.updated`, `*.deleted` — changes to specific Common Models (e.g., `employee.created`, `ticket.updated`)

Configure: **https://app.merge.dev/configuration/webhooks → Add webhook**

### 2. Third-party → Merge → You (Third-party webhooks)

For providers that support webhooks natively (Salesforce, Jira, Slack, etc.), Merge subscribes on your behalf and forwards normalized events to your URL. Faster than polling.

Configure: **https://app.merge.dev/configuration/webhooks → Third Party tab → toggle on per integration**

## Webhook payload structure

Every Merge webhook POST has this shape:

```json
{
  "hook": {
    "id": "webhook-config-uuid",
    "event": "linked_account.synced",
    "target": "https://yourapp.com/webhooks/merge"
  },
  "linked_account": {
    "id": "linked-account-uuid",
    "integration": "google-drive",
    "category": "filestorage",
    "end_user_origin_id": "user_123",
    "end_user_email_address": "alice@acme.com"
  },
  "data": {
    // Event-specific payload. For *.created/updated, this is the Common Model record.
    // For sync events, this is sync metadata.
  }
}
```

Headers on every webhook request:
- `Content-Type: application/json`
- `X-Merge-Webhook-Signature: <signature>`
- `User-Agent: Merge/Webhooks`

## Signature verification (CRITICAL)

Always verify the signature. Without verification, anyone who knows your URL can spoof Merge webhooks.

**Algorithm:** HMAC-SHA256 of the raw request body, base64url-encoded, padding stripped.

**Webhook secret:** Found at `https://app.merge.dev/configuration/webhooks → click your webhook → Security`. Different per webhook config.

### Python (Flask)

```python
import hmac, hashlib, base64
from flask import Flask, request, abort

app = Flask(__name__)
WEBHOOK_SECRET = os.environ["MERGE_WEBHOOK_SECRET"]

def verify_merge_signature(payload_bytes: bytes, signature: str) -> bool:
    digest = hmac.new(WEBHOOK_SECRET.encode(), payload_bytes, hashlib.sha256).digest()
    expected = base64.urlsafe_b64encode(digest).decode().rstrip("=")
    return hmac.compare_digest(expected, signature.rstrip("="))

@app.route("/webhooks/merge", methods=["POST"])
def merge_webhook():
    raw_body = request.get_data()  # bytes BEFORE any JSON parsing
    signature = request.headers.get("X-Merge-Webhook-Signature", "")

    if not verify_merge_signature(raw_body, signature):
        abort(401, "Invalid signature")

    payload = request.get_json()
    handle_event(payload)
    return "", 200
```

⚠️ **Critical:** verify against the **raw body bytes**, not the parsed JSON. Re-serializing JSON will produce a different byte sequence and break the signature.

### Node.js (Express)

```typescript
import express from "express";
import crypto from "crypto";

const app = express();
const SECRET = process.env.MERGE_WEBHOOK_SECRET!;

// Capture raw body for signature verification
app.use(
  "/webhooks/merge",
  express.raw({ type: "application/json" })
);

function verifyMergeSignature(payload: Buffer, signature: string): boolean {
  const digest = crypto.createHmac("sha256", SECRET).update(payload).digest();
  const expected = digest.toString("base64url").replace(/=+$/, "");
  return crypto.timingSafeEqual(
    Buffer.from(expected),
    Buffer.from(signature.replace(/=+$/, ""))
  );
}

app.post("/webhooks/merge", (req, res) => {
  const signature = req.header("X-Merge-Webhook-Signature") || "";
  const rawBody = req.body as Buffer;

  if (!verifyMergeSignature(rawBody, signature)) {
    return res.status(401).send("Invalid signature");
  }

  const payload = JSON.parse(rawBody.toString());
  handleEvent(payload);
  res.status(200).send();
});
```

### Common signature gotchas

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Invalid signature` on every request | Wrong secret (using API key instead of webhook secret) | Get the secret from the webhook config page, not API keys page |
| `Invalid signature` on some requests | JSON re-serialized before verification | Capture raw bytes BEFORE any framework parses JSON |
| Verification works locally, fails in prod | Reverse proxy (nginx, CloudFlare) modifying body | Configure proxy to pass raw body unchanged |
| Intermittent failures | Trailing `=` padding mismatch | Strip `=` from both sides before comparing |
| `crypto.timingSafeEqual` throws | Buffers different lengths | Always strip padding to make lengths consistent |

## Event types per category

The `*.created`, `*.updated`, `*.deleted` events are scoped per Common Model. Examples:

**HRIS:** `employee.created`, `employment.updated`, `team.created`, `payroll_run.created`

**ATS:** `candidate.created`, `application.updated`, `job.created`, `offer.created`

**CRM:** `contact.created`, `account.updated`, `opportunity.stage_changed`, `lead.created`

**Accounting:** `invoice.created`, `payment.created`, `invoice.updated`

**Ticketing:** `ticket.created`, `ticket.updated`, `comment.created`

**File Storage:** `file.created`, `file.updated`, `file.deleted`, `folder.created`

**Knowledge Base:** `article.created`, `article.updated`

**Marketing:** `campaign.created`, `campaign.updated`, `contact.added_to_list`

You configure which events your webhook subscribes to in the dashboard.

## Sync lifecycle events

These fire regardless of category:

| Event | When |
|-------|------|
| `linked_account.created` | End-user finishes Merge Link |
| `linked_account.synced` | Initial sync OR a periodic sync completes |
| `linked_account.deleted` | You or the end-user removed the Linked Account |
| `linked_account.relink_needed` | Credentials expired, end-user must re-link |

For most apps: subscribe to `linked_account.synced` to know when fresh data is queryable. Then call `merge.{category}.{model}.list(modified_after=last_sync_time)` to pull only what changed.

## Webhook vs polling

| Use webhooks when... | Use polling when... |
|---------------------|---------------------|
| You need real-time updates | Sandbox testing |
| The provider supports third-party webhooks | The provider doesn't (some HRIS systems) |
| You're at scale (1,000+ Linked Accounts) | You're a prototype with <50 accounts |
| You want to minimize API calls | You need a guaranteed catch-all |

Best practice: use webhooks as the primary signal, then run a daily reconciliation poll as a safety net. Webhooks can be lost (network issues, your endpoint down). The reconciliation poll catches anything missed.

## Retries

Merge retries failed webhook deliveries:
- Initial: immediate
- Retries: 5 attempts over ~1 hour with exponential backoff
- Counts as failure: 4xx or 5xx response, or no response within 10 seconds

Return `200 OK` quickly (under 5 seconds). Do heavy processing in a background job:

```python
@app.route("/webhooks/merge", methods=["POST"])
def merge_webhook():
    raw_body = request.get_data()
    if not verify_merge_signature(raw_body, request.headers.get("X-Merge-Webhook-Signature", "")):
        abort(401)

    # Queue and return immediately
    background_queue.enqueue(handle_event, raw_body)
    return "", 200
```

## Local development

Test webhooks locally with ngrok or similar:

```bash
ngrok http 3000
# Use https://abc123.ngrok.io/webhooks/merge as the URL in Merge dashboard
```

Or use the dashboard's "Send test event" button to fire a sample payload at your URL.

## Webhook logs

Every webhook delivery is logged in the dashboard: **https://app.merge.dev/logs/webhooks**. Filter by status, integration, or event type. Useful for debugging when an expected event didn't trigger your handler.
