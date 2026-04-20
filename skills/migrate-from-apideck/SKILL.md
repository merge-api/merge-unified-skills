---
name: migrate-from-apideck
description: |
  Migrate a project from Apideck to Merge. Use when a developer says
  "migrate from Apideck", "switch from Apideck to Merge", "replace Apideck",
  "move from Apideck", "convert Apideck to Merge", "Apideck alternative",
  "Apideck to Merge migration", or has Apideck imports/config in their project
  and asks about Merge. Detects Apideck SDK usage, maps concepts to Merge
  equivalents, rewrites API calls, and highlights behavioral differences.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Apideck → Merge Migration

Migrate a project from the Apideck Unified API to the Merge Unified API. Detects existing Apideck usage, maps concepts, rewrites code, and flags behavioral differences.

## When to use this skill

Activate when:
- Developer explicitly asks to migrate or switch from Apideck to Merge
- Developer has Apideck imports (`apideck-unify`, `@apideck/unify`, `apideck`) in their project
- Developer asks "how does Merge compare to Apideck" and wants to switch
- Developer mentions Apideck and Merge in the same request

Do NOT activate for:
- General Apideck questions unrelated to Merge
- Migrations from other providers (Finch, Codat, Nango, etc.) — this skill is Apideck-specific
- Initial Merge setup with no existing Apideck code (route to `merge-onboarding`)

## First activation: self-introduce

> I'm the Apideck → Merge Migration skill (v0.1.0). I'll scan your project for Apideck usage, map everything to Merge equivalents, and generate the replacement code. Tell me which directory to scan, or point me at the relevant files.

## Step 0: Detect Apideck usage

Scan the project for:

**Python:**
- `import apideck` or `from apideck` or `from apideck_unify` or `import apideck_unify`
- `pip install apideck` or `pip install apideck-unify` in requirements/pyproject
- `APIDECK_API_KEY`, `APIDECK_APP_ID`, `APIDECK_CONSUMER_ID` in env files

**Node / TypeScript:**
- `@apideck/unify` or `@apideck/node` (legacy) in package.json
- `import { Apideck }` or `require('@apideck/unify')`
- `APIDECK_API_KEY`, `APIDECK_APP_ID` in env files

**HTTP / curl:**
- Calls to `unify.apideck.com`
- Headers: `x-apideck-app-id`, `x-apideck-consumer-id`, `x-apideck-service-id`

Report: "Found Apideck usage in N files. Here's what needs to change:"

## Step 1: Explain the concept mapping

Present the mapping table from `references/concept-mapping.md`. Walk through each row and explain what changes and what stays the same.

Key points to emphasize:
- **Authentication simplifies**: Apideck requires 4 credentials (API key, App ID, Consumer ID, Service ID). Merge requires 2 (API key, Account Token).
- **Connection management changes**: Apideck Vault → Merge Link. Different UX but same purpose.
- **Endpoint structure changes**: `unify.apideck.com/{category}/...` → `api.merge.dev/api/{category}/v1/...`
- **Data models are similar but not identical**: Both normalize provider data into common schemas, but field names differ.

## Step 2: Rewrite the code

For each file with Apideck usage, generate the Merge equivalent. Follow this pattern:

### Python migration

**Before (Apideck):**
```python
from apideck_unify import Apideck
import os

apideck = Apideck(
    api_key=os.getenv("APIDECK_API_KEY"),
    consumer_id="user_123",
    app_id=os.getenv("APIDECK_APP_ID"),
)

# List employees
with apideck:
    res = apideck.hris.employees.list(service_id="workday")
    for emp in res.data:
        print(emp.first_name, emp.last_name)
```

**After (Merge):**
```python
from merge import Merge
import os

merge = Merge(
    api_key=os.getenv("MERGE_API_KEY"),
    account_token=os.getenv("MERGE_ACCOUNT_TOKEN"),
)

# List employees
page = merge.hris.employees.list()
for emp in page.results:
    print(emp.first_name, emp.last_name)
```

**What changed:**
- `apideck_unify.Apideck` → `merge.Merge`
- 3 auth params (api_key, consumer_id, app_id) → 2 (api_key, account_token)
- No `service_id` per call — the account_token is already scoped to one provider
- `res.data` → `page.results`
- No context manager needed

### Node / TypeScript migration

**Before (Apideck):**
```typescript
import { Apideck } from "@apideck/unify";

const apideck = new Apideck({
  apiKey: process.env.APIDECK_API_KEY!,
  consumerId: "user_123",
  appId: process.env.APIDECK_APP_ID!,
});

const { data } = await apideck.crm.contacts.list({
  serviceId: "salesforce",
  limit: 20,
});
```

**After (Merge):**
```typescript
import { MergeClient } from "@mergeapi/merge-node-client";

const merge = new MergeClient({
  apiKey: process.env.MERGE_API_KEY!,
  accountToken: process.env.MERGE_ACCOUNT_TOKEN!,
});

const page = await merge.crm.contacts.list({ pageSize: 20 });
```

**What changed:**
- `@apideck/unify` → `@mergeapi/merge-node-client`
- `Apideck` → `MergeClient`
- `consumerId` + `appId` → `accountToken`
- No `serviceId` per call
- `limit` → `pageSize`
- Response shape: `{ data }` → `page` with `.results` and `.next`

## Step 3: Migrate environment variables

Generate a mapping for the `.env` file:

```bash
# Apideck (remove these)
APIDECK_API_KEY=...
APIDECK_APP_ID=...

# Merge (add these)
MERGE_API_KEY=...            # Get from https://app.merge.dev/keys
MERGE_ACCOUNT_TOKEN=...      # From the Merge Link token exchange flow
```

Note: Apideck's `consumer_id` and `service_id` don't map to env vars in Merge — they're embedded in the `account_token` concept (one token = one customer's connection to one provider).

## Step 4: Migrate connection management (Vault → Merge Link)

If the project embeds Apideck Vault for user-facing OAuth:

**Apideck Vault flow:**
1. Server creates a Vault session → gets a session URL
2. Frontend opens Vault URL (hosted or embedded)
3. User authorizes → connection is created
4. Server uses `consumer_id` + `service_id` on API calls

**Merge Link flow:**
1. Server generates a `link_token` → passes to frontend
2. Frontend opens Merge Link (React component, JS SDK, or vanilla)
3. User authorizes → `onSuccess` fires with a `public_token`
4. Server exchanges `public_token` for `account_token`
5. Server uses `account_token` on API calls

Key difference: Merge requires a token exchange step. Apideck's Vault creates the connection implicitly.

For the full Merge Link implementation, run `/merge-unified:merge-onboarding` (Steps 3–5).

## Step 5: Behavioral differences to watch

Present these to the developer after code migration:

| Behavior | Apideck | Merge |
|---|---|---|
| **Auth per request** | 4 headers (api_key, app_id, consumer_id, service_id) | 2 headers (Authorization, X-Account-Token) |
| **Provider selection** | `service_id` per API call — can switch providers dynamically | Baked into `account_token` — one token = one provider connection |
| **Pagination** | Cursor-based, `cursor` param | Cursor-based, `cursor` param (similar) |
| **Page size param** | `limit` (default 20) | `page_size` (default 30, max 100) |
| **Response shape** | `{ data: [...], meta: { cursors: { next } } }` | `{ results: [...], next: "cursor_string" }` |
| **Webhook format** | Apideck webhook payload structure | Merge webhook payload with `X-Merge-Webhook-Signature` (HMAC-SHA256) |
| **Rate limits** | Per app, varies by plan | Per Linked Account (~120 req/min) |
| **Common Model fields** | Apideck-specific field names | Merge-specific field names (similar but not identical) |

## Step 6: Verify the migration

After rewriting, suggest the developer run `/merge-unified:merge-validate` to confirm the Merge integration is healthy.

## Troubleshooting

**SYMPTOM:** Field names don't match after migration.
**CAUSE:** Apideck and Merge normalize provider data differently. Field names are similar but not identical (e.g., Apideck `email` vs Merge `work_email`).
**FIX:** Compare the Common Model schema for your category in `references/concept-mapping.md` and map fields explicitly.

---

**SYMPTOM:** Getting `401` after switching to Merge credentials.
**CAUSE:** Using Apideck API key instead of Merge API key, or missing the `X-Account-Token` header.
**FIX:** Verify both `MERGE_API_KEY` and `MERGE_ACCOUNT_TOKEN` are set. Merge requires both on every API call.

---

**SYMPTOM:** Pagination breaks after migration.
**CAUSE:** Response structure changed. Apideck uses `meta.cursors.next`, Merge uses `next` at the top level.
**FIX:** Update pagination code to read `response.next` (or `page.next` in SDKs) instead of `response.meta.cursors.next`.

## Reference docs

- Full concept mapping table: `references/concept-mapping.md`
- Apideck SDK patterns (for detection): `references/apideck-patterns.md`
