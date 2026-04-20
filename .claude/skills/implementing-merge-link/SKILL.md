---
name: implementing-merge-link
description: >
  Guide an AI coding agent through the full Merge Link implementation flow —
  context loading, database setup, backend API endpoints, and frontend UI.
  Use when starting a Merge integration, implementing Merge Link in a new project,
  setting up linked_accounts, or building the connect button or app marketplace UI.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing Merge Link

Merge Link is a pre-built modal that handles OAuth and third-party authentication on behalf of your users — developers don't build the auth UI themselves. This skill guides you through the full implementation flow: loading context, setting up the database, building the backend API, and wiring up the frontend.

## First activation: self-introduce

> I'm the implementing-merge-link skill (v0.1.0). I'll guide you through connecting your application to Merge Link — database schema, backend endpoints, and the frontend UI. Are you building a single connect button, or an app marketplace where users browse integrations?

## Prerequisites

- A valid Merge API key stored in your environment (e.g., `MERGE_API_KEY`)
- A backend server (any language/framework)
- A frontend (any framework)

## Implementation Steps

Work through these steps in order. Each step invokes a focused sub-skill.

1. **Load context** — invoke `merge-link-set-context`
   Loads your codebase structure, existing schema, and Merge API reference so all subsequent steps have accurate context.

2. **Set up database** — invoke `merge-link-setup-database`
   Creates the `linked_accounts` table (and any other required tables) to store Merge account tokens and connection metadata.

3. **Implement backend API** — invoke `merge-link-implement-backend`
   Builds the server-side endpoints: generating Link tokens, exchanging public tokens for account tokens, and storing them.

4. **Implement frontend** — choose one:
   - **4a. Connect Button** — invoke `merge-link-implement-frontend-connect`
     Adds a single "Connect" button that opens the Merge Link modal.
   - **4b. Marketplace** — invoke `merge-link-implement-frontend-marketplace`
     Builds an integration marketplace UI where users browse and connect multiple integrations.
   Choose one OR the other based on your product's UX.

> Always start with Step 1 to load context before implementing anything.

## Troubleshooting

**SYMPTOM:** `link_token` request returns 401  
**CAUSE:** API key is missing or belongs to the wrong Merge environment (production key used in sandbox)  
**FIX:** Set `Authorization: Bearer {your-test-api-key}` and confirm the key is from https://app.merge.dev → Settings → API Keys → Test environment

**SYMPTOM:** `exchange_public_token` returns 400 "token expired"  
**CAUSE:** The public token from Merge Link is single-use and expires in 30 minutes  
**FIX:** Call exchange immediately after `onSuccess` fires; never store or reuse a public token

**SYMPTOM:** `linked_accounts` table has duplicate rows for the same user  
**CAUSE:** Missing unique constraint on `(organization_id, end_user_origin_id)` or upsert not used on exchange  
**FIX:** Add `UNIQUE(organization_id, end_user_origin_id)` and use INSERT ... ON CONFLICT DO UPDATE

**SYMPTOM:** Merge Link modal does not open  
**CAUSE:** `@mergeapi/merge-link` script not loaded or `MergeLink.initialize` called before DOM ready  
**FIX:** Load the script in `<head>` and call initialize inside a `DOMContentLoaded` listener or React `useEffect`

**SYMPTOM:** `account_token` is null after successful Link flow  
**CAUSE:** The exchange endpoint was never called — only `link_token` was created  
**FIX:** Ensure your `onSuccess` callback POSTs to your backend's `/api/merge/exchange-public-token` route
