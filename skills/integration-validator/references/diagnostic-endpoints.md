# Diagnostic Endpoints

Each check in the validator maps to a specific Merge API endpoint. This reference documents the expected request and response for each.

## Check 1: Auth (API Key + Account Token)

**Endpoint:** `GET https://api.merge.dev/api/{category}/v1/account-details`
**Headers:** `Authorization: Bearer {API_KEY}`, `X-Account-Token: {ACCOUNT_TOKEN}`

This single endpoint validates both credentials at once. If it returns 401, the validator retries without the account_token header to isolate which credential is bad.

**Expected 200 response:**
```json
{
  "id": "linked-account-uuid",
  "integration": "Google Drive",
  "integration_slug": "google-drive",
  "status": "COMPLETE",
  "category": "filestorage",
  "end_user_origin_id": "user_123",
  "end_user_email_address": "alice@acme.com"
}
```
**Key fields to check:**
- `status`: should be `COMPLETE`. If `RELINK_NEEDED` → credentials expired. If `INCOMPLETE` → user didn't finish the Link flow.
- `integration`: confirms which provider is connected. This is the provider's display name (`"Google Drive"`); the slug is a separate field, `integration_slug`. There is no `integration_name` on this response — reading it yields `undefined`.

**Failure modes:**
- `401` with both headers → could be either credential. Retry without `X-Account-Token` to isolate.
- `401` without account_token → API key itself is invalid.
- `401` with valid API key but invalid account_token → token is wrong, expired, or for a different key environment.

## Check 3: Sync Status

**Endpoint:** `GET https://api.merge.dev/api/{category}/v1/sync-status`
**Headers:** same as Check 2
**Expected 200 response:**
```json
{
  "results": [
    {
      "model_name": "Employee",
      "model_id": "hris.Employee",
      "status": "DONE",
      "last_sync_start": "2026-04-15T10:00:00Z",
      "next_sync_start": "2026-04-15T11:00:00Z",
      "is_initial_sync": false
    }
  ]
}
```
**Status values** — all six, and only two of them mean "in progress":

| Status | Meaning | Terminal? |
|---|---|---|
| `SYNCING` | Merge is actively syncing this model, or a sync is queued for it | No |
| `DONE` | Merge finished syncing the model successfully | Yes |
| `PARTIALLY_SYNCED` | The sync finished, but one or more fields failed to sync while others succeeded | **Yes** |
| `FAILED` | Merge failed to sync all Common Models within the sync | Yes |
| `DISABLED` | The Common Model is disabled in Common Model Scopes | Yes |
| `PAUSED` | The Linked Account has had no inbound API request or webhook for over 2 weeks, or failed syncs for over 2 weeks | Yes |

⚠️ **`PARTIALLY_SYNCED` is terminal, not "still going."** Waiting on it never resolves. Treat it as "data is queryable but incomplete" and surface it, don't retry-loop on it.

⚠️ **`PAUSED` and `DISABLED` will not progress on their own.** A validator that only branches on `DONE` / `SYNCING` / `FAILED` reports a paused or disabled account as healthy. `PAUSED` clears once traffic resumes; `DISABLED` clears only when someone enables the scope.

Two more fields explain a `SYNCING` model that isn't moving:

- `sync_status_reason` — `RATE_LIMITED` (paused behind the provider's rate limits) or `WAITING_ON_OTHER_MODELS` (on hold until other models finish). Null when progressing normally.
- `data_fresh_as_of` — the start time of the most recent successful sync for the model, so data is current at least through this point. Null until the first sync completes. This is the timestamp to show a user, not `last_sync_start`.

## Check 4: Data Exists

**Endpoint:** `GET https://api.merge.dev/api/{category}/v1/{primary_model}?page_size=1`
**Headers:** same as Check 2

Primary models per category:
| Category | Model endpoint |
|---|---|
| hris | employees |
| ats | candidates |
| crm | contacts |
| accounting | invoices |
| ticketing | tickets |
| filestorage | files |
| knowledgebase | articles |
| mktg | campaigns |

**Expected 200 response:**
```json
{
  "next": "cursor_or_null",
  "previous": null,
  "results": [{ ... }]
}
```
Empty `results` with status 200 means: scopes might be disabled, initial sync might not be complete, or the source provider genuinely has no data for this model.

## Check 5: Pagination

**Endpoint:** Same as Check 4, then `GET ...?page_size=1&cursor={next_cursor}`

If Check 4 returned a `next` cursor, fetch the second page and confirm it returns 200 with a valid response structure. This validates that cursor-based pagination works end-to-end.

## Optional: Webhook Verification

**Endpoint:** Not an API call — the validator generates a test payload and signs it with the developer's webhook secret, then verifies the signature using the same algorithm Merge uses.

Algorithm: `HMAC-SHA256(webhook_secret, raw_body_bytes)` → base64url encode → strip `=` padding.

This confirms the developer's webhook handler will accept real Merge webhook deliveries.
