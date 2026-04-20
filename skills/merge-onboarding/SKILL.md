---
name: merge-onboarding
description: Step-by-step onboarding for the Merge Unified API. Use when a developer says "set up Merge", "integrate Merge", "Merge Unified API", "create a Linked Account", "Merge Link", "generate a link token", "exchange account token", "integrate Google Drive", "integrate Notion", "integrate Workday", "pull HRIS data", "sync employee data", "sync candidate data", "sync CRM contacts", "sync invoices", "sync tickets", "sync files", or asks how to connect to HRIS, ATS, CRM, Accounting, Ticketing, File Storage, Knowledge Base, or Marketing systems via a single unified API. Covers signup → first API call → Merge Link integration → webhooks → production checklist. Embeds real Common Model schemas, SDK install snippets, the link_token → account_token auth flow, and webhook verification code.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
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

> I'm the Merge Integration Assistant (v0.1.0). I'll help you get from signup to a working production Linked Account. Tell me which Merge category and SDK language you want to use, and where you are in the journey.

This confirms install worked and surfaces the version so the developer knows if they're on a stale copy.

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

**Common Model** (term defined): a normalized data shape across providers. Whether the developer connects to Workday or BambooHR, they query the same `Employee` shape with the same fields.

**Linked Account** (term defined): one end-customer's connection to one provider. Each Linked Account has an `account_token` that authenticates API calls for that customer's data.

## Step 0: Confirm context

Ask the developer (one at a time, **skip questions whose answers are obvious from their first message**):

1. **Which Merge category?** HRIS, ATS, CRM, Accounting, Ticketing, File Storage, Knowledge Base, or Marketing.
2. **Which SDK language?** Python, Node.js (TypeScript), Java/Kotlin, Go, Ruby, or C#/.NET. (Or vanilla HTTP if they prefer.)
3. **Where are you in the journey?**
   - Just signed up, no API key yet
   - Have API key, no Linked Account yet
   - Have a test Linked Account, want to go to production
   - Production live, debugging an issue

If they say "I want to integrate Google Drive into my app" → infer File Storage category, ask only for SDK language.

## Step 1: Get your API key

Direct them to: **https://app.merge.dev/keys**

Two key types:
- **Production key** (`production_xxx`): for real customer data
- **Test key** (`test_xxx`): for sandbox/test Linked Accounts

For initial development, use the test key. Switch to production when shipping.

Tell them: "Copy your test key. We'll need it in the next step. Do NOT commit it to git — store it in `.env` or your secrets manager."

## Step 2: Install the SDK

Pick the language. Detailed code in `references/sdk-quickstarts.md`.

**Python:**
```bash
pip install MergePythonClient
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
- `end_user_origin_id` — your unique ID for this customer (we recommend their user ID in your system)
- `categories` — array of categories this Linked Account can access, e.g. `["filestorage"]`

Optional:
- `integration` — pre-select a single provider (skip the integration picker)
- `link_expiry_mins` — default 30, max 30

**Python example:**
```python
from merge import Merge

merge = Merge(api_key="YOUR_TEST_KEY")

response = merge.filestorage.link_token.create(
    end_user_email_address="alice@acme.com",
    end_user_organization_name="Acme Corp",
    end_user_origin_id="user_123",
    categories=["filestorage"],
)
print(response.link_token)
```

**Node example:**
```typescript
import { MergeClient } from "@mergeapi/merge-node-client";

const merge = new MergeClient({ apiKey: "YOUR_TEST_KEY" });

const response = await merge.filestorage.linkToken.create({
  endUserEmailAddress: "alice@acme.com",
  endUserOrganizationName: "Acme Corp",
  endUserOriginId: "user_123",
  categories: ["filestorage"],
});
console.log(response.linkToken);
```

**No backend yet?** (frontend-first prototype)

For testing only, you can call the endpoint directly with curl and paste the link_token into your frontend:

```bash
curl -X POST https://api.merge.dev/api/integrations/create-link-token \
  -H "Authorization: Bearer YOUR_TEST_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "end_user_email_address": "alice@acme.com",
    "end_user_organization_name": "Acme Corp",
    "end_user_origin_id": "user_123",
    "categories": ["filestorage"]
  }'
```

⚠️ **NEVER do this in production.** API keys exposed in the browser leak all your customer data. Move to a real backend before launching.

## Step 4: Open Merge Link (frontend) — the magical moment

This is where the developer sees the magic: paste the snippet, see Merge Link open with the provider picker.

**React:**
```tsx
import { useMergeLink } from "@mergeapi/react-merge-link";

function ConnectButton({ linkToken }: { linkToken: string }) {
  const { open, isReady } = useMergeLink({
    linkToken,
    onSuccess: async (publicToken) => {
      // Send publicToken to your backend to exchange for an account_token
      await fetch("/api/merge/exchange", {
        method: "POST",
        body: JSON.stringify({ publicToken }),
      });
    },
    onExit: () => console.log("User closed Merge Link"),
  });

  return (
    <button onClick={open} disabled={!isReady}>
      Connect your account
    </button>
  );
}
```

**Vanilla JS:**
```html
<script src="https://cdn.merge.dev/initialize.js"></script>
<script>
  const link = MergeLink.initialize({
    linkToken: "YOUR_LINK_TOKEN",
    onSuccess: (publicToken) => {
      fetch("/api/merge/exchange", {
        method: "POST",
        body: JSON.stringify({ publicToken }),
      });
    },
  });
  link.openLink();
</script>
```

When the user finishes the flow, `onSuccess` fires with a **public_token**. This is a one-time token. Send it to your backend immediately to exchange for the long-lived `account_token`.

## Step 5: Exchange public_token for account_token (backend)

The `account_token` is the long-lived credential that authenticates all future API calls for this Linked Account. **Store it securely in your database, keyed by your customer ID.** Never expose it to the browser.

Endpoint: `GET https://api.merge.dev/api/integrations/account-token/{public_token}`

**Python:**
```python
account_response = merge.filestorage.account_token.retrieve(public_token=public_token)
account_token = account_response.account_token
# Save to your DB: customer.merge_account_token = account_token
```

**Node:**
```typescript
const accountResponse = await merge.filestorage.accountToken.retrieve(publicToken);
const accountToken = accountResponse.accountToken;
// Save to your DB: customer.mergeAccountToken = accountToken
```

The two-step token flow:
```
link_token (30 min, server-generated)
  ↓ used by Merge Link in frontend
public_token (one-time, from onSuccess)
  ↓ exchanged server-side
account_token (long-lived, store in DB)
```

## Step 6: Make your first API call

Two headers required on every Unified API call:
- `Authorization: Bearer YOUR_API_KEY`
- `X-Account-Token: ACCOUNT_TOKEN_FROM_STEP_5`

The SDKs handle this when you pass the account_token at client init.

**Python (File Storage example):**
```python
merge = Merge(api_key="YOUR_TEST_KEY", account_token=account_token)

files = merge.filestorage.files.list()
for file in files.results:
    print(file.name, file.mime_type, file.size)
```

**Node (HRIS example):**
```typescript
const merge = new MergeClient({
  apiKey: "YOUR_TEST_KEY",
  accountToken: accountToken,
});

const employees = await merge.hris.employees.list();
employees.results.forEach((emp) => {
  console.log(emp.firstName, emp.lastName, emp.workEmail);
});
```

If the response array is empty, see Troubleshooting below.

For the primary Common Model and key fields per category, see `references/common-models.md`.

## Step 7: Set up webhooks (recommended)

Polling for new data is fine for sandbox testing. For production, set up webhooks so Merge pushes updates to your app within seconds.

Two webhook types:
1. **Merge → You**: Merge tells your app when sync completes, when a Linked Account changes, etc.
2. **Third-party → Merge**: Real-time updates from the source provider, then forwarded to you.

Configure in dashboard: **https://app.merge.dev/configuration/webhooks**

Verify the signature on every incoming webhook. Header: `X-Merge-Webhook-Signature`. Algorithm: HMAC-SHA256, base64url encoded.

**Python verification:**
```python
import hmac, hashlib, base64

def verify_merge_webhook(payload_bytes: bytes, signature: str, secret: str) -> bool:
    digest = hmac.new(secret.encode(), payload_bytes, hashlib.sha256).digest()
    expected = base64.urlsafe_b64encode(digest).decode().rstrip("=")
    return hmac.compare_digest(expected, signature.rstrip("="))
```

Detailed webhook setup, event types, and Node example: `references/webhooks.md`.

## Step 8: Production checklist

Before going live, verify these 8 items (mirrors the in-app checklist):

1. **[Frontend]** Embed Merge Link in your app
2. **[Frontend]** Generate link_tokens from your backend
3. **[Backend]** Set up webhook listeners for sync events
4. **[Backend]** Map Common Model fields to your database
5. **[Configuration]** Configure Common Model scopes for production at `/configuration/common-model-scopes`
6. **[Testing]** Test with a production Linked Account (not just sandbox)
7. **[Backend]** Handle API errors and rate limits (see `references/auth-flow.md`)
8. **[Frontend]** Design the re-connect flow for broken connections (Linked Accounts can disconnect when end-users revoke access)

When all 8 are done, switch your API key from `test_xxx` to `production_xxx` and ship.

## Common Model reference (quick)

| Category | Primary Model | Key fields you'll likely use |
|----------|---------------|------------------------------|
| HRIS | `Employee` | first_name, last_name, work_email, employments[], manager, team |
| ATS | `Candidate` | first_name, last_name, company, title, last_interaction_at |
| CRM | `Contact` | first_name, last_name, account, email_addresses[], phone_numbers[] |
| Accounting | `Invoice` | type, contact, number, issue_date, due_date, paid_on_date |
| Ticketing | `Ticket` | name, status, assignees[], assigned_teams[], creator, due_date |
| File Storage | `File` | name, file_url, size, mime_type, folder, checksum |
| Knowledge Base | `Article` | title, description, author, visibility, article_url |
| Marketing | `Campaign` | name, unique_opens, emails_sent |

Full schemas with all fields: `references/common-models.md`.

## Troubleshooting

Format: **SYMPTOM** / **CAUSE** / **FIX**.

---

**SYMPTOM:** API call returns an empty `results` array.
**CAUSE:** The Common Model scope is not enabled for this Linked Account, OR the initial sync hasn't completed yet.
**FIX:** Check `/configuration/common-model-scopes` and enable the model. If scopes are enabled, wait for initial sync (can take a few minutes for large accounts), or check the Linked Account detail page for sync status.

---

**SYMPTOM:** `401 Unauthorized` on every API call.
**CAUSE:** Wrong API key, missing `Authorization` header, or wrong key environment (production key against test data or vice versa).
**FIX:** Verify key at `https://app.merge.dev/keys`. Format must be `Authorization: Bearer YOUR_KEY`. Match key environment to data environment.

---

**SYMPTOM:** `400 Bad Request` when calling `/account-token/{public_token}`.
**CAUSE:** Public token already used (one-time only) or expired (~10 min TTL).
**FIX:** Re-trigger Merge Link to get a new public_token. Exchange immediately on receipt — do not store public_tokens.

---

**SYMPTOM:** `link_token` rejected as expired.
**CAUSE:** link_tokens expire after 30 minutes by default.
**FIX:** Generate a fresh link_token on every Merge Link open. Don't cache or reuse them.

---

**SYMPTOM:** Webhook signature verification fails.
**CAUSE:** Wrong webhook secret, body parsed before signature check (must verify against raw bytes), or trailing `=` padding mismatch in base64url.
**FIX:** Use the secret from the webhook config page (not the API key). Verify against raw request body bytes BEFORE parsing JSON. Strip `=` padding on both sides before comparing.

---

**SYMPTOM:** Linked Account shows as "relink_needed" or "incomplete".
**CAUSE:** End-user revoked access in the source provider, or credentials expired.
**FIX:** Trigger your re-connect flow. Generate a new link_token with the existing `end_user_origin_id` and re-open Merge Link. The user re-authorizes and the existing Linked Account is updated (no new account_token).

---

**SYMPTOM:** Field exists on the source provider but not on the Common Model response.
**CAUSE:** Merge's Common Model normalizes across providers. Provider-specific fields go on `remote_data`.
**FIX:** Enable Remote Data on the model (Configuration → Scopes), or use Field Mappings to surface specific provider fields onto the Common Model.

## When to ask the user vs proceed

**Always ask** at start: which category, which SDK language. These shape every code snippet.

**Pick a sensible default** without asking:
- HTTP examples in addition to SDK examples (always show both).
- Test environment first, production second (always default to test).
- Use `end_user_origin_id` = "user_123" as a placeholder; tell them to swap with their real ID.
- Show webhook handlers in the same language as the SDK they picked.

**Ask before proceeding** if:
- The developer's request implies multiple categories ("HRIS and CRM"). Confirm if they want one Linked Account per category or per provider.
- They mention production-sensitive concerns (PII, encryption, multi-region). Pause and confirm before suggesting an architecture.

## Next step: validate your integration

Once the developer has completed the production checklist, suggest:

> Your integration is set up. Want to run a quick health check? Try `/merge-unified:merge-validate` — it'll verify your API key, account_token, sync status, and data access in under a minute.

## Reference docs (for deeper reading)

- Common Model field reference per category: `references/common-models.md`
- SDK install + initialization for all 6 languages: `references/sdk-quickstarts.md`
- Full link_token lifecycle, EndUserDetailsRequest schema, Magic Link variant: `references/auth-flow.md`
- Webhook setup, signature verification, event types per category: `references/webhooks.md`

External:
- Merge docs: https://docs.merge.dev/merge-unified/link/overview/
- API status: https://status.merge.dev
- Sign up: https://app.merge.dev/signup
- Get an API key: https://app.merge.dev/keys
