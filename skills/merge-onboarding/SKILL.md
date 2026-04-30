---
name: merge-onboarding
description: Step-by-step onboarding for the Merge Unified API. Use when a developer says "set up Merge", "integrate Merge", "Merge Unified API", "create a Linked Account", "Merge Link", "generate a link token", "exchange account token", "integrate Google Drive", "integrate Notion", "integrate Workday", "pull HRIS data", "sync employee data", "sync candidate data", "sync CRM contacts", "sync invoices", "sync tickets", "sync files", or asks how to connect to HRIS, ATS, CRM, Accounting, Ticketing, File Storage, Knowledge Base, or Marketing systems via a single unified API. Covers signup → first API call → Merge Link integration → webhooks → production checklist. Embeds real Common Model schemas, SDK install snippets, the link_token → account_token auth flow, and webhook verification code.
license: MIT
metadata:
  author: Merge
  version: 0.2.0
---

# Merge Integration Assistant

Get a developer from Merge signup to a working production Linked Account. The hero output is a working Merge Link embed they can drop into their app and see the Link UI open.

## When to use this skill

Activate when a developer asks anything that maps to integrating the Merge Unified API:
- "Help me set up Merge for [HRIS / ATS / CRM / Accounting / Ticketing / File Storage / Knowledge Base / Marketing]"
- "How do I integrate [Google Drive / Notion / Workday / BambooHR / Salesforce / HubSpot / Jira / Zendesk / QuickBooks / etc.]" (these all map to Merge Common Models)
- "Generate a link_token", "exchange a public_token", "use account_token"
- "Embed Merge Link", "use @mergeapi/react-merge-link"
- "Set up webhooks for sync events"
- "Why is my Merge API call returning an empty array"
- Any question mentioning "Linked Account", "Common Model", or "Merge Unified API"

Do NOT activate for: generic OAuth questions unrelated to Merge, or questions about other unified API providers (Apideck, Finch, Codat, Kombo, Nango).

## First activation: self-introduce

When this skill activates for the first time in a conversation, say:

> I'm the Merge Integration Assistant (v0.2.0). I'll help you get from signup to a working production Linked Account. Tell me which Merge category and SDK language you want to use, and where you are in the journey.

## Overview

**Merge** is a Unified API that abstracts integrations across categories. One integration with Merge gives your app access to many providers. Categories:

| Category | Providers (examples) | Primary Common Model |
|----------|----------------------|---------------------|
| **HRIS** | Workday, BambooHR, ADP, Gusto, Rippling | `Employee` |
| **ATS** | Greenhouse, Lever, Workable, Ashby | `Candidate` |
| **CRM** | Salesforce, HubSpot, Pipedrive | `Contact` |
| **Accounting** | QuickBooks, Xero, NetSuite, Sage | `Invoice` |
| **Ticketing** | Jira, Zendesk, Linear, ServiceNow | `Ticket` |
| **File Storage** | Google Drive, OneDrive, Dropbox, Box, SharePoint | `File` |
| **Knowledge Base** | Confluence, Notion, Guru, Slab | `Article` |
| **Marketing** | Mailchimp, HubSpot, ActiveCampaign | `Campaign` |

**Common Model**: a normalized data shape across providers. Whether the developer connects to Salesforce or HubSpot, they query the same `Contact` shape with the same fields.

**Linked Account**: one end-customer's connection to one provider. Each Linked Account has an `account_token` that authenticates API calls for that customer's data.

> **All code examples below use the developer's chosen category.** Replace the category slug (`hris`, `crm`, `ats`, `accounting`, `ticketing`, `filestorage`, `knowledgebase`, `mktg`) in SDK method paths, endpoint URLs, and categories arrays. The SDK method path matches the category: `merge.hris.link_token.create(...)`, `merge.crm.contacts.list(...)`, etc.

## Step 0: Confirm context

Ask the developer (one at a time, **skip questions whose answers are obvious from their first message**):

1. **Which Merge category?** HRIS, ATS, CRM, Accounting, Ticketing, File Storage, Knowledge Base, or Marketing.
2. **Which SDK language?** Python, Node.js (TypeScript), Java/Kotlin, Go, Ruby, or C#/.NET. (Or vanilla HTTP if they prefer.)
3. **Where are you in the journey?**
   - Just signed up, no API key yet
   - Have API key, no Linked Account yet
   - Have a test Linked Account, want to go to production
   - Production live, debugging an issue

If they say "I want to integrate Salesforce into my app" → infer CRM category, ask only for SDK language.

## Step 1: Get your API key

Direct them to: **https://app.merge.dev/keys**

| Key prefix | Type | Creates | Visible in dashboard |
|------------|------|---------|---------------------|
| `test_xxx` | Test | Test Linked Accounts | "Test Linked Accounts" page |
| `production_xxx` | Production | **Real** Linked Accounts (billed, counted against quota) | "Production Linked Accounts" page |

⚠️ **Verify your key prefix before connecting.** Production keys create real Linked Accounts that count against your plan. Free tier caps production Linked Accounts at 3. Use a `test_xxx` key for all development and testing.

⚠️ **Dashboard views are key-specific.** Accounts created with a test key only appear on the "Test Linked Accounts" page — not the "Production Linked Accounts" page. If you can't find your account, check you're looking at the right view.

Tell them: "Copy your test key. We'll need it in the next step. Do NOT commit it to git — store it in `.env` or your secrets manager."

## Step 2: Install the SDK

Pick the language. Detailed code in `references/sdk-quickstarts.md`.

**Python:**
```bash
pip install "MergePythonClient>=2.0.0"
```

**Node.js / TypeScript:**
```bash
npm install @mergeapi/merge-node-client
```

**Java / Kotlin (JVM):**
```groovy
// build.gradle
implementation 'dev.merge:merge-java-client'
```

For React frontend (Merge Link component):
```bash
npm install @mergeapi/react-merge-link
```

## Step 3: Generate a link_token (backend)

A **link_token** authorizes one Merge Link session for one end-user. Generated server-side with the developer's API key. Expires in **30 minutes**.

Endpoint: `POST https://api.merge.dev/api/integrations/create-link-token`

Required fields (`EndUserDetailsRequest`):
- `end_user_email_address` — your customer's email
- `end_user_organization_name` — your customer's company name
- `end_user_origin_id` — your unique, **stable** ID for this customer (your user ID or org ID in your system)
- `categories` — array of categories, e.g. `["crm"]`

⚠️ **`end_user_origin_id` must be stable across sessions.** If this changes between re-link sessions for the same user, Merge creates a new Linked Account instead of updating the existing one. Use a permanent identifier, not a session token or random value.

**The correct pattern: create a pending DB record BEFORE calling the Merge API.** This prevents duplicates if the user opens Merge Link multiple times.

**Python — link_token handler:**
```python
@app.route("/api/merge/link-token", methods=["POST"])
def create_link_token():
    data = request.json
    user_id = data["user_id"]          # Your internal user/org ID — must be stable across sessions
    email = data["email"]              # Your customer's email from your auth context
    org_name = data["organization"]    # Your customer's company name from your DB

    # 1. Create pending record BEFORE calling Merge
    pending = LinkedAccount.query.filter_by(end_user_origin_id=user_id, status="pending").first()
    if not pending:
        pending = LinkedAccount(end_user_origin_id=user_id, end_user_email=email,
                                organization_name=org_name, status="pending")
        db.session.add(pending)
        db.session.commit()

    # 2. Call Merge API
    merge = Merge(api_key=os.environ["MERGE_API_KEY"])
    response = merge.crm.link_token.create(           # Replace .crm with your category
        end_user_email_address=email,
        end_user_organization_name=org_name,
        end_user_origin_id=user_id,
        categories=["crm"],                            # Replace with your category
    )
    return jsonify({"link_token": response.link_token})
```

**Node — link_token handler:**
```typescript
app.post("/api/merge/link-token", async (req, res) => {
  const { userId, email, organizationName } = req.body;
  // 1. Create pending record BEFORE calling Merge
  await db.query(
    `INSERT INTO linked_accounts (end_user_origin_id, end_user_email, organization_name, status)
     VALUES ($1, $2, $3, 'pending')
     ON CONFLICT (end_user_origin_id) WHERE status = 'pending' DO NOTHING`,
    [userId, email, organizationName]);
  // 2. Call Merge API
  const merge = new MergeClient({ apiKey: process.env.MERGE_API_KEY });
  const response = await merge.crm.linkToken.create({  // Replace .crm with your category
    endUserEmailAddress: email, endUserOrganizationName: organizationName,
    endUserOriginId: userId, categories: ["crm"],       // Replace with your category
  });
  res.json({ linkToken: response.linkToken });
});
```

## Step 4: Open Merge Link (frontend)

### First run: use the Test integration

For your first build, select the **"Test" integration** inside Merge Link. It accepts any credentials and creates a Linked Account with sample data — no real provider account needed. This lets you verify the full flow before dealing with real provider sandboxes.

To test API calls without going through Merge Link at all, create a **Test Linked Account** from https://app.merge.dev/linked-accounts/test and use its `account_token` directly in Step 6.

> **No frontend?** If you're building a B2B integration with no customer-facing UI, use **Magic Link** — a hosted URL your customer opens to complete auth. See `references/auth-flow.md`.

### React

```tsx
import { useMergeLink } from "@mergeapi/react-merge-link";

function ConnectButton({ linkToken }: { linkToken: string | null }) {
  const { open, isReady } = useMergeLink({
    linkToken: linkToken ?? "",
    onSuccess: async (publicToken) => {
      await fetch("/api/merge/exchange", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ publicToken, endUserOriginId: "your_user_id" }),
      });
    },
    onExit: () => console.log("User closed Merge Link"),
  });
  // isReady = true when SDK loaded + initialized. Gate the button on it.
  return <button onClick={open} disabled={!isReady || !linkToken}>Connect your CRM</button>;
}
```

### Vanilla JS

```html
<script src="https://cdn.merge.dev/initialize.js"></script>
<script>
  function openMergeLink(linkToken) {
    MergeLink.initialize({
      linkToken,
      onReady: () => { MergeLink.openLink(); },   // MUST wait for onReady
      onSuccess: (publicToken) => {
        fetch("/api/merge/exchange", {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ publicToken, endUserOriginId: "your_user_id" }),
        });
      },
      onExit: () => console.log("User closed Merge Link"),
    });
  }
</script>
```

⚠️ **`initialize()` is async.** Always call `openLink()` inside the `onReady` callback. Calling before `onReady` results in an invisible iframe. Callbacks: `onReady`, `onSuccess(publicToken)`, `onExit`, `onValidationError(error)`.

`onSuccess` fires with a **public_token** — a one-time token (~10 min TTL). Send it and the `end_user_origin_id` to your backend immediately.

## Step 5: Exchange public_token for account_token (backend)

### Linked Account states

| Status | Meaning |
|--------|---------|
| `pending` | link_token issued, exchange not yet completed |
| `active` | exchange completed, account_token stored |
| `relink_needed` | end-user revoked access or credentials expired |
| `incomplete` | issue on Merge's side — check Linked Account logs |

### AccountToken response schema

Endpoint: `GET https://api.merge.dev/api/integrations/account-token/{public_token}`

| Field | Type | Notes |
|---|---|---|
| `account_token` | string | Long-lived credential — store in DB (column must be **nullable**) |
| `integration` | SDK model object | `.name` = string. **Not a dict** — use `.name`, not the raw object |
| `id` | string (UUID) | Merge's Linked Account ID. **Store this** — needed for webhook matching |

⚠️ Response does NOT contain `end_user_origin_id`. Pass it from the frontend alongside `public_token`.

**Python — complete exchange handler:**
```python
@app.route("/api/merge/exchange", methods=["POST"])
def exchange_token():
    data = request.json
    public_token = data["public_token"]
    origin_id = data["end_user_origin_id"]

    merge = Merge(api_key=os.environ["MERGE_API_KEY"])
    result = merge.crm.account_token.retrieve(public_token=public_token)

    linked = LinkedAccount.query.filter_by(end_user_origin_id=origin_id, status="pending").first()
    if not linked:
        return jsonify({"error": "No pending record found"}), 404
    linked.account_token = result.account_token
    linked.merge_account_id = result.id               # Store Merge's UUID for webhook matching
    linked.integration_name = result.integration.name if result.integration else None
    linked.status = "active"
    db.session.commit()
    return jsonify({"status": "connected", "integration": linked.integration_name})
```

**Node — complete exchange handler:**
```typescript
app.post("/api/merge/exchange", async (req, res) => {
  const { publicToken, endUserOriginId } = req.body;
  const merge = new MergeClient({ apiKey: process.env.MERGE_API_KEY });
  const result = await merge.crm.accountToken.retrieve(publicToken);
  const integrationName = result.integration?.name ?? null;
  const { rowCount, rows } = await db.query(
    `UPDATE linked_accounts SET account_token=$1, integration_name=$2, merge_account_id=$3,
       status='active', updated_at=NOW()
     WHERE end_user_origin_id=$4 AND status='pending' RETURNING id`,
    [result.accountToken, integrationName, result.id ?? null, endUserOriginId]);
  if (!rowCount) return res.status(404).json({ error: "No pending record" });
  res.json({ status: "connected", integration: integrationName, linkedAccountId: rows[0].id });
});
```

> **SDK objects vs JSON:** `result.integration` is a pydantic model (Python) / typed object (Node), not a plain dict. Use `.name` for the string. Don't pass the raw object to `jsonify()` / `res.json()`.

## Step 6: Make your first API call

Two headers on every call: `Authorization: Bearer YOUR_API_KEY` + `X-Account-Token: ACCOUNT_TOKEN`. SDKs handle this when you pass `account_token` at init.

### Always paginate

Merge returns paginated results. **Without cursor handling you only get page 1.** Real accounts have thousands of records.

**Python — paginated list:**
```python
merge = Merge(api_key="YOUR_TEST_KEY", account_token=account_token)
all_results, cursor = [], None
while True:
    page = merge.crm.contacts.list(cursor=cursor, page_size=100)
    all_results.extend(page.results)
    if page.next is None: break
    cursor = page.next
print(f"Fetched {len(all_results)} contacts")
```

**Node — paginated list:**
```typescript
const merge = new MergeClient({ apiKey: "YOUR_TEST_KEY", accountToken });
const all = [];
let cursor: string | undefined;
do {
  const page = await merge.crm.contacts.list({ cursor, pageSize: 100 });
  all.push(...(page.results ?? []));
  cursor = page.next ?? undefined;
} while (cursor);
console.log(`Fetched ${all.length} contacts`);
```

### Common Model field shapes

Fields are NOT all strings. Some are arrays of nested objects:

| Field | Type | Extract |
|-------|------|---------|
| `emailAddresses` | `[{emailAddress, emailAddressType}]` | `c.emailAddresses?.[0]?.emailAddress` |
| `phoneNumbers` | `[{phoneNumber, phoneNumberType}]` | `c.phoneNumbers?.[0]?.phoneNumber` |
| `account` | Reference object `{id, name}` or string ID | `typeof c.account === "object" ? c.account?.name : null` |
| `modifiedAt` | ISO 8601 timestamp | Key for incremental sync — use with `modified_after` query param |

**Provider-specific fields:** Use Remote Data (enable in Configuration → Common Model Scopes) or the Field Mappings API. See `/merge-unified:merge-post-connection-enable-custom-fields`.

**Incremental sync:** `modifiedAt` + the `modified_after` query param = only fetch changed records. See `/merge-unified:implementing-merge-sync` for the full pattern.

Full schemas: `references/common-models.md`.

## Step 7: Set up webhooks (recommended)

**Default sync cadence:** 24 hours in production (configurable per Linked Account).

Configure at: **https://app.merge.dev/configuration/webhooks**

⚠️ **The "Send test" button sends a connectivity ping, NOT a real event.** You'll see `{"response": "Success! This URL will be notified."}` — your handler will get `event_type=undefined`. This is normal. To test real events, reconnect via Merge Link with the Test integration.

### Signature verification (REQUIRED)

Header: `X-Merge-Webhook-Signature`. Algorithm: **HMAC-SHA256, base64url** (not standard base64).

⚠️ Verify against raw body bytes BEFORE JSON parsing. In Express, mount the webhook route with `express.raw()` BEFORE `express.json()` middleware.

**Python:**
```python
import hmac, hashlib, base64

def verify_merge_webhook(payload_bytes: bytes, signature: str, secret: str) -> bool:
    digest = hmac.new(secret.encode(), payload_bytes, hashlib.sha256).digest()
    expected = base64.urlsafe_b64encode(digest).decode().rstrip("=")
    return hmac.compare_digest(expected, signature.rstrip("="))
```

**Node (Express):**
```typescript
import { raw } from "express";
import crypto from "node:crypto";

// Mount BEFORE express.json() middleware
app.post("/webhook", raw({ type: "application/json" }), (req, res) => {
  const sig = req.header("X-Merge-Webhook-Signature") ?? "";
  const rawBody = req.body as Buffer;
  const expected = crypto.createHmac("sha256", process.env.MERGE_WEBHOOK_SECRET!)
    .update(rawBody).digest("base64url").replace(/=+$/, "");
  if (!crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(sig.replace(/=+$/, "")))) {
    return res.status(401).send("invalid signature");
  }
  const event = JSON.parse(rawBody.toString("utf8"));
  res.sendStatus(200);  // ACK fast — Merge retries on >30s response
  setImmediate(() => processEvent(event));  // Process async; use a real queue in production
});
```

More webhook event types and payload schemas: `references/webhooks.md`.

## Step 8: Production checklist

### Frontend
- [ ] Merge Link embedded, link_tokens from backend (never client-side)
- [ ] Re-connect flow: "Reconnect" button when status = `relink_needed`, using same `end_user_origin_id`

### Backend
- [ ] Webhook listeners with HMAC-SHA256 base64url signature verification
- [ ] Async webhook processing (queue — Merge retries on >30s response)
- [ ] Pagination on all list endpoints (cursor loop)
- [ ] API error handling per status: 401 → relink, 403 → enable scope at https://app.merge.dev/common-models/{category}, 429 → exponential backoff, 5xx → retry then alert
- [ ] Encrypt `account_token` at rest (KMS / pgcrypto)

### Configuration
- [ ] Common Model scopes enabled at https://app.merge.dev/common-models/{category}
- [ ] Tested with a production Linked Account (not just sandbox)

Switch from `test_xxx` to `production_xxx` key and ship.

## Common Model reference (quick)

| Category | Primary Model | Key fields |
|----------|---------------|------------|
| HRIS | `Employee` | first_name, last_name, work_email, employments[], manager |
| ATS | `Candidate` | first_name, last_name, company, title |
| CRM | `Contact` | first_name, last_name, account `{id, name}`, email_addresses `[{emailAddress, emailAddressType}]`, phone_numbers `[{phoneNumber, phoneNumberType}]` |
| Accounting | `Invoice` | type, contact, number, issue_date, due_date |
| Ticketing | `Ticket` | name, status, assignees[], creator, due_date |
| File Storage | `File` | name, file_url, size, mime_type, folder |
| Knowledge Base | `Article` | title, description, author, visibility |
| Marketing | `Campaign` | name, unique_opens, emails_sent |

> `email_addresses` and `phone_numbers` are arrays of objects, not strings. `account` is a reference object with `{id, name}`, not a name string. See `references/common-models.md` for full schemas.

## Troubleshooting

---

**SYMPTOM:** API call returns an empty `results` array.
**CAUSE:** Diagnose in order: (1) Common Model scope not enabled → enable at https://app.merge.dev/common-models/{category}. (2) Initial sync still running → check `GET /sync-status`, look for `is_initial_sync: true` with `status: "SYNCING"` (can take 30 min to hours). (3) Sync failed → check Linked Account detail page.
**FIX:** Most common is #1. Enable the scope and re-check.

---

**SYMPTOM:** `401 Unauthorized` on every API call.
**CAUSE:** Wrong API key, missing header, or key environment mismatch (test key vs production data).
**FIX:** Verify at https://app.merge.dev/keys. Match key environment to data environment.

---

**SYMPTOM:** `400 Bad Request` on `/account-token/{public_token}`.
**CAUSE:** Public token already used (one-time) or expired (~10 min TTL).
**FIX:** Re-trigger Merge Link for a new public_token. Exchange immediately.

---

**SYMPTOM:** `400` with "Organization has already reached their maximum number of test accounts."
**CAUSE:** Test tier cap on simultaneous test Linked Accounts.
**FIX:** Delete unused at https://app.merge.dev/linked-accounts/test.

---

**SYMPTOM:** `link_token` rejected as expired.
**CAUSE:** link_tokens expire after 30 minutes.
**FIX:** Generate fresh on every Merge Link open.

---

**SYMPTOM:** Webhook handler sees `event_type=undefined` or `{"response": "Success!"}`.
**CAUSE:** You clicked "Send test" in dashboard — that's a connectivity ping, not a real event.
**FIX:** Reconnect via Merge Link with the Test integration to trigger real events.

---

**SYMPTOM:** Webhook signature verification fails.
**CAUSE:** Wrong secret, body parsed before check, standard base64 (not base64url), or `=` padding mismatch.
**FIX:** Use webhook secret (not API key). Verify raw bytes BEFORE JSON parse. Use base64url. Strip `=` padding. In Express, mount `express.raw()` BEFORE `express.json()`.

---

**SYMPTOM:** Linked Account shows "relink_needed" or "incomplete".
**CAUSE:** End-user revoked access or credentials expired.
**FIX:** Generate new link_token with same `end_user_origin_id`, re-open Merge Link.

---

**SYMPTOM:** `is_initial_sync: true` and `status: SYNCING` for a long time.
**CAUSE:** Initial sync in progress — normal for large accounts (30 min to hours).
**FIX:** Wait. Check Linked Account detail page for progress.

---

**SYMPTOM:** `last_sync_result: FAILED` but `status: SYNCING`.
**CAUSE:** FAILED is from a previous attempt; current run is still going and may succeed.
**FIX:** Wait for current run to complete.

---

**SYMPTOM:** Field exists on source provider but not on Common Model response.
**CAUSE:** Common Model normalizes across providers. Provider-specific fields go on `remote_data`.
**FIX:** Enable Remote Data in Configuration → Common Model Scopes, or use Field Mappings API.

## When to ask the user vs proceed

**Always ask** at start: which category, which SDK language.

**Pick a sensible default** without asking: test environment first, both SDK and HTTP examples, `end_user_origin_id` = "your_user_id" as placeholder.

**Ask before proceeding** if: multiple categories requested, or production-sensitive concerns (PII, encryption, multi-region).

## Next steps: go deeper

> Your basic integration is set up. Here's what to do next:
>
> - **Validate:** `/merge-unified:merge-validate` — diagnostic checks on API key, account_token, sync status
> - **Full Merge Link** (all 4 endpoints, database schema, production frontend): `/merge-unified:implementing-merge-link`
> - **Automated data syncing** (polling or webhooks, incremental fetches): `/merge-unified:implementing-merge-sync`
> - **Post-connection** (settings page, sync status, relink, custom fields): `/merge-unified:implementing-merge-post-connection`

## Reference docs

- Common Model schemas per category: `references/common-models.md`
- SDK install for all 6 languages: `references/sdk-quickstarts.md`
- Full link_token lifecycle + Magic Link variant: `references/auth-flow.md`
- Webhook event types + signature verification: `references/webhooks.md`

External: [Merge docs](https://docs.merge.dev/merge-unified/link/overview/) · [API status](https://status.merge.dev) · [Sign up](https://app.merge.dev/signup) · [API keys](https://app.merge.dev/keys)
