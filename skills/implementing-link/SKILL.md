---
name: implementing-link
description: >
  Guide an AI coding agent through the full Merge Link implementation flow —
  context loading, database setup, backend API endpoints, and frontend UI.
  Use when starting a Merge integration, implementing Merge Link in a new project,
  setting up linked_accounts, or building the connect button or app marketplace UI.
license: MIT
metadata:
  author: Merge
  version: 0.5.1
---

# Implementing Merge Link

Merge Link is a pre-built modal that handles OAuth and third-party authentication on behalf of your users — developers don't build the auth UI themselves. This skill guides you through the full implementation flow: loading context, setting up the database, building the backend API, and wiring up the frontend.

## First activation: self-introduce

> I'm the implementing-link skill. I'll guide you through connecting your application to Merge Link — database schema, backend endpoints, and the frontend UI. Are you building a single connect button, or an app marketplace where users browse integrations?

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

- **Tech stack** language, framework, ORM
- **Existing database schema** (migrations, models, or schema files)
- **Any existing Merge-related code** (search for `merge`, `MERGE_API_KEY`, `account_token`)
- **Backend Merge SDK installed?** Search the project's manifest for the language-appropriate package: `@mergeapi/merge-node-client` (package.json), `MergePythonClient` (requirements.txt / pyproject.toml), `dev.merge:merge-java-client` (pom.xml / build.gradle), `merge-go-client` (go.mod), `merge_ruby_client` (Gemfile), `Merge.Client` (.csproj). Record yes/no and which language.
- **React Merge Link SDK installed?** If the frontend is React, also search for `@mergeapi/react-merge-link` in package.json. Record yes/no (or N/A if not React).
- **Merge categories in use?** Look for table names (`employees`, `candidates`, `contacts`, `deals`), route names, model names, or README/CLAUDE.md references to HR, recruiting, CRM, ticketing, etc. Record what you find or `unknown`.
- **Organization/tenant table?** Find the table or model representing the user's customer organization or tenant — look for names like `organizations`, `companies`, `tenants`, `accounts`, `workspaces`. Record the table name and its primary key column, or `not found`.

**1c. Confirm readiness** with a brief summary:

1. Tech stack identified (language, framework, ORM)
2. Merge docs loaded (list the three files read)
3. Any existing Merge code found (or none)
4. Backend Merge SDK installed: yes / no
5. React Merge Link SDK installed: yes / no / N/A
6. Inferred categories: (list) or `unknown`
7. Organization/tenant table: `{table}.{pk}` or `not found`

**1d. Ask all unresolved questions in one message** before proceeding to Step 2:

> Before I start building, I have a few quick questions:
>
> 1. **Categories**: Based on your codebase I believe you're implementing [inferred list, or "—"]. Which Merge categories are you implementing? (`hris`, `ats`, `crm`, `accounting`, `ticketing`, `filestorage`, `knowledgebase`, `mktg`)
>
> 2. **Linked Account strategy** — at the Merge API level, `end_user_origin_id` + `category` determines uniqueness:
>    - **Strategy 1**: Use a stable per-org identifier as `end_user_origin_id` (e.g. a GUID on your org record). Each org can have **1 Linked Account per category** (one HRIS, one ATS, etc.).
>    - **Strategy 2**: Generate a new GUID per connection as `end_user_origin_id`. Each org can have **multiple Linked Accounts per category** (e.g. two different HRIS systems).
>    Which do you need?
>
> 3. **Backend SDK preference**: [If not installed:] Would you prefer the official Merge SDK (recommended — handles types and retries) or raw HTTP? [If already installed:] I see the Merge SDK is in your dependencies — I'll use it unless you prefer raw HTTP.
>
> 4. **Organization table**: [If found:] I found `{table}` as your org/tenant table — I'll FK `linked_accounts.organization_id` to `{table}.{pk}`. Is that correct? [If not found:] What is the table or model that represents a customer organization or tenant in your system?
>
> 5. **Frontend SDK** *(React projects only)*: [If `@mergeapi/react-merge-link` not installed:] Would you prefer the React Merge Link SDK (`@mergeapi/react-merge-link`, recommended — uses the `useMergeLink` hook) or CDN+vanilla JS? [If already installed:] I see `@mergeapi/react-merge-link` in your dependencies — I'll use it unless you prefer the CDN approach. [If not React:] Skipped.

Record the user's answers. Carry them as context into all sub-skills (Steps 2–4).

### Step 2: Set up database — invoke `link-setup-database`

Creates the `linked_accounts` table (and any other required tables) to store Merge account tokens and connection metadata.

### Step 3: Implement backend API — invoke `link-implement-backend`

Builds the server-side endpoints: generating Link tokens, exchanging public tokens for account tokens, and storing them.

### Step 4: Implement frontend — choose one

- **4a. Connect Button** — invoke `link-implement-frontend-connect`
  Adds a single "Connect" button that opens the Merge Link modal.
- **4b. Marketplace** — invoke `link-implement-frontend-marketplace`
  Builds an integration marketplace UI where users browse and connect multiple integrations.

Choose one OR the other based on your product's UX.

**Before invoking the Marketplace skill (4b only):** Scan the frontend for an existing integrations page, marketplace, or app catalog. Look for files or routes named `marketplace`, `integrations`, `app-center`, `catalog`, or similar.

- If an existing page is found: identify the exact file and location where the integration catalog would be inserted. Tell the user what you found.
- If no existing page is found: ask — "I didn't find an existing marketplace page in your frontend. Do you have design mockups? If not, I can generate a marketplace UI that matches your app's existing component style."

If you chose the Connect Button (4a), skip the pre-scan and invoke `link-implement-frontend-connect` directly.

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
**FIX:** React: `npm install @mergeapi/react-merge-link` and use the `useMergeLink` hook (see `/merge-unified:onboarding` Step 4 for the full setup). Vanilla JS: include `<script src="https://cdn.merge.dev/initialize.js"></script>` in `<head>` and call `MergeLink.initialize` inside a `DOMContentLoaded` listener.

**SYMPTOM:** `account_token` is null after successful Link flow  
**CAUSE:** The exchange endpoint was never called — only `link_token` was created  
**FIX:** Ensure your `onSuccess` callback POSTs to your backend's `/api/merge/exchange-public-token` route
