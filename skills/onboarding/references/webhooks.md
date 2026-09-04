# Webhooks Reference

Webhook setup, signature verification, and event types per Merge category.

## Two webhook systems

### 1. Merge → You (Merge webhooks)

Merge tells your app when something happens. Always available, configured per webhook URL.

Event names are PascalCase on the model, lowercase on the action, joined by a dot. Match `hook.event` against these exact strings:

- `LinkedAccount.linked` — new Linked Account finished linking
- `LinkedAccount.deleted` — Linked Account fully removed
- `LinkedAccount.sync_completed` — a sync finished, with per-model results in the payload
- `Issue.new`, `Issue.reopened`, `Issue.resolved` — Linked Account issue lifecycle
- `{WebhookModel}.added`, `{WebhookModel}.changed`, `{WebhookModel}.removed` — a record was created, updated, or deleted (e.g. `Employee.added`, `Ticket.changed`)
- `{WebhookModel}.synced` — one model finished syncing (e.g. `Candidate.synced`)

`{WebhookModel}` carries an internal prefix in four categories (`CRMAccount`, `FileStorageFile`, `KnowledgeBaseArticle`, `MKTGCampaign`, …). The verbatim list per category is in **Event types per category** below — don't derive it from the endpoint path.
- `AsyncPassthrough.resolved`, `AsyncPost.completed`, `AsyncBulkPost.completed` — async operation completion

⚠️ **`LinkedAccount.synced` is the deprecated predecessor of `LinkedAccount.sync_completed`.** Subscribe to `sync_completed` on anything new.

⚠️ **`LinkedAccount.status_changed` appears in the dashboard's event list but has no emitter — it never fires.** Do not build relink detection on it. Detect a broken account from `Issue.new` webhooks, from polling `GET /issues?linked_account_id=<id>` for `ONGOING` issues, or from `status` on `GET /account-details`.

Configure: **https://app.merge.dev/configuration/webhooks/emitters → Add webhook**

⚠️ **The "Send test" button** sends a connectivity ping (`{"response": "Success! This URL will be notified."}`), NOT a real event payload. Your handler will see `event_type=undefined`. To test real event handling, reconnect via Merge Link with the Test integration — that triggers actual `LinkedAccount.linked` and `LinkedAccount.sync_completed` events.

### 2. Third-party → Merge → You (Third-party webhooks)

For providers that support webhooks natively (Salesforce, Jira, Slack, etc.), Merge subscribes on your behalf and forwards normalized events to your URL. Faster than polling.

Configure: **https://app.merge.dev/configuration/webhooks/receivers → toggle on per integration**

## Webhook payload structure

Every Merge webhook POST has this shape:

```javascript
{
  "hook": {
    "id": "webhook-config-uuid",
    "event": "LinkedAccount.sync_completed",
    "target": "https://yourapp.com/webhooks/merge"
  },
  "linked_account": {
    "id": "linked-account-uuid",
    "integration": "Google Drive",          // display NAME, not the slug
    "integration_slug": "google-drive",     // the slug lives here
    "category": "filestorage",
    "end_user_origin_id": "user_123",
    "end_user_organization_name": "Acme Corp",
    "end_user_email_address": "alice@acme.com",
    "status": "COMPLETE",
    "webhook_listener_url": "https://api.merge.dev/api/integrations/webhook-listener/abcd1234",
    "is_duplicate": false,
    "account_type": "PRODUCTION"
  },
  "data": {
    // Event-specific payload. For {WebhookModel}.added/.changed, this is the Common Model record.
    // For sync events, this is sync metadata.
  }
}
```

⚠️ **`linked_account.integration` is the provider's display name** (`"Google Drive"`, `"BambooHR"`), not the slug. Matching on `integration === "google-drive"` never fires — use `integration_slug`.

### Payload differences by event type

| Event | `data` contents |
|-------|----------------|
| `LinkedAccount.sync_completed` | `{ is_initial_sync, integration_name, integration_id, sync_status: { "<category>.<Model>": { last_sync_finished, last_sync_result, data_fresh_as_of, sync_status_reason } } }` |
| `LinkedAccount.linked` | Account info; `linked_account` carries the useful fields |
| `{WebhookModel}.synced` | `{ integration_name, integration_id, synced_fields, sync_status }` for that one model |
| `{WebhookModel}.added`, `{WebhookModel}.changed` | The full Common Model record that changed |
| `{WebhookModel}.removed` | The record as last seen, including its `id` |
| `Issue.new`, `Issue.reopened`, `Issue.resolved` | The Issue object (`status`, `error_description`, `error_details`, `first_incident_time`, `last_incident_time`) |

`sync_status` on `LinkedAccount.sync_completed` is a **map keyed by model ID** (`"hris.Employee"`), not a single status string. A handler that reads `data.sync_status === "DONE"` never matches.

```javascript
{
  "hook": { "event": "LinkedAccount.sync_completed", "target": "https://yourapp.com/webhooks/merge" },
  "linked_account": { "id": "...", "integration": "Ashby", "integration_slug": "ashby", "category": "ats" },
  "data": {
    "is_initial_sync": true,
    "integration_name": "Ashby",
    "integration_id": "ashby",
    "sync_status": {
      "ats.Candidate": {
        "last_sync_finished": "2024-01-15T18:57:12Z",
        "last_sync_result": "PARTIALLY_SYNCED",
        "data_fresh_as_of": "2024-01-15T18:35:00Z",
        "sync_status_reason": null
      }
    }
  }
}
```

Use `hook.event` to determine the event type, then parse `data` accordingly.

Headers on every webhook request:
- `Content-Type: application/json`
- `X-Merge-Webhook-Signature: <signature>`

Merge does not set a distinctive `User-Agent` on webhook deliveries. Authenticate on the signature — never on the user agent or a source IP.

## Signature verification (CRITICAL)

Always verify the signature. Without verification, anyone who knows your URL can spoof Merge webhooks.

**Algorithm:** HMAC-SHA256 of the raw request body, **base64url-encoded** (NOT standard base64 — base64url uses `-_` instead of `+/`), padding stripped.

⚠️ **base64url, not base64.** Using standard `base64` encoding produces a different output and verification silently fails. In Python use `base64.urlsafe_b64encode()`. In Node use `.digest("base64url")`.

**Why strip `=` padding:** base64url signatures may arrive with or without trailing `=` padding depending on the sender. Strip padding from both the computed and received signatures before comparing to avoid mismatches.

**Webhook secret:** Found at `https://app.merge.dev/configuration/webhooks/emitters → click your webhook → Security`. Different per webhook config.

**Secret rotation:** When you rotate the webhook secret in the dashboard, in-flight webhooks signed with the old secret may still arrive for a short period. During rotation, verify against both the old and new secret — accept the webhook if either matches. Remove the old secret after a few minutes.

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

Changed-data events are `{WebhookModel}.added`, `{WebhookModel}.changed`, and `{WebhookModel}.removed`.

⚠️ **`{WebhookModel}` is not always the Common Model name.** Four categories carry an internal prefix on the wire, so the event string for a File Storage file is `FileStorageFile.added`, not `File.added`. Copy the names below verbatim — they are not derivable from the endpoint path or the Scopes label.

| Category | Webhook model names (use these verbatim in `hook.event`) |
|---|---|
| **HRIS** | `Employee`, `Employment`, `Team`, `Location`, `Company`, `Group`, `PayGroup`, `PayrollRun`, `EmployeePayrollRun`, `Benefit`, `EmployerBenefit`, `TimeOff`, `TimeOffBalance`, `BankInfo`, `Dependent`, `Deduction` |
| **ATS** | `Candidate`, `Application`, `Job`, `JobInterviewStage`, `Department`, `Office`, `RemoteUser`, `Tag`, `Attachment`, `RejectReason`, `ScheduledInterview`, `Scorecard`, `Offer`, `EEOC`, `Activity`, `Assessment`, `AssessmentTemplate` |
| **CRM** | `CRMAccount`, `CRMContact`, `CRMUser`, `Opportunity`, `Stage`, `Lead`, `Note`, `Task`, `Engagement` |
| **Accounting** | `Account`, `Contact`, `Invoice`, `InvoiceLineItem`, `Payment`, `Expense`, `ExpenseLine`, `CreditNote`, `VendorCredit`, `PurchaseOrder`, `PurchaseOrderLineItem`, `JournalEntry`, `JournalLine`, `Item`, `TaxRate`, `TrackingCategory`, `AccountingTransaction`, `AccountingAttachment`, `AccountingEmployee`, `AccountingPeriod`, `AccountingPhoneNumber`, `Address`, `GeneralLedgerTransaction`, `BankFeedAccount`, `BankFeedTransaction`, `BalanceSheet`, `IncomeStatement`, `CashFlowStatement`, `CompanyInfo`, `ReportItem` |
| **Ticketing** | `Ticket`, `Comment`, `Collection`, `Project`, `User`, `Role`, `TicketingAccount`, `TicketingContact`, `TicketingTeam`, `TicketingTag`, `TicketingAttachment`, `TicketingViewer` |
| **File Storage** | `FileStorageFile`, `FileStorageFolder`, `FileStorageDrive`, `FileStorageGroup`, `FileStorageUser` |
| **Knowledge Base** | `KnowledgeBaseArticle`, `KnowledgeBaseContainer`, `KnowledgeBaseUser`, `KnowledgeBaseGroup`, `KnowledgeBaseAttachment` |
| **Marketing** | `MKTGCampaign`, `MKTGContact`, `MKTGList`, `MKTGMessage`, `MKTGTemplate`, `MKTGMarketingEmail`, `MKTGEvent`, `MKTGAutomation`, `MKTGAction`, `MKTGUser` |

Worked examples: `Employee.added` (HRIS), `Candidate.changed` (ATS), `CRMAccount.changed` (CRM), `Invoice.added` (Accounting), `Ticket.changed` (Ticketing), `FileStorageFile.removed` (File Storage), `KnowledgeBaseArticle.added` (Knowledge Base), `MKTGCampaign.changed` (Marketing).

The same names take a `.synced` suffix for per-model sync events: `FileStorageFile.synced`, `Candidate.synced`.

⚠️ **There are only three changed-data actions: `added`, `changed`, `removed`.** There is no per-field or per-relationship event — no `opportunity.stage_changed`, no `contact.added_to_list`. A stage move arrives as `Opportunity.changed` carrying the full record; diff it against your stored copy to see what moved.

You configure which events your webhook subscribes to in the dashboard. A few models appear as webhook events without having a list endpoint of their own (HRIS `Deduction`, Accounting `InvoiceLineItem`, `JournalLine`, `ExpenseLine`) — subscribe to those to catch line-item changes you'd otherwise have to re-fetch the parent to see.

## Sync lifecycle events

These fire regardless of category:

| Event | When |
|-------|------|
| `LinkedAccount.linked` | End-user finishes Merge Link |
| `LinkedAccount.sync_completed` | Initial sync OR a periodic sync completes |
| `LinkedAccount.deleted` | You or the end-user removed the Linked Account |
| `Issue.new` | Merge opened an issue on the account (expired credentials, missing permissions, provider outage) |
| `Issue.resolved` | The issue cleared |

For most apps: subscribe to `LinkedAccount.sync_completed` to know when fresh data is queryable, then call the list endpoint with `modified_after=last_sync_finished` to pull only what changed. Pair it with `Issue.new` for the "this account is broken, prompt a reconnect" path — there is no dedicated relink-needed event.

## Webhook vs polling

| Use webhooks when... | Use polling when... |
|---------------------|---------------------|
| You need real-time updates | Sandbox testing |
| The provider supports third-party webhooks | The provider doesn't (some HRIS systems) |
| You're at scale (1,000+ Linked Accounts) | You're a prototype with <50 accounts |
| You want to minimize API calls | You need a guaranteed catch-all |

Best practice: use webhooks as the primary signal, then run a daily reconciliation poll as a safety net. Webhooks can be lost (network issues, your endpoint down). The reconciliation poll catches anything missed.

## Retries

Merge retries failed webhook deliveries, but far less generously than most webhook systems:

- 1 initial attempt + **2 retries**, backing off 1s then 2s. The whole sequence finishes in seconds, not hours.
- **Retries only fire on 5xx, a connection error, or a timeout.** A `4xx` from your endpoint is treated as a permanently bad target and the event is dropped with no further attempt.
- The delivery timeout is 10 seconds.

⚠️ **Three attempts inside ~3 seconds is not a safety net.** If your endpoint is down for a deploy, or your framework returns `400`/`422` on a payload it can't parse, that event is gone. Always run a reconciliation poll (`GET /sync-status`, or a `modified_after` sweep) as the backstop — do not treat webhooks as guaranteed delivery.

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
