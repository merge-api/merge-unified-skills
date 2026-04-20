# Auth Flow Reference

The full lifecycle of every token Merge uses, from the first link to long-lived data access.

## Three tokens, three lifetimes

```
┌─────────────────────────────────────────────────────────────────────┐
│  API key                                                            │
│  ─ Created in dashboard, identifies your organization               │
│  ─ Long-lived, rotate manually                                      │
│  ─ Backend ONLY. Never expose in the browser.                       │
│  ─ Two environments: test_xxx and production_xxx                    │
└─────────────────────────────────────────────────────────────────────┘
            │
            │ used to generate
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  link_token                                                         │
│  ─ Authorizes one Merge Link session for one end-user               │
│  ─ Expires in 30 minutes (default and max)                          │
│  ─ Backend-generated, passed to frontend                            │
│  ─ Single session use (don't cache or reuse)                        │
└─────────────────────────────────────────────────────────────────────┘
            │
            │ used by Merge Link in browser
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  public_token                                                       │
│  ─ Returned in Merge Link's onSuccess callback                      │
│  ─ Single use, ~10 min TTL                                          │
│  ─ Send to backend immediately, exchange before it expires          │
└─────────────────────────────────────────────────────────────────────┘
            │
            │ exchanged via GET /account-token/{public_token}
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  account_token                                                      │
│  ─ The long-lived credential for one Linked Account                 │
│  ─ Authenticates all Unified API calls for that customer's data     │
│  ─ Store in your DB, keyed by your customer ID                      │
│  ─ Never expose to the browser                                      │
│  ─ Use lifetime: until end-user revokes or relinks                  │
└─────────────────────────────────────────────────────────────────────┘
```

## API key

Get from: **https://app.merge.dev/keys**

Two key types:
- **`production_xxx`**: hits real customer data
- **`test_xxx`**: hits sandbox / test Linked Accounts only

Always start with the test key. Switch to production only when shipping. Never put either in client-side code.

Storage:
- Local dev: `.env` file (gitignored)
- Production: secrets manager (Doppler, AWS Secrets Manager, Vault, etc.)

## link_token — `EndUserDetailsRequest` schema

`POST https://api.merge.dev/api/integrations/create-link-token`

Required fields:

| Field | Type | Notes |
|-------|------|-------|
| `end_user_email_address` | string | Your customer's email |
| `end_user_organization_name` | string | Your customer's company name |
| `end_user_origin_id` | string | YOUR unique ID for this customer. Use your DB user ID. |
| `categories` | array<string> | One or more of: `hris`, `ats`, `accounting`, `ticketing`, `crm`, `mktg`, `filestorage`, `knowledgebase` |

Optional fields:

| Field | Type | Notes |
|-------|------|-------|
| `integration` | string | Pre-select a single provider, skip the integration picker. Use the integration's slug (e.g., `"google-drive"`). |
| `link_expiry_mins` | integer | Default 30. Max 30. |
| `should_create_magic_link_url` | boolean | If true, returns a `magic_link_url` that emails the user a Merge Link page (no embed needed). |
| `common_models` | array | Pre-restrict which Common Models this Linked Account can access. |
| `language` | string | UI language for Merge Link, e.g. `"en"`, `"de"`, `"fr"`. |
| `are_syncs_disabled` | boolean | Pause syncs on creation. |

Response:

```json
{
  "link_token": "ZGVtb190b2tlbjpkZW1vIGFwaSBrZXkgZGVtbw==",
  "integration_name": null,
  "magic_link_url": null
}
```

`integration_name` is set when the link_token is for an existing Linked Account being relinked. `magic_link_url` is set when `should_create_magic_link_url=true`.

## Magic Link — alternative to embedded Link

If you don't want to embed the Merge Link UI, generate a `magic_link_url` and email it to your customer. They click, complete the flow on Merge's hosted page, and Merge calls your webhook with the result.

```python
response = merge.filestorage.link_token.create(
    end_user_email_address="alice@acme.com",
    end_user_organization_name="Acme Corp",
    end_user_origin_id="user_123",
    categories=["filestorage"],
    should_create_magic_link_url=True,
)
# Email response.magic_link_url to alice@acme.com
```

When the customer completes Magic Link, set up a webhook listener for the `linked_account.created` event to be notified.

## public_token → account_token exchange

`GET https://api.merge.dev/api/integrations/account-token/{public_token}`

Headers: `Authorization: Bearer YOUR_API_KEY`

Response:
```json
{
  "account_token": "AT_xxxxxxxxxxxxxxxxxx",
  "integration": {
    "name": "Google Drive",
    "categories": ["filestorage"],
    "image": "https://...",
    "square_image": "https://...",
    "color": "#4285F4",
    "slug": "google-drive"
  },
  "id": "uuid-of-linked-account"
}
```

The `id` is the Linked Account's UUID. Store it alongside the `account_token`. Useful for webhook payloads (which reference Linked Accounts by ID, not account_token).

## Re-linking (when an account breaks)

End-users sometimes revoke access in the source provider. The Linked Account moves to `relink_needed` status. Your app should detect this (via webhook or status check) and prompt the user to reconnect.

To re-link:

1. Generate a new link_token with the **same** `end_user_origin_id` and `end_user_email_address`.
2. Open Merge Link with this new token.
3. The user re-authorizes.
4. The existing Linked Account is updated. **Same `account_token`** — do not exchange a new one.

```python
# Same call, same end_user_origin_id
response = merge.filestorage.link_token.create(
    end_user_email_address="alice@acme.com",
    end_user_organization_name="Acme Corp",
    end_user_origin_id="user_123",  # ← matches the original
    categories=["filestorage"],
)
```

The `integration_name` field in the response will be set, signaling this is a relink.

## Linked Account status

Status field on the Linked Account. Check via API or webhook payloads.

| Status | Meaning | Action |
|--------|---------|--------|
| `COMPLETE` | Healthy, syncing | None |
| `INCOMPLETE` | Linking flow not finished | Prompt user to complete Merge Link |
| `RELINK_NEEDED` | Credentials expired or revoked | Trigger re-link flow |
| `IDLE` | Active but no recent sync | Investigate, may be normal |

## Rate limits

Per Linked Account (not per API key):

- Default: ~120 requests/min
- Bursts above this return `429 Too Many Requests` with a `Retry-After` header
- Use the SDK's built-in retry logic, or implement exponential backoff manually

```python
# SDK retry config
merge = Merge(
    api_key="YOUR_TEST_KEY",
    account_token=account_token,
    timeout=30.0,
    max_retries=3,
)
```

## Multi-region

Merge has US and EU API endpoints. The base URL changes:
- US: `https://api.merge.dev/api/...`
- EU: `https://api-eu.merge.dev/api/...`

Use the EU endpoint if you signed up on the EU dashboard. The SDKs auto-detect from the API key, but you can override:

```python
merge = Merge(api_key="...", base_url="https://api-eu.merge.dev")
```
