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
  version: 0.3.0
---

# Implementing Merge Link

Merge Link is a pre-built modal that handles OAuth and third-party authentication on behalf of your users — developers don't build the auth UI themselves. This skill guides you through the full implementation flow: loading context, setting up the database, building the backend API, and wiring up the frontend.

## First activation: self-introduce

> I'm the implementing-merge-link skill (v0.2.0). I'll guide you through connecting your application to Merge Link — database schema, backend endpoints, and the frontend UI. Are you building a single connect button, or an app marketplace where users browse integrations?

## Prerequisites

- A valid Merge API key stored in your environment (e.g., `MERGE_API_KEY`)
- A backend server (any language/framework)
- A frontend (any framework)

## Implementation Steps

Work through these steps in order. Steps 2–4 invoke focused sub-skills; Step 1 runs inline.

### Step 1: Load context

Do **not** write any code in this step. Read the reference docs first, then scan the codebase, then confirm readiness.

**1a. Read all three reference docs:**

- `references/platform-overview.md` — Core Merge concepts, auth flow, account lifecycle
- `references/backend-implementation.md` — Backend API patterns, token exchange, database schema
- `references/frontend-implementation.md` — Frontend UI patterns (Connect Button and Marketplace)

Read each file completely before proceeding.

**1b. Scan the codebase.** Ask the user first:

> "I'll search your codebase for your tech stack, existing schema, and any Merge-related code. Ready to proceed?"

Then identify:

- Tech stack: language, framework, ORM
- Existing database schema (migrations, models, or schema files)
- Any existing Merge-related code (search for `merge`, `MERGE_API_KEY`, `account_token`)

**1c. Confirm readiness** with a brief summary:

1. Tech stack identified (language, framework, ORM)
2. Merge docs loaded (list the three files read)
3. Any existing Merge code found (or none)
4. Ready to proceed to the next implementation step

### Step 2: Set up database — invoke `merge-link-setup-database`

Creates the `linked_accounts` table (and any other required tables) to store Merge account tokens and connection metadata.

### Step 3: Implement backend API — invoke `merge-link-implement-backend`

Builds the server-side endpoints: generating Link tokens, exchanging public tokens for account tokens, and storing them.

### Step 4: Implement frontend — choose one

- **4a. Connect Button** — invoke `merge-link-implement-frontend-connect`
  Adds a single "Connect" button that opens the Merge Link modal.
- **4b. Marketplace** — invoke `merge-link-implement-frontend-marketplace`
  Builds an integration marketplace UI where users browse and connect multiple integrations.

Choose one OR the other based on your product's UX.

> Always complete Step 1 (load context) before starting Step 2.

## Troubleshooting

**SYMPTOM:** `link_token` request returns 401  
**CAUSE:** API key is missing or belongs to the wrong Merge environment (production key used in sandbox)  
**FIX:** Set `Authorization: Bearer {your-test-api-key}` and confirm the key is from https://app.merge.dev → Settings → API Keys → Test environment

**SYMPTOM:** `exchange_public_token` returns 400 "token expired"  
**CAUSE:** The public token from Merge Link is single-use and has a short TTL (~10 min). Either it was already exchanged once, or `/exchange` was deferred (e.g., to a background job) and the window passed.  
**FIX:** Call exchange immediately after `onSuccess` fires; never store or reuse a public token

**SYMPTOM:** `linked_accounts` table has duplicate rows for the same user  
**CAUSE:** Missing unique constraint on `(organization_id, end_user_origin_id)` or upsert not used on exchange  
**FIX:** Add `UNIQUE(organization_id, end_user_origin_id)` and use INSERT ... ON CONFLICT DO UPDATE

**SYMPTOM:** Merge Link modal does not open  
**CAUSE:** Merge Link wasn't loaded before invocation. For React, `@mergeapi/react-merge-link` (npm) wasn't installed or imported. For vanilla JS, the CDN script `https://cdn.merge.dev/initialize.js` wasn't loaded yet, or `MergeLink.initialize` was called before DOM ready.  
**FIX:** React: `npm install @mergeapi/react-merge-link` and use the `useMergeLink` hook (see `/merge-unified:merge-onboarding` Step 4 for the full setup). Vanilla JS: include `<script src="https://cdn.merge.dev/initialize.js"></script>` in `<head>` and call `MergeLink.initialize` inside a `DOMContentLoaded` listener.

**SYMPTOM:** `account_token` is null after successful Link flow  
**CAUSE:** The exchange endpoint was never called — only `link_token` was created  
**FIX:** Ensure your `onSuccess` callback POSTs to your backend's `/api/merge/exchange-public-token` route
