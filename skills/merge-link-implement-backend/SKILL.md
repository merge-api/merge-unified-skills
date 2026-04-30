---
name: merge-link-implement-backend
description: Implement the four Merge Link backend API endpoints: link token creation, public token exchange, relinking, and deletion. Use as Step 3 of Merge Link implementation.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implement Merge Link Backend

Implements the server-side API that powers the Merge Link flow. These endpoints are called by the frontend to initiate connections, exchange tokens, refresh credentials, and delete integrations.

## Prerequisites

- `merge-link-setup-database` complete (`linked_accounts` table exists with `end_user_origin_id`, `account_token`, `integration_slug`, `category`, `status` columns)
- `MERGE_API_KEY` environment variable set
- HTTP client installed (e.g., `requests` for Python, `axios` for Node)

## Implementation

> **These are routes on your server, not Merge's API.** The `/api/merge/...` paths below are endpoints you add to your own backend. They wrap Merge API calls with your authentication middleware and business logic. Name them however fits your existing API structure.

Implement all four endpoints with authentication middleware on each. Use the existing DB model and HTTP client pattern already in the codebase.

### Endpoint 1: POST /api/merge/create-link-token

1. Read `category` and optional `integration` from request body
2. Generate `end_user_origin_id` — use a deterministic format like `{org_id}_{category}` (one per category) or `{org_id}_{category}_{integration_slug}` (multiple per category)
3. **Create the `linked_accounts` record NOW** with `status = "pending"` — do this BEFORE calling the Merge API (prevents duplicate accounts if the modal is opened multiple times)
4. If a pending record already exists for this `end_user_origin_id`, reset it instead of creating a duplicate
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
