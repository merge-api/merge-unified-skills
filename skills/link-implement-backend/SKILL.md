---
name: link-implement-backend
description: Implement the four Merge Link backend API endpoints: link token creation, public token exchange, relinking, and deletion. Use as Step 3 of Merge Link implementation.
license: MIT
metadata:
  author: Merge
  version: 0.2.0
---

# Implement Merge Link Backend

Implements the server-side API that powers the Merge Link flow. These endpoints are called by the frontend to initiate connections, exchange tokens, refresh credentials, and delete integrations.

## Prerequisites

- `link-setup-database` complete (`linked_accounts` table exists with `end_user_origin_id`, `account_token`, `integration_slug`, `category`, `status` columns)
- `MERGE_API_KEY` environment variable set

## Before Proceeding

Before writing any code, confirm or gather the following:

- **Categories**: Which Merge categories are being implemented? (`hris`, `ats`, `crm`, `accounting`, `ticketing`, `filestorage`, `knowledgebase`) — used to scope endpoints.
- **Linked Account strategy**: 1 Linked Account per category per org (Strategy 1), or multiple per category (Strategy 2)? — drives `end_user_origin_id` generation in Endpoint 1.
- **SDK vs raw HTTP**: Official Merge SDK (recommended) or raw HTTP calls?

If invoked from `implementing-link`, these were answered in Step 1d — use that context. Otherwise, ask the user now before proceeding.

### SDK Installation

**If using the Merge SDK (recommended):** Merge ships official SDKs for six backend languages — pick the one matching your stack.

| Language | Install | Import |
|---|---|---|
| Python | `pip install MergePythonClient` | `from merge import Merge` |
| Node / TypeScript | `npm install @mergeapi/merge-node-client` | `import { MergeClient } from "@mergeapi/merge-node-client"` |
| Java / Kotlin | Maven `dev.merge:merge-java-client` (Gradle: `implementation "dev.merge:merge-java-client:<version>"`) | `import com.merge.api.MergeApiClient;` |
| Go | `go get github.com/merge-api/merge-go-client/v2` | `import mergeclient "github.com/merge-api/merge-go-client/v2/client"` |
| Ruby | `gem install merge_ruby_client` (or `gem "merge_ruby_client"` in Gemfile) | `require "merge_ruby_client"` |
| C# / .NET | `dotnet add package Merge.Client` | `using Merge.Client;` |

Check if the SDK is already installed before adding it. Do not add a dependency that's already present. For per-language initialize / list / paginate samples, see `../onboarding/references/sdk-quickstarts.md`.

**If using raw HTTP:** use whatever HTTP client your stack already has — `requests` / `httpx` (Python), `axios` / `fetch` (Node), `net/http` (Go), `Net::HTTP` / `Faraday` (Ruby), `HttpClient` (.NET), `OkHttp` (JVM). The endpoint patterns shown below work for any.

## Implementation

> **These are routes on your server, not Merge's API.** The `/api/merge/...` paths below are endpoints you add to your own backend. They wrap Merge API calls with your authentication middleware and business logic. Name them however fits your existing API structure.

Implement all four endpoints with authentication middleware on each. Use the existing DB model and HTTP client pattern already in the codebase.

### Endpoint 1: POST /api/merge/create-link-token

1. Read `category` (validated against `["hris", "ats", "crm", "accounting", "ticketing", "filestorage", "knowledgebase"]`) and optional `integration` from request body. Reject unknown category values.
2. Determine `end_user_origin_id` based on the strategy chosen in Step 1:
   - **Strategy 1 (1 account per category)**: Use a stable per-org identifier — e.g. a GUID column already on your org/tenant table, or the org's primary key formatted as a string. This value must be the same every time the same org connects. Merge uses `end_user_origin_id + category` for uniqueness, so the same stable ID will produce one Linked Account per category per org.
   - **Strategy 2 (multiple accounts per category)**: Check for an existing `pending` record for this org+category first. If one exists (incomplete prior attempt), reuse its `end_user_origin_id`. If none exists, generate a new GUID. Do NOT generate a new GUID on every click — that creates duplicate Linked Accounts on every open-and-abandon. Full deduplication logic: see `../implementing-link/references/backend-implementation.md` under "Handling Incomplete Linking Attempts."
3. **Create the `linked_accounts` record NOW** with `status = "pending"` — do this BEFORE calling the Merge API (prevents duplicate accounts if the modal is opened multiple times)
4. If a pending record already exists for this `end_user_origin_id`, reuse it. **Dedup pattern:** `INSERT ... ON CONFLICT (end_user_origin_id) WHERE status = 'pending' DO NOTHING`, or delete the prior pending row before inserting.
5. Call `POST https://api.merge.dev/api/{category}/v1/link-token` with `Authorization: Bearer {MERGE_API_KEY}`, passing `end_user_origin_id`, `end_user_email_address`, `end_user_organization_name`, `categories`, and optional `integration`
6. Return `{ link_token }` to the frontend

### Endpoint 2: POST /api/merge/exchange-public-token

1. Receive `public_token` and `end_user_origin_id` from frontend (the frontend must send the origin ID alongside the public token — the exchange response does NOT contain it)
2. Call `POST https://api.merge.dev/api/{category}/v1/account-token/{public_token}` with `Authorization: Bearer {MERGE_API_KEY}` to get `account_token`
3. Call `GET https://api.merge.dev/api/{category}/v1/account-details` with both `Authorization: Bearer {MERGE_API_KEY}` and `X-Account-Token: {account_token}` headers
4. Extract `end_user_origin_id`, `integration`, and `integration_slug` from the account details response (top level, not nested — see gotchas)
5. Look up the `linked_accounts` record by `end_user_origin_id`
6. Update: `account_token`, `integration_slug`, `status = "active"`
7. Return success

**Account-token response** (from step 2):

| Field | Type | Notes |
|---|---|---|
| `account_token` | string | The long-lived credential |
| `integration` | SDK model object | Has `.name` (string). **Not a dict** — use `.name` for the string |
| `id` | string (UUID) | Merge's ID for this Linked Account |

⚠️ This response does NOT include `end_user_origin_id`. Pass it from the frontend or use the `end_user_origin_id` from the account-details call below.

**Account-details response** (from step 3):

| Field | Type | Notes |
|---|---|---|
| `end_user_origin_id` | string | The ID you sent in step 1 — use to look up the pending record |
| `integration` | string | Provider name (this IS a plain string, unlike the account-token response) |
| `integration_slug` | string | Provider slug |
| `status` | string | Connection status |
| `id` | string (UUID) | Merge's Linked Account ID |

> **SDK type warning:** When using the Merge SDK, `account_token_response.integration` is an SDK model object (use `.name`), but `account_details.integration` is a plain string. They are different types despite the same field name.

### Endpoint 3: POST /api/merge/relink-integration

1. Receive `linked_account_id`
2. Fetch the existing `linked_accounts` record — verify it belongs to the current user
3. Call the same link token generation logic using the **stored `end_user_origin_id`** — do NOT generate a new ID or create a new DB record
4. Return `{ link_token }` to the frontend

**The reconnect data flow that almost everyone gets wrong on the first try:**

```typescript
// Server-side: pull the broken row's exact end_user_origin_id and reuse it.
app.post("/api/merge/relink-integration", async (req, res) => {
  const { linkedAccountId } = req.body;
  const { rows } = await db.query(
    `SELECT end_user_origin_id, end_user_email, organization_name, category
       FROM linked_accounts WHERE id = $1`,
    [linkedAccountId],
  );
  const broken = rows[0];
  // Reuse the stored origin_id verbatim — do NOT compute a new one.
  const merge = new MergeClient({ apiKey: process.env.MERGE_API_KEY });
  const response = await merge[broken.category].linkToken.create({
    endUserOriginId: broken.end_user_origin_id,    // KEY POINT — same value
    endUserEmailAddress: broken.end_user_email,
    endUserOrganizationName: broken.organization_name,
    categories: [broken.category],
  });
  // Flip the row back to pending so /exchange updates it (instead of inserting a new row).
  await db.query(
    `UPDATE linked_accounts SET status='pending', updated_at=NOW() WHERE id=$1`,
    [linkedAccountId],
  );
  res.json({ link_token: response.linkToken });
});
```

⚠️ Wiring the Reconnect button to your regular `create-link-token` endpoint will *silently* create a duplicate Linked Account every time a user clicks Reconnect — your app keeps working, but you accumulate orphans. The Reconnect path must call this dedicated endpoint with the broken row's id, and this endpoint must reuse the stored `end_user_origin_id` exactly.

### Endpoint 4: POST /api/merge/delete-integration

1. Receive `linked_account_id`
2. Fetch the `linked_accounts` record — verify it belongs to the current user
3. Call `POST https://api.merge.dev/api/{category}/v1/delete-account` with `Authorization: Bearer {MERGE_API_KEY}` and `X-Account-Token: {account_token}` headers (Merge uses POST, not DELETE, for this operation)
4. Delete the local `linked_accounts` record from the DB
5. Return success

## Critical Gotchas

**`end_user_origin_id` must be stored before calling Merge API.** If the DB write happens after the Merge API call, repeated modal opens can create duplicate Merge accounts with no local record to match against.

**Account details response is flat.** `integration` and `integration_slug` are top-level fields (not nested). When using the SDK:

```text
# Account-details: integration IS a plain string
integration_name = account_details.integration        # provider name string
integration_slug = account_details.integration_slug   # provider slug string

# WRONG — on account-details, "integration" is a string, not an object
integration_name = account_details["integration"]["name"]   # TypeError

# Account-token: integration is an SDK MODEL OBJECT (different!)
integration_name = account_token_response.integration.name  # provider name string
# account_token_response.integration is NOT a string — don't pass it directly to JSON
```

**Relinking reuses the existing record.** Pass the stored `end_user_origin_id` to Merge — do not generate a new one or insert a new row.

**Relink UX:** Show a "Reconnect" button on the frontend when `status = "relink_needed"`. On click, call your `/api/merge/relink-integration` endpoint to get a fresh `link_token`, then re-open Merge Link with it. The user re-authenticates and the existing Linked Account is updated — no new record created. Example:

```javascript
// Frontend: show reconnect when status is relink_needed
if (account.status === "relink_needed") {
  showButton("Reconnect " + account.integrationName, async () => {
    const { link_token } = await fetch("/api/merge/relink-integration", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ linked_account_id: account.id }),
    }).then(r => r.json());
    openMergeLink(link_token);  // Same openMergeLink from Step 4
  });
}
```

**Delete uses POST, not HTTP DELETE.** Merge's delete-account endpoint is `POST /delete-account`, not `DELETE /linked-accounts/{id}`.

## Error Handling and Rate Limits

Wrap every Merge API call in error handling. Merge returns standard HTTP status codes:

| Status | Meaning | Action |
|--------|---------|--------|
| `200` | Success | Process the response |
| `401` | API key or account_token invalid | Surface to user: "Check your API key" or trigger relink flow |
| `429` | Rate limited | Retry with exponential backoff (1s, 2s, 4s), max 3 retries |
| `500` | Merge server error | Retry once after 2s, then fail gracefully with a user-facing message |

**Rate limit retry pattern:**

```python
import time

def merge_api_call(method, url, headers, **kwargs):
    for attempt in range(3):
        resp = getattr(requests, method)(url, headers=headers, **kwargs)
        if resp.status_code == 429:
            retry_after = int(resp.headers.get("Retry-After", 2 ** attempt))
            time.sleep(retry_after)
            continue
        return resp
    return resp  # Return last response even if still 429
```

**Idempotence on failure:** If `create-link-token` fails after the DB record is created, the record stays as `status = "pending"`. The next attempt finds the existing pending record and reuses it — no duplicate is created. This is by design.

## Testing Checklist

- [ ] Create link token returns a valid token
- [ ] `linked_accounts` record created BEFORE Merge API call in endpoint 1
- [ ] Exchange public token stores `account_token` in DB
- [ ] `integration_slug` and `category` populated correctly after exchange
- [ ] Relink returns fresh token without creating a new DB record
- [ ] Delete removes from both Merge and local DB
- [ ] All four endpoints require authentication
- [ ] API calls retry on 429 with exponential backoff
- [ ] 401 errors surface an actionable message (not a generic 500)
